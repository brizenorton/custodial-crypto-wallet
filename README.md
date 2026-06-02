# Custodial Crypto Wallet — Проектная работа по базам данных

## Описание проекта

Данная работа представляет собой документацию и SQL-скрипты для базы данных кастодиальной криптовалютной платёжной системы, обеспечивающей:

- **Хранение данных о мерчантах**, их кошельках и клиентах
- **Приём криптовалютных платежей** от клиентов мерчантов через персональные кошельки и самих мерчантов через транзитные кошельки
- **Выплаты (payouts)** с платформы на внешние blockchain-адреса
- **Возвраты (refunds)** средств по транзакциям непрошедших AML (Anti-Money Laundering) проверки
- **AML-проверки** входящих транзакций через Crystal AML API 
- **Учёт движения средств** на аккаунтах с детализацией комиссий
- **Хранение кастомных тарифов** для мерчантов
- **Callback-уведомления** мерчантов о статусах транзакций
- **Агрегация данных для клиента BO (бек-офис)** с помощью обобщающей таблицы

---

## Структура репозитория

```
custodial-crypto-wallet/
├── DDL/
│   ├── create_db.sql           — создание БД, ролей и пользователей
│   ├── create_tables.sql       — создание всех таблиц и enum-типов
│   ├── create_indexes.sql      — создание индексов
│   ├── stored_procedures.sql   — хранимые процедуры
│   └── triggers.sql            — триггеры
└── DML/
    ├── insert_data.sql         — примеры вставки данных
    ├── update_data.sql         — примеры обновления данных
    └── select_data.sql         — примеры выборок
```

---

## Запуск через Docker

### Требования

- [Docker](https://docs.docker.com/get-docker/) 24+
- [Docker Compose](https://docs.docker.com/compose/install/) v2+

### Запуск базы данных

```bash
# Запустить PostgreSQL в фоне (схема создаётся автоматически)
docker compose up -d

# Проверить статус (ждать healthy)
docker compose ps

# Просмотр логов инициализации
docker compose logs postgres
```

После старта база доступна по адресу `localhost:5433`.

> Скрипты `DDL/create_tables.sql`, `create_indexes.sql`, `stored_procedures.sql` и `triggers.sql`
> применяются автоматически при первом запуске (через `docker-entrypoint-initdb.d`).

### Подключение в DBeaver

1. Открыть DBeaver → **New Database Connection** → PostgreSQL
2. Заполнить параметры:

| Параметр | Значение                     |
|----------|------------------------------|
| Host     | `localhost`                  |
| Port     | `5433`                       |
| Database | `custodial_crypto_wallet_db` |
| Username | `payment_admin`              |
| Password | `!VerySecretPass!*^`         |

3. Нажать **Test Connection**, затем **Finish**

### Остановка и очистка

```bash
# Остановить контейнер (данные сохраняются в volume)
docker compose down

# Остановить и удалить данные (полный сброс)
docker compose down -v
```

### Загрузка тестовых данных вручную

```bash
# Подключиться к контейнеру и выполнить DML
docker exec -i custodial_crypto_wallet_db psql -U payment_admin -d custodial_crypto_wallet_db < DML/insert_data.sql
```

---

## Порядок применения скриптов (без Docker)

```sql
-- 1. Создание БД, ролей и пользователей
\i DDL/create_db.sql

-- 2. Подключение к созданной БД
\c custodial_crypto_wallet_db

-- 3. Создание таблиц и enum-типов
\i DDL/create_tables.sql

-- 4. Создание индексов
\i DDL/create_indexes.sql

-- 5. Создание хранимых процедур
\i DDL/stored_procedures.sql

-- 6. Создание триггеров
\i DDL/triggers.sql

-- 7. Тестовые данные (опционально)
\i DML/insert_data.sql
```

---

## Описание таблиц

### `accounts`
Базовая таблица-идентификатор аккаунта. Каждый мерчант привязан к аккаунту, через который ведётся учёт баланса и начисляются комиссии. Не содержит балансовых полей — состояние баланса вычисляется динамически через сложный SELECT-запрос к таблицам `account_transactions`, `account_transaction_fees`, `account_fees`.

| Колонка      | Тип       | Описание                  |
|--------------|-----------|---------------------------|
| `id`         | uuid PK   | Идентификатор аккаунта    |
| `created_at` | timestamp | Дата создания             |
| `updated_at` | timestamp | Дата последнего изменения |

---

### `rates`
Исторические курсы криптовалют к фиатным валютам. Курсы загружаются раз в 30 секунд из внешних источников. `fiat_rates` хранит JSON-объект вида `{"USD": 67450.5, "EUR": 62300.0, ...}`.

| Колонка           | Тип                | Описание                              |
|-------------------|--------------------|---------------------------------------|
| `id`              | uuid PK            | Идентификатор курса                   |
| `fiat_rates`      | jsonb              | Котировки к фиатным валютам           |
| `crypto_currency` | RateCryptoCurrency | Криптовалюта                          |
| `type`            | RateType           | `EXTERNAL` / `WALLET_INTERNAL`        |
| `created_at`      | timestamp          | Дата создания                         |
| `updated_at`      | timestamp          | Дата последнего изменения             |

---

### `merchants`
Юридические лица, использующие кастодиальную платёжную систему. Привязаны к аккаунту для учёта средств. Имеют тип: `SMB` (малый/средний бизнес) или `ENTERPRISE`.

| Колонка                 | Тип              | Описание                              |
|-------------------------|------------------|---------------------------------------|
| `id`                    | uuid PK          | Идентификатор мерчанта                |
| `name`                  | varchar          | Название                              |
| `public_key`            | varchar          | Публичный ключ (legacy)               |
| `encrypted_private_key` | varchar          | Зашифрованный приватный ключ          |
| `account_id`            | uuid FK→accounts | Привязанный аккаунт                   |
| `type`                  | MerchantType     | `SMB` / `ENTERPRISE`                  |
| `created_at`            | timestamp        | Дата создания                         |
| `updated_at`            | timestamp        | Дата последнего изменения             |

---

### `merchant_credentials`
API-ключи и белый список IP-адресов для аутентификации запросов от мерчантов. Один мерчант может иметь несколько наборов учётных данных, при этом только один может быть помечен как `for_callback = true`.

| Колонка        | Тип                        | Описание                              |
|----------------|----------------------------|---------------------------------------|
| `id`           | uuid PK                    | Идентификатор набора учётных данных   |
| `merchant_id`  | uuid FK→merchants          | Мерчант                               |
| `external_id`  | varchar                    | Внешний идентификатор                 |
| `api_key`      | varchar UNIQUE             | API-ключ для аутентификации           |
| `status`       | MerchantCredentialStatus   | `ACTIVE` / `DEPRECATED`               |
| `ip_addresses` | cidr[]                     | Разрешённые IP-адреса                 |
| `for_callback` | boolean                    | Используется ли для отправки callback |
| `created_at`   | timestamp                  | Дата создания                         |
| `updated_at`   | timestamp                  | Дата последнего изменения             |

---

### `merchant_wallets`
Blockchain-кошельки мерчанта для приёма и хранения криптовалюты. Уникальность обеспечивается по паре
`(address, crypto_currency)`.

| Колонка           | Тип                | Описание                    |
|-------------------|--------------------|-----------------------------|
| `id`              | uuid PK            | Идентификатор кошелька      |
| `merchant_id`     | uuid FK→merchants  | Мерчант-владелец            |
| `address`         | varchar            | Blockchain-адрес кошелька   |
| `crypto_currency` | CryptoCurrency     | Валюта кошелька             |
| `account_id`      | uuid FK→accounts   | Привязанный аккаунт         |
| `created_at`      | timestamp          | Дата создания               |
| `updated_at`      | timestamp          | Дата последнего изменения   |

---

### `customer_wallets`
Персональные кошельки клиентов мерчантов.

| Колонка                    | Тип                   | Описание                                |
|----------------------------|-----------------------|-----------------------------------------|
| `id`                       | uuid PK               | Идентификатор кошелька                  |
| `wallet_address`           | varchar               | Blockchain-адрес                        |
| `merchant_id`              | uuid FK→merchants     | Мерчант-владелец                        |
| `customer_id`              | varchar               | ID клиента в системе мерчанта           |
| `crypto_currency`          | CryptoCurrency        | Принимаемая криптовалюта                |
| `convert_to_fiat_currency` | FiatCurrency          | Целевая фиатная валюта                  |
| `callback_url`             | varchar               | коллбек URL для уведомлений             |
| `status`                   | WalletStatus          | `ACTIVE` / `DEPRECATED`                 |
| `merchant_account_id`      | varchar               | Aккаунт пользователя в системе мерчанта |
| `merchant_user_id`         | varchar               | ID пользователя в системе мерчанта      |
| `account_id`               | uuid FK→accounts      | Привязанный аккаунт                     |
| `user_email`               | varchar               | Email пользователя                      |
| `created_at`               | timestamp             | Дата создания                           |
| `updated_at`               | timestamp             | Дата последнего изменения               |

---

### `customer_wallet_transactions`
Входящие blockchain-транзакции на клиентские кошельки. `txid` + `vout` — уникальный идентификатор в блокчейне. `is_collected` — признак того, что средства уже собраны на мерчантский кошелёк.

| Колонка                     | Тип                          | Описание                                       |
|----------------------------|-------------------------------|------------------------------------------------|
| `id`                       | uuid PK                       | Идентификатор транзакции                       |
| `txid`                     | varchar                       | ID транзакции в блокчейне                      |
| `vout`                     | integer                       | Индекс выхода (UTXO)                           |
| `crypto_currency`          | CryptoCurrency                | Валюта транзакции                              |
| `value`                    | numeric                       | Сумма                                          |
| `fee`                      | numeric                       | Комиссия                                       |
| `type`                     | CustomerWalletTransactionType | `CORRECT`, `CANCELED`, `MANUAL`                |
| `status`                   | TransactionStatus             | Статус транзакции                              |
| `aml_status`               | AmlAnalysisStatus             | Результат AML-проверки                         |
| `is_collected`             | boolean                       | Флаг сбора средств                             |
| `from_address`             | varchar                       | Адрес отправителя                              |
| `to_address`               | varchar                       | Адрес получателя                               |
| `value`                    | numeric                       | Сумма транзакции в криптовалюте                |
| `fiat_value`               | numeric                       | Сумма транзакции в фиате                       |
| `fee`                      | numeric                       | Комиссия сети                                  |
| `rate_id`                  | uuid FK→exchange_rates        | ID обменного курса                             |
| `account_id`               | uuid FK→accounts              | ID аккаунта                                    |
| `merchant_id`              | uuid FK→merchants             | Мерчант-владелец                               |
| `income_fee`               | numeric                       | Комиссия сети для крипто-валюты TON            |
| `is_collected`             | boolean                       | Признак что средства были собраны              |
| `is_aml_checked`           | boolean                       | Признак AML-проверки                           |
| `was_aml_skipped`          | boolean                       | Признак что негативный AML статус был пропущен |
| `aml_status`               | AmlAnalysisStatus             | Результат AML-проверки                         |
| `refund_status`            | RefundStatus                  | Статус возврата                                |
| `created_at`               | timestamp                     | Дата создания                                  |
| `updated_at`               | timestamp                     | Дата последнего изменения                      |

---

### `merchant_transit_wallets`
Транзитные кошельки — промежуточное хранилище до перевода средств на кошелёк мерчанта.

| Колонка             | Тип                | Описание                    |
|---------------------|--------------------|-----------------------------|
| `id`                | uuid PK            | Идентификатор               |
| `wallet_address`    | varchar            | Адрес                       |
| `currency`          | CryptoCurrency     | Валюта                      |
| `account_id`        | uuid FK→accounts   | Аккаунт                     |
| `merchant_id`       | uuid FK→merchants  | Мерчант-владелец            |
| `created_at`        | timestamp          | Дата создания               |
| `updated_at`        | timestamp          | Дата последнего изменения   |

---

### `merchant_transit_wallet_transactions`
Транзакции по транзитным кошелькам мерчантов. Транзитный кошелёк — это промежуточное хранилище (копилка), с которого пополняется главный мерчантский кошелёк. `txid` + `crypto_currency` — уникальный on-chain идентификатор.

| Колонка                     | Тип                                  | Описание                                    |
|-----------------------------|--------------------------------------|---------------------------------------------|
| `id`                        | uuid PK                              | Идентификатор транзакции                    |
| `txid`                      | varchar NOT NULL                     | ID транзакции в блокчейне                   |
| `vout`                      | integer                              | Индекс выхода (UTXO), для BTC/LTC           |
| `type`                      | MerchantTransitWalletTransactionType | `CORRECT` / `CANCELED`                      |
| `crypto_currency`           | CryptoCurrency NOT NULL              | Валюта транзакции                           |
| `crypto_value`              | numeric NOT NULL                     | Сумма транзакции в криптовалюте             |
| `from`                      | varchar                              | Адрес отправителя                           |
| `to`                        | varchar NOT NULL                     | Адрес получателя (транзитный кошелёк)       |
| `fee`                       | numeric NOT NULL                     | Комиссия сети                               |
| `income_fee`                | numeric                              | Доход от комиссии (TON-специфика)           |
| `merchant_id`               | varchar NOT NULL                     | Внешний ID мерчанта (не FK, varchar)        |
| `rate_id`                   | uuid FK→rates NOT NULL               | Курс на момент транзакции                   |
| `account_id`                | uuid FK→accounts                     | Привязанный аккаунт                         |
| `status`                    | TransactionStatus NOT NULL           | Статус транзакции                           |
| `blockchain_transaction_id` | uuid UNIQUE                          | ID блокчейн-операции (из internal сервиса)  |
| `is_collected`              | boolean NOT NULL DEFAULT false       | Средства переведены на мерчантский кошелёк  |
| `created_at`                | timestamp                            | Дата создания                               |
| `updated_at`                | timestamp                            | Дата последнего изменения                   |

---

### `payouts`
Выплаты — исходящие переводы с платформы на внешние адреса получателей. `external_id` + `merchant_id` образуют уникальный ключ для идемпотентности API-запросов мерчанта.

| Колонка                     | Тип                              | Описание                                               |
|-----------------------------|----------------------------------|--------------------------------------------------------|
| `id`                        | uuid PK                          | Идентификатор выплаты                                  |
| `external_id`               | varchar NOT NULL                 | ID выплаты в системе мерчанта (для идемпотентности)    |
| `recipient_address`         | varchar NOT NULL                 | Blockchain-адрес получателя                            |
| `status`                    | payouts_status_enum NOT NULL     | `QUEUED` → `SUBMITTED` → `COMPLETED` / `CANCELED`      |
| `callback_url`              | varchar NOT NULL                 | URL для уведомлений мерчанта                           |
| `merchant_id`               | uuid FK→merchants NOT NULL       | Мерчант-инициатор                                      |
| `blockchain_transaction_id` | uuid                             | ID блокчейн-операции                                   |
| `fiat_amount`               | numeric NOT NULL                 | Сумма выплаты в фиатной валюте                         |
| `fiat_currency`             | FiatCurrency NOT NULL            | Фиатная валюта выплаты                                 |
| `crypto_amount`             | numeric NOT NULL                 | Сумма выплаты в криптовалюте                           |
| `crypto_currency`           | CryptoCurrency NOT NULL          | Криптовалюта выплаты                                   |
| `fee`                       | numeric NOT NULL DEFAULT 0       | Комиссия платформы                                     |
| `rate_id`                   | uuid FK→rates                    | Курс на момент создания выплаты                        |
| `txid`                      | varchar                          | Hash транзакции в блокчейне (после отправки)           |
| `user_id`                   | uuid                             | ID пользователя-инициатора (wallet app)                |
| `merchant_account_id`       | varchar                          | Аккаунт пользователя в системе мерчанта                |
| `merchant_user_id`          | varchar                          | ID пользователя в системе мерчанта                     |
| `creation_method`           | payouts_creation_method_enum     | `API_V1`, `API_V2`, `BO`, `UNKNOWN`                    |
| `tag`                       | varchar                          | Тег получателя (для XRP, TON и др.)                    |
| `processing_delay_time_sec` | integer NOT NULL DEFAULT 0       | Задержка перед обработкой (сек)                        |
| `was_aml_skipped`           | boolean NOT NULL DEFAULT false   | Флаг пропуска AML при негативном результате            |
| `aml_status`                | AmlAnalysisStatus NOT NULL       | Статус AML-проверки адреса получателя                  |
| `validation_error`          | payouts_validation_error_enum    | Причина отклонения (`InsufficientLiquidityError`)      |
| `created_at`                | timestamp                        | Дата создания                                          |
| `updated_at`                | timestamp                        | Дата последнего изменения                              |

---

### `payout_transfers`
Отдельные blockchain-попытки для каждой выплаты. При неудаче создаётся новая запись с увеличенным `attempt`. Уникальность по `(payout_id, status, attempt)` гарантирует только одну запись на каждую попытку+статус.

| Колонка                     | Тип                               | Описание                                          |
|-----------------------------|-----------------------------------|---------------------------------------------------|
| `id`                        | uuid PK                           | Идентификатор попытки перевода                    |
| `fee`                       | numeric NOT NULL                  | Комиссия сети за перевод                          |
| `amount`                    | numeric NOT NULL                  | Сумма перевода                                    |
| `currency`                  | CryptoCurrency NOT NULL           | Валюта перевода                                   |
| `status`                    | payout_transfers_status_enum      | `PENDING` → `SUCCESSFUL` / `FAILED`               |
| `from`                      | varchar NOT NULL                  | Адрес-источник (кошелёк платформы)                |
| `to`                        | varchar NOT NULL                  | Адрес получателя                                  |
| `blockchain_api_transfer_id` | varchar                          | ID операции во внутреннем blockchain-сервисе      |
| `txid`                      | varchar                           | Hash транзакции в блокчейне                       |
| `payout_id`                 | uuid FK→payouts NOT NULL          | Выплата                                           |
| `tag`                       | varchar                           | Тег (для XRP, TON и др.)                          |
| `attempt`                   | smallint NOT NULL DEFAULT 1       | Номер попытки (increment при retry)               |
| `failed_reason`             | varchar                           | Краткая причина ошибки                            |
| `details`                   | varchar                           | Детализированное описание ошибки                  |
| `created_at`                | timestamp                         | Дата создания                                     |
| `updated_at`                | timestamp                         | Дата последнего изменения                         |

---

### `refunds`
Возвраты средств по транзакциям, не прошедшим AML или отменённым по иным причинам. Ссылка на исходную транзакцию — полиморфная пара `(transaction_id, transaction_type)`.

| Колонка                     | Тип                              | Описание                                              |
|-----------------------------|----------------------------------|-------------------------------------------------------|
| `id`                        | uuid PK                          | Идентификатор возврата                                |
| `transaction_type`          | RefundTransactionType NOT NULL   | Тип исходной транзакции (CWT или MCAT)                |
| `transaction_id`            | uuid NOT NULL                    | UUID исходной транзакции                              |
| `account_id`                | uuid FK→accounts NOT NULL        | Аккаунт, с которого производится возврат              |
| `from`                      | varchar NOT NULL                 | Адрес-источник возврата (кошелёк платформы)           |
| `to`                        | varchar NOT NULL                 | Адрес получателя возврата (клиент)                    |
| `status`                    | RefundStatus NOT NULL            | `SUBMITTED` → `PENDING` → `SUCCESS` / `FAILED`        |
| `crypto_amount`             | numeric NOT NULL                 | Сумма возврата в криптовалюте                         |
| `crypto_currency`           | CryptoCurrency NOT NULL          | Валюта возврата                                       |
| `fiat_amount`               | numeric NOT NULL                 | Сумма возврата в фиате (на момент исходной транзакции)|
| `fiat_currency`             | FiatCurrency NOT NULL            | Фиатная валюта                                        |
| `issuer_id`                 | varchar NOT NULL                 | ID инициатора возврата (сервис или оператор BO)       |
| `blockchain_transaction_id` | uuid NOT NULL UNIQUE             | UUID блокчейн-операции возврата                       |
| `created_at`                | timestamp                        | Дата создания                                         |
| `updated_at`                | timestamp                        | Дата последнего изменения                             |

---

### `refund_transfers`
Blockchain-переводы для осуществления возврата средств клиенту. Один возврат — один перевод (1:1 по `refund_id`).

| Колонка                  | Тип                            | Описание                                          |
|--------------------------|--------------------------------|-------------------------------------------------- |
| `id`                     | uuid PK                        | Идентификатор перевода возврата                   |
| `status`                 | RefundTransferStatus NOT NULL. | `PENDING` → `SUCCESS` / `FAILED`                  |
| `blockchain_id`          | uuid UNIQUE                    | UUID операции в blockchain-сервисе                |
| `txid`                   | varchar                        | Hash транзакции в блокчейне                       |
| `amount`                 | numeric NOT NULL               | Сумма перевода                                    |
| `currency`               | CryptoCurrency NOT NULL        | Валюта перевода                                   |
| `refund_id`              | uuid FK→refunds NOT NULL UNIQUE| Связанный возврат (1:1)                           |
| `fee_deposit_transfer_id` | uuid UNIQUE                   | ID депозита комиссии (для сети, которой нужна комиссия заранее) |
| `fee`                    | numeric                        | Комиссия сети за возврат                          |
| `created_at`             | timestamp                      | Дата создания                                     |
| `updated_at`             | timestamp                      | Дата последнего изменения                         |

---

### `transfers`
Внутренние blockchain-переводы между сервисом платёжной платформы и внутренним blockchain-сервисом. Используется для операций сбора (collect) средств с кошельков на мерчантский адрес и рефилла (refill) — покрытие сетевой комиссии за вывод.

| Колонка             | Тип                      | Описание                                          |
|---------------------|--------------------------|---------------------------------------------------|
| `id`                | uuid PK                  | Идентификатор перевода                            |
| `value`             | numeric NOT NULL          | Сумма перевода                                   |
| `currency`          | CryptoCurrency NOT NULL   | Валюта перевода                                  |
| `status`            | TransferStatus NOT NULL   | Статус: `READY_TO_TRANSFER` → `SENT` → `COMPLETED` / `FAILED` |
| `from`              | varchar NOT NULL          | Адрес-источник                                   |
| `to`                | varchar NOT NULL          | Адрес назначения                                 |
| `txid`              | varchar                   | Hash on-chain транзакции                         |
| `blockchain_id`     | varchar                   | ID операции в blockchain-сервисе                 |
| `fail_reason`       | varchar NOT NULL DEFAULT '' | Причина ошибки                                 |
| `subtract_fee`      | boolean NOT NULL          | Вычитать ли комиссию из суммы перевода           |
| `fee`               | numeric                   | Комиссия сети                                    |
| `merchant_id`       | varchar NOT NULL          | Внешний ID мерчанта                              |
| `linked_transfer_id` | uuid                     | ID связанного перевода (например, collect → refill) |
| `account_id`        | uuid FK→accounts          | Привязанный аккаунт                              |
| `type`              | TransferType              | `COLLECT`, `REFILL`, `CONSOLIDATION_WALLET_REFILL`, `OPERATION_WALLET_DEPOSIT`, `ACTIVATE` |
| `created_at`        | timestamp                 | Дата создания                                    |
| `updated_at`        | timestamp                 | Дата последнего изменения                        |

---

### `transaction_data`
Агрегированная денормализованная таблица всех транзакций платформы. Служит единой точкой доступа для Back Office, аналитики и повторной генерации колбэков. `source_external_id` + `source_type` — уникальный ключ; запись создаётся через идемпотентный ON CONFLICT DO UPDATE (upsert).

| Колонка             | Тип                              | Описание                                             |
|---------------------|----------------------------------|------------------------------------------------------|
| `id`                | uuid PK                          | Идентификатор                                        |
| `source_type`       | TransactionSourceType NOT NULL   | Тип источника транзакции (enum ниже)                 |
| `source_external_id` | varchar NOT NULL                | UUID исходной транзакции из родительской таблицы     |
| `source_created_at` | timestamp NOT NULL               | Дата создания исходной транзакции                    |
| `source_updated_at` | timestamp NOT NULL               | Дата последнего обновления исходной транзакции       |
| `status`            | transaction_data_status_enum NOT NULL | Статус: `PENDING`, `COMPLETED`, `FAILED`, `AML_FAILED`, `REFUND_PENDING`, ... |
| `merchant_id`       | uuid FK→merchants NOT NULL        | Мерчант-владелец транзакции                         |
| `account_id`        | uuid FK→accounts NOT NULL         | Аккаунт мерчанта                                    |
| `user_id`           | uuid                              | ID пользователя (wallet app)                        |
| `crypto_amount`     | numeric NOT NULL                  | Сумма в криптовалюте                                |
| `crypto_currency`   | CryptoCurrency NOT NULL           | Криптовалюта транзакции                             |
| `fiat_amount`       | numeric NOT NULL                  | Сумма в фиате на момент транзакции                  |
| `fiat_currency`     | FiatCurrency NOT NULL             | Фиатная валюта                                      |
| `fee`               | numeric                           | Комиссия платформы                                  |
| `internal_fee`      | numeric                           | Внутренняя комиссия (TON-специфика)                 |
| `rate_id`           | uuid FK→rates NOT NULL            | Курс на момент транзакции                           |
| `txid`              | varchar                           | Hash транзакции в блокчейне                         |
| `vout`              | integer                           | Индекс выхода (UTXO)                                |
| `external_id`       | varchar                           | Внешний ID на стороне мерчанта                      |
| `customer_id`       | varchar                           | ID клиента мерчанта                                 |
| `customer_address`  | varchar                           | Адрес клиента                                       |
| `customer_email`    | varchar                           | Email клиента                                       |
| `payment_address`   | varchar                           | Адрес кошелька, на который пришли средства          |
| `tag`               | varchar                           | Тег транзакции (XRP, TON и др.)                     |
| `created_at`        | timestamp                         | Дата создания                                       |
| `updated_at`        | timestamp                         | Дата последнего изменения                           |

------------------------------------------------------------------------------------------------
| `source_type` (TransactionSourceType)          | Описание                                    |
|------------------------------------------------|---------------------------------------------|
| `INVOICE_TRANSACTION`                          | Платёж по инвойсу                           |
| `PAYOUT_TRANSACTION`                           | Выплата (API)                               |
| `PAYOUT_TRANSACTION_BO`                        | Выплата (Back Office)                       |
| `CUSTOMER_WALLET_TRANSACTION`                  | Депозит на персональный кошелёк             |
| `MERCHANT_TRANSIT_WALLET_TRANSACTION`          | Депозит на транзитный кошелёк               |
| `MERCHANT_CUSTOMER_ADDRESS_DEPOSIT_TRANSACTION` | Депозит на адрес клиента мерчанта          |
| `REFUND_TRANSACTION`                           | Возврат средств                             |

---

### `callback_histories`
История всех исходящих webhook-запросов к URL мерчантов. Используется для уведомления мерчанта об изменении статуса транзакции, а также для retry-логики при неуспешных доставках. `type_external_id` — UUID транзакции-источника.

| Колонка            | Тип                      | Описание                                                        |
|--------------------|--------------------------|-----------------------------------------------------------------|
| `id`               | uuid PK                  | Идентификатор записи                                            |
| `type`             | varchar NOT NULL          | Тип транзакции-источника (`CUSTOMER_WALLET_TRANSACTION`, `PAYOUT_TRANSACTION` и др.) |
| `url`              | varchar NOT NULL          | URL колбэка мерчанта                                            |
| `type_external_id` | varchar NOT NULL          | UUID исходной транзакции                                        |
| `sent_data`        | jsonb NOT NULL            | Тело запроса, отправленного мерчанту                            |
| `response_status`  | integer                   | HTTP-статус ответа мерчанта (NULL если нет ответа)              |
| `response_message` | varchar                   | Тело ответа мерчанта                                            |
| `payload_status`   | CallbackPayloadStatus     | Статус payload на момент отправки (enum из 14+ значений)        |
| `created_at`       | timestamp                 | Дата создания                                                   |
| `updated_at`       | timestamp                 | Дата последнего изменения (обновляется при retry)               |

---

### `config_properties`
Конфигурационные параметры системы, сгруппированные по `issuer_id`. `issuer_id` — обычно UUID мерчанта или системный идентификатор (не FK, потому что могут быть технические issuers, не являющиеся мерчантами). Актуальное значение — последняя запись по `created_at DESC`.

| Колонка      | Тип                          | Описание                                                        |
|-------------|------------------------------|------------------------------------------------------------------|
| `id`        | uuid PK                      | Идентификатор записи                                             |
| `issuer_id` | varchar NOT NULL              | ID мерчанта или технического issuer (не FK)                     |
| `name`      | ConfigPropertyName NOT NULL   | Название параметра (enum: минимальные суммы, AML-пороги и др.)  |
| `value`     | varchar NOT NULL              | Значение параметра (строка, интерпретируется по контексту)      |
| `created_at` | timestamp                    | Дата создания (новая запись = новое значение)                   |
| `updated_at` | timestamp                    | Дата последнего изменения                                       |

---

### `aml_scorings`
Результаты AML-проверок адресов и транзакций через Crystal AML API. Запись может быть привязана к транзакции (`txid` + `source_transaction_id`) или к адресу кошелька (`address`). Уникальность регулируется составными partial-индексами.

| Колонка                | Тип                          | Описание                                                   |
|------------------------|------------------------------|------------------------------------------------------------|
| `id`                   | uuid PK                      | Идентификатор записи                                       |
| `txid`                 | varchar                       | Hash on-chain транзакции (для проверки транзакций)        |
| `address`              | varchar                       | Blockchain-адрес (для проверки адресов вывода)            |
| `scoring_data`         | jsonb                         | Сырой ответ от Crystal API с рисками и сигналами          |
| `status`               | CrystalAmlAnalysisStatus NOT NULL | `PENDING` → `COMPLETED` / `FAILED` / `STUCK`          |
| `type`                 | AmlScoringType NOT NULL       | `DEPOSIT_TRANSACTION` / `WITHDRAWAL_ADDRESS`              |
| `error`                | varchar                       | Сообщение об ошибке при неудачной проверке                |
| `source_transaction_id` | uuid                         | UUID исходной транзакции (CWT или MCAT)                   |
| `created_at`           | timestamp                     | Дата создания                                             |
| `updated_at`           | timestamp                     | Дата последнего изменения                                 |

---

### `account_fees`
Разовые или накопленные комиссии, напрямую закреплённые за аккаунтом (legacy). Используются для ручных списаний, которые не проходят через стандартный flow `account_transactions` + `account_transaction_fees`. Вычитаются при расчёте виртуального баланса.

| Колонка       | Тип                        | Описание                                         |
|---------------|----------------------------|--------------------------------------------------|
| `id`          | uuid PK                    | Идентификатор                                    |
| `amount`      | numeric NOT NULL            | Сумма комиссии                                  |
| `currency`    | CryptoCurrency NOT NULL     | Валюта комиссии                                 |
| `type`        | AccountFeeType NOT NULL     | Тип: `LEGACY`                                   |
| `account_id`  | uuid FK→accounts NOT NULL   | Аккаунт, с которого списывается комиссия        |
| `description` | varchar NOT NULL UNIQUE(account_id) | Описание/ключ для дедупликации          |
| `created_at`  | timestamp                   | Дата создания                                   |
| `updated_at`  | timestamp                   | Дата последнего изменения                       |

---

### `fee_policies`
Политики начисления комиссий: для каждого аккаунта и типа транзакции задаётся массив применяемых `FeeType`. `source` определяет происхождение политики. Актуальная политика — последняя запись по `created_at DESC`.

| Колонка            | Тип                              | Описание                                              |
|--------------------|----------------------------------|-------------------------------------------------------|
| `id`               | uuid PK                          | Идентификатор политики                                |
| `account_id`       | uuid FK→accounts NOT NULL         | Аккаунт мерчанта                                     |
| `transaction_type` | AccountTransactionType NOT NULL   | Тип транзакции, к которому применяется политика      |
| `fees`             | FeeType[] NOT NULL                | Массив типов комиссий (может быть несколько)         |
| `source`           | FeePolicySource NOT NULL          | `SYSTEM_DEFAULT`, `SEGMENT_DEFAULT`, `MANUAL`        |
| `created_at`       | timestamp                         | Дата создания                                        |
| `updated_at`       | timestamp                         | Дата последнего изменения                            |

-----------------------------------------------------------------------
| `FeeType`          | Описание                                       |
|--------------------|------------------------------------------------|
| `ONE_PERCENT`      | Фиксированный 1% от суммы                      |
| `DYNAMIC_PERCENT`  | Процент по индивидуальному тарифу              |
| `ZERO_PERCENT`     | Без комиссии (0%)                              |
| `FIXED_FEE`        | Фиксированная сумма (не процент)               |
| `NETWORK_FEE`      | Комиссия блокчейн-сети (pass-through)          |

---

### `account_transactions`
Учётные записи движения средств по аккаунтам. Является источником истины для расчёта виртуального баланса. `original_transaction_id` — UUID исходной транзакции из родительской таблицы. Уникальность по `(original_transaction_id, type)` предотвращает дублирование.

| Колонка                  | Тип                               | Описание                                                       |
|--------------------------|---------------------------------- |---------------------------------------------------------------|
| `id`                     | uuid PK                           | Идентификатор                                                  |
| `account_id`             | uuid FK→accounts NOT NULL         | Аккаунт                                                        |
| `amount`                 | numeric NOT NULL                  | Сумма движения                                                |
| `currency`               | CryptoCurrency NOT NULL           | Валюта                                                         |
| `type`                   | AccountTransactionType NOT NULL   | Тип операции (определяет знак в балансе — доход или расход)   |
| `status`                 | TransactionStatus NOT NULL        | Статус; `FAILED` — не участвует в балансе                     |
| `original_transaction_id` | uuid NOT NULL                    | UUID исходной транзакции                                      |
| `timestamp`              | timestamp                         | Время исходной транзакции (из блокчейна)                      |
| `available_at`           | timestamp                         | Время разморозки средств (для отложенной доступности)         |
| `is_available`           | boolean NOT NULL DEFAULT false    | Доступны ли средства для вывода                               |
| `created_at`             | timestamp                         | Дата создания                                                 |
| `updated_at`             | timestamp                         | Дата последнего изменения                                     |

-----------------------------------------------------------------------------------------------------------
| `AccountTransactionType`                        | Знак в балансе | Описание                             |
|-------------------------------------------------|:--------------:|--------------------------------------|
| `CUSTOMER_TRANSACTION`                          | +              | Депозит клиентского кошелька         |
| `MERCHANT_CUSTOMER_ADDRESS_DEPOSIT_TRANSACTION` | +              | Депозит адреса клиента мерчанта      |
| `INVOICE_TRANSACTION`                           | +              | Платёж по инвойсу                    |
| `MERCHANT_TRANSACTION`                          | +              | Транзитный депозит мерчанта          |
| `EXCHANGE_IN`                                   | +              | Входящий обмен валюты                |
| `PAYOUT`                                        | −              | Выплата клиенту мерчанта             |
| `EXCHANGE_OUT`                                  | −              | Исходящий обмен валюты               |
| `EXCHANGE_REVENUE`                              | исключён       | Доход от обмена (не в балансе)       |

---

### `account_transaction_fees`
Детальная разбивка начисленных комиссий по каждой записи `account_transactions`. Вычитается при расчёте виртуального баланса. Уникальность по `(account_transaction_id, type)` — один тип комиссии на транзакцию.

| Колонка                  | Тип                           | Описание                                              |
|--------------------------|-------------------------------|-------------------------------------------------------|
| `id`                     | uuid PK                       | Идентификатор                                         |
| `account_transaction_id` | uuid FK→account_transactions   | Транзакция аккаунта                                  |
| `type`                   | FeeType NOT NULL               | Тип комиссии                                         |
| `amount`                 | numeric NOT NULL               | Сумма комиссии                                       |
| `currency`               | CryptoCurrency NOT NULL        | Валюта комиссии                                      |
| `account_fee_policy_id`  | uuid FK→fee_policies NOT NULL  | Применённая политика комиссий                        |
| `fee_percent_amount`     | numeric DEFAULT 0              | Процентная часть комиссии (для аудита расчёта)       |
| `fee_flat_amount`        | numeric DEFAULT 0              | Фиксированная часть комиссии (для аудита расчёта)    |
| `created_at`             | timestamp                      | Дата создания                                        |
| `updated_at`             | timestamp                      | Дата последнего изменения                            |

---

### `account_transaction_usdt_details`
Дополнительная таблица с USDT-эквивалентами сумм `account_transactions`. Используется в режиме расчётов (`isSettlementEnabled`), когда мерчанту показывается баланс в USDT независимо от исходной криптовалюты транзакции.

| Колонка                  | Тип                              | Описание                                       |
|--------------------------|----------------------------------|------------------------------------------------|
| `id`                     | uuid PK                          | Идентификатор                                  |
| `account_transaction_id` | uuid FK→account_transactions UNIQUE | Транзакция аккаунта (1:1)                   |
| `usdt_amount`            | numeric NOT NULL                  | Сумма транзакции в USDT-эквиваленте           |
| `created_at`             | timestamp                         | Дата создания                                 |
| `updated_at`             | timestamp                         | Дата последнего изменения                     |

---

### `account_transaction_fees_usdt_details`
Дополнительная таблица с USDT-эквивалентами сумм `account_transaction_fees`. Используется совместно с `account_transaction_usdt_details` в режиме расчётов для отображения комиссий в USDT.

| Колонка                      | Тип                                 | Описание                                    |
|----------------------------- |-------------------------------------|---------------------------------------------|
| `id`                         | uuid PK                             | Идентификатор                               |
| `account_transaction_fee_id` | uuid FK→account_transaction_fees UNIQUE | Комиссия транзакции (1:1)               |
| `usdt_amount`                | numeric NOT NULL                    | Сумма комиссии в USDT-эквиваленте           |
| `created_at`                 | timestamp                           | Дата создания                               |
| `updated_at`                 | timestamp                           | Дата последнего изменения                   |

---

## Роли и права доступа

| Роль            | Права                                          | Пользователь       |
|-----------------|------------------------------------------------|--------------------|
| `admin_role`    | ALL PRIVILEGES на все объекты                  | `payment_admin`    |
| `developer_role`| SELECT, INSERT, UPDATE, DELETE на все таблицы  | `payment_app`      |
| `qa_role`       | SELECT, INSERT, UPDATE, DELETE на все таблицы  | `payment_qa`       |
| `devops_role`   | SELECT, INSERT, UPDATE, DELETE на все таблицы  | `payment_devops`   |
| `analyst_role`  | SELECT на все таблицы                          | `payment_analyst`  |

---

## Хранимые процедуры

| Процедура                      | Описание                                                   |
|--------------------------------|-------------------------------------------------------------|
| `create_merchant`              | Создание мерчанта с валидацией типа (SMB/ENTERPRISE)        |
| `update_merchant_type`         | Изменение типа мерчанта                                     |
| `create_merchant_credentials`  | Создание API-ключей с проверкой существования мерчанта      |
| `deprecate_merchant_credentials` | Деактивация учётных данных                                |
| `create_merchant_wallet`       | Создание кошелька с проверкой уникальности адреса+валюты    |
| `create_customer_wallet`       | Создание клиентского кошелька с проверкой уникальности      |
| `create_payout`                | Создание выплаты с идемпотентностью по external_id          |
| `update_payout_status`         | Обновление статуса выплаты с валидацией переходов           |
| `create_account`               | Создание базового аккаунта                                  |
| `create_fee_policy`            | Создание политики комиссий с проверкой аккаунта и типов     |
| `create_account_transaction`   | Создание учётной записи движения средств                    |
| `upsert_transaction_data`      | Идемпотентный upsert агрегированных данных транзакции       |
| `record_callback_history`      | Запись истории callback-вызова                              |
| `create_aml_scoring`           | Создание AML-проверки с валидацией полей                    |

**Коды ошибок хранимых процедур:**
- `0` — успех
- `100` — нарушение ограничений (NOT NULL, FK, UNIQUE)
- `200` — внутренняя ошибка (непредвиденное исключение)
- `300` — сущность не найдена
- `400` — недопустимое значение параметра

---

## Триггеры

Триггеры обеспечивают автоматическую агрегацию данных в `callback_histories` и `account_transactions` при вставке транзакций в родительские таблицы.

| Триггер                            | Событие                                          | Действие                                    |
|-----------------------------------|--------------------------------------------------|---------------------------------------------|
| `trg_cwt_to_callback_history`     | INSERT в `customer_wallet_transactions`          | → INSERT в `callback_histories`             |
| `trg_mtwt_to_callback_history`    | INSERT в `merchant_transit_wallet_transactions`  | → INSERT в `callback_histories`             |
| `trg_payout_to_callback_history`  | INSERT в `payouts`                               | → INSERT в `callback_histories`             |
| `trg_cwt_to_account_transaction`  | INSERT в `customer_wallet_transactions`          | → INSERT в `account_transactions`           |
| `trg_mtwt_to_account_transaction` | INSERT в `merchant_transit_wallet_transactions`  | → INSERT в `account_transactions`           |
| `trg_payout_to_account_transaction` | INSERT в `payouts`                             | → INSERT в `account_transactions`           |

---

## Ключевые индексы

| Таблица                           | Индекс                                   | Назначение                              |
|----------------------------------|------------------------------------------|-----------------------------------------|
| `rates`                          | `(crypto_currency, type, created_at DESC)` | Получение актуального курса           |
| `customer_wallet_transactions`   | `(to_address, crypto_currency, status) WHERE is_collected = false` | Collect-задача |
| `account_transactions`           | `(account_id, currency, status, type)`  | Расчёт баланса аккаунта                |
| `callback_histories`             | `(type_external_id, response_status)`   | Поиск колбэков и проверка доставки     |
| `config_properties`              | `(issuer_id, name, created_at DESC)`    | Получение конфигурационного параметра  |
| `fee_policies`                   | `(account_id, transaction_type, created_at DESC)` | Получение политики комиссий   |
| `payouts`                        | `(merchant_id, crypto_currency)`        | Фильтрация выплат по мерчанту и валюте |
| `aml_scorings`                   | `(txid, source_transaction_id) WHERE NOT NULL` | Дедупликация AML-проверок        |

---

## Технологии

- **PostgreSQL 14+**
- **Расширение**: `uuid-ossp` (генерация UUID v4)
- **ORM в production**: TypeORM (Node.js)
- **Типы данных**: ENUM, UUID, JSONB, CIDR[], numeric (финансовые расчёты без потерь точности)
