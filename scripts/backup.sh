#!/bin/bash
# Backup script for FeedOps
# Creates backups of database, n8n workflows, and configuration

set -e

# Configuration
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="feedops_backup_${DATE}"

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "🔄 Starting FeedOps backup..."

# Create backup directory
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"

# Backup PostgreSQL database
echo "📦 Backing up PostgreSQL database..."
docker-compose exec -T postgres pg_dump \
    -U "${POSTGRES_USER:-n8n}" \
    -d "${POSTGRES_DB:-n8n}" \
    --clean --if-exists \
    > "${BACKUP_DIR}/${BACKUP_NAME}/database.sql"

# Backup n8n workflows (via API)
echo "📦 Backing up n8n workflows..."
if docker-compose exec -T n8n n8n export:workflow --all --output=/tmp/workflows.json 2>/dev/null; then
    docker cp feedops-n8n:/tmp/workflows.json "${BACKUP_DIR}/${BACKUP_NAME}/workflows.json"
    echo "✅ Workflows backed up"
else
    echo "⚠️  Could not backup workflows via n8n CLI, trying alternative method..."
    # Alternative: copy from volume
    docker run --rm \
        -v feedops_n8n_data:/data:ro \
        -v "$(pwd)/${BACKUP_DIR}/${BACKUP_NAME}":/backup \
        alpine \
        sh -c "cp -r /data/*.json /backup/ 2>/dev/null || echo 'No workflow files found'"
fi

# Backup n8n credentials (encrypted)
echo "📦 Backing up n8n data volume..."
docker run --rm \
    -v feedops_n8n_data:/data:ro \
    -v "$(pwd)/${BACKUP_DIR}/${BACKUP_NAME}":/backup \
    alpine \
    tar czf /backup/n8n_data.tar.gz -C /data .

# Backup environment configuration (excluding sensitive values)
echo "📦 Backing up configuration..."
if [ -f .env ]; then
    # Create sanitized backup (remove actual passwords/tokens)
    sed 's/=.*/=REDACTED/' .env > "${BACKUP_DIR}/${BACKUP_NAME}/env.template"
fi

# Copy workflow templates
if [ -d workflows ]; then
    cp -r workflows "${BACKUP_DIR}/${BACKUP_NAME}/"
fi

# Create archive
echo "🗜️  Creating compressed archive..."
cd "${BACKUP_DIR}"
tar czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
rm -rf "${BACKUP_NAME}"
cd ..

# Calculate size
BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)

echo ""
echo "✅ Backup completed successfully!"
echo "📁 Backup location: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "💾 Backup size: ${BACKUP_SIZE}"
echo ""
echo "To restore this backup, run:"
echo "./scripts/restore.sh ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
