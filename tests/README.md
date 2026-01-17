# FeedOps Test Suite

Comprehensive test suite for FeedOps - Automated Feed Monitoring System.

## Overview

The test suite includes:
- **Unit Tests**: Tests for individual bash scripts and functions
- **Integration Tests**: Tests for Docker services and database operations
- **Validation Tests**: Tests for configuration files and workflow definitions

## Prerequisites

- Docker and Docker Compose
- Bash 4.0 or higher
- jq (JSON processor)
- Git

## Quick Start

### 1. Setup Test Environment

```bash
# Run the setup script to install test dependencies
./tests/setup.sh
```

This will install:
- bats-core (Bash Automated Testing System)
- bats-support, bats-assert, bats-file (helper libraries)
- Test environment configuration

### 2. Run All Tests

```bash
# Run all test suites
./tests/run-tests.sh

# Or run with verbose output
./tests/run-tests.sh all -v
```

### 3. Run Specific Test Types

```bash
# Run only unit tests
./tests/run-tests.sh unit

# Run only integration tests
./tests/run-tests.sh integration

# Run only validation tests
./tests/run-tests.sh validation
```

## Test Structure

```
tests/
├── setup.sh                    # Test environment setup
├── run-tests.sh               # Main test runner
├── .env.test                  # Test environment variables
├── lib/                       # Test libraries
│   ├── bats-core/            # Bats testing framework
│   ├── bats-support/         # Bats support library
│   ├── bats-assert/          # Assertion helpers
│   └── bats-file/            # File testing helpers
├── unit/                      # Unit tests
│   ├── test_health_check.bats
│   ├── test_backup.bats
│   ├── test_cleanup.bats
│   ├── test_generate_keys.bats
│   ├── test_init_db.bats
│   └── test_restore.bats
├── integration/               # Integration tests
│   ├── test_docker_services.bats
│   ├── test_database_schema.bats
│   └── test_backup_restore.bats
├── validation/                # Validation tests
│   ├── test_workflows.bats
│   └── test_configuration.bats
├── helpers/                   # Test helper functions
│   └── test_helpers.sh
├── fixtures/                  # Test data and mocks
│   ├── sample_workflow.json
│   ├── test_data.sql
│   └── mock_env_example
└── reports/                   # Test reports (generated)
```

## Unit Tests

Unit tests validate individual bash scripts without requiring running services.

### Test Coverage

- `test_health_check.bats`: Health check script validation
  - Script structure and syntax
  - Function definitions
  - Error handling
  - Service checks
  - Disk usage monitoring

- `test_backup.bats`: Backup script validation
  - Backup directory creation
  - Database dump commands
  - Workflow export
  - Archive creation
  - Environment sanitization

- `test_cleanup.bats`: Cleanup script validation
  - Retention configuration
  - User confirmation
  - Database cleanup queries
  - Docker pruning

- `test_generate_keys.bats`: Key generation validation
  - Encryption key generation
  - Password generation
  - Environment file handling

- `test_init_db.bats`: Database initialization validation
  - Table creation
  - Index creation
  - Default data insertion
  - Function definitions

- `test_restore.bats`: Restore script validation
  - Backup extraction
  - Database restoration
  - Volume restoration
  - Service management

### Running Unit Tests

```bash
./tests/run-tests.sh unit
```

## Integration Tests

Integration tests require running Docker services and validate system integration.

### Test Coverage

- `test_docker_services.bats`: Docker service validation
  - Service definitions
  - Image configurations
  - Volume definitions
  - Network connectivity
  - Service health checks

- `test_database_schema.bats`: Database schema validation
  - Table existence
  - Column definitions
  - Index creation
  - Foreign key constraints
  - Extension installation

- `test_backup_restore.bats`: End-to-end backup/restore
  - Backup creation
  - Archive compression
  - Backup extraction
  - Data restoration

### Running Integration Tests

```bash
# Start services first
docker-compose up -d

# Run integration tests
./tests/run-tests.sh integration

# Skip live tests if services aren't running
SKIP_LIVE_TESTS=1 ./tests/run-tests.sh integration
```

## Validation Tests

Validation tests check configuration files and workflow definitions.

### Test Coverage

- `test_workflows.bats`: n8n workflow validation
  - JSON syntax validation
  - Required field presence
  - Node structure validation
  - Connection validation
  - Duplicate detection

- `test_configuration.bats`: Configuration validation
  - Environment variable presence
  - Docker Compose syntax
  - Volume definitions
  - Network configurations
  - Security settings

### Running Validation Tests

```bash
./tests/run-tests.sh validation
```

## Test Helpers

The `tests/helpers/test_helpers.sh` file provides utility functions:

- `is_docker_available()`: Check Docker availability
- `is_service_running()`: Check service status
- `wait_for_service()`: Wait for service to be ready
- `run_sql_query()`: Execute SQL queries
- `create_test_env()`: Create test environment file
- `validate_json()`: Validate JSON files
- `create_test_backup()`: Create mock backup
- `cleanup_test_resources()`: Clean up test data

## Test Fixtures

Test fixtures provide sample data for testing:

- `sample_workflow.json`: Example n8n workflow
- `test_data.sql`: Sample database data
- `mock_env_example`: Mock environment configuration

## CI/CD Integration

Tests are automatically run via GitHub Actions on:
- Push to main or develop branches
- Pull requests to main or develop

### GitHub Actions Workflow

The `.github/workflows/tests.yml` file defines:
1. **Unit Tests**: Run on every commit
2. **Validation Tests**: Check configuration and workflows
3. **Integration Tests**: Test with live services

### Local CI Testing

Run the same tests that CI runs:

```bash
# Run all test types in sequence
./tests/run-tests.sh unit
./tests/run-tests.sh validation

# Start services for integration tests
docker-compose up -d
sleep 30
./tests/run-tests.sh integration
docker-compose down -v
```

## Writing New Tests

### Unit Test Template

```bash
#!/usr/bin/env bats
# Unit tests for new-script.sh

load '../lib/bats-support/load'
load '../lib/bats-assert/load'

setup() {
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT_PATH="${TEST_DIR}/scripts/new-script.sh"
}

@test "new-script: exists and is executable" {
    assert_file_exist "$SCRIPT_PATH"
    assert_file_executable "$SCRIPT_PATH"
}

@test "new-script: contains proper shebang" {
    run head -n 1 "$SCRIPT_PATH"
    assert_output "#!/bin/bash"
}
```

### Integration Test Template

```bash
#!/usr/bin/env bats
# Integration tests for new feature

load '../lib/bats-support/load'
load '../lib/bats-assert/load'

setup() {
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

@test "integration: service is available" {
    if [ -n "$SKIP_LIVE_TESTS" ]; then
        skip "Live tests disabled"
    fi

    run docker-compose ps service-name
    assert_success
}
```

## Best Practices

1. **Isolation**: Tests should not depend on each other
2. **Idempotency**: Tests should be repeatable
3. **Clean Setup/Teardown**: Always clean up resources
4. **Skip Gracefully**: Use `skip` for unavailable services
5. **Clear Assertions**: Use descriptive test names
6. **Mock External Services**: Don't rely on external APIs

## Troubleshooting

### Tests Failing on Setup

```bash
# Ensure test dependencies are installed
./tests/setup.sh

# Check if bats is available
./tests/lib/bats-core/bin/bats --version
```

### Integration Tests Failing

```bash
# Check if services are running
docker-compose ps

# View service logs
docker-compose logs

# Restart services
docker-compose restart
```

### Permission Issues

```bash
# Make scripts executable
chmod +x tests/setup.sh
chmod +x tests/run-tests.sh
find tests -name "*.bats" -exec chmod +x {} \;
```

## Coverage Reports

Generate test coverage reports:

```bash
# Run all tests with TAP output
./tests/lib/bats-core/bin/bats tests/ --tap

# Generate HTML report (requires tap-html)
./tests/lib/bats-core/bin/bats tests/ --tap | tap-html > tests/reports/coverage.html
```

## Contributing

When adding new features:
1. Write tests first (TDD approach)
2. Ensure all tests pass
3. Add integration tests for new services
4. Update this README with new test information

## Support

For issues with tests:
1. Check the troubleshooting section
2. Review test output for specific failures
3. Check GitHub Actions logs for CI failures
4. Open an issue with test output

## License

Tests are part of the FeedOps project and follow the same license.
