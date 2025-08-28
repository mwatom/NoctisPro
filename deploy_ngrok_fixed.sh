#!/bin/bash

# NoctisPro ngrok Deployment Script - FIXED ADMIN LOGIN
# Optimized for ngrok tunnel deployment with proper admin user creation

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
echo "🌐 NoctisPro ngrok Deployment - FIXED"
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

# Set up environment variables for ngrok
log_info "Setting up environment for ngrok deployment..."
export DJANGO_SETTINGS_MODULE=noctis_pro.settings
export DEBUG=False
export SECRET_KEY="noctis-pro-ngrok-secret-key-change-in-production"
export ALLOWED_HOSTS="*"  # Allow all hosts for ngrok
export USE_TZ=True

# Run migrations
log_info "Running database migrations..."
python manage.py migrate --noinput

# Collect static files
log_info "Collecting static files..."
python manage.py collectstatic --noinput

# Create proper admin user with role='admin' - FIXED VERSION
log_info "Creating admin user with proper role (FIXED)..."
python manage.py shell << 'PYTHON_EOF'
from accounts.models import User, Facility
import os

# Delete any existing admin users that might have wrong roles
existing_admins = User.objects.filter(username='admin')
if existing_admins.exists():
    existing_admins.delete()
    print('Removed existing admin user(s) with potential role issues')

# Create new admin user with correct role='admin'
admin_user = User.objects.create_user(
    username='admin',
    email='admin@noctispro.local',
    password='admin123',
    role='admin',  # This is the key fix!
    is_staff=True,
    is_superuser=True,
    is_active=True
)
print('✅ Created new admin user with PROPER role=admin')

# Create a default facility if none exists
if not Facility.objects.exists():
    facility = Facility.objects.create(
        name='NoctisPro Medical Center',
        address='123 Medical Center Drive',
        phone='(555) 123-4567',
        email='admin@noctispro.local',
        license_number='NOCTIS-001',
        ae_title='NOCTISPRO'
    )
    print('✅ Created default facility')

# Verify the admin user is properly configured
admin_check = User.objects.get(username='admin')
print(f'✅ Admin verification:')
print(f'   Username: {admin_check.username}')
print(f'   Role: {admin_check.role}')
print(f'   Is Admin: {admin_check.is_admin()}')
print(f'   Is Staff: {admin_check.is_staff}')
print(f'   Is Superuser: {admin_check.is_superuser}')
print(f'   Is Active: {admin_check.is_active}')
PYTHON_EOF

log_success "Admin user created and verified!"
echo
echo "=============================================="
echo "🚀 Starting NoctisPro Server..."
echo "=============================================="
echo

# Start the server in background
log_info "Starting Django development server on 0.0.0.0:8000..."
python manage.py runserver 0.0.0.0:8000 &
SERVER_PID=$!

# Wait a moment for server to start
sleep 3

log_success "NoctisPro server is running!"
echo
echo "=============================================="
echo "🌐 ngrok Setup Instructions"
echo "=============================================="
echo
echo "1. In a NEW terminal window, start ngrok:"
echo "   ngrok http 8000"
echo
echo "2. Copy the ngrok URL (e.g., https://abc123.ngrok.io)"
echo
echo "3. Access your application at the ngrok URL:"
echo "   • Main App: https://your-ngrok-url.ngrok.io"
echo "   • Admin Panel: https://your-ngrok-url.ngrok.io/admin-panel/"
echo "   • DICOM Viewer: https://your-ngrok-url.ngrok.io/dicom-viewer/"
echo "   • Worklist: https://your-ngrok-url.ngrok.io/worklist/"
echo
echo "=============================================="
echo "🔐 Login Credentials (FIXED)"
echo "=============================================="
echo "• Username: admin"
echo "• Password: admin123"
echo "• Role: Administrator ✅"
echo
echo "⚠️  The admin login issue has been FIXED!"
echo "   The user now has role='admin' which gives proper permissions."
echo
echo "=============================================="
echo "🛠️ Management Commands"
echo "=============================================="
echo
echo "To stop the server:"
echo "  kill $SERVER_PID"
echo
echo "To restart with fresh admin user:"
echo "  python manage.py fix_admin_user"
echo
echo "To view server logs:"
echo "  Check this terminal for Django output"
echo
echo "=============================================="
echo "🔒 Security Notes"
echo "=============================================="
echo "1. Change admin password immediately in production"
echo "2. The ALLOWED_HOSTS is set to '*' for ngrok compatibility"
echo "3. DEBUG is set to False for better security"
echo "4. Use HTTPS URLs from ngrok for secure access"
echo
echo "Press Ctrl+C to stop the server..."

# Keep the script running and show server output
wait $SERVER_PID