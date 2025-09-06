#!/bin/bash
echo "🏥 NOCTIS PRO PACS - System Status Check"
echo "======================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Service Status:${NC}"

# Check Gunicorn
if pgrep -f "gunicorn.*noctis_pro" > /dev/null; then
    GUNICORN_PID=$(pgrep -f "gunicorn.*noctis_pro" | head -1)
    echo -e "   ${GREEN}✅ Gunicorn: Running (PID: $GUNICORN_PID)${NC}"
    
    # Check if port 8000 is listening
    if netstat -tlnp 2>/dev/null | grep :8000 > /dev/null || ss -tlnp 2>/dev/null | grep :8000 > /dev/null; then
        echo -e "   ${GREEN}✅ Port 8000: Listening${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Port 8000: Not listening${NC}"
    fi
else
    echo -e "   ${RED}❌ Gunicorn: Not running${NC}"
fi

# Check Nginx
if pgrep -f nginx > /dev/null; then
    echo -e "   ${GREEN}✅ Nginx: Running${NC}"
else
    echo -e "   ${YELLOW}⚠️  Nginx: Not running${NC}"
fi

# Check Ngrok
if pgrep -f ngrok > /dev/null; then
    echo -e "   ${GREEN}✅ Ngrok: Running${NC}"
    
    # Try to get ngrok URL
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['tunnels'][0]['public_url']) if data.get('tunnels') else print('No active tunnels')" 2>/dev/null)
    if [ "$NGROK_URL" != "No active tunnels" ] && [ ! -z "$NGROK_URL" ]; then
        echo -e "   ${GREEN}🌍 Public URL: $NGROK_URL${NC}"
    else
        echo -e "   ${YELLOW}⚠️  No active ngrok tunnels${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠️  Ngrok: Not running${NC}"
fi

# Check ports
echo ""
echo -e "${BLUE}🔌 Network Status:${NC}"
if command -v netstat &> /dev/null; then
    PORTS=$(netstat -tlnp 2>/dev/null | grep -E ":80|:8000|:4040")
elif command -v ss &> /dev/null; then
    PORTS=$(ss -tlnp 2>/dev/null | grep -E ":80|:8000|:4040")
else
    PORTS=""
fi

if [ ! -z "$PORTS" ]; then
    echo "$PORTS" | while read line; do
        if echo "$line" | grep -q ":8000"; then
            echo -e "   ${GREEN}✅ Django (8000): $line${NC}"
        elif echo "$line" | grep -q ":80"; then
            echo -e "   ${GREEN}✅ HTTP (80): $line${NC}"
        elif echo "$line" | grep -q ":4040"; then
            echo -e "   ${GREEN}✅ Ngrok Dashboard (4040): $line${NC}"
        fi
    done
else
    echo -e "   ${YELLOW}⚠️  No relevant ports found listening${NC}"
fi

# Check disk space
echo ""
echo -e "${BLUE}💾 Disk Space:${NC}"
df -h /workspace | tail -1 | awk '{print "   📁 /workspace: " $3 " used, " $4 " available (" $5 " used)"}'

# Check recent logs
echo ""
echo -e "${BLUE}📝 Recent Activity:${NC}"

if [ -f "/workspace/gunicorn_error.log" ]; then
    RECENT_ERRORS=$(tail -5 /workspace/gunicorn_error.log 2>/dev/null | grep -E "ERROR|CRITICAL" | wc -l)
    if [ $RECENT_ERRORS -gt 0 ]; then
        echo -e "   ${RED}❌ Recent errors in gunicorn log: $RECENT_ERRORS${NC}"
        echo -e "   ${YELLOW}   Run: tail -f /workspace/gunicorn_error.log${NC}"
    else
        echo -e "   ${GREEN}✅ No recent errors in gunicorn log${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠️  Gunicorn error log not found${NC}"
fi

if [ -f "/workspace/gunicorn_access.log" ]; then
    RECENT_REQUESTS=$(tail -10 /workspace/gunicorn_access.log 2>/dev/null | wc -l)
    if [ $RECENT_REQUESTS -gt 0 ]; then
        echo -e "   ${GREEN}✅ Recent requests logged: $RECENT_REQUESTS (last 10 lines)${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠️  Gunicorn access log not found${NC}"
fi

# Test connectivity
echo ""
echo -e "${BLUE}🌐 Connectivity Test:${NC}"

# Test local Django
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 2>/dev/null | grep -q "200\|301\|302"; then
    echo -e "   ${GREEN}✅ Local Django: Responding${NC}"
else
    echo -e "   ${RED}❌ Local Django: Not responding${NC}"
fi

# Test ngrok dashboard
if curl -s -o /dev/null -w "%{http_code}" http://localhost:4040 2>/dev/null | grep -q "200"; then
    echo -e "   ${GREEN}✅ Ngrok Dashboard: Accessible${NC}"
else
    echo -e "   ${YELLOW}⚠️  Ngrok Dashboard: Not accessible${NC}"
fi

echo ""
echo -e "${BLUE}🔧 Quick Actions:${NC}"
echo "   🚀 Start system: ./start_noctispro_manual.sh"
echo "   🔄 Restart gunicorn: pkill -f gunicorn && ./start_noctispro_manual.sh"
echo "   🌍 Start ngrok: ngrok http 8000"
echo "   📊 View logs: tail -f /workspace/gunicorn_error.log"
echo "   🌐 Ngrok dashboard: http://localhost:4040"

echo ""
if pgrep -f "gunicorn.*noctis_pro" > /dev/null; then
    echo -e "${GREEN}🎉 System Status: RUNNING${NC}"
else
    echo -e "${RED}⚠️  System Status: NOT RUNNING${NC}"
    echo -e "${YELLOW}   Run: ./start_noctispro_manual.sh to start${NC}"
fi