#!/bin/bash
echo "🏥 NOCTIS PRO PACS v2.0 - Manual Production Start"
echo "=============================================="

cd /workspace

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Activate virtual environment
echo -e "${YELLOW}🐍 Activating virtual environment...${NC}"
source venv/bin/activate

# Check if Django is ready
echo -e "${YELLOW}🔍 Checking Django configuration...${NC}"
python manage.py check --deploy --verbosity=0
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Django configuration issues detected${NC}"
    echo "Run: python manage.py check --deploy for details"
fi

# Start Gunicorn
echo -e "${YELLOW}🐍 Starting Django application server...${NC}"
pkill -f gunicorn 2>/dev/null
sleep 2

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
    GUNICORN_PID=$(pgrep -f "gunicorn.*noctis_pro" | head -1)
    echo "   Process ID: $GUNICORN_PID"
else
    echo -e "${RED}❌ Failed to start Gunicorn${NC}"
    echo "Check error log: tail -f /workspace/gunicorn_error.log"
    exit 1
fi

# Start Nginx (optional)
echo -e "${YELLOW}🌐 Starting Nginx...${NC}"
if command -v nginx &> /dev/null; then
    sudo nginx -t && sudo nginx -s reload 2>/dev/null || sudo nginx
    if pgrep -f nginx > /dev/null; then
        echo -e "${GREEN}✅ Nginx running on port 80${NC}"
    else
        echo -e "${YELLOW}⚠️  Nginx not configured or failed to start${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Nginx not installed${NC}"
fi

# Show current status
echo ""
echo -e "${GREEN}🎉 NOCTIS PRO PACS Started Successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Access Information:${NC}"
echo "   🏠 Local: http://localhost:8000"
echo "   🌍 For public access, run: ngrok http 8000"
echo ""
echo -e "${YELLOW}🔐 Default Login:${NC}"
echo "   👤 Create superuser: python manage.py createsuperuser"
echo ""
echo -e "${YELLOW}📊 Monitoring:${NC}"
echo "   📋 Status: ./check_noctispro_status.sh"
echo "   📝 Error Log: tail -f /workspace/gunicorn_error.log"
echo "   📝 Access Log: tail -f /workspace/gunicorn_access.log"
echo ""
echo -e "${YELLOW}🌍 Next steps for public access:${NC}"
echo "   1. Get ngrok token: https://dashboard.ngrok.com/get-started/your-authtoken"
echo "   2. Configure: ngrok authtoken YOUR_TOKEN"
echo "   3. Start tunnel: ngrok http 8000"
echo "   4. Access via provided ngrok URL"
echo ""
echo -e "${GREEN}✅ Django application ready for connections!${NC}"