#!/bin/bash

# 🔄 NoctisPro - Desktop to Server Migration
# This script helps you migrate your data from desktop to server deployment

set -e

echo "🔄 NoctisPro Desktop to Server Migration"
echo "========================================"

# Check if running from the right directory
if [[ ! -f "docker-compose.simple.yml" ]]; then
    echo "❌ Please run this script from your NoctisPro directory"
    exit 1
fi

# Function to export data
export_data() {
    echo "📦 Exporting data from desktop deployment..."
    
    # Create export directory
    mkdir -p migration_export
    
    # Export database
    echo "📊 Exporting database..."
    docker compose -f docker-compose.simple.yml exec -T db pg_dump -U noctis_user noctis_pro > migration_export/database.sql
    
    # Export media files
    echo "📁 Exporting media files..."
    docker run --rm -v $(pwd)/migration_export:/backup -v noctis-pro_media_files:/data alpine tar czf /backup/media_files.tar.gz -C /data .
    
    # Export static files
    echo "🎨 Exporting static files..."
    docker run --rm -v $(pwd)/migration_export:/backup -v noctis-pro_static_files:/data alpine tar czf /backup/static_files.tar.gz -C /data .
    
    # Export DICOM storage
    echo "🏥 Exporting DICOM storage..."
    docker run --rm -v $(pwd)/migration_export:/backup -v noctis-pro_dicom_storage:/data alpine tar czf /backup/dicom_storage.tar.gz -C /data .
    
    echo "✅ Export complete! Files are in migration_export/"
}

# Function to import data
import_data() {
    echo "📥 Importing data to server deployment..."
    
    if [[ ! -d "migration_export" ]]; then
        echo "❌ No migration_export directory found. Please run export first."
        exit 1
    fi
    
    # Wait for database to be ready
    echo "⏳ Waiting for database..."
    while ! docker compose -f docker-compose.server.yml exec db pg_isready -U noctis_user -d noctis_pro >/dev/null 2>&1; do
        sleep 2
    done
    
    # Import database
    echo "📊 Importing database..."
    docker compose -f docker-compose.server.yml exec -T db psql -U noctis_user -d noctis_pro < migration_export/database.sql
    
    # Import media files
    echo "📁 Importing media files..."
    docker run --rm -v $(pwd)/migration_export:/backup -v noctis-pro_media_files:/data alpine sh -c "cd /data && tar xzf /backup/media_files.tar.gz"
    
    # Import static files
    echo "🎨 Importing static files..."
    docker run --rm -v $(pwd)/migration_export:/backup -v noctis-pro_static_files:/data alpine sh -c "cd /data && tar xzf /backup/static_files.tar.gz"
    
    # Import DICOM storage
    echo "🏥 Importing DICOM storage..."
    docker run --rm -v $(pwd)/migration_export:/backup -v noctis-pro_dicom_storage:/data alpine sh -c "cd /data && tar xzf /backup/dicom_storage.tar.gz"
    
    # Restart services to pick up changes
    echo "🔄 Restarting services..."
    docker compose -f docker-compose.server.yml restart
    
    echo "✅ Import complete!"
}

# Menu
echo "What would you like to do?"
echo "1) Export data from desktop (run on desktop)"
echo "2) Import data to server (run on server)"
echo "3) Full migration (export then copy files to server)"
read -p "Choose option (1-3): " choice

case $choice in
    1)
        export_data
        echo ""
        echo "📋 Next steps:"
        echo "1. Copy the migration_export folder to your server"
        echo "2. Run this script on the server with option 2"
        ;;
    2)
        import_data
        echo ""
        echo "🎉 Migration complete!"
        echo "Your data has been imported to the server deployment."
        ;;
    3)
        export_data
        echo ""
        echo "📋 Data exported! Now copy to your server:"
        echo ""
        echo "On your current machine:"
        echo "  tar czf noctis-migration.tar.gz migration_export"
        echo "  scp noctis-migration.tar.gz user@your-server:/path/to/noctis-pro/"
        echo ""
        echo "On your server:"
        echo "  cd /path/to/noctis-pro"
        echo "  tar xzf noctis-migration.tar.gz"
        echo "  ./migrate-to-server.sh"
        echo "  Choose option 2"
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

echo ""
echo "🔄 Migration process complete!"
echo ""