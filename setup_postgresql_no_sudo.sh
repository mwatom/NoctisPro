#!/bin/bash

# NoctisPro PostgreSQL-Only Setup Script (No Sudo Required)
# This script sets up PostgreSQL configuration without requiring sudo access

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

print_status "🐘 Setting up PostgreSQL-only configuration for NoctisPro (No Sudo)..."

# Check if PostgreSQL is running
if ! pg_isready -h localhost -p 5432 2>/dev/null; then
    print_error "PostgreSQL is not running or not accessible on localhost:5432"
    print_status "Please ensure PostgreSQL is running and accessible."
    print_status "If you have access, try: sudo systemctl start postgresql"
    echo ""
    print_status "Alternative: Use a cloud PostgreSQL service like:"
    print_status "- Railway.app (free tier)"
    print_status "- Supabase (free tier)"
    print_status "- AWS RDS (paid)"
    print_status "- DigitalOcean Managed Database (paid)"
    exit 1
else
    print_success "PostgreSQL is accessible on localhost:5432"
fi

# Generate secure password if not provided
if [ -z "$POSTGRES_PASSWORD" ]; then
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    print_warning "Generated PostgreSQL password: $POSTGRES_PASSWORD"
fi

# Try to connect to PostgreSQL with common usernames
print_status "Attempting to connect to PostgreSQL..."

POSTGRES_USER_FOUND=""
for user in postgres noctispro $USER; do
    if psql -h localhost -U $user -d postgres -c "\q" 2>/dev/null; then
        POSTGRES_USER_FOUND=$user
        print_success "Connected to PostgreSQL as user: $user"
        break
    fi
done

if [ -z "$POSTGRES_USER_FOUND" ]; then
    print_error "Cannot connect to PostgreSQL with any common usernames"
    print_status "Please provide PostgreSQL connection details:"
    read -p "PostgreSQL host [localhost]: " POSTGRES_HOST
    POSTGRES_HOST=${POSTGRES_HOST:-localhost}
    read -p "PostgreSQL port [5432]: " POSTGRES_PORT
    POSTGRES_PORT=${POSTGRES_PORT:-5432}
    read -p "PostgreSQL username: " POSTGRES_USER
    read -s -p "PostgreSQL password: " POSTGRES_PASSWORD
    echo ""
    
    # Test connection with provided credentials
    if ! PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d postgres -c "\q" 2>/dev/null; then
        print_error "Cannot connect to PostgreSQL with provided credentials"
        exit 1
    fi
    print_success "Connected to PostgreSQL successfully"
else
    # Use the found user
    POSTGRES_USER="noctis_user"
    POSTGRES_HOST="localhost"
    POSTGRES_PORT="5432"
    
    # Try to create database and user (if we have permissions)
    print_status "Setting up database and user..."
    
    # Create user and database if possible
    psql -h localhost -U $POSTGRES_USER_FOUND -d postgres << EOF 2>/dev/null || print_warning "Could not create user/database (may already exist or insufficient permissions)"
DROP DATABASE IF EXISTS noctis_pro;
DROP USER IF EXISTS $POSTGRES_USER;
CREATE USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';
CREATE DATABASE noctis_pro OWNER $POSTGRES_USER;
GRANT ALL PRIVILEGES ON DATABASE noctis_pro TO $POSTGRES_USER;
ALTER USER $POSTGRES_USER CREATEDB;
EOF

    # Test if we can connect with the new user
    if PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d noctis_pro -c "\q" 2>/dev/null; then
        print_success "Database 'noctis_pro' is accessible with user '$POSTGRES_USER'"
    else
        print_warning "Using existing PostgreSQL user: $POSTGRES_USER_FOUND"
        POSTGRES_USER=$POSTGRES_USER_FOUND
        POSTGRES_PASSWORD=""  # No password needed for peer authentication
    fi
fi

# Create/update environment file
print_status "Creating PostgreSQL-only environment configuration..."
cat > .env.production << EOF
# PostgreSQL Database Configuration
POSTGRES_DB=noctis_pro
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST=$POSTGRES_HOST
POSTGRES_PORT=$POSTGRES_PORT

# Django Settings
DJANGO_SETTINGS_MODULE=noctis_pro.settings
SECRET_KEY=django-insecure-$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-50)
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

# Install Python dependencies if virtual environment exists
if [ -d "venv" ]; then
    print_status "Installing Python dependencies..."
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    print_success "Python dependencies installed"
else
    print_warning "Virtual environment not found. Creating one..."
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    print_success "Virtual environment created and dependencies installed"
fi

# Test database connection
print_status "Testing database connection..."
source venv/bin/activate
export $(cat .env.production | xargs)

python3 << EOF
import os
import django
from django.conf import settings

# Configure Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from django.db import connection
try:
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
    print("✅ Database connection successful!")
except Exception as e:
    print(f"❌ Database connection failed: {e}")
    exit(1)
EOF

# Run Django migrations
print_status "Running Django migrations..."
python manage.py migrate

# Remove any SQLite files
print_status "Cleaning up SQLite files..."
find . -name "*.sqlite3" -type f -delete 2>/dev/null || true
find . -name "db.sqlite3*" -type f -delete 2>/dev/null || true
print_success "SQLite cleanup completed"

print_success "🎉 PostgreSQL-only setup completed successfully!"
echo ""
print_status "Configuration Summary:"
print_status "Database: PostgreSQL ($POSTGRES_HOST:$POSTGRES_PORT)"
print_status "Database Name: noctis_pro"
print_status "User: $POSTGRES_USER"
echo ""
print_status "To start the application:"
echo "  source venv/bin/activate"
echo "  source .env.production"
echo "  python manage.py runserver"
echo ""
print_status "Environment file: .env.production"