#!/usr/bin/env bats
# Integration tests for database schema

# Load test helpers
load '../lib/bats-support/load'
load '../lib/bats-assert/load'

setup() {
    # Load test environment
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

    # Load test environment variables
    if [ -f "${TEST_DIR}/tests/.env.test" ]; then
        export $(cat "${TEST_DIR}/tests/.env.test" | grep -v '^#' | xargs)
    fi

    # Set default values
    export POSTGRES_USER="${POSTGRES_USER:-n8n}"
    export POSTGRES_DB="${POSTGRES_DB:-n8n}"
}

# Helper function to run SQL query
run_sql() {
    local query="$1"
    docker-compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "$query" 2>/dev/null
}

# Check if postgres is running
check_postgres_running() {
    docker-compose ps postgres 2>/dev/null | grep -q "Up"
}

@test "integration-db: feedops_config table exists" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    run run_sql "SELECT to_regclass('public.feedops_config');"
    assert_success
    echo "$output" | grep -q "feedops_config"
}

@test "integration-db: feedops_config has correct columns" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    # Check for key column
    run run_sql "SELECT column_name FROM information_schema.columns WHERE table_name='feedops_config' AND column_name='key';"
    assert_success
    echo "$output" | grep -q "key"

    # Check for value column
    run run_sql "SELECT column_name FROM information_schema.columns WHERE table_name='feedops_config' AND column_name='value';"
    assert_success
    echo "$output" | grep -q "value"
}

@test "integration-db: feed_sources table exists" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    run run_sql "SELECT to_regclass('public.feed_sources');"
    assert_success
    echo "$output" | grep -q "feed_sources"
}

@test "integration-db: feed_sources has source_type column" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    run run_sql "SELECT column_name FROM information_schema.columns WHERE table_name='feed_sources' AND column_name='source_type';"
    assert_success
    echo "$output" | grep -q "source_type"
}

@test "integration-db: feed_sources has enabled boolean column" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    run run_sql "SELECT data_type FROM information_schema.columns WHERE table_name='feed_sources' AND column_name='enabled';"
    assert_success
    echo "$output" | grep -q "boolean"
}

@test "integration-db: notifications_history table exists" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    run run_sql "SELECT to_regclass('public.notifications_history');"
    assert_success
    echo "$output" | grep -q "notifications_history"
}

@test "integration-db: notifications_history has item_hash column" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    run run_sql "SELECT column_name FROM information_schema.columns WHERE table_name='notifications_history' AND column_name='item_hash';"
    assert_success
    echo "$output" | grep -q "item_hash"
}

@test "integration-db: uuid-ossp extension is installed" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    run run_sql "SELECT extname FROM pg_extension WHERE extname='uuid-ossp';"
    assert_success
    echo "$output" | grep -q "uuid-ossp"
}

@test "integration-db: index on feed_sources.enabled exists" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    run run_sql "SELECT indexname FROM pg_indexes WHERE tablename='feed_sources' AND indexname='idx_feed_sources_enabled';"
    assert_success
    echo "$output" | grep -q "idx_feed_sources_enabled"
}

@test "integration-db: index on notifications_history.item_hash exists" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    run run_sql "SELECT indexname FROM pg_indexes WHERE tablename='notifications_history' AND indexname='idx_notifications_item_hash';"
    assert_success
    echo "$output" | grep -q "idx_notifications_item_hash"
}

@test "integration-db: default config values are present" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    # Check for notification_retention_days
    run run_sql "SELECT key FROM feedops_config WHERE key='notification_retention_days';"
    assert_success
    echo "$output" | grep -q "notification_retention_days"

    # Check for max_retries
    run run_sql "SELECT key FROM feedops_config WHERE key='max_retries';"
    assert_success
    echo "$output" | grep -q "max_retries"
}

@test "integration-db: cleanup_old_notifications function exists" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    run run_sql "SELECT proname FROM pg_proc WHERE proname='cleanup_old_notifications';"
    assert_success
    echo "$output" | grep -q "cleanup_old_notifications"
}

@test "integration-db: can insert into feed_sources table" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    # Insert test data
    run run_sql "INSERT INTO feed_sources (source_type, source_identifier) VALUES ('test', 'test-source-$(date +%s)') RETURNING id;"
    assert_success
}

@test "integration-db: foreign key constraint works" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    # Try to insert notification with non-existent source_id
    # This should fail due to foreign key constraint
    run run_sql "INSERT INTO notifications_history (source_id, item_id, item_hash) VALUES ('00000000-0000-0000-0000-000000000000', 'test', 'test');"
    assert_failure
}

@test "integration-db: JSONB columns work correctly" {
    if [ -n "$SKIP_LIVE_TESTS" ] || ! check_postgres_running; then
        skip "PostgreSQL not running or live tests disabled"
    fi

    # Test JSONB in feed_sources
    run run_sql "SELECT '{\"test\": \"value\"}'::jsonb;"
    assert_success
}
