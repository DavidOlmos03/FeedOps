#!/bin/bash
# Test setup script - installs test dependencies

set -e

echo "🔧 Setting up FeedOps test environment..."

# Check if bats is installed
if ! command -v bats &> /dev/null; then
    echo "📦 Installing bats-core..."

    # Clone bats and helpers
    mkdir -p tests/lib

    # Install bats-core
    if [ ! -d "tests/lib/bats-core" ]; then
        git clone https://github.com/bats-core/bats-core.git tests/lib/bats-core
    fi

    # Install bats-support
    if [ ! -d "tests/lib/bats-support" ]; then
        git clone https://github.com/bats-core/bats-support.git tests/lib/bats-support
    fi

    # Install bats-assert
    if [ ! -d "tests/lib/bats-assert" ]; then
        git clone https://github.com/bats-core/bats-assert.git tests/lib/bats-assert
    fi

    # Install bats-file
    if [ ! -d "tests/lib/bats-file" ]; then
        git clone https://github.com/bats-core/bats-file.git tests/lib/bats-file
    fi

    echo "✅ bats-core and helpers installed to tests/lib/"
else
    echo "✅ bats-core is already installed"
fi

# Install jq if not present (for JSON validation)
if ! command -v jq &> /dev/null; then
    echo "📦 Installing jq..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update && sudo apt-get install -y jq
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install jq
    fi
else
    echo "✅ jq is already installed"
fi

# Create test environment file
if [ ! -f "tests/.env.test" ]; then
    echo "📝 Creating test environment file..."
    cat > tests/.env.test <<EOF
# Test environment configuration
POSTGRES_USER=test_user
POSTGRES_PASSWORD=test_password
POSTGRES_DB=test_db
REDIS_PASSWORD=test_redis_password
N8N_PORT=5679
N8N_BASIC_AUTH_USER=test_admin
N8N_BASIC_AUTH_PASSWORD=test_password
NOTIFICATION_RETENTION_DAYS=7
EOF
    echo "✅ Test environment file created"
fi

# Create test data directory
mkdir -p tests/fixtures
mkdir -p tests/reports

echo ""
echo "✅ Test environment setup complete!"
echo ""
echo "To run tests:"
echo "  ./tests/lib/bats-core/bin/bats tests/"
echo ""
echo "Or use the test runner:"
echo "  ./tests/run-tests.sh"
