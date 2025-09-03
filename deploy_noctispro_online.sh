#!/bin/bash

# 🚀 Deploy NoctisPro Online with Static URL
# Complete deployment script for your medical imaging system

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}🚀  NoctisPro Online Deployment${NC}"
    echo -e "${CYAN}   Medical Imaging System${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}🚨${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

print_header

# Configuration from .env.ngrok
STATIC_URL="colt-charmed-lark.ngrok-free.app"
DJANGO_PORT="8000"

# Check if ngrok auth token is configured
print_info "Checking ngrok configuration..."
if ! /workspace/ngrok config check > /dev/null 2>&1; then
    print_error "Ngrok auth token is not configured!"
    echo ""
    echo -e "${YELLOW}🔧 To configure ngrok:${NC}"
    echo ""
    echo "1. 🌐 Go to: https://dashboard.ngrok.com/signup"
    echo "2. 📝 Create a free account (if you don't have one)"
    echo "3. 🔑 Get your auth token from: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "4. 💾 Run this command with your token:"
    echo ""
    echo -e "${CYAN}   /workspace/ngrok config add-authtoken YOUR_TOKEN_HERE${NC}"
    echo ""
    echo "5. 🚀 Run this script again to deploy:"
    echo ""
    echo -e "${CYAN}   ./deploy_noctispro_online.sh${NC}"
    echo ""
    echo -e "${YELLOW}💡 The static URL ${CYAN}https://$STATIC_URL${YELLOW} is already configured and ready!${NC}"
    echo ""
    exit 1
fi

print_success "Ngrok is properly configured!"

# Stop any existing processes
print_info "Stopping any existing services..."
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "ngrok.*http" 2>/dev/null || true
sleep 2

# Start Django server
print_info "Starting Django server..."
cd /workspace
source venv/bin/activate
python manage.py runserver 0.0.0.0:$DJANGO_PORT > django_deployment.log 2>&1 &
DJANGO_PID=$!

# Wait for Django to start
sleep 5

# Check if Django started successfully
if ! kill -0 $DJANGO_PID 2>/dev/null; then
    print_error "Django server failed to start!"
    cat django_deployment.log
    exit 1
fi

print_success "Django server started (PID: $DJANGO_PID)"

# Start ngrok with static URL
print_info "Starting ngrok tunnel with static URL..."
/workspace/ngrok http --url=https://$STATIC_URL $DJANGO_PORT > ngrok_deployment.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to establish tunnel
sleep 8

# Check if ngrok started successfully
if ! kill -0 $NGROK_PID 2>/dev/null; then
    print_error "Ngrok tunnel failed to start!"
    cat ngrok_deployment.log
    print_error "Stopping Django server..."
    kill $DJANGO_PID 2>/dev/null || true
    exit 1
fi

print_success "Ngrok tunnel established (PID: $NGROK_PID)"

# Save PIDs for later cleanup
echo "DJANGO_PID=$DJANGO_PID" > deployment_pids.txt
echo "NGROK_PID=$NGROK_PID" >> deployment_pids.txt

# Display success information
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}🎉  DEPLOYMENT SUCCESSFUL!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${CYAN}🌐 Your NoctisPro system is now live at:${NC}"
echo ""
echo -e "${WHITE}📋 Main Application:${NC}"
echo -e "   ${CYAN}https://$STATIC_URL/${NC}"
echo ""
echo -e "${WHITE}🔧 Admin Panel:${NC}"
echo -e "   ${CYAN}https://$STATIC_URL/admin/${NC}"
echo -e "   👤 Username: ${YELLOW}admin${NC}"
echo -e "   🔐 Password: ${YELLOW}admin123${NC}"
echo ""
echo -e "${WHITE}📋 Worklist:${NC}"
echo -e "   ${CYAN}https://$STATIC_URL/worklist/${NC}"
echo ""
echo -e "${WHITE}🖼️ DICOM Viewer:${NC}"
echo -e "   ${CYAN}https://$STATIC_URL/dicom-viewer/${NC}"
echo ""
echo -e "${WHITE}📊 System Status:${NC}"
echo -e "   ${CYAN}https://$STATIC_URL/connection-info/${NC}"
echo ""
echo -e "${BLUE}ℹ️ Process Information:${NC}"
echo -e "   Django PID: $DJANGO_PID"
echo -e "   Ngrok PID: $NGROK_PID"
echo ""
echo -e "${YELLOW}🛑 To stop deployment:${NC}"
echo -e "   ${CYAN}./stop_deployment.sh${NC}"
echo ""
echo -e "${GREEN}✨ Your medical imaging system is now accessible worldwide!${NC}"
echo ""

# Optional: Keep script running to monitor
read -p "Press Enter to exit (services will continue running in background)..."