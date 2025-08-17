#!/bin/bash

# Noctis Pro PACS Production Startup Script

set -e

echo "Starting Noctis Pro PACS in production mode..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install/update dependencies
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Load environment variables
if [ -f ".env" ]; then
    echo "Loading environment variables..."
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Warning: .env file not found. Using default development settings."
fi

# Run database migrations
echo "Running database migrations..."
python manage.py migrate

# Collect static files
echo "Collecting static files..."
python manage.py collectstatic --noinput

# Create superuser if it doesn't exist
echo "Checking for admin user..."
python manage.py shell -c "
from accounts.models import User, Facility
import os

# Create default facility
facility, created = Facility.objects.get_or_create(
    name='Default Hospital',
    defaults={
        'address': '123 Main St',
        'phone': '555-0123',
        'email': 'admin@hospital.com',
        'license_number': 'DEFAULT123'
    }
)

# Create admin user if it doesn't exist
if not User.objects.filter(username='admin').exists():
    admin_password = os.environ.get('ADMIN_PASSWORD', 'admin123')
    admin = User.objects.create_user(
        username='admin',
        email='admin@hospital.com',
        password=admin_password,
        first_name='System',
        last_name='Administrator'
    )
    admin.role = 'admin'
    admin.facility = facility
    admin.is_verified = True
    admin.is_active = True
    admin.is_staff = True
    admin.is_superuser = True
    admin.save()
    print(f'Created admin user with password: {admin_password}')
else:
    print('Admin user already exists')
"

# Start the server
echo "Starting Django server..."
if [ "$DEBUG" = "True" ]; then
    echo "Running in development mode..."
    python manage.py runserver 0.0.0.0:8000
else
    echo "Running in production mode with Gunicorn..."
    gunicorn noctis_pro.wsgi:application \
        --bind 0.0.0.0:8000 \
        --workers 4 \
        --worker-class gthread \
        --threads 2 \
        --timeout 300 \
        --keepalive 2 \
        --max-requests 1000 \
        --max-requests-jitter 100 \
        --access-logfile - \
        --error-logfile -
fi