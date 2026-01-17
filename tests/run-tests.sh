#!/bin/bash
# Main test runner for FeedOps

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 FeedOps Test Suite${NC}"
echo "======================"
echo ""

# Check if bats is installed
if [ ! -f "tests/lib/bats-core/bin/bats" ]; then
    echo -e "${YELLOW}⚠️  Test dependencies not found. Running setup...${NC}"
    bash tests/setup.sh
    echo ""
fi

# Export BATS_LIB_PATH for helper libraries
export BATS_LIB_PATH="tests/lib"

# Parse arguments
TEST_TYPE="${1:-all}"
VERBOSE="${2:-false}"

BATS_BIN="tests/lib/bats-core/bin/bats"
BATS_OPTS=""

if [ "$VERBOSE" = "-v" ] || [ "$VERBOSE" = "--verbose" ]; then
    BATS_OPTS="--verbose-run --show-output-of-passing-tests"
fi

# Run tests based on type
case $TEST_TYPE in
    unit)
        echo -e "${BLUE}Running unit tests...${NC}"
        $BATS_BIN $BATS_OPTS tests/unit/
        ;;
    integration)
        echo -e "${BLUE}Running integration tests...${NC}"
        $BATS_BIN $BATS_OPTS tests/integration/
        ;;
    validation)
        echo -e "${BLUE}Running validation tests...${NC}"
        $BATS_BIN $BATS_OPTS tests/validation/
        ;;
    all)
        echo -e "${BLUE}Running all tests...${NC}"
        echo ""

        echo -e "${YELLOW}📋 Unit Tests${NC}"
        echo "-------------"
        $BATS_BIN $BATS_OPTS tests/unit/ || true
        echo ""

        echo -e "${YELLOW}🔗 Integration Tests${NC}"
        echo "-------------------"
        $BATS_BIN $BATS_OPTS tests/integration/ || true
        echo ""

        echo -e "${YELLOW}✅ Validation Tests${NC}"
        echo "------------------"
        $BATS_BIN $BATS_OPTS tests/validation/ || true
        ;;
    *)
        echo -e "${RED}Unknown test type: $TEST_TYPE${NC}"
        echo ""
        echo "Usage: ./tests/run-tests.sh [unit|integration|validation|all] [-v|--verbose]"
        echo ""
        echo "Examples:"
        echo "  ./tests/run-tests.sh                    # Run all tests"
        echo "  ./tests/run-tests.sh unit               # Run only unit tests"
        echo "  ./tests/run-tests.sh integration -v     # Run integration tests with verbose output"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✅ Test execution complete!${NC}"
