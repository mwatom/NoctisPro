#!/bin/bash

# NoctisPro Local Development Server
# This script starts the application locally without ngrok

set -e

echo "🚀 Starting NoctisPro Local Development Server"
echo "=============================================="

# Change to workspace directory
cd /workspace

# Activate virtual environment
echo "📦 Activating virtual environment..."
source venv/bin/activate

# Run Django checks
echo "🔍 Running system checks..."
python manage.py check

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
sleep 2

# Start the development server
echo ""
echo "🌟 Starting Django development server..."
echo "📍 Local URL: http://localhost:8000"
echo "🔧 Admin URL: http://localhost:8000/admin/"
echo "📊 DICOM Viewer: http://localhost:8000/dicom-viewer/"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start the server
python manage.py runserver 0.0.0.0:8000