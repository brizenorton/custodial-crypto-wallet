-- =============================================================================
-- Payment System Database — TRIGGERS
-- Описание: Триггеры для автоматической агрегации данных транзакций
--           в таблицы callback_histories и account_transactions.
--
-- Логика:
--   При INSERT в родительские таблицы (customer_wallet_transactions,
--   merchant_transit_wallet_transactions, payouts) автоматически создаются
--   записи в дочерних таблицах callback_histories и account_transactions.
-- =============================================================================

SET search_path = public;

-- =============================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ ТРИГГЕРОВ
-- =============================================================================

-- -----------------------------------------------------------------------
-- Функция: trigger_cwt_to_callback_history
-- Назначение: При появлении новой транзакции клиентского кошелька
--             создаёт новую запись в callback_histories.
-- -----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trigger_cwt_to_callback_history()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_callback_url CHARACTER VARYING;
BEGIN
    -- 1. Ищем callback_url в таблице кошельков по адресу и валюте из новой транзакции
    SELECT callback_url 
    INTO v_callback_url
    FROM customer_wallets
    WHERE wallet_address = NEW.to_address
      AND crypto_currency = NEW.crypto_currency
    LIMIT 1;

    -- 2. Финансовый предохранитель: если кошелёк не найден, логируем это или ставим дефолт,
    -- чтобы триггер не упал с ошибкой из-за ограничения NOT NULL на поле url в callback_histories
    IF v_callback_url IS NULL THEN
        RAISE NOTICE 'Warning: No customer wallet found for address % and currency %. Callback record skipped.', 
                     NEW.to_address, NEW.crypto_currency;
        RETURN NEW;
    END IF;

    -- 3. Вставляем запись в историю колбэков, используя найденный URL
    INSERT INTO callback_histories
        (type, url, type_external_id, sent_data, payload_status)
    VALUES (
        'CUSTOMER_WALLET_TRANSACTION',
        v_callback_url, -- Используем локальную переменную вместо NEW.callback_url
        NEW.id::text,
        jsonb_build_object(
            'id',              NEW.id,
            'status',          NEW.status,
            'crypto_currency', NEW.crypto_currency,
            'value',           NEW.value,
            'fee',             NEW.fee,
            'to_address',      NEW.to_address,
            'merchant_id',     NEW.merchant_id,
            'type',            NEW.type,
            'created_at',      NEW.created_at
        ),
        'PENDING'::"public"."CallbackPayloadStatus"
    );
    
    RETURN NEW;
END;
$function$
;

-- -----------------------------------------------------------------------
-- Функция: trigger_mtwt_to_callback_history
-- Назначение: При появлении новой транзакции транзитного кошелька
--             создаёт начальную запись в callback_histories.
-- -----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_mtwt_to_callback_history()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO callback_histories
        (type, url, type_external_id, sent_data, payload_status)
    VALUES (
        'MERCHANT_TRANSIT_WALLET_TRANSACTION',
        '',  -- у mtwt нет прямого callback_url в таблице; будет заполнено сервисом
        NEW.id::text,
        jsonb_build_object(
            'id',              NEW.id,
            'status',          NEW.status,
            'crypto_currency', NEW.crypto_currency,
            'crypto_value',    NEW.crypto_value,
            'fee',             NEW.fee,
            'to',              NEW.to,
            'merchant_id',     NEW.merchant_id,
            'type',            NEW.type,
            'created_at',      NEW.created_at
        ),
        'PENDING'::"public"."CallbackPayloadStatus"
    );
    RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------
-- Функция: trigger_payout_to_callback_history
-- Назначение: При создании новой выплаты создаёт
--             начальную запись в callback_histories.
-- -----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_payout_to_callback_history()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO callback_histories
        (type, url, type_external_id, sent_data, payload_status)
    VALUES (
        'PAYOUT_TRANSACTION',
        NEW.callback_url,
        NEW.id::text,
        jsonb_build_object(
            'id',               NEW.id,
            'external_id',      NEW.external_id,
            'status',           NEW.status,
            'crypto_currency',  NEW.crypto_currency,
            'crypto_amount',    NEW.crypto_amount,
            'fiat_currency',    NEW.fiat_currency,
            'fiat_amount',      NEW.fiat_amount,
            'recipient_address', NEW.recipient_address,
            'merchant_id',      NEW.merchant_id,
            'creation_method',  NEW.creation_method,
            'created_at',       NEW.created_at
        ),
        'SUBMITTED'::"public"."CallbackPayloadStatus"
    );
    RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------
-- Функция: trigger_cwt_to_account_transaction
-- Назначение: При появлении новой транзакции клиентского кошелька
--             создаёт запись в account_transactions (если есть account_id).
-- -----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_cwt_to_account_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.account_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Проверяем уникальность (original_transaction_id, type) перед вставкой
    IF EXISTS (
        SELECT 1 FROM account_transactions
        WHERE original_transaction_id = NEW.id
          AND type = 'CUSTOMER_TRANSACTION'::"public"."AccountTransactionType"
    ) THEN
        RETURN NEW;
    END IF;

    INSERT INTO account_transactions
        (account_id, amount, currency, type, status, original_transaction_id, timestamp)
    VALUES (
        NEW.account_id,
        NEW.value,
        NEW.crypto_currency,
        'CUSTOMER_TRANSACTION'::"public"."AccountTransactionType",
        NEW.status,
        NEW.id,
        NEW.created_at
    );

    RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------
-- Функция: trigger_mtwt_to_account_transaction
-- Назначение: При появлении новой транзакции транзитного кошелька
--             создаёт запись в account_transactions (если есть account_id).
-- -----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_mtwt_to_account_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.account_id IS NULL THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        SELECT 1 FROM account_transactions
        WHERE original_transaction_id = NEW.id
          AND type = 'MERCHANT_TRANSACTION'::"public"."AccountTransactionType"
    ) THEN
        RETURN NEW;
    END IF;

    INSERT INTO account_transactions
        (account_id, amount, currency, type, status, original_transaction_id, timestamp)
    VALUES (
        NEW.account_id,
        NEW.crypto_value,
        NEW.crypto_currency,
        'MERCHANT_TRANSACTION'::"public"."AccountTransactionType",
        NEW.status,
        NEW.id,
        NEW.created_at
    );

    RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------
-- Функция: trigger_payout_to_account_transaction
-- Назначение: При создании новой выплаты создаёт запись в account_transactions
--             (тип PAYOUT) через account мерчанта.
-- -----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_payout_to_account_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_account_id UUID;
BEGIN
    -- Получаем account_id мерчанта
    SELECT account_id INTO v_account_id
    FROM merchants
    WHERE id = NEW.merchant_id;

    IF v_account_id IS NULL THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        SELECT 1 FROM account_transactions
        WHERE original_transaction_id = NEW.id
          AND type = 'PAYOUT'::"public"."AccountTransactionType"
    ) THEN
        RETURN NEW;
    END IF;

    INSERT INTO account_transactions
        (account_id, amount, currency, type, status, original_transaction_id, timestamp)
    VALUES (
        v_account_id,
        NEW.crypto_amount,
        NEW.crypto_currency,
        'PAYOUT'::"public"."AccountTransactionType",
        'PENDING'::"public"."TransactionStatus",
        NEW.id,
        NEW.created_at
    );

    RETURN NEW;
END;
$$;


-- =============================================================================
-- ТРИГГЕРЫ
-- =============================================================================

-- Удаляем старые версии триггеров перед созданием (идемпотентность скрипта)
DROP TRIGGER IF EXISTS trg_cwt_to_callback_history   ON customer_wallet_transactions;
DROP TRIGGER IF EXISTS trg_mtwt_to_callback_history  ON merchant_transit_wallet_transactions;
DROP TRIGGER IF EXISTS trg_payout_to_callback_history ON payouts;
DROP TRIGGER IF EXISTS trg_cwt_to_account_transaction   ON customer_wallet_transactions;
DROP TRIGGER IF EXISTS trg_mtwt_to_account_transaction  ON merchant_transit_wallet_transactions;
DROP TRIGGER IF EXISTS trg_payout_to_account_transaction ON payouts;


-- -----------------------------------------------------------------------
-- Триггеры для callback_histories
-- -----------------------------------------------------------------------

-- После INSERT в customer_wallet_transactions → callback_histories
CREATE TRIGGER trg_cwt_to_callback_history
    AFTER INSERT ON customer_wallet_transactions
    FOR EACH ROW
    EXECUTE FUNCTION trigger_cwt_to_callback_history();

-- После INSERT в merchant_transit_wallet_transactions → callback_histories
CREATE TRIGGER trg_mtwt_to_callback_history
    AFTER INSERT ON merchant_transit_wallet_transactions
    FOR EACH ROW
    EXECUTE FUNCTION trigger_mtwt_to_callback_history();

-- После INSERT в payouts → callback_histories
CREATE TRIGGER trg_payout_to_callback_history
    AFTER INSERT ON payouts
    FOR EACH ROW
    EXECUTE FUNCTION trigger_payout_to_callback_history();


-- -----------------------------------------------------------------------
-- Триггеры для account_transactions
-- -----------------------------------------------------------------------

-- После INSERT в customer_wallet_transactions → account_transactions
CREATE TRIGGER trg_cwt_to_account_transaction
    AFTER INSERT ON customer_wallet_transactions
    FOR EACH ROW
    EXECUTE FUNCTION trigger_cwt_to_account_transaction();

-- После INSERT в merchant_transit_wallet_transactions → account_transactions
CREATE TRIGGER trg_mtwt_to_account_transaction
    AFTER INSERT ON merchant_transit_wallet_transactions
    FOR EACH ROW
    EXECUTE FUNCTION trigger_mtwt_to_account_transaction();

-- После INSERT в payouts → account_transactions
CREATE TRIGGER trg_payout_to_account_transaction
    AFTER INSERT ON payouts
    FOR EACH ROW
    EXECUTE FUNCTION trigger_payout_to_account_transaction();
