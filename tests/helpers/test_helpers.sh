#!/bin/bash
# Test helper functions for FeedOps tests

# Colors for output
export TEST_RED='\033[0;31m'
export TEST_GREEN='\033[0;32m'
export TEST_YELLOW='\033[1;33m'
export TEST_BLUE='\033[0;34m'
export TEST_NC='\033[0m' # No Color

# Check if Docker is available
is_docker_available() {
    command -v docker &> /dev/null && docker info &> /dev/null
}

# Check if docker-compose is available
is_docker_compose_available() {
    command -v docker-compose &> /dev/null
}

# Check if a service is running
is_service_running() {
    local service_name="$1"
    docker-compose ps "$service_name" 2>/dev/null | grep -q "Up"
}

# Wait for service to be healthy
wait_for_service() {
    local service_name="$1"
    local max_attempts="${2:-30}"
    local attempt=0

    echo "Waiting for $service_name to be ready..."

    while [ $attempt -lt $max_attempts ]; do
        if is_service_running "$service_name"; then
            echo "$service_name is ready!"
            return 0
        fi

        attempt=$((attempt + 1))
        sleep 1
    done

    echo "Timeout waiting for $service_name"
    return 1
}

# Create test database
create_test_database() {
    local db_name="${1:-test_feedops}"

    docker-compose exec -T postgres psql -U "${POSTGRES_USER:-n8n}" -c "CREATE DATABASE $db_name;" 2>/dev/null || true
}

# Drop test database
drop_test_database() {
    local db_name="${1:-test_feedops}"

    docker-compose exec -T postgres psql -U "${POSTGRES_USER:-n8n}" -c "DROP DATABASE IF EXISTS $db_name;" 2>/dev/null || true
}

# Run SQL query
run_sql_query() {
    local query="$1"
    local db_name="${2:-${POSTGRES_DB:-n8n}}"

    docker-compose exec -T postgres psql -U "${POSTGRES_USER:-n8n}" -d "$db_name" -t -c "$query" 2>/dev/null
}

# Generate test UUID
generate_test_uuid() {
    # Simple UUID v4 generator for testing
    cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || echo "00000000-0000-0000-0000-000000000000"
}

# Create mock .env file for testing
create_test_env() {
    local env_file="${1:-.env.test}"

    cat > "$env_file" <<EOF
# Test environment configuration
POSTGRES_USER=test_user
POSTGRES_PASSWORD=test_password
POSTGRES_DB=test_db
REDIS_PASSWORD=test_redis_password
N8N_PORT=5679
N8N_BASIC_AUTH_USER=test_admin
N8N_BASIC_AUTH_PASSWORD=test_password
N8N_ENCRYPTION_KEY=test_encryption_key_32_characters
GITHUB_TOKEN=test_github_token
REDDIT_CLIENT_ID=test_reddit_client
REDDIT_CLIENT_SECRET=test_reddit_secret
TELEGRAM_BOT_TOKEN=test_telegram_token
NOTIFICATION_RETENTION_DAYS=7
EOF
}

# Clean up test resources
cleanup_test_resources() {
    # Remove test databases
    drop_test_database "test_feedops"

    # Remove test files
    find /tmp -name "feedops_test_*" -type f -mtime +1 -delete 2>/dev/null || true
}

# Create mock workflow JSON
create_mock_workflow() {
    local workflow_name="${1:-Test Workflow}"
    local output_file="${2:-/tmp/test_workflow.json}"

    cat > "$output_file" <<EOF
{
  "name": "$workflow_name",
  "nodes": [
    {
      "parameters": {},
      "name": "Start",
      "type": "n8n-nodes-base.start",
      "typeVersion": 1,
      "position": [250, 300]
    }
  ],
  "connections": {},
  "active": false,
  "settings": {},
  "id": "test-workflow-id"
}
EOF

    echo "$output_file"
}

# Validate JSON file
validate_json() {
    local json_file="$1"

    if [ ! -f "$json_file" ]; then
        return 1
    fi

    jq empty "$json_file" 2>/dev/null
}

# Create test backup structure
create_test_backup() {
    local backup_dir="${1:-/tmp/test_backup}"
    local backup_name="feedops_backup_test"

    mkdir -p "${backup_dir}/${backup_name}"

    # Create mock backup files
    echo "-- Test database dump" > "${backup_dir}/${backup_name}/database.sql"
    echo '{"workflows": []}' > "${backup_dir}/${backup_name}/workflows.json"

    # Create mock n8n data
    mkdir -p "${backup_dir}/n8n_temp"
    echo "test" > "${backup_dir}/n8n_temp/test.txt"
    tar czf "${backup_dir}/${backup_name}/n8n_data.tar.gz" -C "${backup_dir}/n8n_temp" .
    rm -rf "${backup_dir}/n8n_temp"

    # Create workflows directory
    mkdir -p "${backup_dir}/${backup_name}/workflows"

    # Create env template
    echo "TEST_VAR=REDACTED" > "${backup_dir}/${backup_name}/env.template"

    # Create archive
    cd "$backup_dir"
    tar czf "${backup_name}.tar.gz" "$backup_name"
    rm -rf "$backup_name"

    echo "${backup_dir}/${backup_name}.tar.gz"
}

# Get service health status
get_service_health() {
    local service_name="$1"

    if ! is_service_running "$service_name"; then
        echo "down"
        return 1
    fi

    local container_id=$(docker-compose ps -q "$service_name" 2>/dev/null)
    if [ -z "$container_id" ]; then
        echo "unknown"
        return 1
    fi

    local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null || echo "no-health-check")

    echo "$health"
}

# Print test header
print_test_header() {
    local title="$1"
    echo ""
    echo -e "${TEST_BLUE}========================================${TEST_NC}"
    echo -e "${TEST_BLUE}  $title${TEST_NC}"
    echo -e "${TEST_BLUE}========================================${TEST_NC}"
    echo ""
}

# Print test result
print_test_result() {
    local status="$1"
    local message="$2"

    if [ "$status" = "pass" ]; then
        echo -e "${TEST_GREEN}✓${TEST_NC} $message"
    elif [ "$status" = "fail" ]; then
        echo -e "${TEST_RED}✗${TEST_NC} $message"
    elif [ "$status" = "skip" ]; then
        echo -e "${TEST_YELLOW}⊘${TEST_NC} $message"
    else
        echo -e "${TEST_BLUE}•${TEST_NC} $message"
    fi
}

# Export functions for use in tests
export -f is_docker_available
export -f is_docker_compose_available
export -f is_service_running
export -f wait_for_service
export -f create_test_database
export -f drop_test_database
export -f run_sql_query
export -f generate_test_uuid
export -f create_test_env
export -f cleanup_test_resources
export -f create_mock_workflow
export -f validate_json
export -f create_test_backup
export -f get_service_health
export -f print_test_header
export -f print_test_result
