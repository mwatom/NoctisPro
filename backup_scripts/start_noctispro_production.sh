#!/bin/bash
echo "🏥 NOCTIS PRO PACS v2.0 - PRODUCTION AUTO-START"
echo "=============================================="
echo "🚀 Starting all services with public access..."
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cd /workspace

# 1. Start/Restart Nginx
echo -e "${YELLOW}🌐 Starting Nginx reverse proxy...${NC}"
sudo nginx -t && sudo nginx -s reload 2>/dev/null || sudo nginx
if pgrep -f "nginx" > /dev/null; then
    echo -e "${GREEN}✅ Nginx running on port 80${NC}"
else
    echo "❌ Failed to start Nginx"
    exit 1
fi

# 2. Start/Restart Gunicorn
echo -e "${YELLOW}🐍 Starting Django application server...${NC}"
pkill -f gunicorn 2>/dev/null
sleep 2

source venv/bin/activate
nohup gunicorn noctis_pro.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers 3 \
    --timeout 1800 \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --preload \
    --access-logfile /workspace/gunicorn_access.log \
    --error-logfile /workspace/gunicorn_error.log \
    --daemon

sleep 3
if pgrep -f "gunicorn.*noctis_pro" > /dev/null; then
    echo -e "${GREEN}✅ Gunicorn running on port 8000${NC}"
else
    echo "❌ Failed to start Gunicorn"
    exit 1
fi

# 3. Start Ngrok tunnel (ALWAYS) - with auth token check
echo -e "${YELLOW}🌍 Starting ngrok public tunnel...${NC}"
pkill -f ngrok 2>/dev/null
sleep 2

# Check if ngrok auth token is configured
if ! ngrok config check > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Ngrok auth token not configured${NC}"
    echo "   Please run: ngrok config add-authtoken YOUR_TOKEN"
    echo "   Get your token from: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "   For now, starting without public tunnel..."
    echo ""
else
    # Start ngrok in background with logging
    nohup ngrok http --url=mallard-shining-curiously.ngrok-free.app 80 \
        > /workspace/ngrok.log 2>&1 &

    # Wait for ngrok to start
    sleep 5

    if pgrep -f ngrok > /dev/null; then
        echo -e "${GREEN}✅ Ngrok tunnel active${NC}"
        echo "   🌍 Public URL: https://mallard-shining-curiously.ngrok-free.app"
    else
        echo -e "${YELLOW}⚠️  Ngrok tunnel failed to start - check logs${NC}"
        echo "   📝 Logs: tail -f /workspace/ngrok.log"
    fi
fi

echo ""
echo -e "${GREEN}🎉 NOCTIS PRO PACS PRODUCTION READY WITH PUBLIC ACCESS!${NC}"
echo ""
echo -e "${BLUE}📋 ACCESS INFORMATION:${NC}"
echo "   🏠 Local Domain: http://noctispro"
echo "   🌍 Public Domain: https://mallard-shining-curiously.ngrok-free.app"
echo ""
echo -e "${BLUE}🔐 LOGIN CREDENTIALS:${NC}"
echo "   👤 Username: admin"
echo "   🔑 Password: admin123"
echo ""
echo -e "${BLUE}📊 MONITORING:${NC}"
echo "   📋 System Status: ./noctispro_status.sh"
echo "   📝 Ngrok Logs: tail -f /workspace/ngrok.log"
echo "   📝 Gunicorn Logs: tail -f /workspace/gunicorn_*.log"
echo ""
echo -e "${GREEN}✅ All services running with automatic public access!${NC}"
