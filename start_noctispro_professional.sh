#!/bin/bash

# NoctisPro Professional Startup Script
# This script starts the NoctisPro professional medical imaging system

set -e

echo "🏥 Starting NoctisPro Professional Medical Imaging System..."

# Change to project directory
cd /workspace/noctis_pro_deployment

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | xargs)
fi

# Activate virtual environment
source venv/bin/activate

# Set environment variables
export DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
export PYTHONPATH=/workspace/noctis_pro_deployment

echo "🔧 Collecting static files..."
python manage.py collectstatic --noinput --clear

echo "🗄️  Running database migrations..."
python manage.py migrate

echo "🚀 Starting NoctisPro Professional server..."
exec gunicorn noctis_pro.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers 4 \
    --timeout 300 \
    --max-requests 1000 \
    --preload \
    --access-logfile - \
    --error-logfile -