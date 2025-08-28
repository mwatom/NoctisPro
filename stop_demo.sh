#!/bin/bash

# 🏥 NoctisPro Demo System Stopper

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}🛑 Stopping NoctisPro Demo System${NC}"
echo "=================================="

# Stop Docker services
echo "Stopping Docker services..."
docker-compose -f docker-compose.production.yml down --remove-orphans

# Stop ngrok if running
echo "Stopping ngrok..."
pkill ngrok || true

# Clean up
echo "Cleaning up..."
rm -f current_ngrok_url.txt
rm -f ngrok.log

echo -e "${GREEN}✅ Demo system stopped successfully${NC}"