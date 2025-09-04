#!/bin/bash

# NoctisPro Production Startup Script
# This script handles proper production deployment with environment management

set -e

echo "🚀 Starting NoctisPro Production Server..."

# Load production environment
export $(cat .env.production.fixed | xargs)

# Ensure directories exist
mkdir -p /workspace/staticfiles
mkdir -p /workspace/media/dicom
mkdir -p /workspace/logs

# Install dependencies if needed
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

echo "📦 Activating virtual environment..."
source venv/bin/activate

echo "📦 Installing/updating dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Django management commands
echo "🔧 Running Django migrations..."
python manage.py makemigrations --noinput
python manage.py migrate --noinput

echo "🔧 Collecting static files..."
python manage.py collectstatic --noinput --clear

echo "🔧 Creating superuser if needed..."
python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
    print('✅ Superuser created: admin/admin123')
else:
    print('✅ Superuser already exists')
"

# Kill any existing processes on port 8000
echo "🧹 Cleaning up existing processes..."
pkill -f "daphne.*8000" || true
pkill -f "python.*manage.py.*runserver" || true

# Wait a moment for cleanup
sleep 2

echo "🌟 Starting Daphne server on port 8000..."
echo "📊 Access your application at: http://localhost:8000"
echo "🔑 Admin access: http://localhost:8000/admin (admin/admin123)"
echo ""
echo "🔄 Server logs will appear below..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Start Daphne server
exec daphne -b 0.0.0.0 -p 8000 noctis_pro.asgi:application