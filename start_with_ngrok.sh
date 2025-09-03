#!/bin/bash

# 🚀 NoctisPro Ngrok Static URL Deployment
# Deploy your medical imaging system online with a fixed URL

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Icons
ICON_ROCKET="🚀"
ICON_SUCCESS="✅"
ICON_ERROR="🚨"
ICON_WARNING="⚠️"
ICON_INFO="ℹ️"
ICON_NETWORK="🌐"

print_status() {
    echo -e "${BLUE}${ICON_INFO}${NC} $1"
}

print_success() {
    echo -e "${GREEN}${ICON_SUCCESS}${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}${ICON_WARNING}${NC} $1"
}

print_error() {
    echo -e "${RED}${ICON_ERROR}${NC} $1"
}

print_header() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}${ICON_ROCKET}  NoctisPro Online Deployment${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATIC_URL="colt-charmed-lark.ngrok-free.app"
DJANGO_PORT="8000"
NGROK_BINARY="$SCRIPT_DIR/ngrok"

print_header

# Check if ngrok is configured
print_status "Checking ngrok configuration..."
if ! $NGROK_BINARY config check > /dev/null 2>&1; then
    print_error "Ngrok is not configured with an auth token!"
    echo ""
    echo -e "${YELLOW}To set up ngrok:${NC}"
    echo "1. Go to: https://dashboard.ngrok.com/signup"
    echo "2. Create a free account"
    echo "3. Get your auth token from: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "4. Run: $NGROK_BINARY config add-authtoken YOUR_TOKEN_HERE"
    echo ""
    echo -e "${YELLOW}Then run this script again.${NC}"
    exit 1
fi

print_success "Ngrok is configured!"

# Check if Django server is already running
if pgrep -f "manage.py runserver" > /dev/null; then
    print_warning "Django server is already running. Stopping it first..."
    pkill -f "manage.py runserver" || true
    sleep 2
fi

# Check if ngrok is already running
if pgrep -f "ngrok.*http" > /dev/null; then
    print_warning "Ngrok is already running. Stopping it first..."
    pkill -f "ngrok.*http" || true
    sleep 2
fi

# Activate virtual environment
print_status "Activating virtual environment..."
if [ -d "$SCRIPT_DIR/venv" ]; then
    source "$SCRIPT_DIR/venv/bin/activate"
    print_success "Virtual environment activated"
else
    print_error "Virtual environment not found at $SCRIPT_DIR/venv"
    exit 1
fi

# Load environment variables for ngrok
if [ -f "$SCRIPT_DIR/.env.ngrok" ]; then
    print_status "Loading ngrok environment variables..."
    source "$SCRIPT_DIR/.env.ngrok"
    print_success "Environment variables loaded"
fi

# Start Django server
print_status "Starting Django server on port $DJANGO_PORT..."
cd "$SCRIPT_DIR"
python manage.py runserver 0.0.0.0:$DJANGO_PORT > django_server.log 2>&1 &
DJANGO_PID=$!

# Wait for Django to start
print_status "Waiting for Django server to initialize..."
sleep 5

# Check if Django started successfully
if ! kill -0 $DJANGO_PID 2>/dev/null; then
    print_error "Django server failed to start!"
    cat django_server.log
    exit 1
fi

print_success "Django server started (PID: $DJANGO_PID)"

# Start ngrok with static URL
print_status "Starting ngrok with static URL: $STATIC_URL..."
$NGROK_BINARY http --url=https://$STATIC_URL $DJANGO_PORT > ngrok.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to establish tunnel
print_status "Waiting for ngrok tunnel to establish..."
sleep 8

# Check if ngrok started successfully
if ! kill -0 $NGROK_PID 2>/dev/null; then
    print_error "Ngrok failed to start!"
    cat ngrok.log
    print_error "Stopping Django server..."
    kill $DJANGO_PID 2>/dev/null || true
    exit 1
fi

print_success "Ngrok tunnel established (PID: $NGROK_PID)"

# Save process IDs
echo "DJANGO_PID=$DJANGO_PID" > "$SCRIPT_DIR/deployment_pids.env"
echo "NGROK_PID=$NGROK_PID" >> "$SCRIPT_DIR/deployment_pids.env"

# Display deployment information
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}${ICON_ROCKET}  DEPLOYMENT SUCCESSFUL!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${CYAN}${ICON_NETWORK} Your NoctisPro system is now online:${NC}"
echo ""
echo -e "${WHITE}🌐 Main Application:${NC}"
echo -e "   https://$STATIC_URL/"
echo ""
echo -e "${WHITE}🔧 Admin Panel:${NC}"
echo -e "   https://$STATIC_URL/admin/"
echo -e "   Username: admin"
echo -e "   Password: admin123"
echo ""
echo -e "${WHITE}📋 Worklist:${NC}"
echo -e "   https://$STATIC_URL/worklist/"
echo ""
echo -e "${WHITE}🖼️ DICOM Viewer:${NC}"
echo -e "   https://$STATIC_URL/dicom-viewer/"
echo ""
echo -e "${WHITE}📊 System Status:${NC}"
echo -e "   https://$STATIC_URL/connection-info/"
echo ""
echo -e "${CYAN}${ICON_INFO} Process Information:${NC}"
echo -e "   Django PID: $DJANGO_PID"
echo -e "   Ngrok PID: $NGROK_PID"
echo ""
echo -e "${YELLOW}To stop the deployment:${NC}"
echo -e "   ./stop_deployment.sh"
echo ""
echo -e "${GREEN}${ICON_SUCCESS} Your medical imaging system is live and ready for global access!${NC}"
echo ""

# Keep script running to maintain deployment
print_status "Deployment is running. Press Ctrl+C to stop..."
trap 'echo ""; print_warning "Stopping deployment..."; kill $DJANGO_PID $NGROK_PID 2>/dev/null || true; exit 0' INT

# Monitor deployment
while true; do
    if ! kill -0 $DJANGO_PID 2>/dev/null; then
        print_error "Django server stopped unexpectedly!"
        kill $NGROK_PID 2>/dev/null || true
        exit 1
    fi
    
    if ! kill -0 $NGROK_PID 2>/dev/null; then
        print_error "Ngrok tunnel stopped unexpectedly!"
        kill $DJANGO_PID 2>/dev/null || true
        exit 1
    fi
    
    sleep 30
done