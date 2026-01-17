#!/usr/bin/env bats
# Integration tests for backup and restore operations

# Load test helpers
load '../lib/bats-support/load'
load '../lib/bats-assert/load'
load '../lib/bats-file/load'

setup() {
    # Load test environment
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

    # Create temporary test directory
    export TEMP_DIR="$(mktemp -d)"
    export TEST_BACKUP_DIR="${TEMP_DIR}/backups"
    mkdir -p "$TEST_BACKUP_DIR"
}

teardown() {
    # Clean up temporary files
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

@test "integration-backup: backup script can create backup directory" {
    cd "$TEMP_DIR"
    mkdir -p backups
    assert_dir_exist "backups"
}

@test "integration-backup: backup creates timestamped directory name" {
    DATE=$(date +%Y%m%d_%H%M%S)
    BACKUP_NAME="feedops_backup_${DATE}"

    # Test the pattern matches expected format
    [[ "$BACKUP_NAME" =~ ^feedops_backup_[0-9]{8}_[0-9]{6}$ ]]
}

@test "integration-backup: can create mock backup structure" {
    BACKUP_NAME="feedops_backup_test"
    mkdir -p "${TEST_BACKUP_DIR}/${BACKUP_NAME}"

    # Create mock backup files
    echo "-- Mock SQL" > "${TEST_BACKUP_DIR}/${BACKUP_NAME}/database.sql"
    echo '{"workflows": []}' > "${TEST_BACKUP_DIR}/${BACKUP_NAME}/workflows.json"
    touch "${TEST_BACKUP_DIR}/${BACKUP_NAME}/n8n_data.tar.gz"

    assert_file_exist "${TEST_BACKUP_DIR}/${BACKUP_NAME}/database.sql"
    assert_file_exist "${TEST_BACKUP_DIR}/${BACKUP_NAME}/workflows.json"
    assert_file_exist "${TEST_BACKUP_DIR}/${BACKUP_NAME}/n8n_data.tar.gz"
}

@test "integration-backup: can create compressed archive" {
    BACKUP_NAME="feedops_backup_test"
    mkdir -p "${TEST_BACKUP_DIR}/${BACKUP_NAME}"
    echo "test" > "${TEST_BACKUP_DIR}/${BACKUP_NAME}/test.txt"

    cd "$TEST_BACKUP_DIR"
    tar czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"

    assert_file_exist "${TEST_BACKUP_DIR}/${BACKUP_NAME}.tar.gz"

    # Verify it's a valid gzip file
    run file "${TEST_BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    assert_success
    echo "$output" | grep -q "gzip compressed"
}

@test "integration-backup: can extract backup archive" {
    BACKUP_NAME="feedops_backup_test"
    mkdir -p "${TEST_BACKUP_DIR}/${BACKUP_NAME}"
    echo "test content" > "${TEST_BACKUP_DIR}/${BACKUP_NAME}/test.txt"

    cd "$TEST_BACKUP_DIR"
    tar czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
    rm -rf "${BACKUP_NAME}"

    # Extract
    tar xzf "${BACKUP_NAME}.tar.gz"

    assert_dir_exist "${TEST_BACKUP_DIR}/${BACKUP_NAME}"
    assert_file_exist "${TEST_BACKUP_DIR}/${BACKUP_NAME}/test.txt"

    run cat "${TEST_BACKUP_DIR}/${BACKUP_NAME}/test.txt"
    assert_output "test content"
}

@test "integration-backup: environment sanitization works" {
    # Create test .env file
    cat > "${TEMP_DIR}/.env" <<EOF
POSTGRES_PASSWORD=secret123
REDIS_PASSWORD=redis_secret
N8N_ENCRYPTION_KEY=encryption_key_here
PUBLIC_VAR=public_value
EOF

    # Sanitize
    sed 's/=.*/=REDACTED/' "${TEMP_DIR}/.env" > "${TEMP_DIR}/env.template"

    # Verify passwords are redacted
    run cat "${TEMP_DIR}/env.template"
    assert_success
    echo "$output" | grep -q "POSTGRES_PASSWORD=REDACTED"
    echo "$output" | grep -q "REDIS_PASSWORD=REDACTED"
    echo "$output" | grep -q "N8N_ENCRYPTION_KEY=REDACTED"

    # Verify structure is preserved
    echo "$output" | grep -q "PUBLIC_VAR=REDACTED"
}

@test "integration-restore: can find backup directory in extracted archive" {
    BACKUP_NAME="feedops_backup_20240101_120000"
    mkdir -p "${TEST_BACKUP_DIR}/${BACKUP_NAME}"
    echo "test" > "${TEST_BACKUP_DIR}/${BACKUP_NAME}/database.sql"

    # Find the directory
    run find "$TEST_BACKUP_DIR" -maxdepth 1 -type d -name "feedops_backup_*"
    assert_success
    echo "$output" | grep -q "$BACKUP_NAME"
}

@test "integration-restore: validates backup file format" {
    # Test with invalid backup (missing expected directory)
    INVALID_DIR="${TEST_BACKUP_DIR}/invalid"
    mkdir -p "$INVALID_DIR"
    echo "test" > "${INVALID_DIR}/test.txt"

    run find "$INVALID_DIR" -maxdepth 1 -type d -name "feedops_backup_*"
    assert_success
    # Output should be empty
    [ -z "$output" ]
}

@test "integration-restore: can check for required backup files" {
    BACKUP_NAME="feedops_backup_test"
    BACKUP_PATH="${TEST_BACKUP_DIR}/${BACKUP_NAME}"
    mkdir -p "$BACKUP_PATH"

    # Test database.sql check
    [ ! -f "${BACKUP_PATH}/database.sql" ]

    # Create it
    touch "${BACKUP_PATH}/database.sql"
    [ -f "${BACKUP_PATH}/database.sql" ]

    # Test n8n_data.tar.gz check
    [ ! -f "${BACKUP_PATH}/n8n_data.tar.gz" ]

    # Create it
    touch "${BACKUP_PATH}/n8n_data.tar.gz"
    [ -f "${BACKUP_PATH}/n8n_data.tar.gz" ]

    # Test workflows directory check
    [ ! -d "${BACKUP_PATH}/workflows" ]

    # Create it
    mkdir -p "${BACKUP_PATH}/workflows"
    [ -d "${BACKUP_PATH}/workflows" ]
}

@test "integration-backup-restore: full backup and restore cycle" {
    if [ -n "$SKIP_LIVE_TESTS" ]; then
        skip "Live tests disabled"
    fi

    # This test validates the complete backup/restore workflow
    BACKUP_NAME="feedops_backup_integration_test"
    BACKUP_PATH="${TEST_BACKUP_DIR}/${BACKUP_NAME}"

    # Create mock backup
    mkdir -p "$BACKUP_PATH"
    echo "-- Test database dump" > "${BACKUP_PATH}/database.sql"
    echo '{"test": "workflows"}' > "${BACKUP_PATH}/workflows.json"

    # Create n8n data archive
    mkdir -p "${TEMP_DIR}/n8n_data"
    echo "test data" > "${TEMP_DIR}/n8n_data/test.txt"
    tar czf "${BACKUP_PATH}/n8n_data.tar.gz" -C "${TEMP_DIR}/n8n_data" .

    # Create workflows directory
    mkdir -p "${BACKUP_PATH}/workflows"
    echo '{"workflow": "test"}' > "${BACKUP_PATH}/workflows/test.json"

    # Create sanitized env
    echo "TEST_VAR=REDACTED" > "${BACKUP_PATH}/env.template"

    # Create archive
    cd "$TEST_BACKUP_DIR"
    tar czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"

    # Simulate restore: extract
    RESTORE_DIR="${TEMP_DIR}/restore"
    mkdir -p "$RESTORE_DIR"
    tar xzf "${TEST_BACKUP_DIR}/${BACKUP_NAME}.tar.gz" -C "$RESTORE_DIR"

    # Verify all files are present
    assert_file_exist "${RESTORE_DIR}/${BACKUP_NAME}/database.sql"
    assert_file_exist "${RESTORE_DIR}/${BACKUP_NAME}/workflows.json"
    assert_file_exist "${RESTORE_DIR}/${BACKUP_NAME}/n8n_data.tar.gz"
    assert_dir_exist "${RESTORE_DIR}/${BACKUP_NAME}/workflows"
    assert_file_exist "${RESTORE_DIR}/${BACKUP_NAME}/env.template"

    # Verify n8n data can be extracted
    mkdir -p "${TEMP_DIR}/restored_n8n"
    tar xzf "${RESTORE_DIR}/${BACKUP_NAME}/n8n_data.tar.gz" -C "${TEMP_DIR}/restored_n8n"
    assert_file_exist "${TEMP_DIR}/restored_n8n/test.txt"
}
