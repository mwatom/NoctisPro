#!/bin/bash

# 🏥 NoctisPro Quick Demo Starter
# Simple script to start the demo system

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🏥 Starting NoctisPro Demo System${NC}"
echo "=================================="

# Check if system is already deployed
if [ ! -f .env.production ]; then
    echo -e "${YELLOW}⚠️  System not deployed yet. Running full deployment...${NC}"
    ./deploy_for_demo.sh
    exit $?
fi

# Start the system
echo -e "${GREEN}🚀 Starting services...${NC}"
docker-compose -f docker-compose.production.yml up -d

# Wait for services
echo -e "${GREEN}⏳ Waiting for services to be ready...${NC}"
sleep 30

# Run health check
echo -e "${GREEN}🏥 Running health check...${NC}"
python3 health_check.py

# Display access info
echo
echo -e "${GREEN}✅ Demo system is ready!${NC}"
echo
echo "🌐 Access URLs:"
echo "  Local:  http://localhost:8000"

# Check for ngrok URL
if [ -f current_ngrok_url.txt ]; then
    NGROK_URL=$(cat current_ngrok_url.txt)
    echo "  Remote: $NGROK_URL"
fi

echo
echo "👤 Demo Accounts:"
echo "  Admin:  admin / demo123456"
echo "  Doctor: doctor / doctor123"
echo
echo "🔧 Management:"
echo "  Stop:   docker-compose -f docker-compose.production.yml down"
echo "  Logs:   docker-compose -f docker-compose.production.yml logs -f"
echo "  Health: python3 health_check.py"
echo