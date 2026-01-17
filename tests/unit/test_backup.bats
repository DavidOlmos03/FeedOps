#!/usr/bin/env bats
# Unit tests for backup.sh

# Load test helpers
load '../lib/bats-support/load'
load '../lib/bats-assert/load'
load '../lib/bats-file/load'

setup() {
    # Load test environment
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT_PATH="${TEST_DIR}/scripts/backup.sh"

    # Mock environment
    export POSTGRES_USER=n8n
    export POSTGRES_DB=n8n

    # Create temporary test directory
    export TEMP_DIR="$(mktemp -d)"
}

teardown() {
    # Clean up temporary files
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

@test "backup.sh: script exists and is executable" {
    assert_file_exist "$SCRIPT_PATH"
    assert_file_executable "$SCRIPT_PATH"
}

@test "backup.sh: contains proper shebang" {
    run head -n 1 "$SCRIPT_PATH"
    assert_output "#!/bin/bash"
}

@test "backup.sh: uses set -e for error handling" {
    run grep -q "set -e" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: defines backup directory configuration" {
    run grep -q 'BACKUP_DIR="./backups"' "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: generates timestamped backup names" {
    run grep -q "DATE=\$(date +%Y%m%d_%H%M%S)" "$SCRIPT_PATH"
    assert_success

    run grep -q "BACKUP_NAME=\"feedops_backup_\${DATE}\"" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: loads environment variables from .env" {
    run grep -q "if \[ -f .env \]" "$SCRIPT_PATH"
    assert_success

    run grep -q "export.*\.env" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: creates backup directory structure" {
    run grep -q "mkdir -p.*BACKUP_DIR.*BACKUP_NAME" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: backs up PostgreSQL database with pg_dump" {
    run grep -q "pg_dump" "$SCRIPT_PATH"
    assert_success

    run grep -q "database.sql" "$SCRIPT_PATH"
    assert_success

    run grep -q -- "--clean --if-exists" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: uses environment variables for database connection" {
    run grep -q "POSTGRES_USER:-n8n" "$SCRIPT_PATH"
    assert_success

    run grep -q "POSTGRES_DB:-n8n" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: backs up n8n workflows" {
    run grep -q "n8n export:workflow" "$SCRIPT_PATH"
    assert_success

    run grep -q "workflows.json" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: has fallback method for workflow backup" {
    run grep -q "alternative method" "$SCRIPT_PATH"
    assert_success

    run grep -q "feedops_n8n_data" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: backs up n8n data volume" {
    run grep -q "n8n_data.tar.gz" "$SCRIPT_PATH"
    assert_success

    run grep -q "tar czf" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: creates sanitized environment backup" {
    run grep -q "env.template" "$SCRIPT_PATH"
    assert_success

    run grep -q "sed 's/=.*/=REDACTED/'" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: copies workflow templates" {
    run grep -q "if \[ -d workflows \]" "$SCRIPT_PATH"
    assert_success

    run grep -q "cp -r workflows" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: creates compressed archive" {
    run grep -q 'tar czf "${BACKUP_NAME}.tar.gz"' "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: cleans up temporary backup directory" {
    run grep -q 'rm -rf "${BACKUP_NAME}"' "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: calculates and displays backup size" {
    run grep -q "BACKUP_SIZE=\$(du -h" "$SCRIPT_PATH"
    assert_success

    run grep -q "Backup size:" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: provides restore instructions" {
    run grep -q "To restore this backup" "$SCRIPT_PATH"
    assert_success

    run grep -q "./scripts/restore.sh" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: uses docker-compose exec for operations" {
    run grep -q "docker-compose exec -T" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: uses docker cp to copy files from container" {
    run grep -q "docker cp" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: handles workflow backup errors gracefully" {
    run grep -q "Could not backup workflows" "$SCRIPT_PATH"
    assert_success
}

@test "backup.sh: outputs progress messages" {
    run grep -q "Starting FeedOps backup" "$SCRIPT_PATH"
    assert_success

    run grep -q "Backing up PostgreSQL database" "$SCRIPT_PATH"
    assert_success

    run grep -q "Backing up n8n workflows" "$SCRIPT_PATH"
    assert_success

    run grep -q "Backup completed successfully" "$SCRIPT_PATH"
    assert_success
}
