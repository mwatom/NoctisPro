#!/bin/bash

# 🔍 Verify Ngrok Setup
# This script checks if everything is properly configured

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}🔍 NoctisPro Ngrok Setup Verification${NC}"
echo "========================================"
echo ""

# Function to check status
check_status() {
    local service="$1"
    local command="$2"
    
    echo -n "Checking $service... "
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
}

# Check ngrok binary
echo -e "${BLUE}📋 System Checks:${NC}"
check_status "Ngrok binary" "[ -f /workspace/ngrok ] && /workspace/ngrok version"

# Check Django directory
check_status "Django directory" "[ -d /workspace/noctis_pro_deployment ]"

# Check scripts
check_status "Fix scripts" "[ -x /workspace/fix_ngrok_now.sh ]"

echo ""

# Check authentication
echo -e "${BLUE}🔐 Authentication Status:${NC}"
if /workspace/ngrok config check > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Ngrok is authenticated${NC}"
    AUTH_STATUS="configured"
else
    echo -e "${YELLOW}⚠️  Ngrok authentication not configured${NC}"
    AUTH_STATUS="needed"
fi

echo ""

# Check running services
echo -e "${BLUE}🏃 Running Services:${NC}"
DJANGO_RUNNING=false
NGROK_RUNNING=false

if pgrep -f "manage.py runserver" > /dev/null; then
    echo -e "${GREEN}✅ Django server is running${NC}"
    DJANGO_RUNNING=true
else
    echo -e "${YELLOW}⚠️  Django server is not running${NC}"
fi

if pgrep -f ngrok > /dev/null; then
    echo -e "${GREEN}✅ Ngrok tunnel is running${NC}"
    NGROK_RUNNING=true
else
    echo -e "${YELLOW}⚠️  Ngrok tunnel is not running${NC}"
fi

echo ""

# Check connectivity
echo -e "${BLUE}🌐 Connectivity Tests:${NC}"
check_status "Django local access" "curl -s http://localhost:8000"

if [ -f "/workspace/current_ngrok_url.txt" ]; then
    NGROK_URL=$(cat /workspace/current_ngrok_url.txt)
    echo -n "Checking ngrok tunnel ($NGROK_URL)... "
    if curl -s "$NGROK_URL" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${YELLOW}⚠️  Not accessible (may still be starting)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No ngrok URL file found${NC}"
fi

echo ""

# Recommendations
echo -e "${CYAN}${BOLD}📋 Recommendations:${NC}"

if [ "$AUTH_STATUS" = "needed" ]; then
    echo -e "${YELLOW}1. Set up ngrok authentication:${NC}"
    echo -e "   Get token: ${BLUE}https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
    echo -e "   Run: ${BLUE}./fix_ngrok_now.sh YOUR_TOKEN${NC}"
    echo ""
fi

if [ "$DJANGO_RUNNING" = false ] || [ "$NGROK_RUNNING" = false ]; then
    echo -e "${YELLOW}2. Start services:${NC}"
    if [ "$AUTH_STATUS" = "configured" ]; then
        echo -e "   Run: ${BLUE}./fix_ngrok_now.sh${NC}"
    else
        echo -e "   Run: ${BLUE}./fix_ngrok_now.sh YOUR_TOKEN${NC}"
    fi
    echo ""
fi

if [ "$DJANGO_RUNNING" = true ] && [ "$NGROK_RUNNING" = true ]; then
    echo -e "${GREEN}✅ Everything looks good!${NC}"
    echo -e "   Access your app: ${CYAN}https://mallard-shining-curiously.ngrok-free.app${NC}"
    echo ""
fi

echo -e "${BLUE}📝 Log files:${NC}"
echo -e "   Django: ${YELLOW}/workspace/django_server.log${NC}"
echo -e "   Ngrok:  ${YELLOW}/workspace/ngrok_output.log${NC}"
echo ""

echo -e "${CYAN}${BOLD}🚀 Quick Commands:${NC}"
echo -e "   Fix everything: ${BLUE}./fix_ngrok_now.sh YOUR_TOKEN${NC}"
echo -e "   Stop all: ${BLUE}pkill -f 'manage.py\\|ngrok'${NC}"
echo -e "   Check logs: ${BLUE}tail -f /workspace/*.log${NC}"
echo ""