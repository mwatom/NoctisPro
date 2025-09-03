#!/bin/bash

# 🛑 Stop NoctisPro Online Deployment

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/deployment_pids.env"

echo -e "${YELLOW}🛑 Stopping NoctisPro Online Deployment...${NC}"
echo ""

# Stop processes by name
print_status "Stopping Django server..."
pkill -f "manage.py runserver" || print_warning "Django server not found"

print_status "Stopping ngrok tunnel..."
pkill -f "ngrok.*http" || print_warning "Ngrok tunnel not found"

# Stop processes by PID if file exists
if [ -f "$PID_FILE" ]; then
    print_status "Stopping processes from PID file..."
    source "$PID_FILE"
    
    if [ ! -z "${DJANGO_PID:-}" ]; then
        kill $DJANGO_PID 2>/dev/null || print_warning "Django PID $DJANGO_PID not found"
    fi
    
    if [ ! -z "${NGROK_PID:-}" ]; then
        kill $NGROK_PID 2>/dev/null || print_warning "Ngrok PID $NGROK_PID not found"
    fi
    
    rm "$PID_FILE"
fi

# Clean up log files
rm -f "$SCRIPT_DIR/django_server.log"
rm -f "$SCRIPT_DIR/ngrok.log"

print_success "✅ Deployment stopped successfully!"
print_status "Your application is now offline."