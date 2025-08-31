#!/bin/bash

# Noctis Pro PACS Startup Script
echo "🚀 Starting Noctis Pro PACS System"
echo "=================================="

# Set up environment
export PATH="/home/ubuntu/.local/bin:$PATH"
export PYTHONPATH="/workspace:$PYTHONPATH"

# Change to workspace directory
cd /workspace

# Check if dependencies are installed
echo "📦 Checking dependencies..."
if ! python3 -c "import django" 2>/dev/null; then
    echo "⚠️  Installing missing dependencies..."
    pip3 install --break-system-packages -r requirements.txt
fi

# Create admin user if it doesn't exist
echo "👤 Setting up admin user..."
python3 -c "
import os, sys, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from accounts.models import User, Facility
from worklist.models import Modality
from django.contrib.auth.hashers import make_password

# Create facility
facility, created = Facility.objects.get_or_create(
    name='Test Hospital',
    defaults={
        'ae_title': 'TESTHSP',
        'address': '123 Test St',
        'phone': '555-0123',
        'contact_person': 'Test Admin'
    }
)

# Create admin user
admin_user, created = User.objects.get_or_create(
    username='admin',
    defaults={
        'email': 'admin@test.com',
        'password': make_password('admin123'),
        'role': 'admin',
        'first_name': 'Admin',
        'last_name': 'User',
        'is_staff': True,
        'is_superuser': True,
        'facility': facility
    }
)

# Create modalities
modalities = [('CT', 'Computed Tomography'), ('MRI', 'Magnetic Resonance Imaging'), ('XR', 'X-Ray'), ('US', 'Ultrasound'), ('NM', 'Nuclear Medicine')]
for code, name in modalities:
    Modality.objects.get_or_create(code=code, defaults={'name': name, 'is_active': True})

print(f'Admin user ready: admin / admin123')
"

# Run migrations
echo "🔧 Running database migrations..."
python3 manage.py makemigrations --noinput
python3 manage.py migrate --noinput

# Collect static files
echo "📁 Collecting static files..."
python3 manage.py collectstatic --noinput --clear

# Start the server
echo "🌐 Starting Django server..."
echo "Access the system at: http://localhost:8000"
echo "Login: admin / admin123"
echo ""

# Kill any existing server processes
pkill -f "manage.py runserver" 2>/dev/null || true

# Start server
python3 manage.py runserver 0.0.0.0:8000