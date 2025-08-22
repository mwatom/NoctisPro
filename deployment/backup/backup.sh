#!/bin/bash

# NoctisPro Production Backup Script
# Backs up database, media files, and configuration

set -e

BACKUP_DIR="/app/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="noctis_backup_${DATE}"

echo "Starting backup: $BACKUP_NAME"

# Create backup directory
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

# Database backup
echo "Backing up PostgreSQL database..."
pg_dump -h db -U ${POSTGRES_USER} -d ${POSTGRES_DB} > "$BACKUP_DIR/$BACKUP_NAME/database.sql"

# Media files backup
echo "Backing up media files..."
if [ -d "/app/media" ]; then
    tar -czf "$BACKUP_DIR/$BACKUP_NAME/media.tar.gz" -C /app media/
fi

# Configuration backup
echo "Backing up configuration..."
echo "Backup completed at: $(date)" > "$BACKUP_DIR/$BACKUP_NAME/backup_info.txt"
echo "Database: ${POSTGRES_DB}" >> "$BACKUP_DIR/$BACKUP_NAME/backup_info.txt"
echo "User: ${POSTGRES_USER}" >> "$BACKUP_DIR/$BACKUP_NAME/backup_info.txt"

# Create archive
echo "Creating backup archive..."
tar -czf "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" -C "$BACKUP_DIR" "$BACKUP_NAME"

# Clean up uncompressed backup
rm -rf "$BACKUP_DIR/$BACKUP_NAME"

# Clean old backups (keep last 7 days)
find "$BACKUP_DIR" -name "noctis_backup_*.tar.gz" -mtime +7 -delete

echo "Backup completed: ${BACKUP_NAME}.tar.gz"