#!/bin/bash

# NoctisPro PostgreSQL-Only Setup Script
# This script ensures PostgreSQL is the only database used in the system

set -e

print_status() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

print_status "🐘 Setting up PostgreSQL-only configuration for NoctisPro..."

# Install PostgreSQL if not already installed
if ! command -v psql &> /dev/null; then
    print_status "Installing PostgreSQL..."
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib python3-dev libpq-dev
else
    print_success "PostgreSQL is already installed"
fi

# Start PostgreSQL service
print_status "Starting PostgreSQL service..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
print_status "Setting up PostgreSQL database and user..."

# Generate secure password if not provided
if [ -z "$POSTGRES_PASSWORD" ]; then
    POSTGRES_PASSWORD=$(openssl rand -base64 32)
    print_warning "Generated PostgreSQL password: $POSTGRES_PASSWORD"
    echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> .env.production
fi

# Create database and user
sudo -u postgres psql -c "DROP DATABASE IF EXISTS noctis_pro;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS noctis_user;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE USER noctis_user WITH PASSWORD '$POSTGRES_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE noctis_pro OWNER noctis_user;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE noctis_pro TO noctis_user;"
sudo -u postgres psql -c "ALTER USER noctis_user CREATEDB;"

print_success "PostgreSQL database 'noctis_pro' created with user 'noctis_user'"

# Create/update environment file
print_status "Creating PostgreSQL-only environment configuration..."
cat > .env.production << EOF
# PostgreSQL Database Configuration
POSTGRES_DB=noctis_pro
POSTGRES_USER=noctis_user
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST=localhost
POSTGRES_PORT=5432

# Django Settings
DJANGO_SETTINGS_MODULE=noctis_pro.settings
SECRET_KEY=django-insecure-$(openssl rand -base64 32)
DEBUG=False
ALLOWED_HOSTS=*,localhost,127.0.0.1

# Application Settings
STATIC_ROOT=/workspace/staticfiles
MEDIA_ROOT=/workspace/media
SERVE_MEDIA_FILES=True
BUILD_TARGET=production
ENVIRONMENT=production
HEALTH_CHECK_ENABLED=True
TIME_ZONE=UTC
USE_TZ=True
DICOM_STORAGE_PATH=/workspace/media/dicom

# Security Settings
SECURE_SSL_REDIRECT=False
SESSION_COOKIE_SECURE=False
CSRF_COOKIE_SECURE=False
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https

# Performance Settings
CONN_MAX_AGE=600
DATABASE_CONNECTION_HEALTH_CHECKS=True
EOF

print_success "Environment file created with PostgreSQL-only configuration"

# Install Python dependencies
if [ -d "venv" ]; then
    print_status "Installing Python dependencies..."
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    print_success "Python dependencies installed"
else
    print_warning "Virtual environment not found. Please create one first."
fi

# Run Django migrations
if [ -d "venv" ]; then
    print_status "Running Django migrations..."
    source venv/bin/activate
    source .env.production
    python manage.py migrate
    print_success "Database migrations completed"
fi

# Remove any SQLite files
print_status "Cleaning up SQLite files..."
rm -f db.sqlite3 db.sqlite3.* *.sqlite3 2>/dev/null || true
print_success "SQLite cleanup completed"

print_success "🎉 PostgreSQL-only setup completed successfully!"
print_status "Database: PostgreSQL (noctis_pro)"
print_status "User: noctis_user"
print_status "Host: localhost:5432"
echo ""
print_status "To start the application:"
echo "  source venv/bin/activate"
echo "  source .env.production"
echo "  python manage.py runserver"