-- =============================================================================
-- Payment System Database — INSERT DATA
-- Описание: Примеры вставки данных во все основные таблицы
-- =============================================================================

-- =============================================================================
-- accounts
-- Базовый аккаунт не требует дополнительных полей
-- =============================================================================

INSERT INTO accounts (id)
VALUES
    ('a1000000-0000-0000-0000-000000000001'),
    ('a1000000-0000-0000-0000-000000000002'),
    ('a1000000-0000-0000-0000-000000000003')
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- rates
-- Курсы криптовалют; fiat_rates — JSON с котировками к фиатным валютам
-- =============================================================================

INSERT INTO rates (id, fiat_rates, crypto_currency, type)
VALUES
    (
        'b2000000-0000-0000-0000-000000000001',
        '{"USD": 67450.50, "EUR": 62300.00, "RUB": 6200000.00}'::jsonb,
        'BTC'::"public"."RateCryptoCurrency",
        'EXTERNAL'::"public"."RateType"
    ),
    (
        'b2000000-0000-0000-0000-000000000002',
        '{"USD": 3520.75, "EUR": 3248.00, "RUB": 323500.00}'::jsonb,
        'ETH'::"public"."RateCryptoCurrency",
        'EXTERNAL'::"public"."RateType"
    ),
    (
        'b2000000-0000-0000-0000-000000000003',
        '{"USD": 1.001, "EUR": 0.923, "RUB": 92.00}'::jsonb,
        'USDT'::"public"."RateCryptoCurrency",
        'EXTERNAL'::"public"."RateType"
    ),
    (
        'b2000000-0000-0000-0000-000000000004',
        '{"USD": 0.1285, "EUR": 0.1186, "RUB": 11.82}'::jsonb,
        'TRX'::"public"."RateCryptoCurrency",
        'EXTERNAL'::"public"."RateType"
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- merchants
-- Мерчанты; привязаны к аккаунту через account_id
-- =============================================================================

INSERT INTO merchants (id, name, public_key, private_key, encrypted_private_key, type, account_id)
VALUES
    (
        'c3000000-0000-0000-0000-000000000001',
        'Acme Corp',
        'pk_acme_pub_key_example',
        'pk_acme_priv_key_example',
        'encrypted_priv_key_acme',
        'ENTERPRISE'::"public"."MerchantType",
        'a1000000-0000-0000-0000-000000000001'
    ),
    (
        'c3000000-0000-0000-0000-000000000002',
        'Small Shop LLC',
        'pk_shop_pub_key_example',
        'pk_shop_priv_key_example',
        'encrypted_priv_key_shop',
        'SMB'::"public"."MerchantType",
        'a1000000-0000-0000-0000-000000000002'
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- merchant_credentials
-- API-ключи для аутентификации мерчантов
-- =============================================================================

INSERT INTO merchant_credentials
    (id, merchant_id, external_id, api_key, private_key, status, ip_addresses, for_callback)
VALUES
    (
        'd4000000-0000-0000-0000-000000000001',
        'c3000000-0000-0000-0000-000000000001',
        'acme-main-cred',
        'api_key_acme_main_example',
        'priv_key_cred_acme',
        'ACTIVE'::"public"."MerchantCredentialStatus",
        ARRAY['185.10.50.0/24', '192.168.1.100/32']::cidr[],
        false
    ),
    (
        'd4000000-0000-0000-0000-000000000002',
        'c3000000-0000-0000-0000-000000000001',
        'acme-callback-cred',
        'api_key_acme_callback_example',
        'priv_key_cred_callback',
        'ACTIVE'::"public"."MerchantCredentialStatus",
        ARRAY['185.10.50.0/24']::cidr[],
        true  -- единственный callback-credential для мерчанта
    ),
    (
        'd4000000-0000-0000-0000-000000000003',
        'c3000000-0000-0000-0000-000000000002',
        'shop-main-cred',
        'api_key_shop_main_example',
        'priv_key_cred_shop',
        'ACTIVE'::"public"."MerchantCredentialStatus",
        ARRAY['0.0.0.0/0']::cidr[], -- любой IP
        false
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- merchant_wallets
-- Кошельки мерчантов для приёма криптовалюты
-- =============================================================================

INSERT INTO merchant_wallets
    (id, merchant_id, address, crypto_currency, account_id)
VALUES
    (
        'e5000000-0000-0000-0000-000000000001',
        'c3000000-0000-0000-0000-000000000001',
        '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2',
        'BTC'::"public"."CryptoCurrency",
        'a1000000-0000-0000-0000-000000000001'
    ),
    (
        'e5000000-0000-0000-0000-000000000002',
        'c3000000-0000-0000-0000-000000000001',
        'TXYZacme0000000000000000000000000000',
        'USDT-TRC20'::"public"."CryptoCurrency",
        'a1000000-0000-0000-0000-000000000001'
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- customer_wallets
-- Персональные кошельки клиентов мерчантов
-- =============================================================================

INSERT INTO customer_wallets
    (id, wallet_address, merchant_id, customer_id, merchant_account_id, merchant_user_id, crypto_currency,
     convert_to_fiat_currency, callback_url, account_id, status)
VALUES
    (
        'f6000000-0000-0000-0000-000000000001',
        'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
        'c3000000-0000-0000-0000-000000000001',
        'client-001',
        '392619',
        '874215',
        'BTC'::"public"."CryptoCurrency",
        'USD'::"public"."FiatCurrency",
        'https://acme.example.com/callbacks/btc',
        'a1000000-0000-0000-0000-000000000003',
        'ACTIVE'::"public"."WalletStatus"
    ),
    (
        'f6000000-0000-0000-0000-000000000002',
        'TRXclientaddress000000000000000000',
        'c3000000-0000-0000-0000-000000000001',
        'client-002',
        '573831',
        '475932',
        'USDT-TRC20'::"public"."CryptoCurrency",
        'EUR'::"public"."FiatCurrency",
        'https://acme.example.com/callbacks/trx',
        NULL,
        'ACTIVE'::"public"."WalletStatus"
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- merchant_transit_wallets
-- Транзитные кошельки для промежуточного хранения средств
-- =============================================================================

INSERT INTO merchant_transit_wallets
    (id, wallet_address, merchant_id, crypto_currency, account_id)
VALUES
    (
        'f7000000-0000-0000-0000-000000000001',
        'transit_btc_address_acme_0001',
        'c3000000-0000-0000-0000-000000000001',
        'BTC'::"public"."CryptoCurrency",
        'a1000000-0000-0000-0000-000000000001'
    ),
    (
        'f7000000-0000-0000-0000-000000000002',
        'transit_trc20_address_acme_0001',
        'c3000000-0000-0000-0000-000000000001',
        'USDT-TRC20'::"public"."CryptoCurrency",
        'a1000000-0000-0000-0000-000000000001'
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- customer_wallet_transactions
-- Входящие транзакции на клиентские кошельки
-- =============================================================================

INSERT INTO customer_wallet_transactions
    (id, txid, vout, crypto_currency, from_address, to_address, value, fiat_value, fee,
     merchant_id, type, rate_id,
     account_id, is_aml_checked, status, was_aml_skipped, aml_status)
VALUES
    (
        'aa000000-0000-0000-0000-000000000001',
        'btc_txid_example_0000000000000000000000000000000000000000000001',
        0,
        'BTC'::"public"."CryptoCurrency",
        '1SenderBitcoinAddress00000000000000',
        'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
        0.005,
        357,
        0.00001,
        'c3000000-0000-0000-0000-000000000001',
        'CORRECT'::"public"."CustomerWalletTransactionType",
        'b2000000-0000-0000-0000-000000000001',
        'a1000000-0000-0000-0000-000000000003',
        true,
        'SUCCESSFUL'::"public"."TransactionStatus",
        false,
        'COMPLETED'::"public"."AmlAnalysisStatus"
    ),
    (
        'aa000000-0000-0000-0000-000000000002',
        'trc20_txid_example_000000000000000000000000000000000000000001',
        0,
        'USDT-TRC20'::"public"."CryptoCurrency",
        NULL,
        'TRXclientaddress000000000000000000',
        150.00,
        150.00,
        0.00001,
        'c3000000-0000-0000-0000-000000000001',
        'CORRECT'::"public"."CustomerWalletTransactionType",
        'b2000000-0000-0000-0000-000000000003',
        'a1000000-0000-0000-0000-000000000003',
        true,
        false,
        'PENDING'::"public"."TransactionStatus",
        false,
        'COMPLETED'::"public"."AmlAnalysisStatus"
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- merchant_transit_wallet_transactions
-- Транзакции через транзитные кошельки мерчантов
-- =============================================================================

INSERT INTO merchant_transit_wallet_transactions
    (id, txid, vout, type, crypto_currency, crypto_value,
     "from", "to", fee, merchant_id, rate_id, account_id, status)
VALUES
    (
        'bb000000-0000-0000-0000-000000000001',
        'transit_btc_txid_000000000000000000000000000000000000000001',
        0,
        'CORRECT'::"public"."MerchantTransitWalletTransactionType",
        'BTC'::"public"."CryptoCurrency",
        0.015,
        '1SenderBitcoinAddress00000000000000',
        'transit_btc_address_acme_0001',
        0.00003,
        'c3000000-0000-0000-0000-000000000001',
        'b2000000-0000-0000-0000-000000000001',
        'a1000000-0000-0000-0000-000000000001',
        'SUCCESSFUL'::"public"."TransactionStatus"
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- payouts
-- Выплаты мерчантов на внешние адреса
-- =============================================================================

INSERT INTO payouts
    (id, external_id, recipient_address, status, callback_url, merchant_id,
     fiat_amount, fiat_currency, crypto_amount, crypto_currency, fee,
     rate_id, creation_method, aml_status)
VALUES
    (
        'cc000000-0000-0000-0000-000000000001',
        'payout-acme-2024-001',
        'TRXrecipientaddress00000000000000000',
        'QUEUED'::"public"."payouts_status_enum",
        'https://acme.example.com/callbacks/payout',
        'c3000000-0000-0000-0000-000000000001',
        100.00,
        'USD'::"public"."FiatCurrency",
        99.85,
        'USDT-TRC20'::"public"."CryptoCurrency",
        1.50,
        'b2000000-0000-0000-0000-000000000003',
        'API_V2'::"public"."payouts_creation_method_enum",
        'PENDING'::"public"."AmlAnalysisStatus"
    ),
    (
        'cc000000-0000-0000-0000-000000000002',
        'payout-acme-2024-002',
        '1BTCrecipientAddress0000000000000000',
        'COMPLETED'::"public"."payouts_status_enum",
        'https://acme.example.com/callbacks/payout',
        'c3000000-0000-0000-0000-000000000001',
        500.00,
        'USD'::"public"."FiatCurrency",
        0.00741,
        'BTC'::"public"."CryptoCurrency",
        5.00,
        'b2000000-0000-0000-0000-000000000001',
        'API_V1'::"public"."payouts_creation_method_enum",
        'COMPLETED'::"public"."AmlAnalysisStatus"
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- payout_transfers
-- Попытки blockchain-перевода для выплаты
-- =============================================================================

INSERT INTO payout_transfers
    (id, fee, amount, currency, status, "from", "to",
     txid, payout_id, attempt)
VALUES
    (
        'dd000000-0000-0000-0000-000000000001',
        1.50,
        99.85,
        'USDT-TRC20'::"public"."CryptoCurrency",
        'PENDING'::"public"."payout_transfers_status_enum",
        'transit_trc20_address_acme_0001',
        'TRXrecipientaddress00000000000000000',
        NULL,
        'cc000000-0000-0000-0000-000000000001',
        1
    ),
    (
        'dd000000-0000-0000-0000-000000000002',
        5.00,
        0.00741,
        'BTC'::"public"."CryptoCurrency",
        'SUCCESSFUL'::"public"."payout_transfers_status_enum",
        'transit_btc_address_acme_0001',
        '1BTCrecipientAddress0000000000000000',
        'completed_btc_txid_0000000000000000000000000000000000000001',
        'cc000000-0000-0000-0000-000000000002',
        1
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- refunds
-- Возвраты средств по транзакциям
-- =============================================================================

INSERT INTO refunds
    (id, transaction_type, transaction_id, account_id, "from",
     status, crypto_amount, crypto_currency, fiat_amount, fiat_currency,
     "to", issuer_id, blockchain_transaction_id)
VALUES
    (
        'ee000000-0000-0000-0000-000000000001',
        'CUSTOMER_WALLET_TRANSACTION'::"public"."RefundTransactionType",
        'aa000000-0000-0000-0000-000000000001',
        'a1000000-0000-0000-0000-000000000003',
        'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
        'PENDING'::"public"."RefundStatus",
        0.005,
        'BTC'::"public"."CryptoCurrency",
        337.25,
        'USD'::"public"."FiatCurrency",
        '1SenderBitcoinAddress00000000000000',
        'issuer-001',
        'ff000000-0000-0000-0000-000000000099'
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- refund_transfers
-- Blockchain-переводы для выполнения возврата
-- =============================================================================

INSERT INTO refund_transfers
    (id, status, blockchain_id, txid, amount, currency, refund_id)
VALUES
    (
        'ff000000-0000-0000-0000-000000000001',
        'PENDING'::"public"."RefundTransferStatus",
        NULL,
        NULL,
        0.005,
        'BTC'::"public"."CryptoCurrency",
        'ee000000-0000-0000-0000-000000000001'
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- transfers
-- Внутренние blockchain-переводы между custodial-crypto-wallet и blockchain cервисом
-- =============================================================================

INSERT INTO transfers
    (id, value, currency, status, "from", "to",
     subtract_fee, merchant_id, account_id, type)
VALUES
    (
        '11000000-0000-0000-0000-000000000001',
        0.010,
        'BTC'::"public"."CryptoCurrency",
        'READY_TO_TRANSFER'::"public"."TransferStatus",
        '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2',
        'transit_btc_address_acme_0001',
        false,
        'c3000000-0000-0000-0000-000000000001',
        'a1000000-0000-0000-0000-000000000001',
        'COLLECT'::"public"."TransferType"
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- transaction_data
-- Агрегированная таблица всех транзакций для BO и отчётности
-- =============================================================================

INSERT INTO transaction_data
    (id, customer_id, crypto_amount, crypto_currency, fiat_amount, fiat_currency,
     merchant_id, source_type, source_created_at, source_updated_at,
     source_external_id, status, account_id, txid, fee, user_id, rate_id)
VALUES
    (
        '22000000-0000-0000-0000-000000000001',
        'client-001',
        0.005,
        'BTC'::"public"."CryptoCurrency",
        337.25,
        'USD'::"public"."FiatCurrency",
        'c3000000-0000-0000-0000-000000000001',
        'CUSTOMER_WALLET_TRANSACTION'::"public"."TransactionSourceType",
        now() - INTERVAL '1 hour',
        now(),
        'aa000000-0000-0000-0000-000000000001',
        'COMPLETED'::"public"."transaction_data_status_enum",
        'a1000000-0000-0000-0000-000000000001',
        'btc_txid_example_0000000000000000000000000000000000000000000001',
        0.00001,
        '67d25754-1628-479d-8626-e6baea023c34',
        'b2000000-0000-0000-0000-000000000001'
    ),
    (
        '22000000-0000-0000-0000-000000000002',
        NULL,
        99.85,
        'USDT-TRC20'::"public"."CryptoCurrency",
        100.00,
        'USD'::"public"."FiatCurrency",
        'c3000000-0000-0000-0000-000000000001',
        'PAYOUT_TRANSACTION'::"public"."TransactionSourceType",
        now() - INTERVAL '2 hours',
        now() - INTERVAL '1 hour',
        'cc000000-0000-0000-0000-000000000001',
        'COMPLETED'::"public"."transaction_data_status_enum",
        'a1000000-0000-0000-0000-000000000001',
        NULL,
        1.50,
        '6792f577-cd62-4600-8943-bd0e9492f7ed',
        'b2000000-0000-0000-0000-000000000003'
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- callback_histories
-- История исходящих webhook-вызовов к мерчантам
-- =============================================================================

INSERT INTO callback_histories
    (id, type, url, type_external_id, sent_data, response_status, response_message, payload_status)
VALUES
    (
        '33000000-0000-0000-0000-000000000001',
        'CUSTOMER_WALLET_TRANSACTION',
        'https://acme.example.com/callbacks/btc',
        'aa000000-0000-0000-0000-000000000001',
        '{"status": "SUCCESSFUL", "amount": 0.005, "currency": "BTC"}'::jsonb,
        200,
        'OK',
        'SUCCESSFUL'::"public"."CallbackPayloadStatus"
    ),
    (
        '33000000-0000-0000-0000-000000000002',
        'PAYOUT_TRANSACTION',
        'https://acme.example.com/callbacks/payout',
        'cc000000-0000-0000-0000-000000000001',
        '{"status": "QUEUED", "external_id": "payout-acme-2024-001"}'::jsonb,
        NULL,
        NULL,
        'SUBMITTED'::"public"."CallbackPayloadStatus"
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- config_properties
-- Конфигурационные параметры системы
-- =============================================================================

INSERT INTO config_properties (id, issuer_id, name, value)
VALUES
    (
        '44000000-0000-0000-0000-000000000001',
        'c3000000-0000-0000-0000-000000000001',
        'BITCOIN_MINIMUM_PAYOUT_AMOUNT'::"public"."ConfigPropertyName",
        '0.001'
    ),
    (
        '44000000-0000-0000-0000-000000000002',
        'c3000000-0000-0000-0000-000000000001',
        'TETHER_TRC20_MINIMUM_PAYOUT_AMOUNT'::"public"."ConfigPropertyName",
        '10'
    ),
    (
        '44000000-0000-0000-0000-000000000003',
        'c3000000-0000-0000-0000-000000000001',
        'MAX_SCORING'::"public"."ConfigPropertyName",
        '75'
    ),
    (
        '44000000-0000-0000-0000-000000000004',
        'c3000000-0000-0000-0000-000000000001',
        'MERCHANT_CREDENTIAL_IP_LIMIT'::"public"."ConfigPropertyName",
        '10'
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- aml_scorings
-- Результаты AML-проверок от Crystal API
-- =============================================================================

INSERT INTO aml_scorings
    (id, txid, address, scoring_data, status, type, source_transaction_id)
VALUES
    (
        '55000000-0000-0000-0000-000000000001',
        'btc_txid_example_0000000000000000000000000000000000000000000001',
        NULL,
        '{"riskscore": 15, "signals": []}'::jsonb,
        'COMPLETED'::"public"."CrystalAmlAnalysisStatus",
        'DEPOSIT_TRANSACTION'::"public"."AmlScoringType",
        'aa000000-0000-0000-0000-000000000001'
    ),
    (
        '55000000-0000-0000-0000-000000000002',
        NULL,
        '1SenderBitcoinAddress00000000000000',
        NULL,
        'PENDING'::"public"."CrystalAmlAnalysisStatus",
        'WITHDRAWAL_ADDRESS'::"public"."AmlScoringType",
        NULL
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- account_fees
-- Legacy-комиссии на аккаунтах
-- =============================================================================

INSERT INTO account_fees (id, amount, currency, type, account_id, description)
VALUES
    (
        '66000000-0000-0000-0000-000000000001',
        0.0005,
        'BTC'::"public"."CryptoCurrency",
        'LEGACY'::"public"."AccountFeeType",
        'a1000000-0000-0000-0000-000000000001',
        'legacy-btc-fee-001'
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- fee_policies
-- Политики начисления комиссий для аккаунта
-- =============================================================================

INSERT INTO fee_policies (id, account_id, transaction_type, fees, source)
VALUES
    (
        '77000000-0000-0000-0000-000000000001',
        'a1000000-0000-0000-0000-000000000001',
        'PAYOUT'::"public"."AccountTransactionType",
        ARRAY['ONE_PERCENT']::"public"."FeeType"[],
        'SYSTEM_DEFAULT'::"public"."FeePolicySource"
    ),
    (
        '77000000-0000-0000-0000-000000000002',
        'a1000000-0000-0000-0000-000000000001',
        'CUSTOMER_TRANSACTION'::"public"."AccountTransactionType",
        ARRAY['ONE_PERCENT', 'NETWORK_FEE']::"public"."FeeType"[],
        'MANUAL'::"public"."FeePolicySource"
    ),
    (
        '77000000-0000-0000-0000-000000000003',
        'a1000000-0000-0000-0000-000000000001',
        'MERCHANT_TRANSACTION'::"public"."AccountTransactionType",
        ARRAY['ZERO_PERCENT']::"public"."FeeType"[],
        'SEGMENT_DEFAULT'::"public"."FeePolicySource"
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- account_transactions
-- Учётные записи движения средств
-- =============================================================================

INSERT INTO account_transactions
    (id, account_id, amount, currency, type, status, original_transaction_id, timestamp)
VALUES
    (
        '88000000-0000-0000-0000-000000000001',
        'a1000000-0000-0000-0000-000000000003',
        0.005,
        'BTC'::"public"."CryptoCurrency",
        'CUSTOMER_TRANSACTION'::"public"."AccountTransactionType",
        'SUCCESSFUL'::"public"."TransactionStatus",
        'aa000000-0000-0000-0000-000000000001',
        now() - INTERVAL '1 hour'
    ),
    (
        '88000000-0000-0000-0000-000000000002',
        'a1000000-0000-0000-0000-000000000001',
        99.85,
        'USDT-TRC20'::"public"."CryptoCurrency",
        'PAYOUT'::"public"."AccountTransactionType",
        'PENDING'::"public"."TransactionStatus",
        'cc000000-0000-0000-0000-000000000001',
        now() - INTERVAL '2 hours'
    )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- account_transaction_fees
-- Детальные комиссии по каждой транзакции аккаунта
-- =============================================================================

INSERT INTO account_transaction_fees
    (id, account_transaction_id, type, amount, currency,
     account_fee_policy_id, fee_percent_amount, fee_flat_amount)
VALUES
    (
        '99000000-0000-0000-0000-000000000001',
        '88000000-0000-0000-0000-000000000001',
        'ONE_PERCENT'::"public"."FeeType",
        0.00005,
        'BTC'::"public"."CryptoCurrency",
        '77000000-0000-0000-0000-000000000002',
        0.00005,
        0
    ),
    (
        '99000000-0000-0000-0000-000000000002',
        '88000000-0000-0000-0000-000000000002',
        'ONE_PERCENT'::"public"."FeeType",
        0.9985,
        'USDT-TRC20'::"public"."CryptoCurrency",
        '77000000-0000-0000-0000-000000000001',
        0.9985,
        0
    )
ON CONFLICT (id) DO NOTHING;
