#!/bin/bash
# Health check script for FeedOps services

set -e

echo "🏥 FeedOps Health Check"
echo "======================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

check_service() {
    local service=$1
    local status=$(docker-compose ps -q $service 2>/dev/null)

    if [ -z "$status" ]; then
        echo -e "${RED}✗${NC} $service: Not running"
        return 1
    fi

    local health=$(docker inspect --format='{{.State.Health.Status}}' $(docker-compose ps -q $service) 2>/dev/null || echo "no-health-check")

    if [ "$health" = "healthy" ]; then
        echo -e "${GREEN}✓${NC} $service: Healthy"
        return 0
    elif [ "$health" = "no-health-check" ]; then
        # Check if container is running
        local state=$(docker inspect --format='{{.State.Running}}' $(docker-compose ps -q $service) 2>/dev/null)
        if [ "$state" = "true" ]; then
            echo -e "${GREEN}✓${NC} $service: Running (no health check)"
            return 0
        else
            echo -e "${RED}✗${NC} $service: Not running"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠${NC} $service: $health"
        return 1
    fi
}

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗${NC} Docker is not installed"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}✗${NC} Docker daemon is not running"
    exit 1
fi

echo "Services:"
echo "--------"

FAILED=0

# Check each service
check_service postgres || FAILED=$((FAILED+1))
check_service redis || FAILED=$((FAILED+1))
check_service n8n || FAILED=$((FAILED+1))

echo ""
echo "Connectivity:"
echo "------------"

# Check n8n web interface
if curl -s -o /dev/null -w "%{http_code}" http://localhost:${N8N_PORT:-5678} | grep -q "200\|401"; then
    echo -e "${GREEN}✓${NC} n8n web interface: Accessible"
else
    echo -e "${RED}✗${NC} n8n web interface: Not accessible"
    FAILED=$((FAILED+1))
fi

# Check database connection
if docker-compose exec -T postgres pg_isready -U ${POSTGRES_USER:-n8n} &>/dev/null; then
    echo -e "${GREEN}✓${NC} PostgreSQL: Accepting connections"
else
    echo -e "${RED}✗${NC} PostgreSQL: Not accepting connections"
    FAILED=$((FAILED+1))
fi

# Check Redis
if docker-compose exec -T redis redis-cli -a ${REDIS_PASSWORD} ping 2>/dev/null | grep -q PONG; then
    echo -e "${GREEN}✓${NC} Redis: Responding"
else
    echo -e "${YELLOW}⚠${NC} Redis: Not responding (may be disabled)"
fi

echo ""
echo "Resources:"
echo "---------"

# Check disk space
DISK_USAGE=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo -e "${RED}✗${NC} Disk usage: ${DISK_USAGE}% (Critical)"
    FAILED=$((FAILED+1))
elif [ "$DISK_USAGE" -gt 80 ]; then
    echo -e "${YELLOW}⚠${NC} Disk usage: ${DISK_USAGE}% (Warning)"
else
    echo -e "${GREEN}✓${NC} Disk usage: ${DISK_USAGE}%"
fi

# Check volume sizes
echo ""
echo "Volume sizes:"
docker volume ls --format "table {{.Name}}\t{{.Size}}" | grep feedops || echo "No volumes found"

echo ""
echo "======================="

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAILED check(s) failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "- Check logs: docker-compose logs"
    echo "- Restart services: docker-compose restart"
    echo "- Full restart: docker-compose down && docker-compose up -d"
    exit 1
fi
