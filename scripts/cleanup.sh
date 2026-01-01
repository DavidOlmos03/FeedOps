#!/bin/bash
# Cleanup script for FeedOps - removes old notifications and optimizes database

set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "🧹 FeedOps Cleanup Script"
echo "========================"
echo ""

# Get retention days from config or env
RETENTION_DAYS=${NOTIFICATION_RETENTION_DAYS:-30}

echo "Settings:"
echo "- Retention period: $RETENTION_DAYS days"
echo ""

read -p "Continue with cleanup? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

# Cleanup old notifications
echo "🗑️  Cleaning up notifications older than $RETENTION_DAYS days..."

docker-compose exec -T postgres psql \
    -U "${POSTGRES_USER:-n8n}" \
    -d "${POSTGRES_DB:-n8n}" \
    <<-EOSQL
    DO \$\$
    DECLARE
        deleted_count INTEGER;
    BEGIN
        DELETE FROM notifications_history
        WHERE sent_at < NOW() - INTERVAL '$RETENTION_DAYS days';

        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'Deleted % old notifications', deleted_count;
    END\$\$;
EOSQL

# Vacuum database
echo "🔧 Optimizing database..."
docker-compose exec -T postgres psql \
    -U "${POSTGRES_USER:-n8n}" \
    -d "${POSTGRES_DB:-n8n}" \
    -c "VACUUM ANALYZE;"

# Clean up old n8n executions (if configured)
echo "🗑️  Cleaning up old workflow executions..."
docker-compose exec -T postgres psql \
    -U "${POSTGRES_USER:-n8n}" \
    -d "${POSTGRES_DB:-n8n}" \
    <<-EOSQL
    DO \$\$
    DECLARE
        deleted_count INTEGER;
    BEGIN
        -- Only if execution_entity table exists
        IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'execution_entity') THEN
            DELETE FROM execution_entity
            WHERE "startedAt" < NOW() - INTERVAL '7 days'
            AND finished = true;

            GET DIAGNOSTICS deleted_count = ROW_COUNT;
            RAISE NOTICE 'Deleted % old executions', deleted_count;
        END IF;
    END\$\$;
EOSQL

# Clean Docker system
echo "🐳 Cleaning Docker system..."
docker system prune -f --volumes

# Show results
echo ""
echo "📊 Cleanup Results:"
echo "==================="

# Database size
docker-compose exec -T postgres psql \
    -U "${POSTGRES_USER:-n8n}" \
    -d "${POSTGRES_DB:-n8n}" \
    -c "SELECT pg_size_pretty(pg_database_size('${POSTGRES_DB:-n8n}')) as database_size;"

# Volume sizes
echo ""
echo "Volume sizes:"
docker volume ls --format "table {{.Name}}\t{{.Size}}" | grep feedops

echo ""
echo "✅ Cleanup completed successfully!"
