-- =============================================================================
-- Payment System Database — UPDATE DATA
-- Описание: Примеры обновления данных в основных таблицах
-- =============================================================================

-- =============================================================================
-- merchants
-- =============================================================================

-- Обновление типа мерчанта с SMB на ENTERPRISE
UPDATE merchants
SET type       = 'ENTERPRISE'::"public"."MerchantType",
    updated_at = now()
WHERE id = 'c3000000-0000-0000-0000-000000000002';

-- Привязка аккаунта к мерчанту, если не был задан при создании
UPDATE merchants
SET account_id = 'a1000000-0000-0000-0000-000000000002',
    updated_at = now()
WHERE id = 'c3000000-0000-0000-0000-000000000002'
  AND account_id IS NULL;

-- Ротация зашифрованного приватного ключа мерчанта
UPDATE merchants
SET encrypted_private_key = 'new_encrypted_priv_key_acme',
    updated_at            = now()
WHERE id = 'c3000000-0000-0000-0000-000000000001';


-- =============================================================================
-- merchant_credentials
-- =============================================================================

-- Деактивация устаревшего набора учётных данных
UPDATE merchant_credentials
SET status     = 'DEPRECATED'::"public"."MerchantCredentialStatus",
    updated_at = now()
WHERE id = 'd4000000-0000-0000-0000-000000000001';

-- Обновление списка разрешённых IP-адресов
UPDATE merchant_credentials
SET ip_addresses = ARRAY['10.0.0.0/8', '185.10.50.100/32']::cidr[],
    updated_at   = now()
WHERE id = 'd4000000-0000-0000-0000-000000000003';


-- =============================================================================
-- merchant_wallets
-- =============================================================================

-- Привязка кошелька к аккаунту
UPDATE merchant_wallets
SET account_id = 'a1000000-0000-0000-0000-000000000001',
    updated_at = now()
WHERE merchant_id = 'c3000000-0000-0000-0000-000000000001'
  AND account_id IS NULL;


-- =============================================================================
-- customer_wallets
-- =============================================================================

-- Депрекация кошелька клиента (например, при смене адреса)
UPDATE customer_wallets
SET status     = 'DEPRECATED'::"public"."WalletStatus",
    updated_at = now()
WHERE id = 'f6000000-0000-0000-0000-000000000002';

-- Привязка email клиента к кошельку
UPDATE customer_wallets
SET user_email = 'client-002@example.com',
    updated_at = now()
WHERE merchant_id = 'c3000000-0000-0000-0000-000000000001'
  AND customer_id = 'client-002';

-- Обновление callback URL для всех кошельков мерчанта
UPDATE customer_wallets
SET callback_url = 'https://acme-new.example.com/callbacks/wallet',
    updated_at   = now()
WHERE merchant_id = 'c3000000-0000-0000-0000-000000000001';


-- =============================================================================
-- customer_wallet_transactions
-- =============================================================================

-- Проставление флага AML-проверки
UPDATE customer_wallet_transactions
SET is_aml_checked = true,
    aml_status     = 'COMPLETED'::"public"."AmlAnalysisStatus",
    updated_at     = now()
WHERE id = 'aa000000-0000-0000-0000-000000000002';

-- Обновление статуса транзакции после подтверждения блокчейном
UPDATE customer_wallet_transactions
SET status     = 'SUCCESSFUL'::"public"."TransactionStatus",
    updated_at = now()
WHERE id = 'aa000000-0000-0000-0000-000000000002';

-- Пометка транзакций как собранных (collect job)
-- Массовое обновление для адреса, валюты и даты
UPDATE customer_wallet_transactions
SET is_collected = true,
    updated_at   = now()
WHERE to_address      = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh'
  AND crypto_currency = 'BTC'::"public"."CryptoCurrency"
  AND created_at      <= now()
  AND status          = 'SUCCESSFUL'::"public"."TransactionStatus"
  AND is_collected    = false;

-- Обновление комиссии транзакции после получения точных данных из блокчейна
UPDATE customer_wallet_transactions
SET fee        = 0.000015,
    updated_at = now()
WHERE id = 'aa000000-0000-0000-0000-000000000001';


-- =============================================================================
-- merchant_transit_wallet_transactions
-- =============================================================================

-- Пометка транзакций как собранных
UPDATE merchant_transit_wallet_transactions
SET is_collected = true,
    updated_at   = now()
WHERE "to"            = 'transit_btc_address_acme_0001'
  AND crypto_currency = 'BTC'::"public"."CryptoCurrency"
  AND created_at      <= now()
  AND is_collected    = false;

-- Обновление статуса после завершения блокчейн-операции
UPDATE merchant_transit_wallet_transactions
SET status     = 'SUCCESSFUL'::"public"."TransactionStatus",
    updated_at = now()
WHERE id = 'bb000000-0000-0000-0000-000000000001';


-- =============================================================================
-- payouts
-- =============================================================================

-- Перевод выплаты в статус SUBMITTED после начала обработки
UPDATE payouts
SET status     = 'SUBMITTED'::"public"."payouts_status_enum",
    updated_at = now()
WHERE id = 'cc000000-0000-0000-0000-000000000001';

-- Подтверждение выплаты с записью txid
UPDATE payouts
SET status     = 'COMPLETED'::"public"."payouts_status_enum",
    txid       = 'trc20_payout_txid_00000000000000000000000000000000000001',
    updated_at = now()
WHERE id = 'cc000000-0000-0000-0000-000000000001';

-- Отмена выплаты с записью ошибки валидации
UPDATE payouts
SET status           = 'CANCELED'::"public"."payouts_status_enum",
    validation_error = 'InsufficientLiquidityError'::"public"."payouts_validation_error_enum",
    updated_at       = now()
WHERE external_id  = 'payout-acme-2024-003'
  AND merchant_id  = 'c3000000-0000-0000-0000-000000000001'
  AND status       = 'QUEUED'::"public"."payouts_status_enum";


-- =============================================================================
-- payout_transfers
-- =============================================================================

-- Обновление статуса перевода выплаты после отправки в блокчейн
UPDATE payout_transfers
SET status     = 'SUCCESSFUL'::"public"."payout_transfers_status_enum",
    txid       = 'trc20_payout_txid_00000000000000000000000000000000000001',
    updated_at = now()
WHERE id = 'dd000000-0000-0000-0000-000000000001';

-- Фиксация ошибки попытки перевода
UPDATE payout_transfers
SET status        = 'FAILED'::"public"."payout_transfers_status_enum",
    failed_reason = 'INSUFFICIENT_BALANCE',
    updated_at    = now()
WHERE payout_id = 'cc000000-0000-0000-0000-000000000001'
  AND attempt   = 1
  AND status    = 'PENDING'::"public"."payout_transfers_status_enum";


-- =============================================================================
-- refunds
-- =============================================================================

-- Обновление статуса возврата
UPDATE refunds
SET status     = 'SUCCESS'::"public"."RefundStatus",
    updated_at = now()
WHERE id = 'ee000000-0000-0000-0000-000000000001';


-- =============================================================================
-- refund_transfers
-- =============================================================================

-- Проставление txid и статуса после завершения blockchain-перевода
UPDATE refund_transfers
SET status     = 'SUCCESS'::"public"."RefundTransferStatus",
    txid       = 'refund_btc_txid_0000000000000000000000000000000000000001',
    updated_at = now()
WHERE refund_id = 'ee000000-0000-0000-0000-000000000001';


-- =============================================================================
-- transfers
-- =============================================================================

-- Обновление статуса
UPDATE transfers
SET status     = 'COMPLETED'::"public"."TransferStatus",
    txid       = 'btc_txid_000000000000000000000000000000000000001',
    updated_at = now()
WHERE id = '11000000-0000-0000-0000-000000000001';

-- =============================================================================
-- transaction_data
-- =============================================================================

-- Обновление статуса через SET_ONCE / CONTROLLED_MUTABLE политику:
-- статус меняется только при переходе из промежуточных состояний
UPDATE transaction_data
SET source_updated_at = now(),
    status            = CASE
        WHEN status IN ('PENDING', 'QUEUED', 'AML_CHECKING')
        THEN 'COMPLETED'::"public"."transaction_data_status_enum"
        ELSE status
    END,
    updated_at        = now()
WHERE source_external_id = 'cc000000-0000-0000-0000-000000000001'
  AND source_type        = 'PAYOUT_TRANSACTION'::"public"."TransactionSourceType";

-- Обновление fee и txid (SET_ONCE: записывается только если ещё не было)
UPDATE transaction_data
SET fee               = COALESCE(NULLIF(fee, 0), 1.50),
    txid              = COALESCE(txid, 'trc20_payout_txid_00000000000000000000000000000000000001'),
    source_updated_at = now(),
    updated_at        = now()
WHERE source_external_id = 'cc000000-0000-0000-0000-000000000001'
  AND source_type        = 'PAYOUT_TRANSACTION'::"public"."TransactionSourceType";


-- =============================================================================
-- callback_histories
-- =============================================================================

-- Обновление статуса ответа после получения ответа от мерчанта
UPDATE callback_histories
SET response_status  = 200,
    response_message = 'OK',
    payload_status   = 'SUCCESSFUL'::"public"."CallbackPayloadStatus",
    updated_at       = now()
WHERE id = '33000000-0000-0000-0000-000000000002';

-- Запись неуспешного ответа (timeout / 5xx)
UPDATE callback_histories
SET response_status  = 503,
    response_message = 'Service Unavailable',
    payload_status   = 'FAILED'::"public"."CallbackPayloadStatus",
    updated_at       = now()
WHERE type_external_id = 'cc000000-0000-0000-0000-000000000001'
  AND response_status IS NULL;


-- =============================================================================
-- rates
-- =============================================================================

-- Удаление старых записей в конфигурируемом промежутке, оставляя последние на каждый день.
-- Запускается через планировщик в коде
WITH day_ends AS (
    SELECT DISTINCT ON ("crypto_currency", "type", DATE("created_at"))
    "id"
    FROM "rates"
    ORDER BY "crypto_currency", "type", DATE("created_at"), "created_at" DESC
)
DELETE FROM rates WHERE id IN (
    SELECT r1.id
    FROM rates r1
    WHERE r1.created_at <= NOW() - make_interval(hours => 1)
    AND r1.created_at >= NOW() - make_interval(hours => 12)
    -- Preserve end-of-day snapshot (latest rate per currency/type/day)
    AND r1.id NOT IN (SELECT id FROM day_ends)
    -- Do not delete if referenced in other tables
    AND NOT EXISTS (SELECT 1 FROM payouts p WHERE p.rate_id = r1.id)
    AND NOT EXISTS (SELECT 1 FROM customer_wallet_transactions cwt WHERE cwt.rate_id = r1.id)
    AND NOT EXISTS (SELECT 1 FROM merchant_transit_wallet_transactions mtwt WHERE mtwt.rate_id = r1.id)
    AND NOT EXISTS (SELECT 1 FROM transaction_data td WHERE td.rate_id = r1.id)
    LIMIT 5000;
)
RETURNING id;


-- =============================================================================
-- config_properties
-- =============================================================================

-- Обновление порогового значения минимальной суммы выплаты
UPDATE config_properties
SET value      = '0.0005',
    updated_at = now()
WHERE issuer_id = 'c3000000-0000-0000-0000-000000000001'
  AND name      = 'BITCOIN_MINIMUM_PAYOUT_AMOUNT'::"public"."ConfigPropertyName";


-- =============================================================================
-- aml_scorings
-- =============================================================================

-- Проставление результата AML-проверки
UPDATE aml_scorings
SET status       = 'COMPLETED'::"public"."CrystalAmlAnalysisStatus",
    scoring_data = '{"riskscore": 5, "signals": [], "address_type": "exchange"}'::jsonb,
    updated_at   = now()
WHERE id = '55000000-0000-0000-0000-000000000002';

-- Перевод застрявшей проверки в статус FAILED
UPDATE aml_scorings
SET status     = 'FAILED'::"public"."CrystalAmlAnalysisStatus",
    error      = 'API timeout after 30s',
    updated_at = now()
WHERE status     = 'STUCK'::"public"."CrystalAmlAnalysisStatus"
  AND created_at < now() - INTERVAL '1 hour';


-- =============================================================================
-- fee_policies
-- =============================================================================

-- Изменение набора комиссий для типа транзакции
UPDATE fee_policies
SET fees       = ARRAY['ONE_PERCENT', 'NETWORK_FEE']::"public"."FeeType"[],
    source     = 'MANUAL'::"public"."FeePolicySource",
    updated_at = now()
WHERE id = '77000000-0000-0000-0000-000000000001';


-- =============================================================================
-- account_transactions
-- =============================================================================

-- Обновление статуса учётной записи после подтверждения
UPDATE account_transactions
SET status     = 'SUCCESSFUL'::"public"."TransactionStatus",
    updated_at = now()
WHERE id = '88000000-0000-0000-0000-000000000002';

-- Проставление флага is_available (средства разморожены)
UPDATE account_transactions
SET is_available = true,
    updated_at   = now()
WHERE id = '88000000-0000-0000-0000-000000000001';

-- Массовое обновление: разморозка средств, у которых available_at уже наступил
UPDATE account_transactions
SET is_available = true,
    updated_at   = now()
WHERE is_available = false
  AND available_at IS NOT NULL
  AND available_at <= now();
