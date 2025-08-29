#!/bin/bash

# Quick Start Script for NoctisPro
# Uses existing virtual environment and packages

set -e

echo "🚀 Starting NoctisPro (Quick Mode)"
echo "=================================="

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found. Please run the full deployment first."
    exit 1
fi

# Stop any existing processes
echo "🛑 Stopping existing processes..."
pkill -f "daphne.*noctis_pro" 2>/dev/null || true
sleep 2

# Set environment variables for SQLite mode
export USE_SQLITE=true
export DISABLE_REDIS=true
export DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Quick Django setup
echo "📊 Running quick database setup..."
python manage.py migrate --run-syncdb 2>/dev/null || python manage.py migrate

echo "📁 Collecting static files..."
python manage.py collectstatic --noinput --clear

# Start Daphne server
echo "🚀 Starting Daphne server..."
daphne -b 0.0.0.0 -p 8000 noctis_pro.asgi:application &

# Save process ID
sleep 3
pgrep -f "daphne.*noctis_pro" > daphne.pid 2>/dev/null || true

# Verify deployment
echo "🔍 Verifying deployment..."
sleep 2

if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ | grep -q "302"; then
    echo ""
    echo "✅ SUCCESS! NoctisPro is running!"
    echo "================================="
    echo "📍 Application URL: http://localhost:8000"
    echo "🔐 Login URL: http://localhost:8000/login/"
    echo "👑 Admin URL: http://localhost:8000/admin/"
    echo ""
    echo "🔑 Default Credentials:"
    echo "   Username: admin"
    echo "   Password: admin123456"
    echo ""
    echo "🛠️  Management:"
    echo "   • Stop: pkill -f daphne"
    echo "   • Restart: ./quick_start_noctispro.sh"
    echo "   • Status: curl -I http://localhost:8000/"
    echo ""
else
    echo "❌ Deployment verification failed"
    echo "Check logs: tail -f logs/*.log"
    exit 1
fi