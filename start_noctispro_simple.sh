#!/bin/bash

# Simple NoctisPro Startup Script
# Works without systemd, ngrok, or complex dependencies

set -e

echo "🚀 NoctisPro Simple Startup"
echo "=========================="

# Change to workspace directory
cd /workspace

# Create necessary directories
mkdir -p logs staticfiles

# Activate virtual environment
echo "📦 Activating virtual environment..."
if [ -d "venv" ]; then
    source venv/bin/activate
else
    echo "❌ Virtual environment not found. Run: python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
    exit 1
fi

# Basic Django setup
echo "🔧 Setting up Django..."
python manage.py collectstatic --noinput
python manage.py migrate

# Kill existing processes
echo "🧹 Stopping any existing servers..."
pkill -f "runserver\|daphne\|gunicorn" 2>/dev/null || true
sleep 2

# Start the server
echo ""
echo "🌟 Starting NoctisPro..."
echo "📍 URL: http://localhost:8000"
echo "👤 Admin: http://localhost:8000/admin/"
echo "🏥 DICOM: http://localhost:8000/dicom-viewer/"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Use development server for simplicity
python manage.py runserver 0.0.0.0:8000