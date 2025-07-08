-- Script de inicialização do banco de dados
-- Este script será executado automaticamente quando o container PostgreSQL for criado pela primeira vez

-- Criar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Configurar timezone
SET timezone = 'America/Sao_Paulo';

-- Criar esquemas separados para cada aplicação (opcional, mas recomendado)
CREATE SCHEMA IF NOT EXISTS n8n;
CREATE SCHEMA IF NOT EXISTS evolution;

-- Conceder permissões ao usuário
GRANT ALL PRIVILEGES ON SCHEMA n8n TO chatbot_user;
GRANT ALL PRIVILEGES ON SCHEMA evolution TO chatbot_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA n8n TO chatbot_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA evolution TO chatbot_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA n8n TO chatbot_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA evolution TO chatbot_user;

-- Configurações de performance para PostgreSQL
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;

-- Recarregar configurações
SELECT pg_reload_conf();

