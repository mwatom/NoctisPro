#!/bin/bash

# Noctis Pro PACS - Start with Virtual Environment
# This script activates the virtual environment and starts the system

set -e

echo "🚀 Starting Noctis Pro PACS with Virtual Environment..."
echo "===================================================="

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if we're in the right directory
if [[ ! -f "manage.py" ]]; then
    print_error "This script must be run from the Django project root directory"
    exit 1
fi

print_header "1. Setting up Virtual Environment"

# Check if virtual environment exists
if [[ ! -d "venv" ]]; then
    print_status "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
print_status "Activating virtual environment..."
source venv/bin/activate

print_header "2. Installing Dependencies"

# Upgrade pip in venv
pip install --upgrade pip

# Install required packages
print_status "Installing Python packages..."
pip install \
    django==4.2.7 \
    djangorestframework==3.14.0 \
    pillow==10.0.1 \
    numpy==1.24.3 \
    pydicom==2.4.3 \
    python-decouple==3.8 \
    django-cors-headers==4.3.1 \
    channels==4.0.0 \
    daphne==4.0.0

print_header "3. Environment Setup"

# Set environment variables
export DEBUG=True
export USE_SQLITE=True
export DATABASE_PATH="/workspace/db.sqlite3"
export SERVE_MEDIA_FILES=True

print_status "Environment variables set"

print_header "4. Database Setup"

# Create template tags if missing
mkdir -p worklist/templatetags
touch worklist/templatetags/__init__.py

# Create dicts template tag if missing
if [[ ! -f "worklist/templatetags/dicts.py" ]]; then
    cat > worklist/templatetags/dicts.py << 'EOF'
from django import template

register = template.Library()

@register.filter
def get_item(dictionary, key):
    """Get item from dictionary by key"""
    return dictionary.get(key)

@register.filter  
def get_attr(obj, attr_name):
    """Get attribute from object"""
    return getattr(obj, attr_name, None)
EOF
fi

# Run migrations
print_status "Running database migrations..."
python manage.py makemigrations --noinput 2>/dev/null || echo "No new migrations"
python manage.py migrate --noinput

print_header "5. Static Files"

# Create directories
mkdir -p staticfiles/css staticfiles/js/vendor/three media/dicom

# Collect static files
print_status "Collecting static files..."
python manage.py collectstatic --noinput --clear

print_header "6. Creating Admin User"

# Create superuser if needed
python manage.py shell << 'EOF'
from django.contrib.auth import get_user_model
User = get_user_model()
try:
    if not User.objects.filter(username='admin').exists():
        User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
        print('✅ Superuser created: admin/admin123')
    else:
        print('✅ Superuser already exists')
except Exception as e:
    print(f'Note: {e}')
EOF

print_header "7. System Check"

# Run Django check
print_status "Running system check..."
python manage.py check --deploy 2>/dev/null || python manage.py check

print_header "8. Starting Server"

# Kill any existing processes
pkill -f "manage.py runserver" 2>/dev/null || true
sleep 2

print_status "Starting Django development server..."

# Start the server
echo ""
echo "🎉 Starting Noctis Pro PACS..."
echo "============================="
echo ""
echo "🌐 Access URLs:"
echo "   • Main Application: http://localhost:8000"
echo "   • Admin Interface:  http://localhost:8000/admin"
echo "   • Health Check:     http://localhost:8000/health/"
echo ""
echo "🔐 Login Credentials:"
echo "   • Username: admin"
echo "   • Password: admin123"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start the server in foreground so user can see logs and stop with Ctrl+C
python manage.py runserver 0.0.0.0:8000