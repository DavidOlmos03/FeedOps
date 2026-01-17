# FeedOps Testing Guide

Comprehensive testing documentation for the FeedOps project.

## Table of Contents

1. [Overview](#overview)
2. [Test Infrastructure](#test-infrastructure)
3. [Running Tests](#running-tests)
4. [Test Coverage](#test-coverage)
5. [CI/CD Integration](#cicd-integration)
6. [Contributing Tests](#contributing-tests)

## Overview

FeedOps uses a comprehensive test suite built with **bats-core** (Bash Automated Testing System) to ensure reliability and quality across:

- **Bash Scripts**: All operational scripts in `scripts/`
- **Docker Services**: Service configuration and health
- **Database Schema**: PostgreSQL table structure and integrity
- **Workflow Definitions**: n8n workflow JSON validation
- **Configuration Files**: Environment and Docker Compose validation

### Test Philosophy

- **Fast Feedback**: Unit tests run in seconds without external dependencies
- **Integration Coverage**: Tests validate real Docker service interactions
- **Validation First**: Configuration and workflow syntax checked before deployment
- **CI/CD Ready**: All tests automated via GitHub Actions

## Test Infrastructure

### Installation

```bash
# One-time setup - installs bats-core and dependencies
./tests/setup.sh
```

This installs:
- **bats-core**: Testing framework for bash
- **bats-support**: Helper library for assertions
- **bats-assert**: Rich assertion library
- **bats-file**: File system testing helpers

### Project Structure

```
tests/
├── setup.sh              # Install test dependencies
├── run-tests.sh          # Main test runner
├── unit/                 # Script unit tests (6 files)
├── integration/          # Service integration tests (3 files)
├── validation/           # Configuration tests (2 files)
├── helpers/              # Test utilities
├── fixtures/             # Test data and mocks
└── README.md             # Detailed test documentation
```

## Running Tests

### Quick Start

```bash
# Run all tests
./tests/run-tests.sh

# Run specific test suite
./tests/run-tests.sh unit          # Unit tests only
./tests/run-tests.sh integration   # Integration tests only
./tests/run-tests.sh validation    # Validation tests only

# Verbose output
./tests/run-tests.sh all -v
```

### Unit Tests (No Services Required)

Unit tests validate bash script structure, logic, and patterns without requiring running services.

```bash
./tests/run-tests.sh unit
```

**Coverage:**
- ✅ scripts/health-check.sh (28 tests)
- ✅ scripts/backup.sh (26 tests)
- ✅ scripts/cleanup.sh (24 tests)
- ✅ scripts/generate-keys.sh (21 tests)
- ✅ scripts/init-db.sh (30 tests)
- ✅ scripts/restore.sh (29 tests)

**Total: 158 unit tests**

### Integration Tests (Requires Services)

Integration tests validate Docker services, database operations, and end-to-end workflows.

```bash
# Start services first
docker-compose up -d
sleep 30  # Wait for services to be ready

# Run integration tests
./tests/run-tests.sh integration

# Cleanup
docker-compose down -v
```

**Coverage:**
- ✅ Docker service health (15 tests)
- ✅ Database schema validation (17 tests)
- ✅ Backup/restore operations (12 tests)

**Total: 44 integration tests**

To skip tests requiring live services:

```bash
SKIP_LIVE_TESTS=1 ./tests/run-tests.sh integration
```

### Validation Tests (Configuration)

Validation tests check configuration files, workflows, and project structure.

```bash
./tests/run-tests.sh validation
```

**Coverage:**
- ✅ n8n workflow JSON validation (32 tests)
- ✅ Configuration file validation (28 tests)

**Total: 60 validation tests**

## Test Coverage

### Overall Statistics

- **Total Tests**: 262 tests
- **Unit Tests**: 158 tests (60%)
- **Integration Tests**: 44 tests (17%)
- **Validation Tests**: 60 tests (23%)

### Test Categories

#### 1. Script Validation (158 tests)

**health-check.sh** (28 tests)
- Script structure and permissions
- Service health check logic
- Docker daemon verification
- Disk usage monitoring
- Connectivity tests
- Error handling and exit codes

**backup.sh** (26 tests)
- Backup directory creation
- PostgreSQL dump commands
- n8n workflow export (with fallback)
- Volume backup creation
- Environment sanitization
- Archive compression

**cleanup.sh** (24 tests)
- User confirmation flow
- Retention period configuration
- Database cleanup queries
- Old execution removal
- Docker system pruning
- Result reporting

**generate-keys.sh** (21 tests)
- N8N encryption key generation
- Password generation (strong random)
- Environment file management
- Security warnings
- Placeholder replacement

**init-db.sh** (30 tests)
- UUID extension creation
- Table definitions (3 tables)
- Column structure validation
- Index creation (5 indexes)
- Foreign key constraints
- Default configuration data
- Cleanup function creation

**restore.sh** (29 tests)
- Backup file validation
- Archive extraction
- Service management
- Database restoration
- Volume restoration
- Workflow template restoration

#### 2. Integration Tests (44 tests)

**Docker Services** (15 tests)
- docker-compose.yml parsing
- Service definitions (postgres, redis, n8n)
- Image configurations
- Volume definitions
- Network configurations
- Live service connectivity

**Database Schema** (17 tests)
- Table existence validation
- Column definitions
- Data types verification
- Index presence
- Foreign key constraints
- Extension installation
- CRUD operations

**Backup/Restore Workflow** (12 tests)
- End-to-end backup cycle
- Archive creation/extraction
- Data integrity validation
- Environment sanitization
- Workflow preservation

#### 3. Validation Tests (60 tests)

**Workflow Validation** (32 tests)
- JSON syntax validation (5 workflows)
- Required field presence
- Node structure validation
- Connection definitions
- Active/inactive status
- Duplicate node detection
- Position coordinates

**Configuration Validation** (28 tests)
- .env.example completeness
- Docker Compose validity
- Environment variable presence
- Service definitions
- Volume configurations
- Network definitions
- Security settings (.gitignore)

## CI/CD Integration

### GitHub Actions

Tests run automatically on:
- **Push** to `main` or `develop` branches
- **Pull requests** to `main` or `develop` branches

Workflow file: `.github/workflows/tests.yml`

### CI Pipeline

```
┌─────────────────┐
│   Unit Tests    │  (Fast - ~30 seconds)
└────────┬────────┘
         │
┌────────▼────────┐
│ Validation Tests│  (Fast - ~20 seconds)
└────────┬────────┘
         │
┌────────▼────────┐
│Integration Tests│  (Slower - ~2 minutes)
│ (with services) │
└────────┬────────┘
         │
┌────────▼────────┐
│   All Passed    │  ✅
└─────────────────┘
```

### Running CI Locally

Simulate the CI environment:

```bash
# Clean environment
docker-compose down -v

# Run unit tests
./tests/run-tests.sh unit

# Run validation tests
./tests/run-tests.sh validation

# Start services and run integration tests
docker-compose up -d
sleep 30
./tests/run-tests.sh integration

# Cleanup
docker-compose down -v
```

## Contributing Tests

### Writing a New Unit Test

Create a new file in `tests/unit/`:

```bash
#!/usr/bin/env bats
# Unit tests for my-script.sh

load '../lib/bats-support/load'
load '../lib/bats-assert/load'
load '../lib/bats-file/load'

setup() {
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT_PATH="${TEST_DIR}/scripts/my-script.sh"
}

@test "my-script: exists and is executable" {
    assert_file_exist "$SCRIPT_PATH"
    assert_file_executable "$SCRIPT_PATH"
}

@test "my-script: has proper shebang" {
    run head -n 1 "$SCRIPT_PATH"
    assert_output "#!/bin/bash"
}

@test "my-script: uses set -e" {
    run grep -q "set -e" "$SCRIPT_PATH"
    assert_success
}
```

### Writing an Integration Test

Create a new file in `tests/integration/`:

```bash
#!/usr/bin/env bats
# Integration tests for my-feature

load '../lib/bats-support/load'
load '../lib/bats-assert/load'

setup() {
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

@test "integration: feature works with live service" {
    if [ -n "$SKIP_LIVE_TESTS" ]; then
        skip "Live tests disabled"
    fi

    # Test implementation
    run docker-compose exec -T postgres psql -U n8n -d n8n -c "SELECT 1;"
    assert_success
}
```

### Test Helpers

Use provided helpers from `tests/helpers/test_helpers.sh`:

```bash
# Load helpers
source "${TEST_DIR}/tests/helpers/test_helpers.sh"

# Use helper functions
is_docker_available
is_service_running "postgres"
wait_for_service "postgres" 30
run_sql_query "SELECT * FROM feedops_config;"
```

## Best Practices

### 1. Test Isolation
- Tests should not depend on execution order
- Use `setup()` and `teardown()` for clean state
- Clean up resources after tests

### 2. Descriptive Names
```bash
# Good
@test "backup: creates timestamped directory"

# Bad
@test "test1"
```

### 3. Skip When Appropriate
```bash
@test "integration: requires live service" {
    if [ -n "$SKIP_LIVE_TESTS" ]; then
        skip "Live tests disabled"
    fi
    # Test code
}
```

### 4. Use Assertions
```bash
# Use bats-assert helpers
assert_success
assert_failure
assert_output "expected"
assert_line "expected line"

# Use bats-file helpers
assert_file_exist "/path/to/file"
assert_file_executable "/path/to/script"
assert_dir_exist "/path/to/dir"
```

## Troubleshooting

### Tests Won't Run

```bash
# Reinstall test dependencies
rm -rf tests/lib
./tests/setup.sh

# Make scripts executable
chmod +x tests/setup.sh
chmod +x tests/run-tests.sh
find tests -name "*.bats" -exec chmod +x {} \;
```

### Integration Tests Fail

```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs

# Restart services
docker-compose restart

# Full reset
docker-compose down -v
docker-compose up -d
sleep 30
```

### Permission Denied

```bash
# Fix script permissions
find . -name "*.sh" -exec chmod +x {} \;

# Fix test permissions
find tests -name "*.bats" -exec chmod +x {} \;
```

## Coverage Goals

Current coverage: **Excellent** ✅

- ✅ All bash scripts have comprehensive unit tests
- ✅ All Docker services have integration tests
- ✅ All workflows have validation tests
- ✅ All configuration files validated
- ✅ CI/CD pipeline configured

## Future Enhancements

Potential improvements:

1. **Performance Tests**: Add load testing for n8n workflows
2. **Security Tests**: Automated vulnerability scanning
3. **End-to-End Tests**: Full workflow execution tests
4. **Coverage Reports**: Generate test coverage metrics
5. **Mutation Testing**: Verify test quality

## Resources

- [bats-core Documentation](https://bats-core.readthedocs.io/)
- [FeedOps Test README](tests/README.md) - Detailed test documentation
- [GitHub Actions Workflow](.github/workflows/tests.yml)

## Support

For testing issues:
1. Check `tests/README.md` for detailed information
2. Review test output for specific failures
3. Check GitHub Actions logs for CI failures
4. Open an issue with test output and logs

---

**Happy Testing!** 🧪✅
