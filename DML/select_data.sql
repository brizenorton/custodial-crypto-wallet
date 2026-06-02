-- =============================================================================
-- Payment System Database — SELECT DATA
-- Описание: Примеры выборок из основных таблиц. Это возможные паттерны из репозиториев приложения.
-- =============================================================================

-- =============================================================================
-- accounts
-- =============================================================================

-- Получить аккаунт по ID
SELECT id, created_at, updated_at
FROM accounts
WHERE id = 'a1000000-0000-0000-0000-000000000001';


-- =============================================================================
-- rates
-- =============================================================================

-- Получить последний курс для конкретной валюты и фиатной пары
SELECT id, crypto_currency, fiat_rates, type, created_at
FROM rates
WHERE crypto_currency = 'BTC'::"public"."RateCryptoCurrency"
  AND fiat_rates ? 'USD'
  AND type = 'EXTERNAL'::"public"."RateType"
ORDER BY created_at DESC
LIMIT 1;

-- Получить курс на конкретную дату (для исторических расчётов)
SELECT id, crypto_currency, fiat_rates, type, created_at
FROM rates
WHERE crypto_currency = 'USDT'::"public"."RateCryptoCurrency"
  AND fiat_rates ? 'EUR'
  AND type = 'EXTERNAL'::"public"."RateType"
  AND created_at < '2024-11-01 12:00:00'
ORDER BY created_at DESC
LIMIT 1;

-- Получить последние курсы для всех криптовалют (DISTINCT ON — PostgreSQL)
SELECT DISTINCT ON (crypto_currency)
    id, crypto_currency, fiat_rates, type, created_at
FROM rates
WHERE type = 'EXTERNAL'::"public"."RateType"
ORDER BY crypto_currency, created_at DESC;

-- Рекурсивный CTE: последний курс по каждой валюте (производительный вариант)
WITH RECURSIVE cte AS (
    (
        SELECT id, crypto_currency, fiat_rates, type, created_at
        FROM rates
        WHERE type = 'EXTERNAL'::"public"."RateType"
        ORDER BY crypto_currency, created_at DESC
        LIMIT 1
    )
    UNION ALL
    SELECT r.*
    FROM cte c
    CROSS JOIN LATERAL (
        SELECT r.id, r.crypto_currency, r.fiat_rates, r.type, r.created_at
        FROM rates r
        WHERE r.type = 'EXTERNAL'::"public"."RateType"
          AND r.crypto_currency > c.crypto_currency
        ORDER BY r.crypto_currency, r.created_at DESC
        LIMIT 1
    ) r
)
TABLE cte ORDER BY crypto_currency;


-- =============================================================================
-- merchants
-- =============================================================================

-- Получить мерчанта по ID с его кошельками
SELECT m.id, m.name, m.type, m.account_id,
       w.id AS wallet_id, w.address, w.crypto_currency
FROM merchants m
LEFT JOIN merchant_wallets w ON m.id = w.merchant_id
WHERE m.id = 'c3000000-0000-0000-0000-000000000001';

-- Получить мерчанта по account_id
SELECT m.id, m.name, m.type, m.account_id
FROM merchants m
WHERE m.account_id = 'a1000000-0000-0000-0000-000000000001';

-- Список всех мерчантов с типом ENTERPRISE
SELECT id, name, type, created_at
FROM merchants
WHERE type = 'ENTERPRISE'::"public"."MerchantType"
ORDER BY created_at DESC;

-- Поиск мерчантов по массиву ID (для bulk-операций)
SELECT id, name, account_id
FROM merchants
WHERE id = ANY(
    ARRAY[
        'c3000000-0000-0000-0000-000000000001',
        'c3000000-0000-0000-0000-000000000002'
    ]::uuid[]
);


-- =============================================================================
-- merchant_credentials
-- =============================================================================

-- Получить учётные данные по API-ключу (аутентификация запроса)
SELECT mc.id, mc.merchant_id, mc.external_id, mc.status, mc.ip_addresses, mc.for_callback
FROM merchant_credentials mc
WHERE mc.api_key = 'api_key_acme_main_example'
  AND mc.status  = 'ACTIVE'::"public"."MerchantCredentialStatus";

-- Получить callback-credential мерчанта
SELECT mc.id, mc.merchant_id, mc.api_key, mc.status
FROM merchant_credentials mc
WHERE mc.merchant_id  = 'c3000000-0000-0000-0000-000000000001'
  AND mc.for_callback = true;

-- Все активные credential мерчанта
SELECT id, external_id, status, ip_addresses, for_callback
FROM merchant_credentials
WHERE merchant_id = 'c3000000-0000-0000-0000-000000000001'
  AND status      = 'ACTIVE'::"public"."MerchantCredentialStatus";


-- =============================================================================
-- customer_wallets
-- =============================================================================

-- Найти кошелёк по адресу и валюте
SELECT *
FROM customer_wallets cw
WHERE cw.wallet_address  = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh'
  AND cw.crypto_currency = 'BTC'::"public"."CryptoCurrency";

-- Найти кошелёк по merchant_id + customer_id
SELECT *
FROM customer_wallets
WHERE merchant_id = 'c3000000-0000-0000-0000-000000000001'
  AND customer_id = 'client-001'
  AND status      = 'ACTIVE'::"public"."WalletStatus";

-- Поиск кошелька с приоритетами (customer_id → merchant_account_id → merchant_user_id)
WITH search_results AS (
    SELECT cw.*, 1 AS priority
    FROM customer_wallets cw
    WHERE cw.merchant_id    = 'c3000000-0000-0000-0000-000000000001'
      AND cw.customer_id    = 'client-001'
      AND cw.crypto_currency = 'BTC'::"public"."CryptoCurrency"
    UNION ALL
    SELECT cw.*, 2 AS priority
    FROM customer_wallets cw
    WHERE cw.merchant_id       = 'c3000000-0000-0000-0000-000000000001'
      AND cw.merchant_account_id = 'ext-account-001'
    UNION ALL
    SELECT cw.*, 3 AS priority
    FROM customer_wallets cw
    WHERE cw.merchant_id     = 'c3000000-0000-0000-0000-000000000001'
      AND cw.merchant_user_id = 'ext-user-001'
)
SELECT DISTINCT ON (id) *
FROM search_results
ORDER BY id, priority ASC, created_at DESC
LIMIT 10;


-- =============================================================================
-- customer_wallet_transactions
-- =============================================================================

-- Получить транзакцию по ID с курсом
SELECT cwt.id, cwt.txid, cwt.vout, cwt.crypto_currency, cwt.value, cwt.fee,
       cwt.status, cwt.aml_status, cwt.is_collected, cwt.value, cwt.fiat_value,
       r.id AS rate_id, r.fiat_rates
FROM customer_wallet_transactions cwt
LEFT JOIN rates r ON cwt.rate_id = r.id
WHERE cwt.id = 'aa000000-0000-0000-0000-000000000001';

-- Поиск транзакции по txid + vout + валюта (дедупликация on-chain)
SELECT *
FROM customer_wallet_transactions
WHERE crypto_currency = 'BTC'::"public"."CryptoCurrency"
  AND txid = 'btc_txid_example_0000000000000000000000000000000000000000000001'
  AND vout = 0;

-- Несобранные транзакции на адресе для collect-задачи
SELECT *
FROM customer_wallet_transactions
WHERE to_address      = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh'
  AND crypto_currency = 'BTC'::"public"."CryptoCurrency"
  AND is_collected    = false
  AND status          = 'SUCCESSFUL'::"public"."TransactionStatus"
  AND aml_status      IN ('COMPLETED', 'STUCK')
ORDER BY created_at ASC;


-- =============================================================================
-- merchant_transit_wallet_transactions
-- =============================================================================

-- Получить транзакцию с курсом по ID
SELECT mtwt.*,
       r.id as rate_id, r.fiat_rates
FROM merchant_transit_wallet_transactions mtwt
LEFT JOIN rates r ON mtwt.rate_id = r.id
WHERE mtwt.id = 'bb000000-0000-0000-0000-000000000001';

-- Транзакции по мерчанту, валюте и типу для аналитики
SELECT id, txid, crypto_value, fee, status, created_at
FROM merchant_transit_wallet_transactions
WHERE merchant_id     = 'c3000000-0000-0000-0000-000000000001'
  AND crypto_currency = 'BTC'::"public"."CryptoCurrency"
  AND type            = 'CORRECT'::"public"."MerchantTransitWalletTransactionType"
ORDER BY created_at DESC
LIMIT 50;


-- =============================================================================
-- payouts
-- =============================================================================

-- Получить выплату по ID с курсом
SELECT p.id, p.external_id, p.status, p.recipient_address,
       p.crypto_amount, p.crypto_currency, p.fiat_amount, p.fiat_currency,
       p.fee, p.txid, p.creation_method, p.aml_status,
       r.id AS rate_id, r.fiat_rates
FROM payouts p
LEFT JOIN rates r ON p.rate_id = r.id
WHERE p.id = 'cc000000-0000-0000-0000-000000000001';

-- Найти выплату по external_id и merchant_id
SELECT id, status, crypto_amount, crypto_currency, txid
FROM payouts
WHERE external_id = 'payout-acme-2024-001'
  AND merchant_id = 'c3000000-0000-0000-0000-000000000001';

-- Список выплат в статусе QUEUED для обработки (с пагинацией)
SELECT id, external_id, merchant_id, crypto_currency, crypto_amount, created_at
FROM payouts
WHERE status = 'QUEUED'::"public"."payouts_status_enum"
ORDER BY created_at ASC
LIMIT 20 OFFSET 0;

-- Выплаты мерчанта за период с фильтрацией по валюте
SELECT id, external_id, status, crypto_amount, crypto_currency,
       fiat_amount, fiat_currency, txid, created_at
FROM payouts
WHERE merchant_id     = 'c3000000-0000-0000-0000-000000000001'
  AND crypto_currency = 'USDT-TRC20'::"public"."CryptoCurrency"
  AND created_at      BETWEEN '2024-01-01' AND '2024-12-31'
ORDER BY created_at DESC;


-- =============================================================================
-- payout_transfers
-- =============================================================================

-- Получить последнюю попытку перевода для выплаты
SELECT id, payout_id, status, attempt, txid, fee, amount, currency
FROM payout_transfers
WHERE payout_id = 'cc000000-0000-0000-0000-000000000001'
ORDER BY created_at DESC, id DESC
LIMIT 1;

-- Количество попыток и наличие успешных для retry-логики
SELECT
    MAX(attempt)                                           AS max_attempt,
    BOOL_OR(status = 'SUCCESSFUL'::"public"."payout_transfers_status_enum") AS has_successful,
    BOOL_OR(status = 'FAILED'::"public"."payout_transfers_status_enum")     AS has_failed
FROM payout_transfers
WHERE payout_id = 'cc000000-0000-0000-0000-000000000001';


-- =============================================================================
-- refunds
-- =============================================================================

-- Получить все возвраты по транзакции
SELECT *
FROM refunds
WHERE transaction_id   = 'aa000000-0000-0000-0000-000000000001'
  AND transaction_type = 'CUSTOMER_WALLET_TRANSACTION'::"public"."RefundTransactionType";

-- Возвраты в процессе обработки
SELECT r.*,
       rt.status AS transfer_status, rt.txid
FROM refunds r
LEFT JOIN refund_transfers rt ON rt.refund_id = r.id
WHERE r.status IN ('SUBMITTED', 'PENDING')
ORDER BY r.created_at ASC;


-- =============================================================================
-- transfers
-- =============================================================================

-- Активные переводы на адрес (ожидают отправки)
SELECT *
FROM transfers
WHERE "to"    = 'transit_btc_address_acme_0001'
  AND currency = 'BTC'::"public"."CryptoCurrency"
  AND status  NOT IN (
      'COMPLETED'::"public"."TransferStatus",
      'FAILED'::"public"."TransferStatus"
  );

-- Переводы без txid (для проверки дублей перед отправкой)
SELECT id, value, currency, "from", "to", created_at
FROM transfers
WHERE merchant_id = 'c3000000-0000-0000-0000-000000000001'
  AND txid IS NULL
  AND created_at >= now() - INTERVAL '24 hours';


-- =============================================================================
-- transaction_data
-- =============================================================================

-- Получить данные транзакции по source_external_id
SELECT *
FROM transaction_data
WHERE source_external_id = 'aa000000-0000-0000-0000-000000000001'
  AND source_type        = 'CUSTOMER_WALLET_TRANSACTION'::"public"."TransactionSourceType";

-- История транзакций мерчанта с пагинацией и фильтрацией
SELECT *
FROM transaction_data td
WHERE td.merchant_id = 'c3000000-0000-0000-0000-000000000001'
  AND td.created_at  BETWEEN '2024-01-01' AND '2024-12-31'
  AND td.status      = 'COMPLETED'::"public"."transaction_data_status_enum"
ORDER BY td.created_at DESC
LIMIT 50 OFFSET 0;

-- Агрегация оборота по мерчанту, валюте и типу транзакции
SELECT source_type, crypto_currency, fiat_currency,
       COUNT(*)            AS tx_count,
       SUM(crypto_amount)  AS total_crypto,
       SUM(fiat_amount)    AS total_fiat,
       SUM(COALESCE(fee, 0)) AS total_fee
FROM transaction_data
WHERE merchant_id = 'c3000000-0000-0000-0000-000000000001'
  AND status      = 'COMPLETED'::"public"."transaction_data_status_enum"
  AND created_at  >= date_trunc('month', now())
GROUP BY source_type, crypto_currency, fiat_currency
ORDER BY source_type, total_fiat DESC;


-- =============================================================================
-- callback_histories
-- =============================================================================

-- История колбэков по транзакции (по возрастанию для аудита)
SELECT *
FROM callback_histories
WHERE type_external_id = 'aa000000-0000-0000-0000-000000000001'
ORDER BY created_at ASC;

-- Последний колбэк по транзакции (для проверки текущего статуса)
SELECT *
FROM callback_histories
WHERE type             = 'CUSTOMER_WALLET_TRANSACTION'
  AND type_external_id = 'aa000000-0000-0000-0000-000000000001'
ORDER BY created_at DESC
LIMIT 1;

-- Проверка успешности доставки колбэка
SELECT EXISTS (
    SELECT 1
    FROM callback_histories
    WHERE response_status  = 200
      AND type             = 'PAYOUT_TRANSACTION'
      AND type_external_id = 'cc000000-0000-0000-0000-000000000001'
) AS is_delivered;

-- Кандидаты на повтор отправки (нет успешного колбэка за последние N секунд)
WITH retry_candidates AS (
    SELECT DISTINCT ON (ch.type_external_id)
        ch.type_external_id, ch.sent_data, ch.type, ch.url, ch.updated_at
    FROM callback_histories ch
    WHERE ch.type    = 'PAYOUT_TRANSACTION'
      AND ch.updated_at >= now() - INTERVAL '1 hour'
      AND NOT EXISTS (
          SELECT 1
          FROM callback_histories ok
          WHERE ok.response_status  = 200
            AND ok.type_external_id = ch.type_external_id
      )
    ORDER BY ch.type_external_id, ch.created_at DESC
)
SELECT type_external_id, url, sent_data->>'status' AS last_status, updated_at
FROM retry_candidates
LIMIT 100;

-- Колбэки мерчанта (UNION по всем типам источников)
SELECT ch.id, ch.type, ch.type_external_id,
       ch.sent_data->>'status' AS tx_status,
       ch.response_status, ch.updated_at
FROM callback_histories ch
WHERE ch.type_external_id IN (
    SELECT id::text FROM payouts WHERE merchant_id = 'c3000000-0000-0000-0000-000000000001'
    UNION ALL
    SELECT id::text FROM customer_wallet_transactions WHERE merchant_id::text = 'c3000000-0000-0000-0000-000000000001'
)
ORDER BY ch.updated_at DESC
LIMIT 20;


-- =============================================================================
-- config_properties
-- =============================================================================

-- Получить актуальное значение конфигурации (последняя запись по дате)
SELECT DISTINCT ON (name) id, name, value, created_at
FROM config_properties
WHERE issuer_id = 'c3000000-0000-0000-0000-000000000001'
ORDER BY name, created_at DESC;

-- Получить конкретный параметр конфигурации
SELECT value
FROM config_properties
WHERE issuer_id = 'c3000000-0000-0000-0000-000000000001'
  AND name      = 'BITCOIN_MINIMUM_PAYOUT_AMOUNT'::"public"."ConfigPropertyName"
ORDER BY created_at DESC
LIMIT 1;

-- Все AML-параметры мерчанта
SELECT name, value, created_at
FROM config_properties
WHERE issuer_id = 'c3000000-0000-0000-0000-000000000001'
  AND name::text LIKE 'MAX_%'
ORDER BY name;


-- =============================================================================
-- aml_scorings
-- =============================================================================

-- Получить AML-оценку по txid
SELECT id, txid, status, type, scoring_data, error, created_at
FROM aml_scorings
WHERE txid                 = 'btc_txid_example_0000000000000000000000000000000000000000000001'
  AND source_transaction_id = 'aa000000-0000-0000-0000-000000000001';

-- AML-проверки в ожидании (для мониторинга)
SELECT id, txid, address, type, status, created_at
FROM aml_scorings
WHERE status IN (
    'PENDING'::"public"."CrystalAmlAnalysisStatus",
    'STUCK'::"public"."CrystalAmlAnalysisStatus"
)
ORDER BY created_at ASC;


-- =============================================================================
-- account_fees
-- =============================================================================

-- Комиссии аккаунта по валюте
SELECT *
FROM account_fees
WHERE account_id = 'a1000000-0000-0000-0000-000000000001'
  AND currency   = 'BTC'::"public"."CryptoCurrency";


-- =============================================================================
-- fee_policies
-- =============================================================================

-- Получить политику комиссий аккаунта для типа транзакции
SELECT *
FROM fee_policies
WHERE account_id       = 'a1000000-0000-0000-0000-000000000001'
  AND transaction_type = 'PAYOUT'::"public"."AccountTransactionType"
ORDER BY created_at DESC
LIMIT 1;

-- Все политики комиссий аккаунта
SELECT *
FROM fee_policies
WHERE account_id = 'a1000000-0000-0000-0000-000000000001'
ORDER BY transaction_type, created_at DESC;


-- =============================================================================
-- account_transactions
-- =============================================================================

-- Получить транзакцию аккаунта с детализацией комиссий
SELECT at.*,
       atf.type AS fee_type, atf.amount AS fee_amount, atf.currency AS fee_currency
FROM account_transactions at
LEFT JOIN account_transaction_fees atf ON at.id = atf.account_transaction_id
WHERE at.id = '88000000-0000-0000-0000-000000000001';

-- Поиск по original_transaction_id + type (upsert-проверка)
SELECT at.*,
       atf.type AS fee_type, atf.amount AS fee_amount
FROM account_transactions at
LEFT JOIN account_transaction_fees atf ON at.id = atf.account_transaction_id
WHERE at.original_transaction_id = 'aa000000-0000-0000-0000-000000000001'
  AND at.type = 'CUSTOMER_TRANSACTION'::"public"."AccountTransactionType";

-- Расчёт виртуального баланса аккаунта c использованием наших собственных политик удержания фи
-- Логика:
--   tx          — движение средств по транзакциям (deposits +, withdrawals -)
--   tx_fee      — списание комиссий (вычитается из баланса)
--   acc_fee     — legacy account_fees (вычитается из баланса)
--   total_balance     = tx_total     - tx_fee_total     - acc_fee_total
--   available_balance = tx_available - tx_fee_available - acc_fee_total
WITH tx AS (
    SELECT
        act.account_id,
        act.currency,
        SUM(
            CASE
                WHEN act.type IN ('PAYOUT'::"public"."AccountTransactionType") THEN act.amount * -1
                WHEN act.status = 'SUCCESSFUL'::"public"."TransactionStatus"
                THEN act.amount
                ELSE 0
            END
        ) AS transaction_total_balance,
        SUM(
            CASE
                WHEN act.type IN ('PAYOUT'::"public"."AccountTransactionType") THEN act.amount * -1
                WHEN act.status = 'SUCCESSFUL'::"public"."TransactionStatus"
                    AND act.is_available = true
                THEN act.amount
                ELSE 0
            END
        ) AS transaction_available_balance
    FROM account_transactions act
    WHERE act.account_id = 'a1000000-0000-0000-0000-000000000001'
      AND act.status    != 'FAILED'::"public"."TransactionStatus"
    GROUP BY act.account_id, act.currency
),
tx_fee AS (
    SELECT
        act.account_id,
        actf.currency,
        SUM(
            CASE
                WHEN act.type IN (
                    'CUSTOMER_TRANSACTION'::"public"."AccountTransactionType",
                    'MERCHANT_TRANSACTION'::"public"."AccountTransactionType"
                ) AND act.status = 'SUCCESSFUL'::"public"."TransactionStatus"
                THEN actf.amount
                WHEN act.type IN (
                    'PAYOUT'::"public"."AccountTransactionType"
                ) AND act.status != 'FAILED'::"public"."TransactionStatus"
                THEN actf.amount
                ELSE 0
            END
        ) AS total_fee_amount,
        SUM(
            CASE
                WHEN act.type IN (
                    'PAYOUT'::"public"."AccountTransactionType"
                ) AND act.status != 'FAILED'::"public"."TransactionStatus"
                THEN actf.amount
                WHEN act.type IN (
                    'CUSTOMER_TRANSACTION'::"public"."AccountTransactionType",
                    'MERCHANT_TRANSACTION'::"public"."AccountTransactionType"
                ) AND act.status = 'SUCCESSFUL'::"public"."TransactionStatus"
                    AND act.is_available = true
                THEN actf.amount
                ELSE 0
            END
        ) AS available_fee_amount
    FROM account_transaction_fees actf
    INNER JOIN account_transactions act ON act.id = actf.account_transaction_id
    WHERE act.account_id = 'a1000000-0000-0000-0000-000000000001'
      AND act.status    != 'FAILED'::"public"."TransactionStatus"
    GROUP BY act.account_id, actf.currency
),
acc_fee AS (
    SELECT
        af.account_id,
        af.currency,
        SUM(af.amount) AS full_account_fee_amount
    FROM account_fees af
    WHERE af.account_id = 'a1000000-0000-0000-0000-000000000001'
    GROUP BY af.account_id, af.currency
)
SELECT
    cryptos.crypto                                                                                                           AS currency,
    COALESCE(tx.transaction_total_balance,     0) - COALESCE(tx_fee.total_fee_amount,     0) - COALESCE(acc_fee.full_account_fee_amount, 0) AS total_balance,
    COALESCE(tx.transaction_available_balance, 0) - COALESCE(tx_fee.available_fee_amount, 0) - COALESCE(acc_fee.full_account_fee_amount, 0) AS available_balance
FROM accounts a
CROSS JOIN LATERAL (
    SELECT unnest(enum_range(NULL::"public"."CryptoCurrency")) AS crypto
) cryptos
LEFT JOIN tx
    ON tx.account_id  = a.id AND tx.currency  = cryptos.crypto
LEFT JOIN tx_fee
    ON tx_fee.account_id = a.id AND tx_fee.currency = cryptos.crypto
LEFT JOIN acc_fee
    ON acc_fee.account_id = a.id AND acc_fee.currency = cryptos.crypto
WHERE a.id = 'a1000000-0000-0000-0000-000000000001'
  AND (
      tx.transaction_total_balance IS NOT NULL
      OR acc_fee.full_account_fee_amount IS NOT NULL
  )
ORDER BY cryptos.crypto ASC;

-- История транзакций аккаунта за последние 30 дней
SELECT type, currency, amount, status, timestamp, original_transaction_id
FROM account_transactions
WHERE account_id  = 'a1000000-0000-0000-0000-000000000001'
  AND timestamp  >= now() - INTERVAL '30 days'
ORDER BY timestamp DESC
LIMIT 100;


-- =============================================================================
-- account_transaction_fees
-- =============================================================================

-- Детальные комиссии по транзакции аккаунта
SELECT atf.id, atf.type, atf.amount, atf.currency,
       atf.fee_percent_amount, atf.fee_flat_amount,
       fp.transaction_type AS policy_type, fp.source AS policy_source
FROM account_transaction_fees atf
INNER JOIN fee_policies fp ON atf.account_fee_policy_id = fp.id
WHERE atf.account_transaction_id = '88000000-0000-0000-0000-000000000001';

-- Суммарные комиссии аккаунта по типу и валюте за месяц
SELECT atf.type, atf.currency,
       COUNT(*)          AS fee_count,
       SUM(atf.amount)   AS total_fee_amount
FROM account_transaction_fees atf
INNER JOIN account_transactions at ON atf.account_transaction_id = at.id
WHERE at.account_id = 'a1000000-0000-0000-0000-000000000001'
  AND at.created_at >= date_trunc('month', now())
GROUP BY atf.type, atf.currency
ORDER BY total_fee_amount DESC;
