#!/bin/bash

# 🔧 NoctisPro Ngrok Authentication Setup
# Quick setup script for ngrok authentication

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}🔧  NoctisPro Ngrok Authentication Setup${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

echo -e "${BLUE}ℹ️ Setting up ngrok authentication for NoctisPro deployment...${NC}"
echo ""

# Check if authtoken is provided as argument
if [ $# -eq 1 ]; then
    AUTHTOKEN="$1"
    echo -e "${GREEN}✅ Using provided authtoken${NC}"
else
    echo -e "${YELLOW}🔑 Please provide your ngrok authtoken:${NC}"
    echo ""
    echo -e "${BLUE}1. Go to: https://dashboard.ngrok.com/signup${NC}"
    echo -e "${BLUE}2. Create a free account (if you don't have one)${NC}"
    echo -e "${BLUE}3. Get your authtoken from: https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
    echo ""
    read -p "Enter your ngrok authtoken: " AUTHTOKEN
fi

# Validate authtoken format (basic check)
if [ ${#AUTHTOKEN} -lt 20 ]; then
    echo -e "${RED}🚨 Invalid authtoken format. Please check your token and try again.${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}ℹ️ Configuring ngrok with your authtoken...${NC}"

# Configure ngrok with authtoken
if /workspace/ngrok config add-authtoken "$AUTHTOKEN"; then
    echo -e "${GREEN}✅ Ngrok authtoken configured successfully!${NC}"
    echo ""
    
    # Verify configuration
    echo -e "${BLUE}ℹ️ Verifying configuration...${NC}"
    if /workspace/ngrok config check > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Ngrok configuration verified!${NC}"
        echo ""
        echo -e "${CYAN}🚀 Ready to deploy! Run:${NC}"
        echo -e "${YELLOW}   ./deploy_noctispro_online.sh${NC}"
        echo ""
        echo -e "${BLUE}📋 Your NoctisPro will be available at:${NC}"
        echo -e "${CYAN}   https://colt-charmed-lark.ngrok-free.app${NC}"
        echo ""
    else
        echo -e "${RED}🚨 Configuration verification failed. Please try again.${NC}"
        exit 1
    fi
else
    echo -e "${RED}🚨 Failed to configure ngrok authtoken. Please check your token and try again.${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Setup complete! You can now deploy NoctisPro online.${NC}"
echo ""