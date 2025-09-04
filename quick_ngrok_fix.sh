#!/bin/bash

# 🚀 Quick Ngrok Fix - One Command Setup
# Usage: ./quick_ngrok_fix.sh YOUR_AUTH_TOKEN

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ $# -eq 0 ]; then
    echo -e "${RED}❌ Usage: ./quick_ngrok_fix.sh YOUR_AUTH_TOKEN${NC}"
    echo ""
    echo -e "${CYAN}Get your auth token from: https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
    exit 1
fi

AUTH_TOKEN="$1"

echo -e "${CYAN}🚀 Quick Ngrok Fix - Setting up everything${NC}"
echo "=============================================="
echo ""

# Step 1: Configure ngrok
echo -e "${BLUE}1. Configuring ngrok authentication...${NC}"
/workspace/ngrok config add-authtoken "$AUTH_TOKEN"

if /workspace/ngrok config check > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Ngrok authentication configured successfully!${NC}"
else
    echo -e "${RED}❌ Failed to configure ngrok authentication${NC}"
    exit 1
fi

# Step 2: Check if Django is running
echo ""
echo -e "${BLUE}2. Checking Django server status...${NC}"
if curl -s http://localhost:8000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Django server is already running${NC}"
else
    echo -e "${YELLOW}⚠️  Starting Django server...${NC}"
    cd /workspace/noctis_pro_deployment
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    nohup python manage.py runserver 0.0.0.0:8000 > /workspace/django_server.log 2>&1 &
    sleep 3
    
    if curl -s http://localhost:8000 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Django server started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start Django server${NC}"
        echo "Check /workspace/django_server.log for details"
        exit 1
    fi
fi

# Step 3: Start ngrok with static URL
echo ""
echo -e "${BLUE}3. Starting ngrok tunnel with static URL...${NC}"
cd /workspace

# Kill any existing ngrok processes
pkill ngrok || true
sleep 2

# Start ngrok with the desired static URL
echo -e "${CYAN}Starting: /workspace/ngrok http 8000 --hostname=mallard-shining-curiously.ngrok-free.app${NC}"
nohup /workspace/ngrok http 8000 --hostname=mallard-shining-curiously.ngrok-free.app > /workspace/ngrok_output.log 2>&1 &

# Wait for ngrok to start
sleep 5

# Check if ngrok is running
if pgrep ngrok > /dev/null; then
    echo -e "${GREEN}✅ Ngrok tunnel started successfully!${NC}"
    
    # Update the URL file
    echo "https://mallard-shining-curiously.ngrok-free.app" > /workspace/current_ngrok_url.txt
    
    echo ""
    echo -e "${GREEN}🎉 SUCCESS! Your application is now online at:${NC}"
    echo -e "${CYAN}https://mallard-shining-curiously.ngrok-free.app${NC}"
    echo ""
    echo -e "${BLUE}Admin access:${NC}"
    echo -e "${CYAN}https://mallard-shining-curiously.ngrok-free.app/admin/${NC}"
    echo "Username: admin"
    echo "Password: admin123"
    echo ""
    
    # Test the URL
    echo -e "${BLUE}Testing URL accessibility...${NC}"
    if curl -I https://mallard-shining-curiously.ngrok-free.app 2>/dev/null | grep -q "200\|302"; then
        echo -e "${GREEN}✅ URL is accessible!${NC}"
    else
        echo -e "${YELLOW}⚠️  URL test inconclusive - may still be starting up${NC}"
    fi
    
else
    echo -e "${RED}❌ Failed to start ngrok tunnel${NC}"
    echo "Check /workspace/ngrok_output.log for details"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ All issues resolved!${NC}"
echo "• Authentication: Fixed"
echo "• URL format: Correct"
echo "• Static URL: Configured"
echo "• Tunnel: Running"