#!/bin/bash

# NoctisPro Fixed Deployment Script
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
echo "🏥 NoctisPro Fixed Deployment"
echo "=============================================="
echo

# Check if we're in the right directory
if [ ! -f "manage.py" ]; then
    log_error "manage.py not found. Please run this script from the NoctisPro root directory."
    exit 1
fi

# Configuration
PROJECT_NAME="noctis_pro"
COMPOSE_FILE="docker-compose.production.yml"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker compose &> /dev/null; then
    log_error "Docker Compose is not available. Please install Docker Compose first."
    exit 1
fi

log_info "Starting NoctisPro deployment with fixed admin login..."

# Step 1: Build and start containers
log_info "Building and starting containers..."
docker compose -f "$COMPOSE_FILE" up -d --build

# Wait for services to be ready
log_info "Waiting for services to be ready..."
sleep 10

# Step 2: Run migrations
log_info "Running database migrations..."
docker compose -f "$COMPOSE_FILE" exec -T web python manage.py migrate --noinput

# Step 3: Collect static files
log_info "Collecting static files..."
docker compose -f "$COMPOSE_FILE" exec -T web python manage.py collectstatic --noinput

# Step 4: Create proper admin user with role='admin'
log_info "Creating admin user with proper role..."
docker compose -f "$COMPOSE_FILE" exec -T web python manage.py shell << 'PYTHON_EOF'
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
        email=os.environ.get('ADMIN_EMAIL', 'admin@noctispro.local'),
        password=os.environ.get('ADMIN_PASSWORD', 'admin123'),
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

# Step 5: Health check
log_info "Performing health check..."
sleep 5

if docker compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
    log_success "Deployment successful!"
    echo
    echo "=============================================="
    echo "🎉 NoctisPro is now running!"
    echo "=============================================="
    echo
    echo "Access your application at:"
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
    echo "To stop the application:"
    echo "docker compose -f $COMPOSE_FILE down"
    echo
    echo "To view logs:"
    echo "docker compose -f $COMPOSE_FILE logs -f"
    echo
else
    log_error "Deployment failed. Check logs with: docker compose -f $COMPOSE_FILE logs"
    exit 1
fi