-- =============================================================================
-- Payment System Database — CREATE DATABASE, USERS & ROLES
-- Описание: Скрипт создания БД, схемы, пользователей и ролей
-- =============================================================================

-- Создание базы данных
CREATE DATABASE custodial_crypto_wallet_db;

-- Подключиться к БД перед выполнением остальных команд:
-- \c custodial_crypto_wallet_db

-- Создание схемы (таблицы используют схему public по умолчанию)
CREATE SCHEMA IF NOT EXISTS public;


-- =============================================================================
-- РОЛИ
-- =============================================================================

-- Роль администратора: полный доступ
CREATE ROLE admin_role;
GRANT ALL PRIVILEGES ON DATABASE custodial_crypto_wallet_db TO admin_role;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_role;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO admin_role;
-- Чтобы привилегии распространялись на новые таблицы:
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO admin_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO admin_role;

-- Роль разработчика: чтение, вставка, обновление, удаление
CREATE ROLE developer_role;
GRANT CONNECT ON DATABASE custodial_crypto_wallet_db TO developer_role;
GRANT USAGE ON SCHEMA public TO developer_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO developer_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO developer_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO developer_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO developer_role;

-- Роль QA: чтение, вставка, обновление, удаление (для тестовых данных)
CREATE ROLE qa_role;
GRANT CONNECT ON DATABASE custodial_crypto_wallet_db TO qa_role;
GRANT USAGE ON SCHEMA public TO qa_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO qa_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO qa_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO qa_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO qa_role;

-- Роль DevOps: чтение, вставка, обновление, удаление (обслуживание данных)
CREATE ROLE devops_role;
GRANT CONNECT ON DATABASE custodial_crypto_wallet_db TO devops_role;
GRANT USAGE ON SCHEMA public TO devops_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO devops_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO devops_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO devops_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO devops_role;

-- Роль аналитика: только чтение
CREATE ROLE analyst_role;
GRANT CONNECT ON DATABASE custodial_crypto_wallet_db TO analyst_role;
GRANT USAGE ON SCHEMA public TO analyst_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO analyst_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO analyst_role;


-- =============================================================================
-- ПОЛЬЗОВАТЕЛИ
-- =============================================================================

-- Администратор базы данных
CREATE USER payment_admin WITH PASSWORD '!VerySecretPass!*^';
GRANT admin_role TO payment_admin;

-- Сервисный пользователь приложения (основной backend)
CREATE USER payment_app WITH PASSWORD '!SecureAppPass456';
GRANT developer_role TO payment_app;

-- Пользователь для QA-окружения
CREATE USER payment_qa WITH PASSWORD '!SecureQaPass789';
GRANT qa_role TO payment_qa;

-- Пользователь для DevOps-операций (миграции, мониторинг)
CREATE USER payment_devops WITH PASSWORD '!SecureDevOpsPass012';
GRANT devops_role TO payment_devops;

-- Пользователь для аналитических запросов (BI-инструменты, отчётность)
CREATE USER payment_analyst WITH PASSWORD '!SecureAnalystPass345';
GRANT analyst_role TO payment_analyst;


-- =============================================================================
-- ПРИМЕЧАНИЯ
-- =============================================================================
-- 1. Пароли в продакшене должны быть сгенерированы и храниться в секрет-менеджере.
-- 2. Роли developer_role, qa_role и devops_role имеют одинаковые права —
--    разделение нужно для аудита и возможности ограничить доступ в будущем.
-- 3. analyst_role не имеет прав на DML-операции — только SELECT.
-- 4. Для хранимых процедур и триггеров необходимо дополнительно выдать:
--    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO <role>;
