#!/usr/bin/env bats
# Unit tests for restore.sh

# Load test helpers
load '../lib/bats-support/load'
load '../lib/bats-assert/load'
load '../lib/bats-file/load'

setup() {
    # Load test environment
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT_PATH="${TEST_DIR}/scripts/restore.sh"

    # Mock environment
    export POSTGRES_USER=n8n
    export POSTGRES_DB=n8n
    export N8N_PORT=5678

    # Create temporary test directory
    export TEMP_DIR="$(mktemp -d)"
}

teardown() {
    # Clean up temporary files
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

@test "restore.sh: script exists and is executable" {
    assert_file_exist "$SCRIPT_PATH"
    assert_file_executable "$SCRIPT_PATH"
}

@test "restore.sh: contains proper shebang" {
    run head -n 1 "$SCRIPT_PATH"
    assert_output "#!/bin/bash"
}

@test "restore.sh: uses set -e for error handling" {
    run grep -q "set -e" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: checks if backup file argument is provided" {
    run grep -q 'if \[ -z "\$1" \]' "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: shows usage instructions when no argument provided" {
    run grep -q "Usage: \$0 <backup-file.tar.gz>" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: lists available backups when no argument provided" {
    run grep -q "Available backups:" "$SCRIPT_PATH"
    assert_success

    run grep -q "ls -lh backups/\*.tar.gz" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: checks if backup file exists" {
    run grep -q 'if \[ ! -f "\$BACKUP_FILE" \]' "$SCRIPT_PATH"
    assert_success

    run grep -q "Backup file not found" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: loads environment variables from .env" {
    run grep -q "if \[ -f .env \]" "$SCRIPT_PATH"
    assert_success

    run grep -q "export.*\.env" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: requires user confirmation before proceeding" {
    run grep -q "WARNING.*restore.*overwrite" "$SCRIPT_PATH"
    assert_success

    run grep -q 'read -p.*Continue.*yes/no' "$SCRIPT_PATH"
    assert_success

    run grep -q 'if \[ "\$CONFIRM" != "yes" \]' "$SCRIPT_PATH"
    assert_success

    run grep -q "Restore cancelled" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: extracts backup to temporary directory" {
    run grep -q "TEMP_DIR=\$(mktemp -d)" "$SCRIPT_PATH"
    assert_success

    run grep -q 'tar xzf "\$BACKUP_FILE" -C "\$TEMP_DIR"' "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: finds backup directory in extracted files" {
    run grep -q 'find "\$TEMP_DIR".*feedops_backup_' "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: validates backup file format" {
    run grep -q 'if \[ -z "\$BACKUP_DIR" \]' "$SCRIPT_PATH"
    assert_success

    run grep -q "Invalid backup file format" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: stops Docker services before restore" {
    run grep -q "docker-compose down" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: checks for database.sql file" {
    run grep -q 'if \[ -f "\$BACKUP_DIR/database.sql" \]' "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: starts PostgreSQL temporarily for restore" {
    run grep -q "docker-compose up -d postgres" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: waits for PostgreSQL to be ready" {
    run grep -q "Waiting for PostgreSQL" "$SCRIPT_PATH"
    assert_success

    run grep -q "sleep 10" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: restores database using psql" {
    run grep -q "docker-compose exec -T postgres psql" "$SCRIPT_PATH"
    assert_success

    run grep -q '< "\$BACKUP_DIR/database.sql"' "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: uses environment variables for database connection" {
    run grep -q "POSTGRES_USER:-n8n" "$SCRIPT_PATH"
    assert_success

    run grep -q "POSTGRES_DB:-n8n" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: checks for n8n_data.tar.gz file" {
    run grep -q 'if \[ -f "\$BACKUP_DIR/n8n_data.tar.gz" \]' "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: creates n8n volume if it doesn't exist" {
    run grep -q "docker volume create feedops_n8n_data" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: restores n8n data to volume" {
    run grep -q "tar xzf /backup/n8n_data.tar.gz" "$SCRIPT_PATH"
    assert_success

    run grep -q "feedops_n8n_data:/data" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: checks for workflows directory" {
    run grep -q 'if \[ -d "\$BACKUP_DIR/workflows" \]' "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: restores workflow templates" {
    run grep -q 'cp -r "\$BACKUP_DIR/workflows"' "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: cleans up temporary directory" {
    run grep -q 'rm -rf "\$TEMP_DIR"' "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: starts all services after restore" {
    run grep -q "docker-compose up -d" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: provides next steps instructions" {
    run grep -q "Next steps:" "$SCRIPT_PATH"
    assert_success

    run grep -q "docker-compose ps" "$SCRIPT_PATH"
    assert_success

    run grep -q "Access n8n at" "$SCRIPT_PATH"
    assert_success

    run grep -q "Verify workflows and data" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: uses N8N_PORT environment variable" {
    run grep -q "N8N_PORT:-5678" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: provides progress messages" {
    run grep -q "Extracting backup" "$SCRIPT_PATH"
    assert_success

    run grep -q "Stopping services" "$SCRIPT_PATH"
    assert_success

    run grep -q "Restoring PostgreSQL database" "$SCRIPT_PATH"
    assert_success

    run grep -q "Restoring n8n data" "$SCRIPT_PATH"
    assert_success

    run grep -q "Starting all services" "$SCRIPT_PATH"
    assert_success

    run grep -q "Restore completed successfully" "$SCRIPT_PATH"
    assert_success
}

@test "restore.sh: uses alpine container for volume operations" {
    run grep -q "docker run --rm.*alpine" "$SCRIPT_PATH"
    assert_success
}
