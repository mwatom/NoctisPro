#!/bin/bash

# 🏥 NoctisPro Production System Starter

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🏥 Starting NoctisPro Production System${NC}"
echo "======================================"

# Check if running as root/sudo
if [[ $EUID -eq 0 ]]; then
    echo -e "${GREEN}✅ Running with administrative privileges${NC}"
    SERVICE_CMD="systemctl"
    DOCKER_CMD="docker-compose"
else
    echo -e "${YELLOW}⚠️  Running as regular user, using sudo${NC}"
    SERVICE_CMD="sudo systemctl"
    DOCKER_CMD="sudo docker-compose"
fi

# Check if system services exist
if systemctl list-unit-files | grep -q "noctispro-production.service"; then
    echo -e "${GREEN}📋 Starting system services...${NC}"
    $SERVICE_CMD start noctispro-production.service
    $SERVICE_CMD start noctispro-ngrok.service
    
    echo -e "${GREEN}⏳ Waiting for services to be ready...${NC}"
    sleep 30
    
    echo -e "${GREEN}📊 Service Status:${NC}"
    $SERVICE_CMD status noctispro-production.service --no-pager -l
    $SERVICE_CMD status noctispro-ngrok.service --no-pager -l
    
else
    echo -e "${YELLOW}⚠️  System services not found. Starting with Docker directly...${NC}"
    
    # Check if in production directory
    if [ -f "docker-compose.production.yml" ]; then
        echo -e "${GREEN}🐳 Starting Docker services...${NC}"
        $DOCKER_CMD -f docker-compose.production.yml up -d
        
        echo -e "${GREEN}⏳ Waiting for services to be ready...${NC}"
        sleep 30
        
        # Start ngrok separately
        echo -e "${GREEN}🌐 Starting ngrok tunnel...${NC}"
        nohup ngrok http --url=colt-charmed-lark.ngrok-free.app 80 --log=stdout > ngrok.log 2>&1 &
        
    else
        echo -e "${RED}❌ Production configuration not found${NC}"
        echo "Please run the production deployment script first:"
        echo "sudo ./production_deployment.sh"
        exit 1
    fi
fi

# Wait a bit more and test
sleep 30

echo -e "${GREEN}🧪 Testing system access...${NC}"

# Test local access
if curl -s http://localhost:8000/health/simple/ > /dev/null; then
    echo -e "${GREEN}✅ Local access: http://localhost:8000${NC}"
else
    echo -e "${RED}❌ Local access failed${NC}"
fi

# Test ngrok tunnel
if curl -s https://colt-charmed-lark.ngrok-free.app/health/simple/ > /dev/null; then
    echo -e "${GREEN}✅ Remote access: https://colt-charmed-lark.ngrok-free.app${NC}"
else
    echo -e "${YELLOW}⚠️  Remote access not ready yet (ngrok may still be starting)${NC}"
fi

echo
echo -e "${GREEN}🎉 NoctisPro Production System Started!${NC}"
echo
echo "🌐 Access URLs:"
echo "  Local:  http://localhost:8000"
echo "  Remote: https://colt-charmed-lark.ngrok-free.app"
echo
echo "🔧 Management Commands:"
echo "  Stop:    sudo systemctl stop noctispro-production noctispro-ngrok"
echo "  Restart: sudo systemctl restart noctispro-production noctispro-ngrok"
echo "  Status:  sudo systemctl status noctispro-production noctispro-ngrok"
echo "  Logs:    sudo journalctl -u noctispro-production -f"
echo