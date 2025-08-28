#!/bin/bash

# NoctisPro Simple Fixed Deployment Script (No Docker)
# Fixes admin login issues by properly creating admin users with role='admin'

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "=============================================="
echo "🏥 NoctisPro Simple Fixed Deployment"
echo "=============================================="
echo

# Check if we're in the right directory
if [ ! -f "manage.py" ]; then
    log_error "manage.py not found. Please run this script from the NoctisPro root directory."
    exit 1
fi

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    log_info "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
log_info "Activating virtual environment..."
source venv/bin/activate

# Install dependencies
log_info "Installing dependencies..."
pip install -r requirements.txt

# Set up environment variables
log_info "Setting up environment..."
export DJANGO_SETTINGS_MODULE=noctis_pro.settings
export DEBUG=True
export SECRET_KEY="noctis-pro-dev-secret-key-change-in-production"
export ALLOWED_HOSTS="localhost,127.0.0.1,0.0.0.0,*"

# Run migrations
log_info "Running database migrations..."
python manage.py migrate --noinput

# Collect static files
log_info "Collecting static files..."
python manage.py collectstatic --noinput

# Create proper admin user with role='admin'
log_info "Creating admin user with proper role..."
python manage.py shell << 'PYTHON_EOF'
from accounts.models import User, Facility
import os

# Check if admin user exists
if User.objects.filter(username='admin').exists():
    admin_user = User.objects.get(username='admin')
    # Update existing user to have admin role
    admin_user.role = 'admin'
    admin_user.is_staff = True
    admin_user.is_superuser = True
    admin_user.is_active = True
    admin_user.save()
    print('Updated existing admin user with proper role')
else:
    # Create new admin user with proper role
    admin_user = User.objects.create_user(
        username='admin',
        email='admin@noctispro.local',
        password='admin123',
        role='admin',
        is_staff=True,
        is_superuser=True,
        is_active=True
    )
    print('Created new admin user with proper role')

# Create a default facility if none exists
if not Facility.objects.exists():
    facility = Facility.objects.create(
        name='Default Medical Center',
        address='123 Medical Center Drive',
        phone='(555) 123-4567',
        email='info@medicalcenter.com',
        license_number='MED-001',
        ae_title='NOCTISPRO'
    )
    print('Created default facility')

print('Admin setup complete!')
print('Username: admin')
print('Password: admin123')
print('Role: Administrator')
PYTHON_EOF

log_success "Deployment successful!"
echo
echo "=============================================="
echo "🎉 NoctisPro is ready to start!"
echo "=============================================="
echo
echo "To start the server, run:"
echo "source venv/bin/activate"
echo "python manage.py runserver 0.0.0.0:8000"
echo
echo "Then access your application at:"
echo "• Main Application: http://localhost:8000"
echo "• Admin Panel: http://localhost:8000/admin-panel/"
echo "• DICOM Viewer: http://localhost:8000/dicom-viewer/"
echo "• Worklist: http://localhost:8000/worklist/"
echo
echo "Login credentials:"
echo "• Username: admin"
echo "• Password: admin123"
echo "• Role: Administrator"
echo
echo "⚠️  IMPORTANT SECURITY NOTES:"
echo "1. Change the admin password immediately in production"
echo "2. Configure your domain/IP in ALLOWED_HOSTS"
echo "3. Set up HTTPS for production use"
echo

# Optionally start the server automatically
read -p "Start the server now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Starting development server..."
    python manage.py runserver 0.0.0.0:8000
fi