#!/bin/bash

# 🚀 ONE-COMMAND NGROK FIX
# Usage: ./fix_ngrok_now.sh [YOUR_AUTH_TOKEN]

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}🚀 ONE-COMMAND NGROK FIX${NC}"
echo "=========================="
echo ""

# Check if auth token provided
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No auth token provided${NC}"
    echo ""
    echo -e "${CYAN}Option 1: Get a free ngrok account and auth token${NC}"
    echo -e "1. Visit: ${BLUE}https://dashboard.ngrok.com/signup${NC}"
    echo -e "2. Get token: ${BLUE}https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
    echo -e "3. Run: ${GREEN}./fix_ngrok_now.sh YOUR_TOKEN${NC}"
    echo ""
    echo -e "${CYAN}Option 2: Continue without static domain (random URL)${NC}"
    read -p "Continue with random URL? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    USE_STATIC=false
else
    AUTH_TOKEN="$1"
    USE_STATIC=true
fi

echo -e "${BLUE}🔧 Fixing ngrok setup...${NC}"

# Kill any existing processes
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f ngrok 2>/dev/null || true
sleep 2

# Setup authentication if token provided
if [ "$USE_STATIC" = true ]; then
    echo -e "${YELLOW}Setting up authentication...${NC}"
    mkdir -p ~/.config/ngrok
    ./ngrok config add-authtoken "$AUTH_TOKEN"
    
    if ./ngrok config check > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Authentication configured${NC}"
    else
        echo -e "${RED}❌ Authentication failed${NC}"
        exit 1
    fi
fi

# Start Django server
echo -e "${YELLOW}Starting Django server...${NC}"
cd /workspace/noctis_pro_deployment

# Activate venv if exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Start Django in background
nohup python manage.py runserver 0.0.0.0:8000 > /workspace/django.log 2>&1 &

# Wait for Django
sleep 5
if curl -s http://localhost:8000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Django server running${NC}"
else
    echo -e "${RED}❌ Django failed to start${NC}"
    echo "Check logs: tail -f /workspace/django.log"
    exit 1
fi

# Start ngrok tunnel
echo -e "${YELLOW}Starting ngrok tunnel...${NC}"
cd /workspace

if [ "$USE_STATIC" = true ]; then
    # Use static domain
    nohup ./ngrok http --url=mallard-shining-curiously.ngrok-free.app 8000 > /workspace/ngrok.log 2>&1 &
    TUNNEL_URL="https://mallard-shining-curiously.ngrok-free.app"
else
    # Use random domain
    nohup ./ngrok http 8000 > /workspace/ngrok.log 2>&1 &
    sleep 5
    # Extract URL from ngrok API
    TUNNEL_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o 'https://[^"]*\.ngrok-free\.app' | head -1)
fi

# Save URL
echo "$TUNNEL_URL" > /workspace/current_ngrok_url.txt

# Wait and verify
sleep 8
if curl -s "$TUNNEL_URL" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Ngrok tunnel established${NC}"
else
    echo -e "${YELLOW}⚠️  Tunnel may still be starting...${NC}"
fi

echo ""
echo -e "${GREEN}${BOLD}🎉 NGROK FIXED! ACCESS FROM ANYWHERE:${NC}"
echo -e "${CYAN}${BOLD}URL: $TUNNEL_URL${NC}"
echo ""
echo -e "${BLUE}Commands:${NC}"
echo -e "Check status: ${YELLOW}curl $TUNNEL_URL${NC}"
echo -e "View logs: ${YELLOW}tail -f /workspace/ngrok.log${NC}"
echo -e "Stop all: ${YELLOW}pkill -f 'manage.py\\|ngrok'${NC}"
echo ""