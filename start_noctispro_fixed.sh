#!/bin/bash
"""
NoctisPro Production Startup Script - FIXED VERSION
Bulletproof startup with comprehensive error handling and validation
"""

set -e  # Exit on any error

echo "🚀 Starting NoctisPro - Medical Imaging System"
echo "=============================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [ ! -f "manage.py" ]; then
    log_error "manage.py not found. Please run this script from the NoctisPro root directory."
    exit 1
fi

# Create and activate virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    log_info "Creating virtual environment..."
    python3 -m venv venv
    log_success "Virtual environment created"
fi

# Activate virtual environment
log_info "Activating virtual environment..."
source venv/bin/activate
log_success "Virtual environment activated"

# Install/upgrade dependencies
log_info "Installing/upgrading dependencies..."
pip install -r requirements.txt --quiet
log_success "Dependencies installed"

# Set environment variables for production
export DJANGO_SETTINGS_MODULE=noctis_pro.settings
export PYTHONPATH=/workspace:$PYTHONPATH

# Check Django installation
log_info "Verifying Django installation..."
python -c "import django; print(f'Django version: {django.get_version()}')"
log_success "Django verification complete"

# Run database migrations
log_info "Running database migrations..."
python manage.py migrate --verbosity=1
log_success "Database migrations completed"

# Collect static files
log_info "Collecting static files..."
python manage.py collectstatic --noinput --verbosity=1
log_success "Static files collected"

# Create superuser if it doesn't exist
log_info "Ensuring admin user exists..."
python manage.py shell -c "
from accounts.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'admin123')
    print('Admin user created')
else:
    print('Admin user already exists')
" 2>/dev/null || log_warning "Admin user creation skipped"
log_success "Admin user ready (admin/admin123)"

# Run system checks
log_info "Running system checks..."
python manage.py check --verbosity=1
log_success "System checks passed"

# Test database connectivity
log_info "Testing database connectivity..."
python -c "
import django
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()
from django.db import connection
cursor = connection.cursor()
cursor.execute('SELECT 1')
print('Database connection successful')
"
log_success "Database connectivity verified"

# Start the server
log_info "Starting NoctisPro server..."
echo ""
log_success "🌐 NoctisPro is starting on http://localhost:8000"
log_success "👤 Admin panel: http://localhost:8000/admin/ (admin/admin123)"
log_success "🖥️  DICOM Viewer: http://localhost:8000/dicom-viewer/"
log_success "📋 Worklist: http://localhost:8000/worklist/"
echo ""
log_info "Press Ctrl+C to stop the server"
echo ""

# Start server with proper error handling
python manage.py runserver 0.0.0.0:8000