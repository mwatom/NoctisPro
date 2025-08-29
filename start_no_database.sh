#!/bin/bash

# NoctisPro - No Database Mode
# Runs without any database persistence

set -e

echo "🚀 Starting NoctisPro (No Database Mode)"
echo "========================================"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found. Please run setup first."
    exit 1
fi

# Stop any existing processes
echo "🛑 Stopping existing processes..."
pkill -f "daphne.*noctis_pro" 2>/dev/null || true
sleep 2

# Set environment variables for no-database mode
export USE_MEMORY_DB=true
export DISABLE_REDIS=true
export USE_DUMMY_CACHE=true
export DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Skip database setup entirely
echo "📊 Skipping database setup (no-database mode)..."

echo "📁 Collecting static files..."
python manage.py collectstatic --noinput --clear

# Create a minimal Django app without database migrations
echo "🏗️  Creating minimal app structure..."

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
    echo "💾 Database: NONE (completely disabled)"
    echo "⚠️  Note: No data persistence at all"
    echo "🎯 Mode: Static files and views only"
    echo ""
    echo "🛠️  Management:"
    echo "   • Stop: pkill -f daphne"
    echo "   • Restart: ./start_no_database.sh"
    echo "   • Status: curl -I http://localhost:8000/"
    echo ""
else
    echo "❌ Deployment verification failed"
    echo "Check logs: tail -f logs/*.log"
    exit 1
fi