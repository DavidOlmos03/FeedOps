#!/bin/bash
# Restore script for FeedOps

set -e

# Check if backup file is provided
if [ -z "$1" ]; then
    echo "❌ Error: No backup file specified"
    echo "Usage: $0 <backup-file.tar.gz>"
    echo ""
    echo "Available backups:"
    ls -lh backups/*.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "⚠️  WARNING: This will restore FeedOps from backup and may overwrite existing data!"
echo "Backup file: $BACKUP_FILE"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled"
    exit 0
fi

# Extract backup
TEMP_DIR=$(mktemp -d)
echo "📦 Extracting backup..."
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"
BACKUP_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "feedops_backup_*" | head -n 1)

if [ -z "$BACKUP_DIR" ]; then
    echo "❌ Error: Invalid backup file format"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Stop services
echo "🛑 Stopping services..."
docker-compose down

# Restore PostgreSQL database
if [ -f "$BACKUP_DIR/database.sql" ]; then
    echo "📥 Restoring PostgreSQL database..."

    # Start only postgres temporarily
    docker-compose up -d postgres

    # Wait for postgres to be ready
    echo "⏳ Waiting for PostgreSQL to be ready..."
    sleep 10

    # Restore database
    docker-compose exec -T postgres psql \
        -U "${POSTGRES_USER:-n8n}" \
        -d "${POSTGRES_DB:-n8n}" \
        < "$BACKUP_DIR/database.sql"

    echo "✅ Database restored"
fi

# Restore n8n data volume
if [ -f "$BACKUP_DIR/n8n_data.tar.gz" ]; then
    echo "📥 Restoring n8n data..."

    # Create volume if it doesn't exist
    docker volume create feedops_n8n_data

    # Restore data
    docker run --rm \
        -v feedops_n8n_data:/data \
        -v "$BACKUP_DIR":/backup \
        alpine \
        sh -c "cd /data && tar xzf /backup/n8n_data.tar.gz"

    echo "✅ n8n data restored"
fi

# Restore workflow templates
if [ -d "$BACKUP_DIR/workflows" ]; then
    echo "📥 Restoring workflow templates..."
    cp -r "$BACKUP_DIR/workflows" .
    echo "✅ Workflow templates restored"
fi

# Cleanup
rm -rf "$TEMP_DIR"

# Start all services
echo "🚀 Starting all services..."
docker-compose up -d

echo ""
echo "✅ Restore completed successfully!"
echo ""
echo "Next steps:"
echo "1. Wait for services to start (check with: docker-compose ps)"
echo "2. Access n8n at: http://localhost:${N8N_PORT:-5678}"
echo "3. Verify workflows and data"
