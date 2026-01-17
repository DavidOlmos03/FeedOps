#!/usr/bin/env bats
# Unit tests for generate-keys.sh

# Load test helpers
load '../lib/bats-support/load'
load '../lib/bats-assert/load'
load '../lib/bats-file/load'

setup() {
    # Load test environment
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT_PATH="${TEST_DIR}/scripts/generate-keys.sh"

    # Create temporary test directory
    export TEMP_DIR="$(mktemp -d)"
}

teardown() {
    # Clean up temporary files
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

@test "generate-keys.sh: script exists and is executable" {
    assert_file_exist "$SCRIPT_PATH"
    assert_file_executable "$SCRIPT_PATH"
}

@test "generate-keys.sh: contains proper shebang" {
    run head -n 1 "$SCRIPT_PATH"
    assert_output "#!/bin/bash"
}

@test "generate-keys.sh: uses set -e for error handling" {
    run grep -q "set -e" "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: checks if .env file exists" {
    run grep -q "if \[ ! -f .env \]" "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: creates .env from .env.example if missing" {
    run grep -q "if \[ -f .env.example \]" "$SCRIPT_PATH"
    assert_success

    run grep -q "cp .env.example .env" "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: handles missing .env.example gracefully" {
    run grep -q ".env.example not found" "$SCRIPT_PATH"
    assert_success

    run grep -q "exit 1" "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: generates N8N encryption key" {
    run grep -q "N8N_ENCRYPTION_KEY" "$SCRIPT_PATH"
    assert_success

    run grep -q "openssl rand -hex 32" "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: checks for existing N8N encryption key" {
    run grep -q 'if grep -q "^N8N_ENCRYPTION_KEY=$"' "$SCRIPT_PATH"
    assert_success

    run grep -q "N8N encryption key already exists" "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: updates existing empty N8N key" {
    run grep -q 'sed -i "s|^N8N_ENCRYPTION_KEY=.*' "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: appends N8N key if not present" {
    run grep -q 'echo "N8N_ENCRYPTION_KEY=$N8N_KEY" >> .env' "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: defines password generation function" {
    run grep -q "generate_password()" "$SCRIPT_PATH"
    assert_success

    run grep -q "openssl rand -base64 32" "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: generates strong random passwords" {
    run grep -q "tr -d \"=+/\"" "$SCRIPT_PATH"
    assert_success

    run grep -q "cut -c1-25" "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: replaces changeme passwords" {
    run grep -q 'if grep -q "changeme" .env' "$SCRIPT_PATH"
    assert_success

    run grep -q "changeme_postgres_password" "$SCRIPT_PATH"
    assert_success

    run grep -q "changeme_n8n_password" "$SCRIPT_PATH"
    assert_success

    run grep -q "changeme_redis_password" "$SCRIPT_PATH"
    assert_success

    run grep -q "changeme_github_webhook_secret" "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: uses sed to replace passwords in-place" {
    run grep -q 'sed -i.*changeme.*generate_password' "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: provides security warning" {
    run grep -q "Keep your .env file secure" "$SCRIPT_PATH"
    assert_success

    run grep -q "never commit it to version control" "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: provides next steps instructions" {
    run grep -q "Next steps:" "$SCRIPT_PATH"
    assert_success

    run grep -q "Edit .env and add your API tokens" "$SCRIPT_PATH"
    assert_success

    run grep -q "docker-compose up -d" "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: outputs progress messages" {
    run grep -q "Generating encryption keys" "$SCRIPT_PATH"
    assert_success

    run grep -q "N8N encryption key generated" "$SCRIPT_PATH"
    assert_success

    run grep -q "Random passwords generated" "$SCRIPT_PATH"
    assert_success

    run grep -q "All keys generated successfully" "$SCRIPT_PATH"
    assert_success
}

@test "generate-keys.sh: uses openssl for cryptographic operations" {
    # Count openssl usage
    run grep -c "openssl" "$SCRIPT_PATH"
    assert_success
    [ "$output" -ge 2 ]
}
