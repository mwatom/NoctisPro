#!/bin/bash

# Quick Emergency Fix Script for NoctisPro
# Run this from the NoctisPro directory where manage.py is located

set -e

echo "🚨 EMERGENCY DEPLOYMENT FIX 🚨"
echo "================================"

# Kill any existing processes on port 8000
echo "🔹 Stopping any process on port 8000..."
sudo lsof -ti:8000 | xargs -r sudo kill -9 2>/dev/null || true
sleep 2

# Check if we're in the right directory
if [ ! -f "manage.py" ]; then
    echo "❌ Error: manage.py not found. Please run this script from the NoctisPro directory."
    exit 1
fi

# Check if virtual environment exists
if [ ! -f "venv/bin/activate" ]; then
    echo "❌ Error: Virtual environment not found. Please ensure venv directory exists."
    exit 1
fi

echo "🔹 Activating virtual environment..."
source venv/bin/activate

echo "🔹 Running migrations..."
python manage.py migrate --noinput

echo "🔹 Creating admin user if missing..."
# Use proper Python multiline syntax
python manage.py shell << 'EOF'
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
    print('✅ Admin user created successfully!')
    print('   Username: admin')
    print('   Password: admin123')
else:
    print('✅ Admin user already exists')
EOF

echo "🔹 Collecting static files..."
python manage.py collectstatic --noinput --clear

echo ""
echo "🎉 DEPLOYMENT FIXED SUCCESSFULLY!"
echo "================================="
echo "🌟 Starting Django server on http://localhost:8000"
echo "🔑 Admin Login:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "🚀 Server starting in 3 seconds..."
sleep 3

# Start the server
python manage.py runserver 0.0.0.0:8000