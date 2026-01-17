#!/usr/bin/env bats
# Integration tests for Docker services

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
}

@test "integration: docker-compose.yml exists" {
    [ -f "${TEST_DIR}/docker-compose.yml" ]
}

@test "integration: docker daemon is running" {
    run docker info
    assert_success
}

@test "integration: docker-compose is available" {
    run command -v docker-compose
    assert_success
}

@test "integration: can parse docker-compose.yml" {
    run docker-compose -f "${TEST_DIR}/docker-compose.yml" config
    assert_success
}

@test "integration: docker-compose defines postgres service" {
    run docker-compose -f "${TEST_DIR}/docker-compose.yml" config --services
    assert_success
    echo "$output" | grep -q "postgres"
}

@test "integration: docker-compose defines redis service" {
    run docker-compose -f "${TEST_DIR}/docker-compose.yml" config --services
    assert_success
    echo "$output" | grep -q "redis"
}

@test "integration: docker-compose defines n8n service" {
    run docker-compose -f "${TEST_DIR}/docker-compose.yml" config --services
    assert_success
    echo "$output" | grep -q "n8n"
}

@test "integration: postgres service uses correct image" {
    run docker-compose -f "${TEST_DIR}/docker-compose.yml" config
    assert_success
    echo "$output" | grep -q "postgres.*16.*alpine"
}

@test "integration: redis service uses correct image" {
    run docker-compose -f "${TEST_DIR}/docker-compose.yml" config
    assert_success
    echo "$output" | grep -q "redis.*7.*alpine"
}

@test "integration: n8n service uses correct image" {
    run docker-compose -f "${TEST_DIR}/docker-compose.yml" config
    assert_success
    echo "$output" | grep -q "n8nio/n8n"
}

@test "integration: postgres volume is defined" {
    run docker-compose -f "${TEST_DIR}/docker-compose.yml" config --volumes
    assert_success
    echo "$output" | grep -q "postgres"
}

@test "integration: redis volume is defined" {
    run docker-compose -f "${TEST_DIR}/docker-compose.yml" config --volumes
    assert_success
    echo "$output" | grep -q "redis"
}

@test "integration: n8n volume is defined" {
    run docker-compose -f "${TEST_DIR}/docker-compose.yml" config --volumes
    assert_success
    echo "$output" | grep -q "n8n"
}

# These tests require services to be running
# Skip if SKIP_LIVE_TESTS is set
@test "integration: can connect to postgres when running" {
    if [ -n "$SKIP_LIVE_TESTS" ]; then
        skip "Live tests disabled"
    fi

    # Check if postgres is running
    if docker-compose ps postgres 2>/dev/null | grep -q "Up"; then
        run docker-compose exec -T postgres pg_isready -U "${POSTGRES_USER:-n8n}"
        assert_success
    else
        skip "PostgreSQL service not running"
    fi
}

@test "integration: can connect to redis when running" {
    if [ -n "$SKIP_LIVE_TESTS" ]; then
        skip "Live tests disabled"
    fi

    # Check if redis is running
    if docker-compose ps redis 2>/dev/null | grep -q "Up"; then
        run docker-compose exec -T redis redis-cli ping
        assert_success
        assert_output "PONG"
    else
        skip "Redis service not running"
    fi
}

@test "integration: n8n web interface responds when running" {
    if [ -n "$SKIP_LIVE_TESTS" ]; then
        skip "Live tests disabled"
    fi

    # Check if n8n is running
    if docker-compose ps n8n 2>/dev/null | grep -q "Up"; then
        run curl -s -o /dev/null -w "%{http_code}" http://localhost:${N8N_PORT:-5678}
        assert_success
        # n8n should return 200 or 401 (auth required)
        [[ "$output" == "200" || "$output" == "401" ]]
    else
        skip "n8n service not running"
    fi
}
