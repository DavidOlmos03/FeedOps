#!/usr/bin/env bats
# Unit tests for init-db.sh

# Load test helpers
load '../lib/bats-support/load'
load '../lib/bats-assert/load'
load '../lib/bats-file/load'

setup() {
    # Load test environment
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT_PATH="${TEST_DIR}/scripts/init-db.sh"
}

@test "init-db.sh: script exists and is executable" {
    assert_file_exist "$SCRIPT_PATH"
    assert_file_executable "$SCRIPT_PATH"
}

@test "init-db.sh: contains proper shebang" {
    run head -n 1 "$SCRIPT_PATH"
    assert_output "#!/bin/bash"
}

@test "init-db.sh: uses set -e for error handling" {
    run grep -q "set -e" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: creates uuid-ossp extension" {
    run grep -q 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp"' "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: creates feedops_config table" {
    run grep -q "CREATE TABLE IF NOT EXISTS feedops_config" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: feedops_config table has required columns" {
    run grep -q "id UUID PRIMARY KEY" "$SCRIPT_PATH"
    assert_success

    run grep -q "key VARCHAR(255) UNIQUE NOT NULL" "$SCRIPT_PATH"
    assert_success

    run grep -q "value TEXT" "$SCRIPT_PATH"
    assert_success

    run grep -q "description TEXT" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: creates feed_sources table" {
    run grep -q "CREATE TABLE IF NOT EXISTS feed_sources" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: feed_sources table has source_type column" {
    run grep -q "source_type VARCHAR(50) NOT NULL" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: feed_sources table has source_identifier column" {
    run grep -q "source_identifier VARCHAR(500) NOT NULL" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: feed_sources table has JSONB config column" {
    run grep -q "config JSONB DEFAULT '{}'" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: feed_sources table has enabled boolean column" {
    run grep -q "enabled BOOLEAN DEFAULT true" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: feed_sources table has unique constraint" {
    run grep -q "UNIQUE(source_type, source_identifier)" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: creates notifications_history table" {
    run grep -q "CREATE TABLE IF NOT EXISTS notifications_history" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: notifications_history has foreign key to feed_sources" {
    run grep -q "source_id UUID REFERENCES feed_sources(id) ON DELETE CASCADE" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: notifications_history has item_hash column for deduplication" {
    run grep -q "item_hash VARCHAR(64) NOT NULL" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: notifications_history has telegram_message_id column" {
    run grep -q "telegram_message_id BIGINT" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: notifications_history has metadata JSONB column" {
    run grep -q "metadata JSONB DEFAULT '{}'" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: creates index on feed_sources.source_type" {
    run grep -q "CREATE INDEX IF NOT EXISTS idx_feed_sources_type ON feed_sources(source_type)" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: creates index on feed_sources.enabled" {
    run grep -q "CREATE INDEX IF NOT EXISTS idx_feed_sources_enabled ON feed_sources(enabled)" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: creates index on notifications_history.item_hash" {
    run grep -q "CREATE INDEX IF NOT EXISTS idx_notifications_item_hash ON notifications_history(item_hash)" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: creates index on notifications_history.sent_at" {
    run grep -q "CREATE INDEX IF NOT EXISTS idx_notifications_sent_at ON notifications_history(sent_at)" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: creates composite index on source_id and item_id" {
    run grep -q "CREATE INDEX IF NOT EXISTS idx_notifications_source_item ON notifications_history(source_id, item_id)" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: inserts default configuration values" {
    run grep -q "INSERT INTO feedops_config" "$SCRIPT_PATH"
    assert_success

    run grep -q "notification_retention_days" "$SCRIPT_PATH"
    assert_success

    run grep -q "max_retries" "$SCRIPT_PATH"
    assert_success

    run grep -q "retry_backoff_multiplier" "$SCRIPT_PATH"
    assert_success

    run grep -q "version" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: uses ON CONFLICT DO NOTHING for idempotency" {
    run grep -q "ON CONFLICT (key) DO NOTHING" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: creates cleanup_old_notifications function" {
    run grep -q "CREATE OR REPLACE FUNCTION cleanup_old_notifications()" "$SCRIPT_PATH"
    assert_success

    run grep -q "DELETE FROM notifications_history" "$SCRIPT_PATH"
    assert_success

    run grep -q "WHERE sent_at < NOW() - INTERVAL '30 days'" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: grants permissions to database user" {
    run grep -q "GRANT ALL PRIVILEGES ON ALL TABLES" "$SCRIPT_PATH"
    assert_success

    run grep -q "GRANT ALL PRIVILEGES ON ALL SEQUENCES" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: uses psql with proper options" {
    run grep -q "psql -v ON_ERROR_STOP=1" "$SCRIPT_PATH"
    assert_success

    run grep -q "--username.*POSTGRES_USER" "$SCRIPT_PATH"
    assert_success

    run grep -q "--dbname.*POSTGRES_DB" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: uses heredoc for SQL commands" {
    run grep -q "<<-EOSQL" "$SCRIPT_PATH"
    assert_success

    run grep -q "^EOSQL" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: provides success message" {
    run grep -q "Database initialization completed successfully" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: uses UUID for primary keys" {
    run grep -q "uuid_generate_v4()" "$SCRIPT_PATH"
    assert_success
}

@test "init-db.sh: sets default timestamps on tables" {
    run grep -q "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP" "$SCRIPT_PATH"
    assert_success

    run grep -q "updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP" "$SCRIPT_PATH"
    assert_success
}
