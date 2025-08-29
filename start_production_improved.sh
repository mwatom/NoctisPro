#!/bin/bash

# NoctisPro Improved Production Startup Script
# Incorporates ideas from the advanced deployment script

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Environment file
ENV_FILE=".env.production"
VENV_DIR="venv"
LOGS_DIR="logs"
DAPHNE_PORT=8000

print_status "🚀 Starting NoctisPro Production Services (Improved)..."

# Load environment variables if file exists
if [ -f "$ENV_FILE" ]; then
    print_status "Loading environment from $ENV_FILE"
    export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | xargs)
else
    print_warning "Environment file $ENV_FILE not found, using defaults"
fi

# Create necessary directories
mkdir -p "$LOGS_DIR"
mkdir -p staticfiles

# Stop any existing processes
print_status "Stopping any existing processes..."
pkill -f "daphne.*noctis_pro" 2>/dev/null || true
pkill -f "gunicorn.*noctis_pro" 2>/dev/null || true
pkill -f "python.*runserver" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true

# Start Redis if not running
print_status "Starting Redis server..."
if ! pgrep redis-server > /dev/null; then
    redis-server --daemonize yes 2>/dev/null || print_warning "Redis may already be running or failed to start"
else
    print_success "Redis already running"
fi

# Activate virtual environment
if [ -f "$VENV_DIR/bin/activate" ]; then
    print_status "Activating virtual environment..."
    source "$VENV_DIR/bin/activate"
else
    print_error "Virtual environment not found at $VENV_DIR"
    exit 1
fi

# Check if Daphne is installed
if ! command -v daphne &> /dev/null; then
    print_status "Installing Daphne..."
    pip install daphne
fi

# Django management commands
print_status "Running Django management commands..."
python manage.py migrate --noinput >/dev/null 2>&1
python manage.py collectstatic --noinput >/dev/null 2>&1

# Start Django with Daphne (ASGI server for WebSocket support)
print_status "Starting Django application with Daphne (ASGI)..."
nohup daphne -b ${DAPHNE_BIND:-0.0.0.0} -p ${DAPHNE_PORT:-8000} \
    --access-log "$LOGS_DIR/daphne-access.log" \
    noctis_pro.asgi:application > "$LOGS_DIR/daphne.log" 2>&1 &

DAPHNE_PID=$!
echo $DAPHNE_PID > daphne.pid

# Wait for Django to start
print_status "Waiting for Django to start..."
sleep 10

# Check if Django is running
if curl -s http://localhost:${DAPHNE_PORT:-8000} >/dev/null 2>&1; then
    print_success "✅ Django application started successfully with Daphne"
else
    print_error "❌ Django application failed to start"
    print_status "Check logs: tail -f $LOGS_DIR/daphne*.log"
    exit 1
fi

# Start ngrok tunnel
print_status "Starting ngrok tunnel..."
if [ ! -z "${NGROK_AUTHTOKEN:-}" ] && [ ! -z "${NGROK_STATIC_DOMAIN:-}" ]; then
    # Use static domain if configured
    print_status "Using static ngrok domain: $NGROK_STATIC_DOMAIN"
    nohup ngrok http --authtoken="$NGROK_AUTHTOKEN" --url="$NGROK_STATIC_DOMAIN" ${DAPHNE_PORT:-8000} --log stdout > "$LOGS_DIR/ngrok.log" 2>&1 &
else
    # Use dynamic domain
    print_status "Using dynamic ngrok domain"
    nohup ngrok http ${DAPHNE_PORT:-8000} --log stdout > "$LOGS_DIR/ngrok.log" 2>&1 &
fi

NGROK_PID=$!
echo $NGROK_PID > ngrok.pid

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
echo "  • Daphne PID: $DAPHNE_PID (saved to daphne.pid)"
echo "  • Ngrok PID: $NGROK_PID (saved to ngrok.pid)"
echo ""

# Show URLs
if [ ! -z "$NGROK_URL" ]; then
    print_success "🌐 Your application is accessible at:"
    echo "  • Public URL: $NGROK_URL"
    echo "  • Admin Panel: $NGROK_URL/admin/"
    echo "  • Local URL: http://localhost:${DAPHNE_PORT:-8000}"
    echo "  • Ngrok Inspector: http://localhost:4040"
    
    # Save URL to file for easy access
    echo "$NGROK_URL" > current_ngrok_url.txt
    print_status "URL saved to current_ngrok_url.txt"
else
    if [ ! -z "${NGROK_STATIC_DOMAIN:-}" ]; then
        print_success "🌐 Your application should be accessible at:"
        echo "  • Static URL: https://$NGROK_STATIC_DOMAIN"
        echo "  • Admin Panel: https://$NGROK_STATIC_DOMAIN/admin/"
    else
        print_warning "⚠️  Ngrok URL not available yet. Check logs: tail -f $LOGS_DIR/ngrok.log"
    fi
fi

echo ""
print_success "📂 Log Files:"
echo "  • Daphne: $LOGS_DIR/daphne*.log"
echo "  • Ngrok: $LOGS_DIR/ngrok.log"
echo ""

print_success "🔧 Management Commands:"
echo "  • Stop services: ./stop_production.sh"
echo "  • Check status: ./status_production.sh"
echo "  • Get URL: cat current_ngrok_url.txt"
echo ""

print_success "✅ Services are now running in the background!"
print_success "🚀 Using Daphne for ASGI/WebSocket support"

if [ -f "$ENV_FILE" ]; then
    print_success "📋 Configuration loaded from $ENV_FILE"
else
    print_warning "💡 Create $ENV_FILE for better configuration management"
fi

echo ""