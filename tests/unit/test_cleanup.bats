#!/usr/bin/env bats
# Unit tests for cleanup.sh

# Load test helpers
load '../lib/bats-support/load'
load '../lib/bats-assert/load'
load '../lib/bats-file/load'

setup() {
    # Load test environment
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT_PATH="${TEST_DIR}/scripts/cleanup.sh"

    # Mock environment
    export POSTGRES_USER=n8n
    export POSTGRES_DB=n8n
    export NOTIFICATION_RETENTION_DAYS=30

    # Create temporary test directory
    export TEMP_DIR="$(mktemp -d)"
}

teardown() {
    # Clean up temporary files
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

@test "cleanup.sh: script exists and is executable" {
    assert_file_exist "$SCRIPT_PATH"
    assert_file_executable "$SCRIPT_PATH"
}

@test "cleanup.sh: contains proper shebang" {
    run head -n 1 "$SCRIPT_PATH"
    assert_output "#!/bin/bash"
}

@test "cleanup.sh: uses set -e for error handling" {
    run grep -q "set -e" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: loads environment variables from .env" {
    run grep -q "if \[ -f .env \]" "$SCRIPT_PATH"
    assert_success

    run grep -q "export.*\.env" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: defines retention period configuration" {
    run grep -q "RETENTION_DAYS=\${NOTIFICATION_RETENTION_DAYS:-30}" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: requires user confirmation before proceeding" {
    run grep -q 'read -p.*Continue with cleanup' "$SCRIPT_PATH"
    assert_success

    run grep -q 'if \[ "\$CONFIRM" != "yes" \]' "$SCRIPT_PATH"
    assert_success

    run grep -q "Cleanup cancelled" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: deletes old notifications based on retention period" {
    run grep -q "DELETE FROM notifications_history" "$SCRIPT_PATH"
    assert_success

    run grep -q "WHERE sent_at < NOW() - INTERVAL" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: reports number of deleted notifications" {
    run grep -q "GET DIAGNOSTICS deleted_count = ROW_COUNT" "$SCRIPT_PATH"
    assert_success

    run grep -q "RAISE NOTICE.*Deleted.*notifications" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: runs VACUUM ANALYZE on database" {
    run grep -q "VACUUM ANALYZE" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: cleans up old workflow executions" {
    run grep -q "DELETE FROM execution_entity" "$SCRIPT_PATH"
    assert_success

    run grep -q 'WHERE "startedAt" < NOW() - INTERVAL' "$SCRIPT_PATH"
    assert_success

    run grep -q "AND finished = true" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: checks if execution_entity table exists before cleanup" {
    run grep -q "IF EXISTS.*information_schema.tables.*execution_entity" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: cleans Docker system resources" {
    run grep -q "docker system prune" "$SCRIPT_PATH"
    assert_success

    run grep -q -- "-f --volumes" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: displays database size after cleanup" {
    run grep -q "pg_size_pretty(pg_database_size" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: displays Docker volume sizes" {
    run grep -q "docker volume ls" "$SCRIPT_PATH"
    assert_success

    run grep -q "grep feedops" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: uses docker-compose exec for database operations" {
    run grep -q "docker-compose exec -T postgres psql" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: uses environment variables for database connection" {
    run grep -q "POSTGRES_USER:-n8n" "$SCRIPT_PATH"
    assert_success

    run grep -q "POSTGRES_DB:-n8n" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: uses DO blocks for PL/pgSQL code" {
    run grep -q 'DO \$\$' "$SCRIPT_PATH"
    assert_success

    run grep -q 'END\$\$' "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: declares variables for tracking deleted items" {
    run grep -q "DECLARE" "$SCRIPT_PATH"
    assert_success

    run grep -q "deleted_count INTEGER" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: provides informative progress messages" {
    run grep -q "FeedOps Cleanup Script" "$SCRIPT_PATH"
    assert_success

    run grep -q "Cleaning up notifications older than" "$SCRIPT_PATH"
    assert_success

    run grep -q "Optimizing database" "$SCRIPT_PATH"
    assert_success

    run grep -q "Cleaning Docker system" "$SCRIPT_PATH"
    assert_success

    run grep -q "Cleanup completed successfully" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: displays cleanup settings before execution" {
    run grep -q "Settings:" "$SCRIPT_PATH"
    assert_success

    run grep -q "Retention period:" "$SCRIPT_PATH"
    assert_success
}

@test "cleanup.sh: shows cleanup results summary" {
    run grep -q "Cleanup Results:" "$SCRIPT_PATH"
    assert_success
}
