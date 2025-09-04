#!/bin/bash

# 🚀 Complete Deployment with Ngrok Authentication
# This script will help you complete the deployment with your ngrok auth token

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 NoctisPro Masterpiece - Complete Deployment${NC}"
echo -e "${CYAN}   Static URL: mallard-shining-curiously.ngrok-free.app${NC}"
echo ""

# Check if ngrok is already authenticated
if /workspace/ngrok config check > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Ngrok is already authenticated!${NC}"
    echo ""
    echo -e "${BLUE}🚀 Starting deployment...${NC}"
    /workspace/deploy_masterpiece_service.sh deploy
    exit 0
fi

echo -e "${YELLOW}⚠️  Ngrok authentication required${NC}"
echo ""
echo "To complete deployment with static URL 'mallard-shining-curiously.ngrok-free.app':"
echo ""
echo "1. Get your ngrok auth token:"
echo -e "   ${CYAN}https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
echo ""
echo "2. Configure ngrok:"
echo -e "   ${BLUE}/workspace/ngrok config add-authtoken YOUR_TOKEN_HERE${NC}"
echo ""
echo "3. Run deployment:"
echo -e "   ${BLUE}/workspace/deploy_masterpiece_service.sh deploy${NC}"
echo ""
echo -e "${GREEN}💡 Quick setup (copy and paste):${NC}"
echo -e "${CYAN}# Replace YOUR_TOKEN_HERE with your actual token${NC}"
echo -e "/workspace/ngrok config add-authtoken YOUR_TOKEN_HERE"
echo -e "/workspace/deploy_masterpiece_service.sh deploy"
echo ""

# Test the exact ngrok command format you specified
echo -e "${BLUE}🧪 Testing ngrok command format...${NC}"
echo -e "Command that will be used: ${CYAN}ngrok http --url=mallard-shining-curiously.ngrok-free.app 8000${NC}"
echo ""

# Show current Django status
echo -e "${BLUE}📊 Current Status:${NC}"
if curl -s http://localhost:8000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Django Server: Running on port 8000${NC}"
else
    echo -e "${YELLOW}⚠️  Django Server: Not running${NC}"
    echo "   Starting Django server..."
    cd /workspace/noctis_pro_deployment
    source venv/bin/activate
    nohup python manage.py runserver 0.0.0.0:8000 > ../django_server.log 2>&1 &
    sleep 3
    if curl -s http://localhost:8000 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Django Server: Started successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Django Server: Failed to start${NC}"
    fi
fi
echo ""
echo -e "${GREEN}🎯 Ready for deployment! Just add your ngrok auth token.${NC}"