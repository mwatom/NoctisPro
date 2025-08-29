#!/bin/bash

# NoctisPro Improved Production Stop Script

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

print_status "🛑 Stopping NoctisPro Production Services..."

# Stop processes using PID files
if [ -f "daphne.pid" ]; then
    DAPHNE_PID=$(cat daphne.pid)
    if kill -0 "$DAPHNE_PID" 2>/dev/null; then
        print_status "Stopping Daphne (PID: $DAPHNE_PID)..."
        kill "$DAPHNE_PID"
        print_success "✅ Daphne stopped"
    else
        print_warning "Daphne process not running"
    fi
    rm -f daphne.pid
fi

if [ -f "ngrok.pid" ]; then
    NGROK_PID=$(cat ngrok.pid)
    if kill -0 "$NGROK_PID" 2>/dev/null; then
        print_status "Stopping Ngrok (PID: $NGROK_PID)..."
        kill "$NGROK_PID"
        print_success "✅ Ngrok stopped"
    else
        print_warning "Ngrok process not running"
    fi
    rm -f ngrok.pid
fi

# Fallback: kill any remaining processes
print_status "Cleaning up any remaining processes..."
pkill -f "daphne.*noctis_pro" 2>/dev/null || true
pkill -f "gunicorn.*noctis_pro" 2>/dev/null || true
pkill -f "python.*runserver" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true

# Clean up URL file
rm -f current_ngrok_url.txt

print_success "🎉 All NoctisPro services stopped!"
echo ""