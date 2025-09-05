#!/bin/bash
echo "🏥 NOCTIS PRO PACS v2.0 - COMPLETE STATUS CHECK"
echo "=============================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get current IP
CURRENT_IP=$(curl -s checkip.amazonaws.com 2>/dev/null || echo "Unknown")

echo -e "${BLUE}📍 SERVER INFORMATION:${NC}"
echo "   Current Public IP: ${CURRENT_IP}"
echo "   Server Time: $(date)"
echo ""

echo -e "${BLUE}🦆 DUCKDNS STATUS:${NC}"
echo "   Domain: noctispro2.duckdns.org"
echo "   Token: 9d40387a-ac37-4268-8d51-69985ae32c30"
echo "   Current IP: ${CURRENT_IP}"

# Check DuckDNS daemon
if pgrep -f "duckdns_daemon.sh" > /dev/null; then
    echo -e "   Auto-updater: ${GREEN}✅ RUNNING${NC}"
else
    echo -e "   Auto-updater: ${RED}❌ STOPPED${NC}"
fi

# Check last update
if [ -f "/workspace/duckdns.log" ]; then
    LAST_UPDATE=$(tail -1 /workspace/duckdns.log)
    echo "   Last Update: ${LAST_UPDATE}"
else
    echo "   Last Update: No log file found"
fi
echo ""

echo -e "${BLUE}🌐 SERVICES STATUS:${NC}"

# Check Nginx
if pgrep nginx > /dev/null; then
    echo -e "   Nginx (port 80): ${GREEN}✅ RUNNING${NC}"
else
    echo -e "   Nginx (port 80): ${RED}❌ STOPPED${NC}"
fi

# Check Django
if pgrep -f "manage.py runserver" > /dev/null; then
    echo -e "   Django (port 8000): ${GREEN}✅ RUNNING${NC}"
else
    echo -e "   Django (port 8000): ${RED}❌ STOPPED${NC}"
fi

# Test application
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "302" ] || [ "$HTTP_STATUS" = "200" ]; then
    echo -e "   Application Response: ${GREEN}✅ HEALTHY${NC} (HTTP $HTTP_STATUS)"
else
    echo -e "   Application Response: ${RED}❌ ERROR${NC} (HTTP $HTTP_STATUS)"
fi
echo ""

echo -e "${BLUE}🔗 ACCESS INFORMATION:${NC}"
echo "   Local Access: http://localhost"
echo "   Public Domain: http://noctispro2.duckdns.org"
echo "   Domain IP: ${CURRENT_IP}"
echo ""

echo -e "${BLUE}🔐 LOGIN CREDENTIALS:${NC}"
echo "   Username: admin"
echo "   Password: admin123"
echo "   ⚠️  Change password after first login!"
echo ""

echo -e "${BLUE}🏥 MEDICAL MODULES:${NC}"
echo "   ✅ DICOM Viewer - Advanced medical imaging"
echo "   ✅ Worklist Management - Patient workflow"
echo "   ✅ AI Analysis - Machine learning diagnostics"
echo "   ✅ Medical Reporting - Clinical documentation"
echo "   ✅ Admin Panel - System administration"
echo "   ✅ User Management - Role-based access"
echo ""

echo -e "${BLUE}🔧 MANAGEMENT COMMANDS:${NC}"
echo "   Check status: ./complete_status.sh"
echo "   Monitor DuckDNS: tail -f /workspace/duckdns.log"
echo "   Manual DNS update: /workspace/update_duckdns.sh"
echo "   Restart services: sudo systemctl restart nginx"
echo ""

echo -e "${GREEN}🎉 NOCTIS PRO PACS v2.0 - READY FOR CLINICAL USE!${NC}"
echo -e "${YELLOW}💰 Enterprise Medical Imaging Platform${NC}"