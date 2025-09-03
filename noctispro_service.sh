#!/bin/bash
# NoctisPro Refined System Startup Service
# Deploys the MASTERPIECE system, not the old one

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🚀 STARTING NOCTISPRO MASTERPIECE SYSTEM${NC}"

# Kill any old processes
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f ngrok 2>/dev/null || true

# Wait a moment
sleep 2

# Go to the REFINED system directory (the masterpiece)
cd /workspace/noctis_pro_deployment

# Activate virtual environment
source venv/bin/activate

echo -e "${BLUE}📊 Starting Django Server...${NC}"
# Start Django server in background
python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!

# Wait for Django to start
sleep 3

echo -e "${BLUE}🌐 Starting Ngrok Tunnel...${NC}"
# Start ngrok with static URL
cd /workspace
./ngrok http 8000 --hostname=colt-charmed-lark.ngrok-free.app > /workspace/ngrok.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to establish tunnel
sleep 5

echo -e "${GREEN}✅ NOCTISPRO MASTERPIECE DEPLOYED!${NC}"
echo -e "${GREEN}🌐 Access at: https://colt-charmed-lark.ngrok-free.app${NC}"
echo -e "${BLUE}📱 Local access: http://localhost:8000${NC}"

# Save PIDs for monitoring
echo $DJANGO_PID > /tmp/noctispro_django.pid
echo $NGROK_PID > /tmp/noctispro_ngrok.pid

# Keep the service running
wait $DJANGO_PID