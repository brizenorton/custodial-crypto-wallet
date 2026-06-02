-- =============================================================================
-- Payment System Database — CREATE INDEXES
-- Описание: Индексы для оптимизации запросов к таблицам платёжной системы
-- Если данных в таблицах много (миллионы строк), то лучше не блокировать запись в таблицу
-- И использовать CREATE INDEX CONCURRENTLY, но для пустых таблиц можно использовать CREATE INDEX
-- Поэтому воспользуемся CREATE INDEX
-- =============================================================================

-- =============================================================================
-- rates
-- =============================================================================

-- Основной индекс для поиска последнего курса по валюте и типу
CREATE INDEX IF NOT EXISTS "Rate_IDX_cryptoCurrency_type_createdAt_DESC"
    ON "rates" ("crypto_currency", "type", "created_at" DESC);

-- Индекс для поиска последнего курса только по типу
CREATE INDEX IF NOT EXISTS "Rate_IDX_type_createdAt_DESC"
    ON "rates" ("type", "created_at" DESC);

-- Индекс для задачи очистки старых курсов (cleanup job)
CREATE INDEX IF NOT EXISTS "Rate_IDX_createdAt"
    ON "rates" ("created_at");

-- Составной индекс для очистки по дате (используется в batch-delete)
CREATE INDEX IF NOT EXISTS "Rate_IDX_cryptoCurrency_type_Date_createdAt_DESC"
    ON "rates" ("crypto_currency", "type", DATE("created_at"), "created_at" DESC);

-- Индекс для поиска курсов по объекту фиатных валют fiat_rates 
CREATE INDEX IF NOT EXISTS "Rate_IDX_fiatRates" ON "rates" USING GIN ("fiat_rates");

-- =============================================================================
-- merchants
-- =============================================================================

-- Индекс для поиска мерчанта по account_id
CREATE INDEX IF NOT EXISTS "Merchant_IDX_accountId"
    ON "merchants" ("account_id");

-- =============================================================================
-- merchant_credentials
-- =============================================================================

-- Только один callback-credential на мерчанта
CREATE UNIQUE INDEX "MerchantCredential_UQ_IDX_merchantId_for_callback"
    ON "merchant_credentials" ("merchant_id")
    WHERE "for_callback" = true;

-- Индекс для поиска учётных данных по merchant_id
CREATE INDEX "MerchantCredential_IDX_merchantId"
    ON "merchant_credentials" ("merchant_id");

-- =============================================================================
-- customer_wallets
-- =============================================================================

-- Индекс для поиска кошельков по merchant_id
CREATE INDEX "CustomerWallet_IDX_merchantId"
    ON "customer_wallets" ("merchant_id");

-- Индекс для поиска активных кошельков по crypto_currency и merchant_id
CREATE INDEX IF NOT EXISTS "CustomerWallet_IDX_cryptoCurrency_merchantId"
    ON "customer_wallets" ("crypto_currency", "merchant_id");

-- Индекс для фильтрации по статусу
CREATE INDEX IF NOT EXISTS "CustomerWallet_IDX_status"
    ON "customer_wallets" ("status");

-- =============================================================================
-- customer_wallet_transactions
-- =============================================================================

-- Индекс для поиска транзакций по адресу и валюте
CREATE INDEX "CustomerWalletTransaction_IDX_cryptoCurrency_toAddress"
    ON "customer_wallet_transactions" ("crypto_currency", "to_address");

-- Индекс для поиска несобранных транзакций (collect job)
CREATE INDEX "CustomerWalletTransaction_IDX_uncollected"
    ON "customer_wallet_transactions" ("to_address", "crypto_currency", "status")
    WHERE "is_collected" = false;

-- Индекс для FK на rates (cleanup rates job)
CREATE INDEX IF NOT EXISTS "CustomerWalletTransaction_IDX_rateId"
    ON "customer_wallet_transactions" ("rate_id");

-- =============================================================================
-- merchant_transit_wallet_transactions
-- =============================================================================

-- Индекс для поиска по назначению и типу
CREATE INDEX "MTWT_IDX_to_type"
    ON "merchant_transit_wallet_transactions" ("to", "type");

-- Индекс для поиска по назначению и валюте
CREATE INDEX "MTWT_IDX_to_cryptoCurrency"
    ON "merchant_transit_wallet_transactions" ("to", "crypto_currency");

-- Составной индекс для запросов по мерчанту, валюте и типу
CREATE INDEX "MTWT_IDX_merchantId_cryptoCurrency_type"
    ON "merchant_transit_wallet_transactions" ("merchant_id", "crypto_currency", "type");

-- Индекс для FK на rates (cleanup rates job)
CREATE INDEX IF NOT EXISTS "MTWT_IDX_rateId"
    ON "merchant_transit_wallet_transactions" ("rate_id");

-- =============================================================================
-- payouts
-- =============================================================================

-- Составной индекс для поиска выплат по мерчанту и валюте
CREATE INDEX "Payout_IDX_merchantId_currency"
    ON "payouts" ("merchant_id", "crypto_currency");

-- Индекс для FK на rates (cleanup rates job)
CREATE INDEX IF NOT EXISTS "Payout_IDX_rateId"
    ON "payouts" ("rate_id");

-- BRIN-индекс для партиционирования по дате создания (большой объём данных)
CREATE INDEX IF NOT EXISTS "Payout_IDX_createdAt_brin"
    ON "payouts" USING BRIN ("created_at");

-- =============================================================================
-- payout_transfers
-- =============================================================================

-- Индекс для поиска переводов по payout_id и статусу
CREATE INDEX IF NOT EXISTS "PayoutTransfer_IDX_payoutId_status"
    ON "payout_transfers" ("payout_id", "status");

-- =============================================================================
-- refunds
-- =============================================================================

-- Уникальный индекс: один активный возврат на транзакцию+тип (за исключением FAILED)
CREATE UNIQUE INDEX "Refund_UQ_IDX_transactionId_transactionType"
    ON "refunds" ("transaction_id", "transaction_type", "status")
    WHERE "status" != 'FAILED';

-- Уникальный индекс: одна транзакция имеет один blockchain_transaction_id
CREATE UNIQUE INDEX "Refund_UQ_IDX_blockchainTransactionId"
    ON "refunds" ("blockchain_transaction_id");

-- Индекс для поиска возвратов по transaction_id
CREATE INDEX IF NOT EXISTS "Refund_IDX_transactionId"
    ON "refunds" ("transaction_id");

-- =============================================================================
-- refund_transfers
-- =============================================================================

-- Уникальный индекс: один рефанд-трансфер на один возврат
CREATE UNIQUE INDEX "RefundTransfer_UQ_IDX_refundId"   ON "refund_transfers" ("refund_id");

-- Уникальный индекс: один blockchain-трансфер на один рефанд-трансфер
CREATE UNIQUE INDEX "RefundTransfer_UQ_IDX_blockchainId" ON "refund_transfers" ("blockchain_id");

-- =============================================================================
-- transfers
-- =============================================================================

-- Индекс для поиска активных переводов на адрес
CREATE INDEX "Transfer_IDX_active_refill"
    ON "transfers" ("to", "currency", "value")
    WHERE "status" NOT IN ('COMPLETED', 'FAILED');

-- Индекс для дедупликации переводов без txid
CREATE INDEX "Transfer_IDX_refill_check"
    ON "transfers" ("from", "to", "currency", "value", "created_at")
    WHERE "txid" IS NULL;

-- Индекс для поиска по статусу
CREATE INDEX "Transfer_IDX_status"
    ON "transfers" ("status");

-- Индекс для связанных переводов
CREATE INDEX "Transfer_IDX_linkedTransferId"
    ON "transfers" ("linked_transfer_id");

-- Индекс для поиска по txid
CREATE INDEX "Transfer_IDX_txid"
    ON "transfers" ("txid");

-- =============================================================================
-- transaction_data
-- =============================================================================

-- Индекс для поиска по external_id (BO-запросы)
CREATE INDEX "TransactionData_IDX_externalId"
    ON "transaction_data" ("external_id");

-- Индекс для FK на rates (cleanup rates job)
CREATE INDEX IF NOT EXISTS "TransactionData_IDX_rateId"
    ON "transaction_data" ("rate_id");

-- =============================================================================
-- callback_histories
-- =============================================================================

-- Составной индекс для поиска колбэков по внешнему id и статусу ответа
CREATE INDEX "CallbackHistory_IDX_typeExternalId_responseStatus"
    ON "callback_histories" ("type_external_id", "response_status");

-- Индекс для поиска колбэков по типу и времени обновления (retry job)
CREATE INDEX "CallbackHistory_IDX_type_updatedAt"
    ON "callback_histories" ("type", "updated_at");

-- Индекс для поиска по типу и статусу ответа
CREATE INDEX IF NOT EXISTS "CallbackHistory_IDX_type_responseStatus"
    ON "callback_histories" ("type", "response_status");

-- Индекс для поиска по статусу payload
CREATE INDEX "CallbackHistory_IDX_payloadStatus"
    ON "callback_histories" ("payload_status");

-- =============================================================================
-- config_properties
-- =============================================================================

-- Составной индекс для поиска актуального значения конфигурации
CREATE INDEX "ConfigProperty_IDX_issuerId_name_createdAt_DESC"
    ON "config_properties" ("issuer_id", "name", "created_at" DESC);

-- Дополнительный индекс для поиска без сортировки
CREATE INDEX IF NOT EXISTS "ConfigProperty_IDX_issuerId_name"
    ON "config_properties" ("issuer_id", "name");

-- =============================================================================
-- aml_scorings
-- =============================================================================

-- Индекс для поиска по статусу AML-проверки
CREATE INDEX IF NOT EXISTS "AmlScoring_IDX_status"
    ON "aml_scorings" ("status");

-- Составные уникальные индексы AML: txid+source_transaction_id или только txid
CREATE UNIQUE INDEX "AmlScoring_UQ_IDX_txid_sourceTransactionId"
    ON "aml_scorings" ("txid", "source_transaction_id")
    WHERE "txid" IS NOT NULL AND "source_transaction_id" IS NOT NULL;

CREATE UNIQUE INDEX "AmlScoring_UQ_IDX_txid_nullSourceTransactionId"
    ON "aml_scorings" ("txid")
    WHERE "txid" IS NOT NULL AND "source_transaction_id" IS NULL;

-- =============================================================================
-- account_fees
-- =============================================================================

-- Индекс для поиска комиссий аккаунта по валюте
CREATE INDEX "AccountFee_IDX_accountId_currency"
    ON "account_fees" ("account_id", "currency");

-- =============================================================================
-- fee_policies
-- =============================================================================

-- Индекс для получения актуальной политики комиссий по аккаунту и типу транзакции
CREATE INDEX "FeePolicy_IDX_accountId_transactionType_createdAt_DESC"
    ON "fee_policies" ("account_id", "transaction_type", "created_at" DESC);

-- =============================================================================
-- account_transactions
-- =============================================================================

-- Индекс для расчёта баланса: поиск транзакций аккаунта по статусу и доступности
CREATE INDEX "AccountTransaction_IDX_accountId_status_isAvailable"
    ON "account_transactions" ("account_id", "status", "is_available");

-- Составной индекс для агрегирования баланса по валюте и типу
CREATE INDEX "AccountTransaction_IDX_accountId_currency_status_type"
    ON "account_transactions" ("account_id", "currency", "status", "type");

-- Уникальный составной индекс: одна запись на пару (original_transaction_id, type)
CREATE UNIQUE INDEX "AccountTransaction_UQ_IDX_originalId_type"
    ON "account_transactions" ("original_transaction_id", "type");

-- =============================================================================
-- account_transaction_fees
-- Детальная разбивка комиссий по каждой учётной записи аккаунта.
-- Позволяет хранить комиссии по разным валютам для одной транзакции
-- =============================================================================

-- Индекс для поиска детальных комиссий по транзакции и валюте
CREATE INDEX "AccountTransactionFee_IDX_accountTransactionId_currency"
    ON "account_transaction_fees" ("account_transaction_id", "currency");
