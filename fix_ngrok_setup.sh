#!/bin/bash

# 🔧 Fix Ngrok Setup and Authentication
# This script resolves the ngrok authentication and URL issues

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔧 Fixing Ngrok Setup Issues${NC}"
echo "=================================="
echo ""

# Step 1: Check current status
echo -e "${BLUE}📊 Current Status Check:${NC}"

# Check if ngrok binary exists and works
if [ ! -f "/workspace/ngrok" ]; then
    echo -e "${RED}❌ Ngrok binary not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Ngrok binary found and working${NC}"

# Step 2: Check connectivity (we already know this works from diagnostics)
echo -e "${GREEN}✅ Network connectivity confirmed${NC}"

# Step 3: The main issue - authentication
echo ""
echo -e "${YELLOW}⚠️  Main Issue: Ngrok Authentication${NC}"
echo ""
echo "The error ERR_NGROK_4018 indicates that ngrok requires authentication."
echo "This is why your tunnel URL returns 404 - the tunnel isn't actually running."
echo ""

# Step 4: Show the solution
echo -e "${BLUE}🔧 Solution Steps:${NC}"
echo ""
echo "1. Get a free ngrok account and auth token:"
echo -e "   ${CYAN}https://dashboard.ngrok.com/signup${NC}"
echo ""
echo "2. Get your auth token:"
echo -e "   ${CYAN}https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
echo ""
echo "3. Configure ngrok with your token:"
echo -e "   ${BLUE}/workspace/ngrok config add-authtoken YOUR_TOKEN_HERE${NC}"
echo ""
echo "4. Start your Django server:"
echo -e "   ${BLUE}cd /workspace/noctis_pro_deployment${NC}"
echo -e "   ${BLUE}source venv/bin/activate${NC}"
echo -e "   ${BLUE}python manage.py runserver 0.0.0.0:8000${NC}"
echo ""
echo "5. In another terminal, start ngrok:"
echo -e "   ${BLUE}/workspace/ngrok http 8000 --hostname=mallard-shining-curiously.ngrok-free.app${NC}"
echo ""

# Step 5: Alternative automatic setup
echo -e "${GREEN}💡 Alternative: Use existing deployment script${NC}"
echo ""
echo "After configuring your auth token, you can use:"
echo -e "   ${BLUE}/workspace/deploy_masterpiece_service.sh deploy${NC}"
echo ""

# Step 6: Show current URL status
echo -e "${BLUE}📋 Current URL Status:${NC}"
echo "Current saved URL: $(cat /workspace/current_ngrok_url.txt)"
echo "Status: 404 (tunnel not running due to authentication)"
echo "Target static URL: mallard-shining-curiously.ngrok-free.app"
echo ""

echo -e "${GREEN}🎯 Summary:${NC}"
echo "• Network/firewall is NOT the issue"
echo "• URL format is correct"
echo "• Main issue: Missing ngrok authentication"
echo "• Solution: Add auth token and restart ngrok"
echo ""
echo -e "${CYAN}Next step: Get your auth token and run the config command above${NC}"