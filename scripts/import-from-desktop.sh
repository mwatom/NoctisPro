#!/bin/bash

# NOCTIS Pro - Import Data from Desktop Export
# This script imports data exported from desktop development environment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMPORT_SOURCE=""
NOCTIS_DIR="/opt/noctis"
COMPOSE_FILE="$NOCTIS_DIR/docker-compose.production.yml"

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Usage information
usage() {
    echo "Usage: $0 <export_directory_or_archive>"
    echo ""
    echo "Examples:"
    echo "  $0 /tmp/noctis-export-20240101_120000"
    echo "  $0 /tmp/noctis-export-20240101_120000.tar.gz"
    echo ""
    echo "This script must be run on the target server where NOCTIS Pro will be deployed."
    exit 1
}

# Check if running with appropriate privileges
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root. This is acceptable for server setup."
    else
        log "Running as regular user. Will use sudo when needed."
    fi
}

# Validate input parameters
validate_input() {
    if [ -z "$1" ]; then
        error "No import source specified"
        usage
    fi
    
    IMPORT_SOURCE="$1"
    
    if [ ! -e "$IMPORT_SOURCE" ]; then
        error "Import source not found: $IMPORT_SOURCE"
        exit 1
    fi
}

# Extract archive if needed
extract_archive() {
    if [[ "$IMPORT_SOURCE" == *.tar.gz ]]; then
        log "Extracting archive: $IMPORT_SOURCE"
        
        EXTRACT_DIR="/tmp/noctis-import-$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$EXTRACT_DIR"
        
        # Verify checksums if available
        if [ -f "${IMPORT_SOURCE}.sha256" ]; then
            log "Verifying SHA256 checksum..."
            if sha256sum -c "${IMPORT_SOURCE}.sha256"; then
                log "SHA256 checksum verified"
            else
                error "SHA256 checksum verification failed"
                exit 1
            fi
        fi
        
        # Extract archive
        tar -xzf "$IMPORT_SOURCE" -C "$EXTRACT_DIR" --strip-components=1
        IMPORT_SOURCE="$EXTRACT_DIR"
        
        log "Archive extracted to: $IMPORT_SOURCE"
    fi
}

# Validate export structure
validate_export() {
    log "Validating export structure..."
    
    required_dirs=("database" "media" "dicom_storage" "config")
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$IMPORT_SOURCE/$dir" ]; then
            error "Required directory not found in export: $dir"
            exit 1
        fi
    done
    
    # Check for required files
    if [ ! -f "$IMPORT_SOURCE/database/database.sql" ]; then
        error "Database dump not found: $IMPORT_SOURCE/database/database.sql"
        exit 1
    fi
    
    if [ ! -f "$IMPORT_SOURCE/system_info.txt" ]; then
        warn "System info file not found. This might be an older export."
    fi
    
    log "Export structure validated"
}

# Setup target directories
setup_directories() {
    log "Setting up target directories..."
    
    # Create NOCTIS directory structure if it doesn't exist
    sudo mkdir -p "$NOCTIS_DIR"/{data,logs,backups,ssl}
    sudo mkdir -p "$NOCTIS_DIR"/data/{postgres,redis,media,staticfiles,dicom_storage}
    
    # Set proper ownership
    sudo chown -R $USER:$USER "$NOCTIS_DIR"
    
    log "Target directories ready"
}

# Copy configuration files
import_configuration() {
    log "Importing configuration files..."
    
    # Copy Docker compose files
    if [ -f "$IMPORT_SOURCE/config/docker-compose.production.yml" ]; then
        cp "$IMPORT_SOURCE/config/docker-compose.production.yml" "$NOCTIS_DIR/"
        log "Production compose file imported"
    fi
    
    if [ -f "$IMPORT_SOURCE/config/docker-compose.yml" ]; then
        cp "$IMPORT_SOURCE/config/docker-compose.yml" "$NOCTIS_DIR/"
        log "Base compose file imported"
    fi
    
    # Copy environment templates
    if [ -f "$IMPORT_SOURCE/config/.env.server.example" ]; then
        cp "$IMPORT_SOURCE/config/.env.server.example" "$NOCTIS_DIR/"
        log "Server environment template imported"
    fi
    
    # Copy scripts
    if [ -d "$IMPORT_SOURCE/config/scripts" ]; then
        cp -r "$IMPORT_SOURCE/config/scripts" "$NOCTIS_DIR/"
        chmod +x "$NOCTIS_DIR"/scripts/*.sh
        log "Scripts imported"
    fi
    
    # Copy deployment configurations
    if [ -d "$IMPORT_SOURCE/config/deployment" ]; then
        cp -r "$IMPORT_SOURCE/config/deployment" "$NOCTIS_DIR/"
        log "Deployment configurations imported"
    fi
    
    # Copy requirements and other app files
    [ -f "$IMPORT_SOURCE/config/requirements.txt" ] && cp "$IMPORT_SOURCE/config/requirements.txt" "$NOCTIS_DIR/"
    [ -f "$IMPORT_SOURCE/config/manage.py" ] && cp "$IMPORT_SOURCE/config/manage.py" "$NOCTIS_DIR/"
    
    log "Configuration files imported"
}

# Import media files
import_media() {
    log "Importing media files..."
    
    if [ "$(ls -A $IMPORT_SOURCE/media 2>/dev/null)" ]; then
        cp -r "$IMPORT_SOURCE/media"/* "$NOCTIS_DIR/data/media/"
        media_size=$(du -sh "$NOCTIS_DIR/data/media" | cut -f1)
        log "Media files imported: $media_size"
    else
        log "No media files to import"
    fi
}

# Import DICOM storage
import_dicom() {
    log "Importing DICOM storage..."
    
    if [ "$(ls -A $IMPORT_SOURCE/dicom_storage 2>/dev/null)" ]; then
        cp -r "$IMPORT_SOURCE/dicom_storage"/* "$NOCTIS_DIR/data/dicom_storage/"
        dicom_size=$(du -sh "$NOCTIS_DIR/data/dicom_storage" | cut -f1)
        log "DICOM storage imported: $dicom_size"
    else
        log "No DICOM files to import"
    fi
}

# Start database service for import
start_database() {
    log "Starting database service for import..."
    
    # Check if compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        error "Production compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    # Start only database and redis services
    cd "$NOCTIS_DIR"
    docker compose -f docker-compose.production.yml up -d db redis
    
    # Wait for database to be ready
    log "Waiting for database to be ready..."
    sleep 10
    
    # Check if database is healthy
    for i in {1..30}; do
        if docker compose -f docker-compose.production.yml exec db pg_isready -U noctis_user -d noctis_pro >/dev/null 2>&1; then
            log "Database is ready"
            break
        fi
        if [ $i -eq 30 ]; then
            error "Database failed to start within 5 minutes"
            exit 1
        fi
        sleep 10
    done
}

# Import database
import_database() {
    log "Importing database..."
    
    cd "$NOCTIS_DIR"
    
    # Choose the best available database file
    if [ -f "$IMPORT_SOURCE/database/database.sql.gz" ]; then
        log "Using compressed database dump"
        gunzip -c "$IMPORT_SOURCE/database/database.sql.gz" | docker compose -f docker-compose.production.yml exec -T db psql -U noctis_user -d noctis_pro
    elif [ -f "$IMPORT_SOURCE/database/database.sql" ]; then
        log "Using uncompressed database dump"
        docker compose -f docker-compose.production.yml exec -T db psql -U noctis_user -d noctis_pro < "$IMPORT_SOURCE/database/database.sql"
    else
        error "No database dump found"
        exit 1
    fi
    
    log "Database imported successfully"
}

# Verify database import
verify_database() {
    log "Verifying database import..."
    
    cd "$NOCTIS_DIR"
    
    # Check if we can connect and get basic info
    table_count=$(docker compose -f docker-compose.production.yml exec -T db psql -U noctis_user -d noctis_pro -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" -t | tr -d ' ')
    
    if [ "$table_count" -gt 0 ]; then
        log "Database verification successful: $table_count tables found"
    else
        error "Database verification failed: no tables found"
        exit 1
    fi
}

# Set proper permissions
set_permissions() {
    log "Setting proper file permissions..."
    
    # Set ownership
    sudo chown -R $USER:$USER "$NOCTIS_DIR"
    
    # Set directory permissions
    find "$NOCTIS_DIR" -type d -exec chmod 755 {} \;
    
    # Set file permissions
    find "$NOCTIS_DIR" -type f -exec chmod 644 {} \;
    
    # Make scripts executable
    if [ -d "$NOCTIS_DIR/scripts" ]; then
        chmod +x "$NOCTIS_DIR"/scripts/*.sh
    fi
    
    log "Permissions set correctly"
}

# Create import summary
create_import_summary() {
    log "Creating import summary..."
    
    cat > "$NOCTIS_DIR/import_summary.txt" <<EOF
NOCTIS Pro Import Summary
========================

Import Date: $(date)
Import Source: $IMPORT_SOURCE
Target Directory: $NOCTIS_DIR

Imported Components:
- Configuration files: Yes
- Database: Yes ($(docker compose -f docker-compose.production.yml exec -T db psql -U noctis_user -d noctis_pro -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" -t | tr -d ' ') tables)
- Media files: $(du -sh "$NOCTIS_DIR/data/media" 2>/dev/null | cut -f1 || echo 'None')
- DICOM storage: $(du -sh "$NOCTIS_DIR/data/dicom_storage" 2>/dev/null | cut -f1 || echo 'None')

Total imported data size: $(du -sh "$NOCTIS_DIR/data" | cut -f1)

Next Steps:
1. Configure .env file for production
2. Start all services: docker compose -f docker-compose.production.yml up -d
3. Configure SSL certificates: sudo certbot --nginx
4. Test the application
5. Set up monitoring and backups

Services Status:
$(docker compose -f docker-compose.production.yml ps)
EOF

    log "Import summary created: $NOCTIS_DIR/import_summary.txt"
}

# Cleanup temporary files
cleanup() {
    if [[ "$IMPORT_SOURCE" == /tmp/noctis-import-* ]]; then
        log "Cleaning up temporary extraction directory..."
        rm -rf "$IMPORT_SOURCE"
    fi
}

# Main import function
main() {
    log "Starting NOCTIS Pro data import from desktop export..."
    
    validate_input "$1"
    check_privileges
    extract_archive
    validate_export
    setup_directories
    import_configuration
    import_media
    import_dicom
    start_database
    import_database
    verify_database
    set_permissions
    create_import_summary
    cleanup
    
    log ""
    log "Import completed successfully!"
    log ""
    log "Next steps:"
    log "1. Configure your production environment:"
    log "   cd $NOCTIS_DIR"
    log "   cp .env.server.example .env"
    log "   nano .env  # Edit with your settings"
    log ""
    log "2. Start all production services:"
    log "   docker compose -f docker-compose.production.yml up -d"
    log ""
    log "3. Configure SSL certificates:"
    log "   sudo certbot --nginx"
    log ""
    log "4. Check the import summary:"
    log "   cat $NOCTIS_DIR/import_summary.txt"
    log ""
    log "5. Verify the application is working:"
    log "   docker compose -f docker-compose.production.yml ps"
    log "   docker compose -f docker-compose.production.yml logs -f"
    log ""
    warn "Remember to:"
    warn "- Change all default passwords in .env"
    warn "- Configure your domain name and SSL"
    warn "- Set up automated backups"
    warn "- Configure monitoring and alerting"
}

# Handle script interruption
trap 'error "Import interrupted"; cleanup; exit 1' INT TERM

# Check if help is requested
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

# Run main function
main "$@"