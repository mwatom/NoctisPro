#!/bin/bash

# 🔑 NoctisPro Ngrok Token Setup Script

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔑 NoctisPro Ngrok Token Setup${NC}"
echo "=================================="
echo

if [[ -z "$1" ]]; then
    echo -e "${YELLOW}Usage: $0 <your-ngrok-authtoken>${NC}"
    echo
    echo "To get your authtoken:"
    echo "1. Visit: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "2. Copy your authtoken"
    echo "3. Run: $0 <your-token>"
    echo
    exit 1
fi

NGROK_TOKEN="$1"

echo -e "${CYAN}Setting up ngrok with your token...${NC}"

# Update the startup script with the real token
sed -i "s/YOUR_NGROK_TOKEN_HERE/$NGROK_TOKEN/g" /workspace/start_noctispro_complete.sh

echo -e "${GREEN}✅ Ngrok token configured successfully!${NC}"
echo
echo -e "${CYAN}You can now run:${NC}"
echo -e "${YELLOW}  ./start_noctispro_complete.sh${NC}"
echo