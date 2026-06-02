SET search_path = public;

-- =============================================================================
-- MERCHANTS
-- =============================================================================

CREATE OR REPLACE PROCEDURE create_merchant(
    OUT p_error_code        INT, -- Перенесён в начало
    p_name                  VARCHAR(255),
    p_public_key            VARCHAR(255),
    p_private_key           VARCHAR(255),
    p_encrypted_private_key VARCHAR(255),
    p_type                  VARCHAR(32),
    p_account_id            UUID DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_merchant_id UUID;
BEGIN
    p_error_code := 0;

    IF p_type NOT IN ('SMB', 'ENTERPRISE') THEN
        p_error_code := 400;
        RAISE NOTICE 'Invalid merchant type: %. Valid values are: SMB, ENTERPRISE', p_type;
        RETURN;
    END IF;

    IF p_account_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM accounts WHERE id = p_account_id) THEN
        p_error_code := 300;
        RAISE NOTICE 'Account with id % does not exist', p_account_id;
        RETURN;
    END IF;

    INSERT INTO merchants (name, public_key, private_key, encrypted_private_key, type, account_id)
    VALUES (p_name, p_public_key, p_private_key, p_encrypted_private_key,
            p_type::"public"."MerchantType", p_account_id)
    RETURNING id INTO v_merchant_id;

    RAISE NOTICE 'Merchant created successfully with id: %', v_merchant_id;

EXCEPTION
    WHEN NOT_NULL_VIOLATION OR FOREIGN_KEY_VIOLATION OR UNIQUE_VIOLATION THEN
        p_error_code := 100;
        RAISE NOTICE 'Error creating merchant: constraint violation — %', SQLERRM;
    WHEN OTHERS THEN
        p_error_code := 200;
        RAISE NOTICE 'Error creating merchant: %', SQLERRM;
END;
$$;


CREATE OR REPLACE PROCEDURE update_merchant_type(
    OUT p_error_code INT, -- Перенесён в начало
    p_merchant_id    UUID,
    p_type           VARCHAR(32)
)
LANGUAGE plpgsql
AS $$
BEGIN
    p_error_code := 0;

    IF p_type NOT IN ('SMB', 'ENTERPRISE') THEN
        p_error_code := 400;
        RAISE NOTICE 'Invalid merchant type: %. Valid values are: SMB, ENTERPRISE', p_type;
        RETURN;
    END IF;

    UPDATE merchants SET type = p_type::"public"."MerchantType", updated_at = now()
    WHERE id = p_merchant_id;

    IF NOT FOUND THEN
        p_error_code := 300;
        RAISE NOTICE 'Merchant with id % does not exist', p_merchant_id;
    ELSE
        RAISE NOTICE 'Merchant % type updated to %', p_merchant_id, p_type;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_error_code := 200;
        RAISE NOTICE 'Error updating merchant type: %', SQLERRM;
END;
$$;


-- =============================================================================
-- MERCHANT CREDENTIALS
-- =============================================================================

CREATE OR REPLACE PROCEDURE create_merchant_credentials(
    OUT p_error_code INT, -- Перенесён в начало
    p_merchant_id    UUID,
    p_external_id    VARCHAR(255),
    p_api_key        VARCHAR(255),
    p_private_key    VARCHAR(255),
    p_status         VARCHAR(32),
    p_ip_addresses   cidr[],
    p_for_callback   BOOLEAN DEFAULT false
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_credential_id UUID;
BEGIN
    p_error_code := 0;

    IF NOT EXISTS (SELECT 1 FROM merchants WHERE id = p_merchant_id) THEN
        p_error_code := 300;
        RAISE NOTICE 'Merchant with id % does not exist', p_merchant_id;
        RETURN;
    END IF;

    IF p_status NOT IN ('ACTIVE', 'DEPRECATED') THEN
        p_error_code := 400;
        RAISE NOTICE 'Invalid credential status: %. Valid values are: ACTIVE, DEPRECATED', p_status;
        RETURN;
    END IF;

    IF p_for_callback = true AND EXISTS (
        SELECT 1 FROM merchant_credentials
        WHERE merchant_id = p_merchant_id AND for_callback = true
    ) THEN
        p_error_code := 400;
        RAISE NOTICE 'Merchant % already has a callback credential', p_merchant_id;
        RETURN;
    END IF;

    INSERT INTO merchant_credentials
        (merchant_id, external_id, api_key, private_key, status, ip_addresses, for_callback)
    VALUES
        (p_merchant_id, p_external_id, p_api_key, p_private_key,
         p_status::"public"."MerchantCredentialStatus", p_ip_addresses, p_for_callback)
    RETURNING id INTO v_credential_id;

    RAISE NOTICE 'Merchant credentials created with id: %', v_credential_id;

EXCEPTION
    WHEN NOT_NULL_VIOLATION OR FOREIGN_KEY_VIOLATION OR UNIQUE_VIOLATION THEN
        p_error_code := 100;
        RAISE NOTICE 'Error creating merchant credentials: constraint violation — %', SQLERRM;
    WHEN OTHERS THEN
        p_error_code := 200;
        RAISE NOTICE 'Error creating merchant credentials: %', SQLERRM;
END;
$$;


CREATE OR REPLACE PROCEDURE deprecate_merchant_credentials(
    OUT p_error_code INT, -- Перенесён в начало
    p_credential_id  UUID
)
LANGUAGE plpgsql
AS $$
BEGIN
    p_error_code := 0;

    UPDATE merchant_credentials
    SET status = 'DEPRECATED'::"public"."MerchantCredentialStatus", updated_at = now()
    WHERE id = p_credential_id;

    IF NOT FOUND THEN
        p_error_code := 300;
        RAISE NOTICE 'Credential with id % does not exist', p_credential_id;
    ELSE
        RAISE NOTICE 'Credential % deprecated successfully', p_credential_id;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_error_code := 200;
        RAISE NOTICE 'Error deprecating credential: %', SQLERRM;
END;
$$;


-- =============================================================================
-- MERCHANT WALLETS
-- =============================================================================

CREATE OR REPLACE PROCEDURE create_merchant_wallet(
    OUT p_error_code  INT, -- Перенесён в начало
    p_merchant_id     UUID,
    p_address         VARCHAR(255),
    p_crypto_currency VARCHAR(64),
    p_account_id      UUID DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_wallet_id UUID;
BEGIN
    p_error_code := 0;

    IF NOT EXISTS (SELECT 1 FROM merchants WHERE id = p_merchant_id) THEN
        p_error_code := 300;
        RAISE NOTICE 'Merchant with id % does not exist', p_merchant_id;
        RETURN;
    END IF;

    IF p_account_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM accounts WHERE id = p_account_id) THEN
        p_error_code := 300;
        RAISE NOTICE 'Account with id % does not exist', p_account_id;
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1 FROM merchant_wallets
        WHERE address = p_address
          AND crypto_currency = p_crypto_currency::"public"."CryptoCurrency"
    ) THEN
        p_error_code := 100;
        RAISE NOTICE 'Wallet with address % and currency % already exists', p_address, p_crypto_currency;
        RETURN;
    END IF;

    INSERT INTO merchant_wallets
        (merchant_id, address, crypto_currency, account_id)
    VALUES
        (p_merchant_id, p_address, p_crypto_currency::"public"."CryptoCurrency", p_account_id)
    RETURNING id INTO v_wallet_id;

    RAISE NOTICE 'Merchant wallet created with id: %', v_wallet_id;

EXCEPTION
    WHEN NOT_NULL_VIOLATION OR FOREIGN_KEY_VIOLATION OR UNIQUE_VIOLATION THEN
        p_error_code := 100;
        RAISE NOTICE 'Error creating merchant wallet: constraint violation — %', SQLERRM;
    WHEN OTHERS THEN
        p_error_code := 200;
        RAISE NOTICE 'Error creating merchant wallet: %', SQLERRM;
END;
$$;


-- =============================================================================
-- CUSTOMER WALLETS
-- =============================================================================

CREATE OR REPLACE PROCEDURE create_customer_wallet(
    OUT p_error_code          INT, -- Перенесён в начало
    p_wallet_address          VARCHAR(255),
    p_merchant_id             VARCHAR(255),
    p_customer_id             VARCHAR(255),
    p_merchant_account_id     VARCHAR(255),
    p_merchant_user_id        VARCHAR(255),
    p_crypto_currency         VARCHAR(64),
    p_convert_to_fiat_currency VARCHAR(16),
    p_callback_url            VARCHAR(255),
    p_account_id              UUID DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_wallet_id UUID;
BEGIN
    p_error_code := 0;

    IF EXISTS (
        SELECT 1 FROM customer_wallets
        WHERE wallet_address = p_wallet_address
          AND merchant_id    = p_merchant_id
          AND customer_id    = p_customer_id
          AND crypto_currency = p_crypto_currency::"public"."CryptoCurrency"
    ) THEN
        p_error_code := 100;
        RAISE NOTICE 'Customer wallet already exists for merchant % / customer % / currency %',
            p_merchant_id, p_customer_id, p_crypto_currency;
        RETURN;
    END IF;

    IF p_account_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM accounts WHERE id = p_account_id) THEN
        p_error_code := 300;
        RAISE NOTICE 'Account with id % does not exist', p_account_id;
        RETURN;
    END IF;

    INSERT INTO customer_wallets
        (wallet_address, merchant_id, customer_id, merchant_account_id, merchant_user_id,
         crypto_currency, convert_to_fiat_currency, callback_url, account_id, status)
    VALUES
        (p_wallet_address, p_merchant_id, p_customer_id,
         p_merchant_account_id, p_merchant_user_id,
         p_crypto_currency::"public"."CryptoCurrency",
         p_convert_to_fiat_currency::"public"."FiatCurrency",
         p_callback_url, p_account_id,
         'ACTIVE'::"public"."WalletStatus")
    RETURNING id INTO v_wallet_id;

    RAISE NOTICE 'Customer wallet created with id: %', v_wallet_id;

EXCEPTION
    WHEN NOT_NULL_VIOLATION OR FOREIGN_KEY_VIOLATION OR UNIQUE_VIOLATION THEN
        p_error_code := 100;
        RAISE NOTICE 'Error creating customer wallet: constraint violation — %', SQLERRM;
    WHEN OTHERS THEN
        p_error_code := 200;
        RAISE NOTICE 'Error creating customer wallet: %', SQLERRM;
END;
$$;


-- =============================================================================
-- PAYOUTS
-- =============================================================================

CREATE OR REPLACE PROCEDURE create_payout(
    OUT p_error_code   INT, -- Перенесён в начало
    p_merchant_id      UUID,
    p_external_id      VARCHAR(255),
    p_recipient_address VARCHAR(255),
    p_callback_url     VARCHAR(255),
    p_fiat_amount      NUMERIC,
    p_fiat_currency    VARCHAR(16),
    p_crypto_amount    NUMERIC,
    p_crypto_currency  VARCHAR(64),
    p_creation_method  VARCHAR(32) DEFAULT 'UNKNOWN',
    p_rate_id          UUID DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_payout_id UUID;
BEGIN
    p_error_code := 0;

    IF NOT EXISTS (SELECT 1 FROM merchants WHERE id = p_merchant_id) THEN
        p_error_code := 300;
        RAISE NOTICE 'Merchant with id % does not exist', p_merchant_id;
        RETURN;
    END IF;

    IF p_creation_method NOT IN ('UNKNOWN', 'API_V1', 'API_V2', 'BO') THEN
        p_error_code := 400;
        RAISE NOTICE 'Invalid creation method: %. Valid: UNKNOWN, API_V1, API_V2, BO', p_creation_method;
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1 FROM payouts WHERE external_id = p_external_id AND merchant_id = p_merchant_id
    ) THEN
        p_error_code := 100;
        RAISE NOTICE 'Payout with external_id % already exists for merchant %', p_external_id, p_merchant_id;
        RETURN;
    END IF;

    IF p_rate_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rates WHERE id = p_rate_id) THEN
        p_error_code := 300;
        RAISE NOTICE 'Rate with id % does not exist', p_rate_id;
        RETURN;
    END IF;

    INSERT INTO payouts
        (merchant_id, external_id, recipient_address, callback_url, fiat_amount,
         fiat_currency, crypto_amount, crypto_currency, creation_method, rate_id, status)
    VALUES
        (p_merchant_id, p_external_id, p_recipient_address, p_callback_url,
         p_fiat_amount, p_fiat_currency::"public"."FiatCurrency",
         p_crypto_amount, p_crypto_currency::"public"."CryptoCurrency",
         p_creation_method::"public"."payouts_creation_method_enum",
         p_rate_id, 'PENDING'::"public"."payouts_status_enum")
    RETURNING id INTO v_payout_id;

    RAISE NOTICE 'Payout created with id: %', v_payout_id;

EXCEPTION
    WHEN NOT_NULL_VIOLATION OR FOREIGN_KEY_VIOLATION OR UNIQUE_VIOLATION THEN
        p_error_code := 100;
        RAISE NOTICE 'Error creating payout: constraint violation — %', SQLERRM;
    WHEN OTHERS THEN
        p_error_code := 200;
        RAISE NOTICE 'Error creating payout: %', SQLERRM;
END;
$$;


CREATE OR REPLACE PROCEDURE update_payout_status(
    OUT p_error_code INT, -- Перенесён в начало
    p_payout_id      UUID,
    p_status         VARCHAR(32),
    p_txid           VARCHAR(255) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    p_error_code := 0;

    IF p_status NOT IN ('SUBMITTED', 'COMPLETED', 'QUEUED', 'CANCELED') THEN
        p_error_code := 400;
        RAISE NOTICE 'Invalid payout status: %. Valid: SUBMITTED, COMPLETED, QUEUED, CANCELED', p_status;
        RETURN;
    END IF;

    UPDATE payouts
    SET status     = p_status::"public"."payouts_status_enum",
        txid       = COALESCE(p_txid, txid),
        updated_at = now()
    WHERE id = p_payout_id;

    IF NOT FOUND THEN
        p_error_code := 300;
        RAISE NOTICE 'Payout with id % does not exist', p_payout_id;
    ELSE
        RAISE NOTICE 'Payout % status updated to %', p_payout_id, p_status;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_error_code := 200;
        RAISE NOTICE 'Error updating payout status: %', SQLERRM;
END;
$$;


-- =============================================================================
-- ACCOUNTS
-- =============================================================================

CREATE OR REPLACE PROCEDURE create_account(
    OUT p_account_id UUID,
    OUT p_error_code INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    p_error_code := 0;

    INSERT INTO accounts DEFAULT VALUES
    RETURNING id INTO p_account_id;

    RAISE NOTICE 'Account created with id: %', p_account_id;

EXCEPTION
    WHEN OTHERS THEN
        p_error_code := 200;
        RAISE NOTICE 'Error creating account: %', SQLERRM;
END;
$$;


-- =============================================================================
-- FEE POLICIES
-- =============================================================================

CREATE OR REPLACE PROCEDURE create_fee_policy(
    OUT p_error_code   INT, -- Перенесён в начало
    p_account_id       UUID,
    p_transaction_type VARCHAR(64),
    p_fees             "public"."FeeType"[],
    p_source           VARCHAR(32) DEFAULT 'SYSTEM_DEFAULT'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_policy_id UUID;
BEGIN
    p_error_code := 0;

    IF NOT EXISTS (SELECT 1 FROM accounts WHERE id = p_account_id) THEN
        p_error_code := 300;
        RAISE NOTICE 'Account with id % does not exist', p_account_id;
        RETURN;
    END IF;

    IF p_transaction_type NOT IN (
        'CUSTOMER_TRANSACTION', 'MERCHANT_TRANSACTION', 'PAYOUT'
    ) THEN
        p_error_code := 400;
        RAISE NOTICE 'Invalid transaction type: %', p_transaction_type;
        RETURN;
    END IF;

    IF p_source NOT IN ('SYSTEM_DEFAULT', 'SEGMENT_DEFAULT', 'MANUAL') THEN
        p_error_code := 400;
        RAISE NOTICE 'Invalid fee policy source: %. Valid: SYSTEM_DEFAULT, SEGMENT_DEFAULT, MANUAL', p_source;
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1 FROM fee_policies
        WHERE account_id = p_account_id
          AND transaction_type = p_transaction_type::"public"."AccountTransactionType"
    ) THEN
        p_error_code := 100;
        RAISE NOTICE 'Fee policy for account % and transaction type % already exists',
            p_account_id, p_transaction_type;
        RETURN;
    END IF;

    INSERT INTO fee_policies (account_id, transaction_type, fees, source)
    VALUES (p_account_id,
            p_transaction_type::"public"."AccountTransactionType",
            p_fees,
            p_source::"public"."FeePolicySource")
    RETURNING id INTO v_policy_id;

    RAISE NOTICE 'Fee policy created with id: %', v_policy_id;

EXCEPTION
    WHEN NOT_NULL_VIOLATION OR FOREIGN_KEY_VIOLATION OR UNIQUE_VIOLATION THEN
        p_error_code := 100;
        RAISE NOTICE 'Error creating fee policy: constraint violation — %', SQLERRM;
    WHEN OTHERS THEN
        p_error_code := 200;
        RAISE NOTICE 'Error creating fee policy: %', SQLERRM;
END;
$$;


-- =============================================================================
-- ACCOUNT TRANSACTIONS
-- =============================================================================

CREATE OR REPLACE PROCEDURE create_account_transaction(
    OUT p_error_code         INT, -- Перенесён в начало
    p_account_id             UUID,
    p_amount                 NUMERIC,
    p_currency               VARCHAR(64),
    p_type                   VARCHAR(64),
    p_status                 VARCHAR(32),
    p_original_transaction_id UUID,
    p_available_at           TIMESTAMP DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tx_id UUID;
BEGIN
    p_error_code := 0;

    IF NOT EXISTS (SELECT 1 FROM accounts WHERE id = p_account_id) THEN
        p_error_code := 300;
        RAISE NOTICE 'Account with id % does not exist', p_account_id;
        RETURN;
    END IF;

    IF p_type NOT IN (
        'CUSTOMER_TRANSACTION', 'MERCHANT_TRANSACTION', 'PAYOUT'
    ) THEN
        p_error_code := 400;
        RAISE NOTICE 'Invalid account transaction type: %', p_type;
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1 FROM account_transactions
        WHERE original_transaction_id = p_original_transaction_id
          AND type = p_type::"public"."AccountTransactionType"
    ) THEN
        p_error_code := 100;
        RAISE NOTICE 'Account transaction for original_id % and type % already exists',
            p_original_transaction_id, p_type;
        RETURN;
    END IF;

    INSERT INTO account_transactions
        (account_id, amount, currency, type, status, original_transaction_id, available_at, timestamp)
    VALUES
        (p_account_id, p_amount,
         p_currency::"public"."CryptoCurrency",
         p_type::"public"."AccountTransactionType",
         p_status::"public"."TransactionStatus",
         p_original_transaction_id, p_available_at, now())
    RETURNING id INTO v_tx_id;

    RAISE NOTICE 'Account transaction created with id: %', v_tx_id;

EXCEPTION
    WHEN NOT_NULL_VIOLATION OR FOREIGN_KEY_VIOLATION OR UNIQUE_VIOLATION THEN
        p_error_code := 100;
        RAISE NOTICE 'Error creating account transaction: constraint violation — %', SQLERRM;
    WHEN OTHERS THEN
        p_error_code := 200;
        RAISE NOTICE 'Error creating account transaction: %', SQLERRM;
END;
$$;


-- =============================================================================
-- TRANSACTION DATA (UPSERT)
-- =============================================================================

CREATE OR REPLACE PROCEDURE upsert_transaction_data(
    OUT p_error_code     INT, -- Перенесён в начало
    p_merchant_id        UUID,
    p_account_id         UUID,
    p_rate_id            UUID,
    p_source_external_id VARCHAR(255),
    p_source_type        VARCHAR(64),
    p_status             VARCHAR(32),
    p_crypto_amount      NUMERIC,
    p_crypto_currency    VARCHAR(64),
    p_fiat_amount        NUMERIC,
    p_fiat_currency      VARCHAR(16),
    p_source_created_at  TIMESTAMP,
    p_source_updated_at  TIMESTAMP,
    p_customer_id        VARCHAR(255) DEFAULT NULL,
    p_external_id        VARCHAR(255) DEFAULT NULL,
    p_fee                NUMERIC      DEFAULT NULL,
    p_txid               VARCHAR(255) DEFAULT NULL,
    p_tag                VARCHAR(255) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    p_error_code := 0;

    IF NOT EXISTS (SELECT 1 FROM merchants WHERE id = p_merchant_id) THEN
        p_error_code := 300;
        RAISE NOTICE 'Merchant with id % does not exist', p_merchant_id;
        RETURN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM accounts WHERE id = p_account_id) THEN
        p_error_code := 300;
        RAISE NOTICE 'Account with id % does not exist', p_account_id;
        RETURN;
    END IF;

    INSERT INTO transaction_data
        (merchant_id, account_id, rate_id, source_external_id, source_type, status,
         crypto_amount, crypto_currency, fiat_amount, fiat_currency,
         source_created_at, source_updated_at, customer_id, external_id, fee, txid, tag)
    VALUES
        (p_merchant_id, p_account_id, p_rate_id, p_source_external_id,
         p_source_type::"public"."TransactionSourceType",
         p_status::"public"."transaction_data_status_enum",
         p_crypto_amount, p_crypto_currency::"public"."CryptoCurrency",
         p_fiat_amount, p_fiat_currency::"public"."FiatCurrency",
         p_source_created_at, p_source_updated_at,
         p_customer_id, p_external_id, p_fee, p_txid, p_tag)
    ON CONFLICT ("source_external_id", "source_type") DO UPDATE SET
        source_updated_at = GREATEST(transaction_data.source_updated_at, EXCLUDED.source_updated_at),
        external_id       = COALESCE(transaction_data.external_id, EXCLUDED.external_id),
        customer_id       = COALESCE(transaction_data.customer_id, EXCLUDED.customer_id),
        fee               = COALESCE(NULLIF(transaction_data.fee, 0), EXCLUDED.fee),
        txid              = COALESCE(transaction_data.txid, EXCLUDED.txid),
        tag               = COALESCE(transaction_data.tag, EXCLUDED.tag),
        status            = CASE
            WHEN transaction_data.status IN ('PENDING', 'QUEUED', 'AML_CHECKING')
            THEN EXCLUDED.status
            ELSE transaction_data.status
        END,
        updated_at        = now();

    RAISE NOTICE 'Transaction data upserted for source_external_id: %', p_source_external_id;

EXCEPTION
    WHEN NOT_NULL_VIOLATION OR FOREIGN_KEY_VIOLATION THEN
        p_error_code := 100;
        RAISE NOTICE 'Error upserting transaction data: constraint violation — %', SQLERRM;
    WHEN OTHERS THEN
        p_error_code := 200;
        RAISE NOTICE 'Error upserting transaction data: %', SQLERRM;
END;
$$;


-- =============================================================================
-- CALLBACK HISTORIES
-- =============================================================================

CREATE OR REPLACE PROCEDURE record_callback_history(
    OUT p_error_code   INT, -- Перенесён в начало
    p_type             VARCHAR(255),
    p_url              VARCHAR(255),
    p_type_external_id VARCHAR(255),
    p_sent_data        JSONB,
    p_response_status  INTEGER      DEFAULT NULL,
    p_response_message VARCHAR(512) DEFAULT NULL,
    p_payload_status   VARCHAR(32)  DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_history_id UUID;
BEGIN
    p_error_code := 0;

    IF p_type_external_id IS NULL OR p_type_external_id = '' THEN
        p_error_code := 400;
        RAISE NOTICE 'type_external_id cannot be empty';
        RETURN;
    END IF;

    INSERT INTO callback_histories
        (type, url, type_external_id, sent_data, response_status, response_message, payload_status)
    VALUES
        (p_type, p_url, p_type_external_id, p_sent_data,
         p_response_status, p_response_message,
         CASE WHEN p_payload_status IS NOT NULL
              THEN p_payload_status::"public"."CallbackPayloadStatus"
              ELSE NULL END)
    RETURNING id INTO v_history_id;

    RAISE NOTICE 'Callback history recorded with id: %', v_history_id;

EXCEPTION
    WHEN NOT_NULL_VIOLATION THEN
        p_error_code := 100;
        RAISE NOTICE 'Error recording callback history: constraint violation — %', SQLERRM;
    WHEN OTHERS THEN
        p_error_code := 200;
        RAISE NOTICE 'Error recording callback history: %', SQLERRM;
END;
$$;


-- =============================================================================
-- AML SCORINGS
-- =============================================================================

CREATE OR REPLACE PROCEDURE create_aml_scoring(
    OUT p_error_code       INT, -- Перенесён в начало
    p_status               VARCHAR(32),
    p_type                 VARCHAR(32) DEFAULT 'DEPOSIT_TRANSACTION',
    p_txid                 VARCHAR(255) DEFAULT NULL,
    p_address              VARCHAR(255) DEFAULT NULL,
    p_source_transaction_id UUID DEFAULT NULL,
    p_scoring_data         JSONB DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_scoring_id UUID;
BEGIN
    p_error_code := 0;

    IF p_txid IS NULL AND p_address IS NULL THEN
        p_error_code := 400;
        RAISE NOTICE 'At least one of txid or address must be provided for AML scoring';
        RETURN;
    END IF;

    IF p_type NOT IN ('DEPOSIT_TRANSACTION', 'WITHDRAWAL_ADDRESS') THEN
        p_error_code := 400;
        RAISE NOTICE 'Invalid AML scoring type: %. Valid: DEPOSIT_TRANSACTION, WITHDRAWAL_ADDRESS', p_type;
        RETURN;
    END IF;

    IF p_status NOT IN ('COMPLETED', 'PENDING', 'FAILED', 'STUCK') THEN
        p_error_code := 400;
        RAISE NOTICE 'Invalid AML status: %. Valid: COMPLETED, PENDING, FAILED, STUCK', p_status;
        RETURN;
    END IF;

    INSERT INTO aml_scorings
        (txid, address, status, type, source_transaction_id, scoring_data)
    VALUES
        (p_txid, p_address,
         p_status::"public"."CrystalAmlAnalysisStatus",
         p_type::"public"."AmlScoringType",
         p_source_transaction_id, p_scoring_data)
    RETURNING id INTO v_scoring_id;

    RAISE NOTICE 'AML scoring created with id: %', v_scoring_id;

EXCEPTION
    WHEN NOT_NULL_VIOLATION OR UNIQUE_VIOLATION THEN
        p_error_code := 100;
        RAISE NOTICE 'Error creating AML scoring: constraint violation — %', SQLERRM;
    WHEN OTHERS THEN
        p_error_code := 200;
        RAISE NOTICE 'Error creating AML scoring: %', SQLERRM;
END;
$$;