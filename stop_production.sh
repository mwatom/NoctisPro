#!/bin/bash

# NoctisPro Production Stop Script

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

# Set working directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_status "🛑 Stopping NoctisPro Production Services..."

# Stop processes by PID if files exist
if [ -f "django.pid" ]; then
    DJANGO_PID=$(cat django.pid)
    if kill -0 $DJANGO_PID 2>/dev/null; then
        print_status "Stopping Django (PID: $DJANGO_PID)..."
        kill $DJANGO_PID
        sleep 3
        # Force kill if still running
        if kill -0 $DJANGO_PID 2>/dev/null; then
            kill -9 $DJANGO_PID 2>/dev/null || true
        fi
    fi
    rm -f django.pid
fi

if [ -f "ngrok.pid" ]; then
    NGROK_PID=$(cat ngrok.pid)
    if kill -0 $NGROK_PID 2>/dev/null; then
        print_status "Stopping Ngrok (PID: $NGROK_PID)..."
        kill $NGROK_PID
        sleep 2
        # Force kill if still running
        if kill -0 $NGROK_PID 2>/dev/null; then
            kill -9 $NGROK_PID 2>/dev/null || true
        fi
    fi
    rm -f ngrok.pid
fi

# Also kill by process name as backup
print_status "Ensuring all processes are stopped..."
pkill -f "gunicorn.*noctis_pro" 2>/dev/null || true
pkill -f "python.*runserver" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true

sleep 2

print_success "✅ All NoctisPro services stopped"

# Check if anything is still running
if pgrep -f "gunicorn.*noctis_pro" >/dev/null || pgrep -f "ngrok" >/dev/null; then
    print_warning "⚠️  Some processes may still be running. Check with: ps aux | grep -E '(gunicorn|ngrok)'"
else
    print_success "✅ No NoctisPro processes detected"
fi

echo ""