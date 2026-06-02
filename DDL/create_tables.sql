-- =============================================================================
-- Payment System Database — CREATE TABLES
-- Описание: Скрипт создания всех таблиц платёжной системы
-- Схема: public
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- ENUM TYPES
-- =============================================================================

CREATE TYPE "public"."CryptoCurrency" AS ENUM (
    'BTC', 'LTC', 'BNB', 'TRX', 'ETH', 'TON',
    'USDT-BEP20', 'USDT-TRC20', 'USDT-ERC20', 'USDT-TEP74',
    'USDT-ARB-ERC20', 'USDT-AVAX-ERC20', 'USDT-BASE-ERC20', 'USDT-OP-ERC20', 'USDT-POL-ERC20', 'USDT-SOL',
    'USDC-ERC20', 'USDC-BEP20', 'USDC-ARB-ERC20', 'USDC-AVAX-ERC20', 'USDC-BASE-ERC20', 'USDC-OP-ERC20', 'USDC-POL-ERC20', 'USDC-SOL',
    'ETH-ARB', 'ETH-BASE', 'ETH-BEP20', 'ETH-OP',
    'ARB-ERC20', 'AVAX', 'SOL', 'POL', 'BCH', 'DOGE', 'XRP', 'ADA', 'ALGO',
    'WBTC-ERC20', 'WBTC-ARB-ERC20', 'WBTC-BASE-ERC20', 'WBTC-OP-ERC20', 'WBTC-POL-ERC20',
    'WETH-ERC20', 'WETH-ARB-ERC20', 'WETH-BASE-ERC20', 'WETH-BEP20', 'WETH-POL-ERC20',
    'LINK-ERC20', 'LINK-BEP20', 'SHIB-ERC20', 'SHIB-BEP20',
    'UNI-ERC20', 'UNI-BEP20', 'DAI-ERC20', 'DAI-BEP20',
    'BNB-ERC20', 'BNB-POL-ERC20', 'BTCB-BEP20', 'DOGE-BEP20',
    'POL-ERC20', 'POL-BEP20', 'SOL-BEP20', 'XRP-BEP20',
    'WBNB-POL-ERC20', 'WSOL-POL-ERC20', 'WXRP-ERC20'
);

CREATE TYPE "public"."RateCryptoCurrency" AS ENUM (
    'BNB', 'BTC', 'ETH', 'LTC', 'TRX', 'TON', 'USDT', 'USDC',
    'ARB', 'AVAX', 'SOL', 'POL', 'BCH', 'ADA', 'ALGO', 'LINK', 'SHIB', 'UNI',
    'DOGE', 'XRP'
);

CREATE TYPE "public"."FiatCurrency" AS ENUM (
    'USD', 'EUR', 'RUB', 'UAH', 'KZT', 'AZN', 'BDT', 'BGN', 'BRL',
    'BYN', 'CAD', 'AUD', 'HUF', 'INR', 'JPY', 'KRW', 'MXN',
    'NOK', 'PLN', 'RON', 'SEK', 'TRY', 'UZS'
);

CREATE TYPE "public"."MerchantType" AS ENUM ('SMB', 'ENTERPRISE');

CREATE TYPE "public"."MerchantCredentialStatus" AS ENUM ('ACTIVE', 'DEPRECATED');

CREATE TYPE "public"."WalletStatus" AS ENUM ('ACTIVE', 'DEPRECATED');

CREATE TYPE "public"."CustomerWalletTransactionType" AS ENUM (
    'CORRECT', 'CANCELED', 'MANUAL', 'MANUAL_FIX', 'INTERNAL'
);

CREATE TYPE "public"."MerchantTransitWalletTransactionType" AS ENUM ('CORRECT', 'CANCELED');

CREATE TYPE "public"."TransactionStatus" AS ENUM (
    'PENDING', 'SUBMITTED', 'SUCCESSFUL', 'SUCCESS', 'FAILED',
    'AML_CHECKING', 'AML_FAILED', 'AML_PENDING',
    'REFUND_PENDING', 'REFUND_FAILED', 'REFUNDED'
);

CREATE TYPE "public"."AmlAnalysisStatus" AS ENUM ('COMPLETED', 'PENDING', 'FAILED', 'STUCK');

CREATE TYPE "public"."CrystalAmlAnalysisStatus" AS ENUM ('COMPLETED', 'PENDING', 'FAILED', 'STUCK');

CREATE TYPE "public"."AmlScoringType" AS ENUM ('DEPOSIT_TRANSACTION', 'WITHDRAWAL_ADDRESS');

CREATE TYPE "public"."payouts_status_enum" AS ENUM (
    'SUBMITTED', 'COMPLETED', 'QUEUED', 'CANCELED'
);

CREATE TYPE "public"."payouts_creation_method_enum" AS ENUM ('UNKNOWN', 'API_V1', 'API_V2', 'BO');

CREATE TYPE "public"."payouts_validation_error_enum" AS ENUM ('InsufficientLiquidityError');

CREATE TYPE "public"."payout_transfers_status_enum" AS ENUM ('PENDING', 'SUCCESSFUL', 'FAILED');

CREATE TYPE "public"."RefundTransactionType" AS ENUM (
    'CUSTOMER_WALLET_TRANSACTION',
    'MERCHANT_CUSTOMER_ADDRESS_DEPOSIT_TRANSACTION'
);

CREATE TYPE "public"."RefundStatus" AS ENUM ('SUBMITTED', 'PENDING', 'SUCCESS', 'FAILED');

CREATE TYPE "public"."RefundTransferStatus" AS ENUM ('PENDING', 'SUCCESS', 'FAILED');

CREATE TYPE "public"."TransferStatus" AS ENUM (
    'AWAITING_FOR_DEPOSIT_COINS_TO_TOKEN_ADDRESS',
    'COMPLETED',
    'FAILED',
    'IN_PROCESSING',
    'PREPARE_TOKEN_TO_TRANSFER',
    'READY_TO_TRANSFER',
    'SENT'
);

CREATE TYPE "public"."TransferType" AS ENUM (
    'COLLECT',
    'REFILL',
    'CONSOLIDATION_WALLET_REFILL',
    'OPERATION_WALLET_DEPOSIT',
    'ACTIVATE'
);

CREATE TYPE "public"."RateType" AS ENUM ('EXTERNAL', 'WALLET_INTERNAL');

-- Тип источника транзакции в transaction_data
CREATE TYPE "public"."TransactionSourceType" AS ENUM (
    'PAYOUT_TRANSACTION',
    'PAYOUT_TRANSACTION_BO',
    'CUSTOMER_WALLET_TRANSACTION',
    'MERCHANT_TRANSIT_WALLET_TRANSACTION',
    'REFUND_TRANSACTION'
);

CREATE TYPE "public"."transaction_data_status_enum" AS ENUM (
    'COMPLETED', 'PENDING', 'FAILED', 'AML_FAILED', 'AML_CHECKING',
    'REFUND_PENDING', 'REFUNDED', 'REFUND_FAILED', 'QUEUED', 'CANCELED'
);

CREATE TYPE "public"."CallbackPayloadStatus" AS ENUM (
    'UNDEFINED', 'PENDING', 'SUCCESSFUL', 'AML_FAILED', 'FAILED',
    'REFUND_PENDING', 'REFUNDED', 'REFUND_FAILED', 'COMPLETED',
    'EXCEEDED', 'EXPIRED', 'PARTIAL', 'REJECTED', 'SUBMITTED', 'CANCELED'
);

-- Типы конфигурационных параметров:
CREATE TYPE "public"."ConfigPropertyName" AS ENUM (
    'BITCOIN_MINIMUM_PAYOUT_AMOUNT',
    'LITECOIN_MINIMUM_PAYOUT_AMOUNT',
    'BINANCE_MINIMUM_PAYOUT_AMOUNT',
    'TRON_MINIMUM_PAYOUT_AMOUNT',
    'TON_MINIMUM_PAYOUT_AMOUNT',
    'ETHEREUM_MINIMUM_PAYOUT_AMOUNT',
    'TETHER_BEP20_MINIMUM_PAYOUT_AMOUNT',
    'TETHER_TRC20_MINIMUM_PAYOUT_AMOUNT',
    'TETHER_ERC20_MINIMUM_PAYOUT_AMOUNT',
    'USDC_BEP20_MINIMUM_PAYOUT_AMOUNT',
    'USDC_ERC20_MINIMUM_PAYOUT_AMOUNT',
    'BITCOIN_MINIMUM_DEPOSIT_AMOUNT',
    'LITECOIN_MINIMUM_DEPOSIT_AMOUNT',
    'BINANCE_MINIMUM_DEPOSIT_AMOUNT',
    'TRON_MINIMUM_DEPOSIT_AMOUNT',
    'TON_MINIMUM_DEPOSIT_AMOUNT',
    'ETHEREUM_MINIMUM_DEPOSIT_AMOUNT',
    'TETHER_BEP20_MINIMUM_DEPOSIT_AMOUNT',
    'TETHER_TRC20_MINIMUM_DEPOSIT_AMOUNT',
    'TETHER_ERC20_MINIMUM_DEPOSIT_AMOUNT',
    'USDC_BEP20_MINIMUM_DEPOSIT_AMOUNT',
    'USDC_ERC20_MINIMUM_DEPOSIT_AMOUNT',
    'BINANCE_TOKEN_FEE_REFILL_AMOUNT',
    'ETHEREUM_TOKEN_FEE_REFILL_AMOUNT',
    'TRON_TOKEN_FEE_REFILL_AMOUNT',
    'TRANSACTION_DATA_MIN_CRYPTO_AMOUNT_TRX',
    'MERCHANT_CREDENTIAL_IP_LIMIT',
    'BEP20_MERCHANT_WALLET_TOKEN_FEE_REFILL_AMOUNT',
    'ERC20_MERCHANT_WALLET_TOKEN_FEE_REFILL_AMOUNT',
    'TRC20_MERCHANT_WALLET_TOKEN_FEE_REFILL_AMOUNT',
    'BITCOIN_MINIMUM_COLLECT_AMOUNT',
    'LITECOIN_MINIMUM_COLLECT_AMOUNT',
    'BINANCE_MINIMUM_COLLECT_AMOUNT',
    'TRON_MINIMUM_COLLECT_AMOUNT',
    'TON_MINIMUM_COLLECT_AMOUNT',
    'ETHEREUM_MINIMUM_COLLECT_AMOUNT',
    'TETHER_BEP20_MINIMUM_COLLECT_AMOUNT',
    'TETHER_TRC20_MINIMUM_COLLECT_AMOUNT',
    'TETHER_ERC20_MINIMUM_COLLECT_AMOUNT',
    'USDC_BEP20_MINIMUM_COLLECT_AMOUNT',
    'USDC_ERC20_MINIMUM_COLLECT_AMOUNT',
    'ETHEREUM_MANUAL_REFILL_ADDRESS',
    'BINANCE_MANUAL_REFILL_ADDRESS',
    'TRON_MANUAL_REFILL_ADDRESS',
    'MAX_SCORING',
    'MAX_SIGNAL_ATM',
    'MAX_CHILD_EXPLOITATION',
    'MAX_DARK_MARKET',
    'MAX_DARK_SERVICE',
    'MAX_ENFORCEMENT_ACTION',
    'MAX_EXCHANGE_FRAUDULENT',
    'MAX_EXCHANGE_LICENSED',
    'MAX_EXCHANGE_UNLICENSED',
    'MAX_GAMBLING',
    'MAX_ILLEGAL_SERVICE',
    'MAX_LIQUIDITY_POOLS',
    'MAX_MARKETPLACE',
    'MAX_MINER',
    'MAX_MIXER',
    'MAX_OTHER',
    'MAX_P2P_EXCHANGE_LICENSED',
    'MAX_P2P_EXCHANGE_UNLICENSED',
    'MAX_PAYMENT'
);

-- Типы транзакций аккаунта 
CREATE TYPE "public"."AccountTransactionType" AS ENUM (
    'CUSTOMER_TRANSACTION',
    'MERCHANT_TRANSACTION',
    'PAYOUT'
);

-- Типы комиссий: 
--  - ONE_PERCENT: фиксированная комиссия в 1%
--  - DYNAMIC_PERCENT: динамический процент
--  - ZERO_PERCENT: 0%
--  - FIXED_FEE: фиксированная сумма
--  - NETWORK_FEE: сетевая комиссия
CREATE TYPE "public"."FeeType" AS ENUM (
    'ONE_PERCENT',
    'DYNAMIC_PERCENT',
    'ZERO_PERCENT',
    'FIXED_FEE',
    'NETWORK_FEE'
);

-- Источник, из которого применена политика:
--  - SYSTEM_DEFAULT: системная политика по умолчанию
--  - SEGMENT_DEFAULT: политика по умолчанию для сегмента аккаунта
--  - MANUAL: ручная политика, заданная вручную
CREATE TYPE "public"."FeePolicySource" AS ENUM ('SYSTEM_DEFAULT', 'SEGMENT_DEFAULT', 'MANUAL');

-- Типы комиссий аккаунта
--  - LEGACY: устаревшая комиссия
CREATE TYPE "public"."AccountFeeType" AS ENUM ('LEGACY');


-- =============================================================================
-- TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- accounts
-- Базовая таблица-идентификатор аккаунта.
-- К аккаунту привязаны мерчанты, кошельки и транзакции.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "accounts" (
    "id"         uuid        NOT NULL DEFAULT uuid_generate_v4(),
    "created_at" TIMESTAMP   NOT NULL DEFAULT now(),
    "updated_at" TIMESTAMP   NOT NULL DEFAULT now(),
    CONSTRAINT "PK_accounts" PRIMARY KEY ("id")
);

-- -----------------------------------------------------------------------------
-- rates
-- Курсы криптовалют к фиатным валютам.
-- Хранит актуальные и исторические курсы; fiat_rates — JSON-объект вида {"USD":1.5,...}
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "rates" (
    "id"              uuid                          NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"      TIMESTAMP                     NOT NULL DEFAULT now(),
    "updated_at"      TIMESTAMP                     NOT NULL DEFAULT now(),
    "fiat_rates"      jsonb,
    "crypto_currency" "public"."RateCryptoCurrency" NOT NULL,
    "type"            "public"."RateType"           NOT NULL DEFAULT 'EXTERNAL',
    CONSTRAINT "PK_rates" PRIMARY KEY ("id")
);

-- -----------------------------------------------------------------------------
-- merchants
-- Мерчант — юридическое лицо, использующее платёжную систему.
-- Привязан к аккаунту (account_id) для учёта баланса.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "merchants" (
    "id"                    uuid                     NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"            TIMESTAMP                NOT NULL DEFAULT now(),
    "updated_at"            TIMESTAMP                NOT NULL DEFAULT now(),
    "name"                  character varying        NOT NULL,
    "public_key"            character varying        NOT NULL,
    "private_key"           character varying        NOT NULL,
    "encrypted_public_key"  character varying,
    "encrypted_private_key" character varying        NOT NULL,
    "account_id"            uuid                     UNIQUE,
    "type"                  "public"."MerchantType"  NOT NULL DEFAULT 'ENTERPRISE',
    CONSTRAINT "PK_merchants" PRIMARY KEY ("id"),
    CONSTRAINT "FK_merchants_accounts" FOREIGN KEY ("account_id")
        REFERENCES "accounts" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- merchant_credentials
-- API-ключи и белый список IP-адресов для мерчантов.
-- Один мерчант может иметь несколько наборов учётных данных.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "merchant_credentials" (
    "id"          uuid                                  NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"  TIMESTAMP                             NOT NULL DEFAULT now(),
    "updated_at"  TIMESTAMP                             NOT NULL DEFAULT now(),
    "merchant_id" uuid                                  NOT NULL,
    "external_id" character varying                     NOT NULL,
    "api_key"     character varying                     NOT NULL,
    "private_key" character varying                     NOT NULL,
    "status"      "public"."MerchantCredentialStatus"   NOT NULL,
    "ip_addresses" cidr[]                               NOT NULL,
    "for_callback" boolean                              NOT NULL DEFAULT false,
    CONSTRAINT "PK_merchant_credentials" PRIMARY KEY ("id"),
    CONSTRAINT "UQ_merchant_credentials_api_key" UNIQUE ("api_key"),
    CONSTRAINT "UQ_merchant_credentials_external_id_merchant_id" UNIQUE ("external_id", "merchant_id"),
    CONSTRAINT "FK_merchant_credentials_merchants" FOREIGN KEY ("merchant_id")
        REFERENCES "merchants" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- merchant_wallets
-- Кошельки мерчанта для получения и хранения криптовалюты.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "merchant_wallets" (
    "id"              uuid                      NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"      TIMESTAMP                 NOT NULL DEFAULT now(),
    "updated_at"      TIMESTAMP                 NOT NULL DEFAULT now(),
    "merchant_id"     uuid                      NOT NULL,
    "address"         character varying         NOT NULL,
    "crypto_currency" "public"."CryptoCurrency" NOT NULL,
    "account_id"      uuid,
    CONSTRAINT "PK_merchant_wallets" PRIMARY KEY ("id"),
    CONSTRAINT "UQ_merchant_wallets_address_currency" UNIQUE ("address", "crypto_currency"),
    CONSTRAINT "FK_merchant_wallets_merchants" FOREIGN KEY ("merchant_id")
        REFERENCES "merchants" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "FK_merchant_wallets_accounts" FOREIGN KEY ("account_id")
        REFERENCES "accounts" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- customer_wallets
-- Персональные кошельки клиентов мерчантов.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "customer_wallets" (
    "id"                      uuid                      NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"              TIMESTAMP                 NOT NULL DEFAULT now(),
    "updated_at"              TIMESTAMP                 NOT NULL DEFAULT now(),
    "wallet_address"          character varying         NOT NULL,
    "merchant_id"             uuid,
    "customer_id"             character varying         NOT NULL,
    "crypto_currency"         "public"."CryptoCurrency" NOT NULL,
    "convert_to_fiat_currency" "public"."FiatCurrency"  NOT NULL,
    "callback_url"            character varying         NOT NULL,
    "merchant_account_id"     character varying,
    "merchant_user_id"        character varying,
    "account_id"              uuid,
    "user_email"              character varying,
    "status"                  "public"."WalletStatus"   NOT NULL,
    CONSTRAINT "PK_customer_wallets" PRIMARY KEY ("id"),
    CONSTRAINT "UQ_customer_wallets_address_merchant_customer_currency"
        UNIQUE ("wallet_address", "merchant_id", "customer_id", "crypto_currency"),
    CONSTRAINT "FK_customer_wallets_accounts" FOREIGN KEY ("account_id")
        REFERENCES "accounts" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "FK_customer_wallets_merchants" FOREIGN KEY ("merchant_id")
        REFERENCES "merchants" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- merchant_transit_wallets
-- Транзитные кошельки мерчантов для промежуточного хранения средств.
-- merchant_id — varchar (внешний идентификатор).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "merchant_transit_wallets" (
    "id"              uuid                      NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"      TIMESTAMP                 NOT NULL DEFAULT now(),
    "updated_at"      TIMESTAMP                 NOT NULL DEFAULT now(),
    "wallet_address"  character varying         NOT NULL,
    "merchant_id"     character varying         NOT NULL,
    "crypto_currency" "public"."CryptoCurrency" NOT NULL,
    "account_id"      uuid,
    CONSTRAINT "PK_merchant_transit_wallets" PRIMARY KEY ("id"),
    CONSTRAINT "UQ_merchant_transit_wallets_address_merchant_currency"
        UNIQUE ("wallet_address", "merchant_id", "crypto_currency"),
    CONSTRAINT "FK_merchant_transit_wallets_accounts" FOREIGN KEY ("account_id")
        REFERENCES "accounts" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- customer_wallet_transactions
-- Транзакции по клиентским кошелькам (входящие депозиты, корректировки).
-- txid + vout — идентификатор on-chain транзакции.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "customer_wallet_transactions" (
    "id"                       uuid                                    NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"               TIMESTAMP                               NOT NULL DEFAULT now(),
    "updated_at"               TIMESTAMP                               NOT NULL DEFAULT now(),
    "txid"                     character varying,
    "vout"                     integer,
    "crypto_currency"          "public"."CryptoCurrency"               NOT NULL,
    "from_address"             character varying,
    "to_address"               character varying                       NOT NULL,
    "value"                    numeric                                 NOT NULL,
    "fiat_value"               numeric                                 NOT NULL,
    "fee"                      numeric                                 NOT NULL,
    "merchant_id"              character varying                       NOT NULL,
    "type"                     "public"."CustomerWalletTransactionType" NOT NULL DEFAULT 'CORRECT',
    "rate_id"                  uuid,
    "account_id"               uuid,
    "is_aml_checked"           boolean                                 NOT NULL,
    "status"                   "public"."TransactionStatus"            NOT NULL,
    "was_aml_skipped"          boolean                                 NOT NULL DEFAULT false,
    "blockchain_transaction_id" uuid                                   UNIQUE,
    "income_fee"               numeric,
    "aml_status"               "public"."AmlAnalysisStatus",
    "refund_status"            "public"."RefundStatus",
    "is_collected"             boolean                                 NOT NULL DEFAULT false,
    CONSTRAINT "PK_customer_wallet_transactions" PRIMARY KEY ("id"),
    CONSTRAINT "UQ_cwt_currency_txid_vout" UNIQUE ("crypto_currency", "txid", "vout"),
    CONSTRAINT "FK_cwt_rates" FOREIGN KEY ("rate_id")
        REFERENCES "rates" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "FK_cwt_accounts" FOREIGN KEY ("account_id")
        REFERENCES "accounts" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- merchant_transit_wallet_transactions
-- Транзакции по транзитным кошелькам мерчантов. Транзитный кошелек, это копилка с которой пополняется главный мерчантский кошелек.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "merchant_transit_wallet_transactions" (
    "id"                       uuid                                          NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"               TIMESTAMP                                     NOT NULL DEFAULT now(),
    "updated_at"               TIMESTAMP                                     NOT NULL DEFAULT now(),
    "txid"                     character varying                             NOT NULL,
    "vout"                     integer,
    "type"                     "public"."MerchantTransitWalletTransactionType" NOT NULL DEFAULT 'CORRECT',
    "crypto_currency"          "public"."CryptoCurrency"                     NOT NULL,
    "crypto_value"             numeric                                       NOT NULL,
    "from"                     character varying,
    "to"                       character varying                             NOT NULL,
    "fee"                      numeric                                       NOT NULL,
    "merchant_id"              character varying                             NOT NULL,
    "rate_id"                  uuid                                          NOT NULL,
    "account_id"               uuid,
    "income_fee"               numeric,
    "status"                   "public"."TransactionStatus"                  NOT NULL,
    "blockchain_transaction_id" uuid                                         UNIQUE,
    "is_collected"             boolean                                       NOT NULL DEFAULT false,
    CONSTRAINT "PK_merchant_transit_wallet_transactions" PRIMARY KEY ("id"),
    CONSTRAINT "UQ_mtwt_currency_txid" UNIQUE ("crypto_currency", "txid"),
    CONSTRAINT "FK_mtwt_rates" FOREIGN KEY ("rate_id")
        REFERENCES "rates" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "FK_mtwt_accounts" FOREIGN KEY ("account_id")
        REFERENCES "accounts" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- payouts
-- Выплаты с платформы на внешние адреса клиентов мерчантов.
-- external_id + merchant_id — уникальный идентификатор выплаты на стороне мерчанта.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "payouts" (
    "id"                        uuid                                   NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"                TIMESTAMP                              NOT NULL DEFAULT now(),
    "updated_at"                TIMESTAMP                              NOT NULL DEFAULT now(),
    "external_id"               character varying                      NOT NULL,
    "recipient_address"         character varying                      NOT NULL,
    "status"                    "public"."payouts_status_enum"         NOT NULL DEFAULT 'QUEUED',
    "callback_url"              character varying                      NOT NULL,
    "merchant_id"               uuid                                   NOT NULL,
    "blockchain_transaction_id" uuid,
    "fiat_amount"               numeric                                NOT NULL,
    "fiat_currency"             "public"."FiatCurrency"                NOT NULL,
    "crypto_amount"             numeric                                NOT NULL,
    "crypto_currency"           "public"."CryptoCurrency"              NOT NULL,
    "fee"                       numeric                                NOT NULL DEFAULT 0,
    "rate_id"                   uuid,
    "txid"                      character varying,
    "user_id"                   uuid,
    "merchant_account_id"       character varying,
    "merchant_user_id"          character varying,
    "creation_method"           "public"."payouts_creation_method_enum" NOT NULL DEFAULT 'UNKNOWN',
    "tag"                       character varying,
    "processing_delay_time_sec" integer                                NOT NULL DEFAULT 0,
    "was_aml_skipped"           boolean                                NOT NULL DEFAULT false,
    "aml_status"                "public"."AmlAnalysisStatus"           NOT NULL DEFAULT 'COMPLETED',
    "validation_error"          "public"."payouts_validation_error_enum",
    CONSTRAINT "PK_payouts" PRIMARY KEY ("id"),
    CONSTRAINT "UQ_payouts_external_id_merchant_id" UNIQUE ("external_id", "merchant_id"),
    CONSTRAINT "FK_payouts_merchants" FOREIGN KEY ("merchant_id")
        REFERENCES "merchants" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "FK_payouts_rates" FOREIGN KEY ("rate_id")
        REFERENCES "rates" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- payout_transfers
-- Отдельные попытки blockchain-перевода для конкретной выплаты.
-- Одна выплата может иметь несколько попыток (attempt).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "payout_transfers" (
    "id"                      uuid                                   NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"              TIMESTAMP                              NOT NULL DEFAULT now(),
    "updated_at"              TIMESTAMP                              NOT NULL DEFAULT now(),
    "fee"                     numeric                                NOT NULL,
    "amount"                  numeric                                NOT NULL,
    "currency"                "public"."CryptoCurrency"              NOT NULL,
    "status"                  "public"."payout_transfers_status_enum" NOT NULL,
    "from"                    character varying                      NOT NULL,
    "to"                      character varying                      NOT NULL,
    "blockchain_api_transfer_id" character varying,
    "txid"                    character varying,
    "payout_id"               uuid                                   NOT NULL,
    "tag"                     character varying,
    "attempt"                 smallint                               NOT NULL DEFAULT 1,
    "failed_reason"           character varying,
    "details"                 character varying,
    CONSTRAINT "PK_payout_transfers" PRIMARY KEY ("id"),
    CONSTRAINT "UQ_payout_transfers_payout_status_attempt" UNIQUE ("payout_id", "status", "attempt"),
    CONSTRAINT "FK_payout_transfers_payouts" FOREIGN KEY ("payout_id")
        REFERENCES "payouts" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- refunds
-- Возвраты средств по конкретным транзакциям.
-- transaction_id + transaction_type — ссылка на исходную транзакцию.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "refunds" (
    "id"                       uuid                              NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"               TIMESTAMP                         NOT NULL DEFAULT now(),
    "updated_at"               TIMESTAMP                         NOT NULL DEFAULT now(),
    "transaction_type"         "public"."RefundTransactionType"  NOT NULL,
    "transaction_id"           uuid                              NOT NULL,
    "account_id"               uuid                              NOT NULL,
    "from"                     character varying                 NOT NULL,
    "status"                   "public"."RefundStatus"           NOT NULL,
    "crypto_amount"            numeric                           NOT NULL,
    "crypto_currency"          "public"."CryptoCurrency"         NOT NULL,
    "fiat_amount"              numeric                           NOT NULL,
    "fiat_currency"            "public"."FiatCurrency"           NOT NULL,
    "to"                       character varying                 NOT NULL,
    "issuer_id"                character varying                 NOT NULL,
    "blockchain_transaction_id" uuid                             NOT NULL,
    CONSTRAINT "PK_refunds" PRIMARY KEY ("id"),
    CONSTRAINT "FK_refunds_accounts" FOREIGN KEY ("account_id")
        REFERENCES "accounts" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- refund_transfers
-- Blockchain-переводы для выполнения возвратов.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "refund_transfers" (
    "id"                    uuid                               NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"            TIMESTAMP                          NOT NULL DEFAULT now(),
    "updated_at"            TIMESTAMP                          NOT NULL DEFAULT now(),
    "status"                "public"."RefundTransferStatus"    NOT NULL,
    "blockchain_id"         uuid,
    "txid"                  character varying,
    "amount"                numeric                            NOT NULL,
    "currency"              "public"."CryptoCurrency"          NOT NULL,
    "refund_id"             uuid                               NOT NULL,
    "fee_deposit_transfer_id" uuid                             UNIQUE,
    "fee"                   numeric,
    CONSTRAINT "PK_refund_transfers" PRIMARY KEY ("id"),
    CONSTRAINT "FK_refund_transfers_refunds" FOREIGN KEY ("refund_id")
        REFERENCES "refunds" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- transfers
-- Внутренние blockchain-переводы между Custodial-crypto-wallet и внутреним blockchain-сервисом
-- (трансферы сбора и рефилла (покрытие коммисии за вывод и сбор)).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "transfers" (
    "id"                uuid                         NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"        TIMESTAMP                    NOT NULL DEFAULT now(),
    "updated_at"        TIMESTAMP                    NOT NULL DEFAULT now(),
    "value"             numeric                      NOT NULL,
    "currency"          "public"."CryptoCurrency"    NOT NULL,
    "status"            "public"."TransferStatus"    NOT NULL,
    "from"              character varying            NOT NULL,
    "to"                character varying            NOT NULL,
    "txid"              character varying,
    "blockchain_id"     character varying,
    "fail_reason"       character varying            NOT NULL DEFAULT '',
    "subtract_fee"      boolean                      NOT NULL,
    "fee"               numeric,
    "merchant_id"       character varying            NOT NULL,
    "linked_transfer_id" uuid,
    "account_id"        uuid,
    "type"              "public"."TransferType",
    CONSTRAINT "PK_transfers" PRIMARY KEY ("id"),
    CONSTRAINT "FK_transfers_accounts" FOREIGN KEY ("account_id")
        REFERENCES "accounts" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- transaction_data
-- Агрегированная таблица данных всех транзакций платформы.
-- Служит единой точкой доступа для BO, отчётности и обратных вызовов.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "transaction_data" (
    "id"                 uuid                                    NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"         TIMESTAMP                               NOT NULL DEFAULT now(),
    "updated_at"         TIMESTAMP                               NOT NULL DEFAULT now(),
    "customer_id"        character varying,
    "customer_address"   character varying,
    "customer_email"     character varying,
    "crypto_amount"      numeric                                 NOT NULL,
    "crypto_currency"    "public"."CryptoCurrency"               NOT NULL,
    "external_id"        character varying,
    "fiat_amount"        numeric                                 NOT NULL,
    "fiat_currency"      "public"."FiatCurrency"                 NOT NULL,
    "fee"                numeric,
    "merchant_id"        uuid                                    NOT NULL,
    "payment_address"    character varying,
    "source_type"        "public"."TransactionSourceType"        NOT NULL,
    "source_created_at"  TIMESTAMP                               NOT NULL,
    "source_updated_at"  TIMESTAMP                               NOT NULL,
    "source_external_id" character varying                       NOT NULL,
    "status"             "public"."transaction_data_status_enum" NOT NULL,
    "txid"               character varying,
    "vout"               integer,
    "account_id"         uuid                                    NOT NULL,
    "rate_id"            uuid                                    NOT NULL,
    "user_id"            uuid,
    "internal_fee"       numeric,
    "tag"                character varying,
    CONSTRAINT "PK_transaction_data" PRIMARY KEY ("id"),
    CONSTRAINT "UQ_transaction_data_source_external_id_source_type" UNIQUE ("source_external_id", "source_type"),
    CONSTRAINT "FK_transaction_data_merchants" FOREIGN KEY ("merchant_id")
        REFERENCES "merchants" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "FK_transaction_data_accounts" FOREIGN KEY ("account_id")
        REFERENCES "accounts" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "FK_transaction_data_rates" FOREIGN KEY ("rate_id")
        REFERENCES "rates" ("id") ON DELETE SET NULL ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- callback_histories
-- История всех исходящих callback-запросов к мерчантам. Используется об уведомлении мерчанта о статусе транзакции.
-- type_external_id — идентификатор транзакции, по которой отправлен callback.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "callback_histories" (
    "id"              uuid                                NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"      TIMESTAMP                           NOT NULL DEFAULT now(),
    "updated_at"      TIMESTAMP                           NOT NULL DEFAULT now(),
    "type"            character varying                   NOT NULL,
    "url"             character varying                   NOT NULL,
    "type_external_id" character varying                  NOT NULL,
    "sent_data"       jsonb                               NOT NULL,
    "response_status" integer,
    "response_message" character varying,
    "payload_status"  "public"."CallbackPayloadStatus",
    CONSTRAINT "PK_callback_histories" PRIMARY KEY ("id")
);

-- -----------------------------------------------------------------------------
-- config_properties
-- Конфигурационные параметры системы, сгруппированные по issuer_id (merchant_id).
-- Почему не merchant_id (uuid) - потому что есть технические issuers, которые не относятся к фактическим мерчантам
-- Используется для хранения лимитов, адресов, порогов AML и других настроек.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "config_properties" (
    "id"         uuid                          NOT NULL DEFAULT uuid_generate_v4(),
    "created_at" TIMESTAMP                     NOT NULL DEFAULT now(),
    "updated_at" TIMESTAMP                     NOT NULL DEFAULT now(),
    "issuer_id"  character varying             NOT NULL,
    "name"       "public"."ConfigPropertyName" NOT NULL,
    "value"      character varying             NOT NULL,
    CONSTRAINT "PK_config_properties" PRIMARY KEY ("id")
);

-- -----------------------------------------------------------------------------
-- aml_scorings
-- Результаты AML-проверок адресов и транзакций через Crystal API.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "aml_scorings" (
    "id"                    uuid                                NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"            TIMESTAMP                           NOT NULL DEFAULT now(),
    "updated_at"            TIMESTAMP                           NOT NULL DEFAULT now(),
    "txid"                  character varying,
    "address"               character varying,
    "scoring_data"          jsonb,
    "status"                "public"."CrystalAmlAnalysisStatus" NOT NULL,
    "type"                  "public"."AmlScoringType"           NOT NULL DEFAULT 'DEPOSIT_TRANSACTION',
    "error"                 character varying,
    "source_transaction_id" uuid,
    CONSTRAINT "PK_aml_scorings" PRIMARY KEY ("id")
);

-- -----------------------------------------------------------------------------
-- account_fees
-- Разовые или накопленные комиссии, закреплённые за аккаунтом.
-- Используются для legacy-миграций списаний с аккаунта.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "account_fees" (
    "id"          uuid                      NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"  TIMESTAMP                 NOT NULL DEFAULT now(),
    "updated_at"  TIMESTAMP                 NOT NULL DEFAULT now(),
    "amount"      numeric                   NOT NULL,
    "currency"    "public"."CryptoCurrency" NOT NULL,
    "type"        "public"."AccountFeeType" NOT NULL,
    "account_id"  uuid                      NOT NULL,
    "description" character varying         NOT NULL,
    CONSTRAINT "PK_account_fees" PRIMARY KEY ("id"),
    CONSTRAINT "UQ_account_fees_account_description" UNIQUE ("account_id", "description"),
    CONSTRAINT "FK_account_fees_accounts" FOREIGN KEY ("account_id")
        REFERENCES "accounts" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- fee_policies
-- Политики начисления комиссий для аккаунта и типа транзакции.
-- Определяет, какие типы комиссий применяются к каждой операции.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "fee_policies" (
    "id"               uuid                              NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"       TIMESTAMP                         NOT NULL DEFAULT now(),
    "updated_at"       TIMESTAMP                         NOT NULL DEFAULT now(),
    "account_id"       uuid                              NOT NULL,
    "transaction_type" "public"."AccountTransactionType" NOT NULL,
    "fees"             "public"."FeeType"[]              NOT NULL,
    "source"           "public"."FeePolicySource"        NOT NULL DEFAULT 'SYSTEM_DEFAULT',
    CONSTRAINT "PK_fee_policies" PRIMARY KEY ("id"),
    CONSTRAINT "UQ_fee_policies_account_transaction_type" UNIQUE ("account_id", "transaction_type"),
    CONSTRAINT "FK_fee_policies_accounts" FOREIGN KEY ("account_id")
        REFERENCES "accounts" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- account_transactions
-- Учётные записи движения средств по аккаунтам.
-- original_transaction_id — UUID исходной транзакции (payout, deposit и т.д.)
-- available_at — время, с которого средства доступны (для заморозок)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "account_transactions" (
    "id"                     uuid                              NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"             TIMESTAMP                         NOT NULL DEFAULT now(),
    "updated_at"             TIMESTAMP                         NOT NULL DEFAULT now(),
    "account_id"             uuid                              NOT NULL,
    "amount"                 numeric                           NOT NULL,
    "currency"               "public"."CryptoCurrency"         NOT NULL,
    "type"                   "public"."AccountTransactionType" NOT NULL,
    "status"                 "public"."TransactionStatus"      NOT NULL,
    "original_transaction_id" uuid                             NOT NULL,
    "timestamp"              TIMESTAMP WITHOUT TIME ZONE,
    "available_at"           TIMESTAMP,
    "is_available"           boolean                           NOT NULL DEFAULT false,
    CONSTRAINT "PK_account_transactions" PRIMARY KEY ("id"),
    CONSTRAINT "FK_account_transactions_accounts" FOREIGN KEY ("account_id")
        REFERENCES "accounts" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- -----------------------------------------------------------------------------
-- account_transaction_fees
-- Детальная разбивка комиссий по каждой учётной записи аккаунта.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "account_transaction_fees" (
    "id"                    uuid                      NOT NULL DEFAULT uuid_generate_v4(),
    "created_at"            TIMESTAMP                 NOT NULL DEFAULT now(),
    "updated_at"            TIMESTAMP                 NOT NULL DEFAULT now(),
    "account_transaction_id" uuid                     NOT NULL,
    "type"                  "public"."FeeType"        NOT NULL,
    "amount"                numeric                   NOT NULL,
    "currency"              "public"."CryptoCurrency" NOT NULL,
    "account_fee_policy_id" uuid                      NOT NULL,
    "fee_percent_amount"    numeric                            DEFAULT 0,
    "fee_flat_amount"       numeric                            DEFAULT 0,
    CONSTRAINT "PK_account_transaction_fees" PRIMARY KEY ("id"),
    CONSTRAINT "UQ_atf_account_transaction_type" UNIQUE ("account_transaction_id", "type"),
    CONSTRAINT "FK_atf_account_transactions" FOREIGN KEY ("account_transaction_id")
        REFERENCES "account_transactions" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT "FK_atf_fee_policies" FOREIGN KEY ("account_fee_policy_id")
        REFERENCES "fee_policies" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);
