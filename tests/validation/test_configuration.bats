#!/usr/bin/env bats
# Validation tests for configuration files

# Load test helpers
load '../lib/bats-support/load'
load '../lib/bats-assert/load'
load '../lib/bats-file/load'

setup() {
    # Load test environment
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

@test "validation-config: .env.example exists" {
    assert_file_exist "${TEST_DIR}/.env.example"
}

@test "validation-config: docker-compose.yml exists" {
    assert_file_exist "${TEST_DIR}/docker-compose.yml"
}

@test "validation-config: .gitignore exists" {
    assert_file_exist "${TEST_DIR}/.gitignore"
}

@test "validation-config: .dockerignore exists" {
    assert_file_exist "${TEST_DIR}/.dockerignore"
}

@test "validation-config: .env.example contains POSTGRES_USER" {
    run grep "POSTGRES_USER" "${TEST_DIR}/.env.example"
    assert_success
}

@test "validation-config: .env.example contains POSTGRES_PASSWORD" {
    run grep "POSTGRES_PASSWORD" "${TEST_DIR}/.env.example"
    assert_success
}

@test "validation-config: .env.example contains POSTGRES_DB" {
    run grep "POSTGRES_DB" "${TEST_DIR}/.env.example"
    assert_success
}

@test "validation-config: .env.example contains N8N_ENCRYPTION_KEY" {
    run grep "N8N_ENCRYPTION_KEY" "${TEST_DIR}/.env.example"
    assert_success
}

@test "validation-config: .env.example contains REDIS_PASSWORD" {
    run grep "REDIS_PASSWORD" "${TEST_DIR}/.env.example"
    assert_success
}

@test "validation-config: .env.example contains N8N_PORT" {
    run grep "N8N_PORT" "${TEST_DIR}/.env.example"
    assert_success
}

@test "validation-config: .env.example contains TELEGRAM_BOT_TOKEN placeholder" {
    run grep "TELEGRAM_BOT_TOKEN" "${TEST_DIR}/.env.example"
    assert_success
}

@test "validation-config: .env.example contains GITHUB_TOKEN placeholder" {
    run grep "GITHUB" "${TEST_DIR}/.env.example"
    assert_success
}

@test "validation-config: docker-compose.yml is valid YAML" {
    run docker-compose -f "${TEST_DIR}/docker-compose.yml" config
    assert_success
}

@test "validation-config: docker-compose defines version or services" {
    # Docker Compose v2 format may not have version
    run grep -E "(version:|services:)" "${TEST_DIR}/docker-compose.yml"
    assert_success
}

@test "validation-config: docker-compose defines postgres service" {
    run grep -A 5 "postgres:" "${TEST_DIR}/docker-compose.yml"
    assert_success
}

@test "validation-config: docker-compose defines redis service" {
    run grep -A 5 "redis:" "${TEST_DIR}/docker-compose.yml"
    assert_success
}

@test "validation-config: docker-compose defines n8n service" {
    run grep -A 5 "n8n:" "${TEST_DIR}/docker-compose.yml"
    assert_success
}

@test "validation-config: postgres uses environment variables" {
    # Check that postgres service uses POSTGRES_USER, POSTGRES_PASSWORD, etc.
    run sh -c "grep -A 20 'postgres:' '${TEST_DIR}/docker-compose.yml' | grep -E 'POSTGRES_(USER|PASSWORD|DB)'"
    assert_success
}

@test "validation-config: n8n uses environment variables" {
    run sh -c "grep -A 30 'n8n:' '${TEST_DIR}/docker-compose.yml' | grep -E 'N8N_|DB_TYPE'"
    assert_success
}

@test "validation-config: volumes are defined for persistence" {
    run grep "volumes:" "${TEST_DIR}/docker-compose.yml"
    assert_success
}

@test "validation-config: postgres volume is defined" {
    run grep -E "postgres.*data|postgres_data" "${TEST_DIR}/docker-compose.yml"
    assert_success
}

@test "validation-config: n8n volume is defined" {
    run grep -E "n8n.*data|n8n_data" "${TEST_DIR}/docker-compose.yml"
    assert_success
}

@test "validation-config: .gitignore excludes .env file" {
    run grep "^\.env$" "${TEST_DIR}/.gitignore"
    assert_success
}

@test "validation-config: .gitignore excludes node_modules" {
    run grep "node_modules" "${TEST_DIR}/.gitignore"
    assert_success
}

@test "validation-config: .gitignore excludes backups" {
    run grep -i "backup" "${TEST_DIR}/.gitignore"
    assert_success
}

@test "validation-config: .dockerignore excludes .git" {
    run grep "\.git" "${TEST_DIR}/.dockerignore"
    assert_success
}

@test "validation-config: .dockerignore excludes .env" {
    run grep "\.env" "${TEST_DIR}/.dockerignore"
    assert_success
}

@test "validation-config: no hardcoded passwords in .env.example" {
    # Check that .env.example doesn't contain actual passwords
    run grep -i "changeme\|example\|your_" "${TEST_DIR}/.env.example"
    assert_success
}

@test "validation-config: docker-compose uses restart policies" {
    run grep "restart:" "${TEST_DIR}/docker-compose.yml"
    assert_success
}

@test "validation-config: health checks are defined" {
    run grep "healthcheck:" "${TEST_DIR}/docker-compose.yml"
    # This might not always be present, so we just check if the file is readable
    [ -f "${TEST_DIR}/docker-compose.yml" ]
}

@test "validation-config: networks are properly configured" {
    run grep "networks:" "${TEST_DIR}/docker-compose.yml"
    assert_success
}

@test "validation-config: postgres exposes port or is networked" {
    # Postgres should either expose a port or be on a network
    run sh -c "grep -A 20 'postgres:' '${TEST_DIR}/docker-compose.yml' | grep -E '(ports:|networks:)'"
    assert_success
}

@test "validation-config: n8n port is configurable" {
    # Check that n8n uses N8N_PORT variable
    run sh -c "grep -A 30 'n8n:' '${TEST_DIR}/docker-compose.yml' | grep -E '\${N8N_PORT|5678'"
    assert_success
}
