#!/bin/bash

# 🚀 Quick NoctisPro PACS Deployment using existing scripts
# Uses your pre-configured static URL: mallard-shining-curiously.ngrok-free.app

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 Quick NoctisPro PACS Deployment${NC}"
echo "=================================="
echo ""

# Check if ngrok is configured
echo -e "${BLUE}Checking ngrok configuration...${NC}"
if ! ngrok config check > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Ngrok needs authentication. Running setup...${NC}"
    
    # Use your existing auth setup script
    if [ -f "/workspace/backup_scripts/setup_ngrok_auth.sh" ]; then
        bash /workspace/backup_scripts/setup_ngrok_auth.sh
    else
        echo -e "${RED}❌ Setup script not found. Please run:${NC}"
        echo "ngrok config add-authtoken YOUR_TOKEN"
        exit 1
    fi
    
    # Check again
    if ! ngrok config check > /dev/null 2>&1; then
        echo -e "${RED}❌ Ngrok still not configured. Please set up manually.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Ngrok is configured!${NC}"

# Start Django server if not running
if ! pgrep -f "manage.py runserver" > /dev/null; then
    echo -e "${BLUE}Starting Django server...${NC}"
    cd /workspace
    
    # Activate venv if it exists
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    
    # Start Django in background
    nohup python manage.py runserver 0.0.0.0:8000 > django_quick.log 2>&1 &
    echo -e "${GREEN}✅ Django server started${NC}"
    sleep 3
else
    echo -e "${GREEN}✅ Django server is already running${NC}"
fi

# Use your existing static URL script
echo -e "${BLUE}Starting ngrok with static URL...${NC}"
if [ -f "/workspace/backup_scripts/start_ngrok_static.sh" ]; then
    bash /workspace/backup_scripts/start_ngrok_static.sh
else
    echo -e "${RED}❌ Static URL script not found${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Deployment complete!${NC}"
echo -e "${CYAN}Your app is live at: https://mallard-shining-curiously.ngrok-free.app${NC}"