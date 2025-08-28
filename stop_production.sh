#!/bin/bash

# 🏥 NoctisPro Production System Stopper

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}🛑 Stopping NoctisPro Production System${NC}"
echo "======================================"

# Check if running as root/sudo
if [[ $EUID -eq 0 ]]; then
    SERVICE_CMD="systemctl"
    DOCKER_CMD="docker-compose"
else
    SERVICE_CMD="sudo systemctl"
    DOCKER_CMD="sudo docker-compose"
fi

# Stop system services if they exist
if systemctl list-unit-files | grep -q "noctispro-production.service"; then
    echo -e "${YELLOW}📋 Stopping system services...${NC}"
    $SERVICE_CMD stop noctispro-ngrok.service || true
    $SERVICE_CMD stop noctispro-production.service || true
    echo -e "${GREEN}✅ System services stopped${NC}"
else
    echo -e "${YELLOW}⚠️  System services not found. Stopping Docker directly...${NC}"
    
    if [ -f "docker-compose.production.yml" ]; then
        $DOCKER_CMD -f docker-compose.production.yml down
        echo -e "${GREEN}✅ Docker services stopped${NC}"
    fi
fi

# Stop any remaining ngrok processes
echo -e "${YELLOW}🌐 Stopping ngrok tunnels...${NC}"
pkill ngrok || true

# Clean up log files
echo -e "${YELLOW}🧹 Cleaning up...${NC}"
rm -f ngrok.log current_ngrok_url.txt

echo -e "${GREEN}✅ NoctisPro Production System Stopped${NC}"