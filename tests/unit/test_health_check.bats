#!/usr/bin/env bats
# Unit tests for health-check.sh

# Load test helpers
load '../lib/bats-support/load'
load '../lib/bats-assert/load'
load '../lib/bats-file/load'

setup() {
    # Load test environment
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT_PATH="${TEST_DIR}/scripts/health-check.sh"

    # Mock environment
    export N8N_PORT=5678
    export POSTGRES_USER=n8n
    export REDIS_PASSWORD=testpass

    # Create temporary test directory
    export TEMP_DIR="$(mktemp -d)"
}

teardown() {
    # Clean up temporary files
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

@test "health-check.sh: script exists and is executable" {
    assert_file_exist "$SCRIPT_PATH"
    assert_file_executable "$SCRIPT_PATH"
}

@test "health-check.sh: contains proper shebang" {
    run head -n 1 "$SCRIPT_PATH"
    assert_output "#!/bin/bash"
}

@test "health-check.sh: uses set -e for error handling" {
    run grep -q "set -e" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: defines color variables" {
    run grep -q "RED=" "$SCRIPT_PATH"
    assert_success

    run grep -q "GREEN=" "$SCRIPT_PATH"
    assert_success

    run grep -q "YELLOW=" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: loads environment variables from .env file" {
    run grep -q "if \[ -f .env \]" "$SCRIPT_PATH"
    assert_success

    run grep -q "export.*\.env" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: checks for docker installation" {
    run grep -q "command -v docker" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: defines check_service function" {
    run grep -q "check_service()" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: checks postgres service" {
    run grep -q "check_service postgres" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: checks redis service" {
    run grep -q "check_service redis" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: checks n8n service" {
    run grep -q "check_service n8n" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: checks n8n web interface connectivity" {
    run grep -q "curl.*localhost.*N8N_PORT" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: checks PostgreSQL connection with pg_isready" {
    run grep -q "pg_isready" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: checks Redis with ping command" {
    run grep -q "redis-cli.*ping" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: monitors disk usage" {
    run grep -q "df -h" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: has disk usage thresholds (80% and 90%)" {
    run grep -q "DISK_USAGE.*-gt 90" "$SCRIPT_PATH"
    assert_success

    run grep -q "DISK_USAGE.*-gt 80" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: checks Docker volume sizes" {
    run grep -q "docker volume ls" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: tracks failed checks counter" {
    run grep -q "FAILED=0" "$SCRIPT_PATH"
    assert_success

    run grep -q "FAILED=\$((FAILED+1))" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: exits with appropriate status codes" {
    run grep -q "exit 0" "$SCRIPT_PATH"
    assert_success

    run grep -q "exit 1" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: provides troubleshooting guidance on failure" {
    run grep -q "Troubleshooting:" "$SCRIPT_PATH"
    assert_success

    run grep -q "docker-compose logs" "$SCRIPT_PATH"
    assert_success

    run grep -q "docker-compose restart" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: uses consistent output formatting" {
    # Check for section headers
    run grep -q "Services:" "$SCRIPT_PATH"
    assert_success

    run grep -q "Connectivity:" "$SCRIPT_PATH"
    assert_success

    run grep -q "Resources:" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: handles missing Docker gracefully" {
    run grep -q "Docker is not installed" "$SCRIPT_PATH"
    assert_success
}

@test "health-check.sh: handles Docker daemon not running" {
    run grep -q "Docker daemon is not running" "$SCRIPT_PATH"
    assert_success

    run grep -q "docker info" "$SCRIPT_PATH"
    assert_success
}
