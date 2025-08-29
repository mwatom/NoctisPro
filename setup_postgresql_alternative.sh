#!/bin/bash

# NoctisPro PostgreSQL Alternative Setup Script
# This script provides alternatives when sudo access is not available

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

print_status "🐘 NoctisPro PostgreSQL Alternative Setup..."

# Check if PostgreSQL is installed
if ! command -v psql &> /dev/null; then
    print_warning "PostgreSQL is not installed and cannot be installed without sudo access."
    print_status "📋 PostgreSQL Installation Instructions:"
    echo ""
    echo "To install PostgreSQL with proper permissions, please run:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y postgresql postgresql-contrib python3-dev libpq-dev"
    echo "  sudo systemctl start postgresql"
    echo "  sudo systemctl enable postgresql"
    echo ""
    print_status "After installing PostgreSQL, you can run the original script:"
    echo "  ./setup_postgresql_only.sh"
    echo ""
    
    # Check if we can continue with development setup
    print_status "🔄 Checking alternative options..."
    
    # Check if SQLite can be used for development
    if python3 -c "import sqlite3" 2>/dev/null; then
        print_warning "For development purposes, you could modify the Django settings to use SQLite."
        print_status "However, the current NoctisPro configuration is hardcoded for PostgreSQL."
        
        # Offer to create a development settings override
        print_status "Creating development environment setup..."
        
        # Create development environment file
        cat > .env.development.local << EOF
# Development Environment (SQLite fallback)
# This is for development only - PostgreSQL is required for production

# Database Configuration (Development SQLite)
USE_SQLITE=true
DATABASE_URL=sqlite:///$(pwd)/db.sqlite3

# Django Settings
DJANGO_DEBUG=true
DJANGO_SETTINGS_MODULE=noctis_pro.settings_development
SECRET_KEY=django-dev-$(openssl rand -base64 32 | tr -d '=' | head -c 32)

# Allowed Hosts
ALLOWED_HOSTS=localhost,127.0.0.1,*.ngrok.io

# Development Settings
DJANGO_ENV=development
USE_DUMMY_CACHE=true
EOF

        print_success "Development environment created: .env.development.local"
        
        # Create development settings file
        if [ ! -f "noctis_pro/settings_development.py" ]; then
            cat > noctis_pro/settings_development.py << 'EOF'
# Development settings for NoctisPro
# This file provides SQLite fallback for development when PostgreSQL is not available

import os
from .settings import *

# Override database settings for development
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# Development-specific settings
DEBUG = True
ALLOWED_HOSTS = ['localhost', '127.0.0.1', '*']

# Use dummy cache for development
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.dummy.DummyCache',
    }
}

# Use database sessions instead of Redis
SESSION_ENGINE = 'django.contrib.sessions.backends.db'

# Disable some production security features for development
SECURE_SSL_REDIRECT = False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False

print("🔧 Using development settings with SQLite database")
EOF
            print_success "Development settings file created: noctis_pro/settings_development.py"
        fi
        
    else
        print_error "SQLite is not available either. Python development environment may be incomplete."
    fi
    
else
    print_success "PostgreSQL is already installed"
    # Check if PostgreSQL is running
    if systemctl is-active --quiet postgresql 2>/dev/null; then
        print_success "PostgreSQL service is running"
    else
        print_warning "PostgreSQL service is not running. Attempting to start..."
        if sudo systemctl start postgresql 2>/dev/null; then
            print_success "PostgreSQL service started"
        else
            print_error "Failed to start PostgreSQL service. Please run: sudo systemctl start postgresql"
            exit 1
        fi
    fi
    
    print_status "Continuing with PostgreSQL setup..."
    # Run the original PostgreSQL setup
    exec ./setup_postgresql_only.sh
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    print_status "Creating Python virtual environment..."
    python3 -m venv venv
    print_success "Virtual environment created"
fi

# Install Python dependencies
print_status "Installing Python dependencies..."
source venv/bin/activate
pip install --upgrade pip

# Install minimal requirements for development if PostgreSQL is not available
if ! command -v psql &> /dev/null; then
    print_status "Installing minimal dependencies (without PostgreSQL support)..."
    # Create a minimal requirements file without psycopg2
    cat > requirements.minimal.txt << EOF
Django
Pillow
django-widget-tweaks
python-dotenv
gunicorn
whitenoise
djangorestframework
django-cors-headers
channels
daphne
pydicom
numpy
requests
django-extensions
django-health-check
EOF
    pip install -r requirements.minimal.txt
    print_warning "Installed minimal dependencies. PostgreSQL-specific packages skipped."
else
    pip install -r requirements.txt
    print_success "All dependencies installed"
fi

# Run migrations if we have a working database setup
if [ -f ".env.development.local" ]; then
    print_status "Running development migrations with SQLite..."
    source .env.development.local
    export DJANGO_SETTINGS_MODULE=noctis_pro.settings_development
    python manage.py migrate
    print_success "Development database migrations completed"
    
    print_status "🎉 Development setup completed!"
    print_warning "This is a DEVELOPMENT setup using SQLite."
    print_warning "For production, PostgreSQL is required."
    echo ""
    print_status "To start the development server:"
    echo "  source venv/bin/activate"
    echo "  source .env.development.local"
    echo "  export DJANGO_SETTINGS_MODULE=noctis_pro.settings_development"
    echo "  python manage.py runserver"
    echo ""
    print_status "To set up PostgreSQL for production:"
    echo "  1. Install PostgreSQL with sudo access"
    echo "  2. Run: ./setup_postgresql_only.sh"
    
elif command -v psql &> /dev/null && systemctl is-active --quiet postgresql 2>/dev/null; then
    print_status "PostgreSQL is available, running production setup..."
    # The script will continue with the original PostgreSQL setup
else
    print_error "Unable to set up database. Please install PostgreSQL or use development mode."
    exit 1
fi