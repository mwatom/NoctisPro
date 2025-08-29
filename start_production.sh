#!/bin/bash

# NoctisPro Production Startup Script (No systemd required)
# This script starts NoctisPro as background processes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Set working directory
cd /workspace

print_status "🚀 Starting NoctisPro Production Services..."

# Create necessary directories
mkdir -p logs
mkdir -p staticfiles

# Stop any existing processes
print_status "Stopping any existing processes..."
pkill -f "gunicorn.*noctis_pro" 2>/dev/null || true
pkill -f "python.*runserver" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true

# Start Redis if not running
print_status "Starting Redis server..."
redis-server --daemonize yes 2>/dev/null || print_warning "Redis may already be running"

# Activate virtual environment
source venv/bin/activate

# Set environment variables
export USE_SQLITE=true
export DEBUG=false
export DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Collect static files
print_status "Collecting static files..."
python manage.py collectstatic --noinput >/dev/null 2>&1

# Run migrations
print_status "Running database migrations..."
python manage.py migrate >/dev/null 2>&1

# Start Django with Gunicorn
print_status "Starting Django application with Gunicorn..."
nohup gunicorn --bind 0.0.0.0:8000 --workers 3 --timeout 120 \
    --access-logfile logs/gunicorn-access.log \
    --error-logfile logs/gunicorn-error.log \
    --log-level info \
    noctis_pro.wsgi:application > logs/gunicorn.log 2>&1 &

DJANGO_PID=$!
echo $DJANGO_PID > /workspace/django.pid

# Wait for Django to start
print_status "Waiting for Django to start..."
sleep 10

# Check if Django is running
if curl -s http://localhost:8000 >/dev/null 2>&1; then
    print_success "✅ Django application started successfully"
else
    print_error "❌ Django application failed to start"
    print_status "Check logs: tail -f logs/gunicorn*.log"
    exit 1
fi

# Start ngrok tunnel
print_status "Starting ngrok tunnel..."
nohup ngrok http 8000 --log stdout > logs/ngrok.log 2>&1 &
NGROK_PID=$!
echo $NGROK_PID > /workspace/ngrok.pid

# Wait for ngrok to start
print_status "Waiting for ngrok tunnel to establish..."
sleep 15

# Get ngrok URL
NGROK_URL=""
for i in {1..10}; do
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "import json, sys; data = json.load(sys.stdin); print(data['tunnels'][0]['public_url'] if data.get('tunnels') else '')" 2>/dev/null || echo "")
    if [ ! -z "$NGROK_URL" ]; then
        break
    fi
    sleep 3
done

echo ""
echo "========================================"
print_success "🎉 NoctisPro Production Started!"
echo "========================================"
echo ""

# Show process information
print_status "📊 Process Information:"
echo "  • Django PID: $DJANGO_PID (saved to django.pid)"
echo "  • Ngrok PID: $NGROK_PID (saved to ngrok.pid)"
echo ""

# Show URLs
if [ ! -z "$NGROK_URL" ]; then
    print_success "🌐 Your application is accessible at:"
    echo "  • Public URL: $NGROK_URL"
    echo "  • Admin Panel: $NGROK_URL/admin/"
    echo "  • Local URL: http://localhost:8000"
    echo "  • Ngrok Inspector: http://localhost:4040"
else
    print_warning "⚠️  Ngrok URL not available yet. Check logs: tail -f logs/ngrok.log"
fi

echo ""
print_success "📂 Log Files:"
echo "  • Django: logs/gunicorn*.log"
echo "  • Ngrok: logs/ngrok.log"
echo ""

print_success "🔧 Management Commands:"
echo "  • Stop services: ./stop_production.sh"
echo "  • Check status: ./status_production.sh"
echo "  • Get URL: ./get_ngrok_url.sh"
echo ""

print_success "✅ Services are now running in the background!"
print_warning "💡 To run at boot, add './start_production.sh' to your server's startup scripts."
echo ""