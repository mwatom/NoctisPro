#!/bin/bash
# PostgreSQL Setup Script for NoctisPro PACS
# This script installs and configures PostgreSQL for production use

set -e

echo "🐘 Setting up PostgreSQL for NoctisPro PACS..."

# Update package list
sudo apt-get update

# Install PostgreSQL and required packages
echo "📦 Installing PostgreSQL..."
sudo apt-get install -y postgresql postgresql-contrib python3-psycopg2

# Start PostgreSQL service
echo "🚀 Starting PostgreSQL service..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Set default values if not in environment
DB_NAME=${DB_NAME:-noctis_pro}
DB_USER=${DB_USER:-noctis_user}
DB_PASSWORD=${DB_PASSWORD:-QGO5IebYph3b1V2InOhv4OBLytpWCvOXoGevBs8M-cY}

echo "🔧 Configuring PostgreSQL database..."

# Create database user and database
sudo -u postgres psql << EOF
-- Create user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '$DB_USER') THEN
        CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
    END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE $DB_NAME OWNER $DB_USER'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;

\q
EOF

echo "🔧 Applying PostgreSQL optimizations..."
# Apply the initialization script
sudo -u postgres psql -d $DB_NAME -f deployment/postgres/init.sql

echo "🔧 Configuring PostgreSQL for production..."

# Backup original configuration
sudo cp /etc/postgresql/*/main/postgresql.conf /etc/postgresql/*/main/postgresql.conf.backup || true

# Apply production configuration if available
if [ -f "deployment/postgres/postgresql.conf.production" ]; then
    sudo cp deployment/postgres/postgresql.conf.production /etc/postgresql/*/main/postgresql.conf
fi

if [ -f "deployment/postgres/pg_hba.conf.production" ]; then
    sudo cp deployment/postgres/pg_hba.conf.production /etc/postgresql/*/main/pg_hba.conf
fi

# Restart PostgreSQL to apply configuration
echo "🔄 Restarting PostgreSQL..."
sudo systemctl restart postgresql

# Test connection
echo "🧪 Testing PostgreSQL connection..."
PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME -c "SELECT version();" || {
    echo "❌ PostgreSQL connection test failed!"
    exit 1
}

echo "✅ PostgreSQL setup completed successfully!"
echo "📊 Database: $DB_NAME"
echo "👤 User: $DB_USER"
echo "🏠 Host: localhost:5432"
echo ""
echo "Next steps:"
echo "1. Run migrations: python manage.py migrate"
echo "2. Create superuser: python manage.py createsuperuser"
echo "3. Collect static files: python manage.py collectstatic"