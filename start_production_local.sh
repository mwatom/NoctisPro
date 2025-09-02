#!/bin/bash

# NoctisPro Production Server (Local)
# This script starts the application in production mode locally

set -e

echo "🚀 Starting NoctisPro Production Server (Local)"
echo "==============================================="

# Change to workspace directory
cd /workspace

# Create logs directory if it doesn't exist
mkdir -p logs

# Activate virtual environment
echo "📦 Activating virtual environment..."
source venv/bin/activate

# Set production environment
export DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
export DEBUG=False

# Run Django checks
echo "🔍 Running production system checks..."
python manage.py check --deploy

# Collect static files
echo "📁 Collecting static files..."
python manage.py collectstatic --noinput

# Run migrations if needed
echo "🗄️ Checking for pending migrations..."
python manage.py migrate --check 2>/dev/null || {
    echo "⚠️ Migrations needed, running them..."
    python manage.py makemigrations
    python manage.py migrate
}

# Kill any existing processes on port 8000
echo "🧹 Cleaning up existing processes..."
pkill -f "runserver" 2>/dev/null || true
pkill -f "daphne" 2>/dev/null || true
pkill -f "gunicorn" 2>/dev/null || true
sleep 2

# Start the production server with Daphne (ASGI server)
echo ""
echo "🌟 Starting Daphne ASGI server..."
echo "📍 Local URL: http://localhost:8000"
echo "🔧 Admin URL: http://localhost:8000/admin/"
echo "📊 DICOM Viewer: http://localhost:8000/dicom-viewer/"
echo ""
echo "📝 Logs: tail -f logs/daphne.log"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start Daphne server
nohup daphne -b 0.0.0.0 -p 8000 noctis_pro.asgi:application > logs/daphne.log 2>&1 &
DAPHNE_PID=$!

echo "🎯 Daphne started with PID: $DAPHNE_PID"
echo "$DAPHNE_PID" > logs/daphne.pid

# Wait for server to start
echo "⏳ Waiting for server to start..."
sleep 5

# Check if server is running
if curl -s http://localhost:8000 > /dev/null; then
    echo "✅ Server is running successfully!"
    echo ""
    echo "🔗 Access your application at: http://localhost:8000"
    echo ""
    echo "To stop the server, run: pkill -f daphne"
    echo "Or use: kill $DAPHNE_PID"
else
    echo "❌ Server failed to start. Check logs/daphne.log for details"
    tail -20 logs/daphne.log
    exit 1
fi

# Keep script running to show logs
echo "📊 Live server logs (Ctrl+C to stop):"
echo "======================================"
tail -f logs/daphne.log