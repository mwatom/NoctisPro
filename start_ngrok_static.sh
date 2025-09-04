#!/bin/bash

# 🚀 Quick Ngrok Static URL Connector
# Connects your Django app running on port 8000 to the static URL

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

STATIC_URL="mallard-shining-curiously.ngrok-free.app"
LOCAL_PORT=8000
NGROK_BINARY="/workspace/ngrok"

echo -e "${CYAN}🚀 Connecting to Static URL: $STATIC_URL${NC}"
echo "=============================================="

# Check if Django is running on port 8000
echo -e "${BLUE}Checking Django server on port $LOCAL_PORT...${NC}"
if curl -s http://localhost:$LOCAL_PORT > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Django server is running on port $LOCAL_PORT${NC}"
else
    echo -e "${YELLOW}⚠️  Django server not detected on port $LOCAL_PORT${NC}"
    echo "Make sure your Django/Daphne server is running:"
    echo -e "${CYAN}cd ~/NoctisPro && daphne -b 0.0.0.0 -p 8000 noctis_pro.asgi:application${NC}"
    echo ""
    echo "Continuing anyway..."
fi

# Kill any existing ngrok processes
echo -e "${BLUE}Stopping any existing ngrok processes...${NC}"
pkill ngrok 2>/dev/null || true
sleep 2

# Check ngrok authentication
echo -e "${BLUE}Checking ngrok authentication...${NC}"
if ! $NGROK_BINARY config check > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Ngrok not authenticated. Please run:${NC}"
    echo -e "${CYAN}$NGROK_BINARY config add-authtoken YOUR_TOKEN${NC}"
    echo -e "Get your token from: ${CYAN}https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Ngrok is authenticated${NC}"

# Start ngrok with your static URL
echo -e "${BLUE}Starting ngrok tunnel...${NC}"
echo -e "${CYAN}Command: $NGROK_BINARY http --url=$STATIC_URL $LOCAL_PORT${NC}"

# Start ngrok in background and capture output
nohup $NGROK_BINARY http --url=$STATIC_URL $LOCAL_PORT > /workspace/ngrok_static.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to start
sleep 5

# Check if ngrok is running
if kill -0 $NGROK_PID 2>/dev/null; then
    echo -e "${GREEN}✅ Ngrok tunnel started successfully!${NC}"
    echo ""
    echo -e "${GREEN}🎉 Your application is now available at:${NC}"
    echo -e "${CYAN}https://$STATIC_URL${NC}"
    echo ""
    echo -e "${BLUE}Admin Panel:${NC}"
    echo -e "${CYAN}https://$STATIC_URL/admin/${NC}"
    echo ""
    echo -e "${BLUE}Process Info:${NC}"
    echo "Ngrok PID: $NGROK_PID"
    echo "Log file: /workspace/ngrok_static.log"
    echo ""
    
    # Test the connection
    echo -e "${BLUE}Testing connection...${NC}"
    sleep 2
    if curl -s -H "ngrok-skip-browser-warning: 1" "https://$STATIC_URL" | grep -q "html\|<!DOCTYPE" 2>/dev/null; then
        echo -e "${GREEN}✅ Static URL is responding!${NC}"
    else
        echo -e "${YELLOW}⚠️  Connection test inconclusive - URL may still be starting${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Setup complete! Your static URL is active.${NC}"
    echo -e "${BLUE}To stop ngrok: ${CYAN}kill $NGROK_PID${NC}"
    echo -e "${BLUE}To view logs: ${CYAN}tail -f /workspace/ngrok_static.log${NC}"
    
else
    echo -e "${RED}❌ Failed to start ngrok tunnel${NC}"
    echo "Check the log file for details:"
    cat /workspace/ngrok_static.log
    exit 1
fi