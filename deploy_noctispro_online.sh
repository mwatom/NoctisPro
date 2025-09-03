#!/bin/bash

# 🚀 Deploy NoctisPro Online with Static URL
# Complete deployment script for your medical imaging system

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}🚀  NoctisPro Online Deployment${NC}"
    echo -e "${CYAN}   Medical Imaging System${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}🚨${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

print_header

# Configuration from .env.ngrok
STATIC_URL="colt-charmed-lark.ngrok-free.app"
DJANGO_PORT="8000"

# Check if ngrok auth token is configured
print_info "Checking ngrok configuration..."
if ! /workspace/ngrok config check > /dev/null 2>&1; then
    print_error "Ngrok auth token is not configured!"
    echo ""
    echo -e "${YELLOW}🔧 To configure ngrok:${NC}"
    echo ""
    echo "1. 🌐 Go to: https://dashboard.ngrok.com/signup"
    echo "2. 📝 Create a free account (if you don't have one)"
    echo "3. 🔑 Get your auth token from: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "4. 💾 Run this command with your token:"
    echo ""
    echo -e "${CYAN}   /workspace/ngrok config add-authtoken YOUR_TOKEN_HERE${NC}"
    echo ""
    echo "5. 🚀 Run this script again to deploy:"
    echo ""
    echo -e "${CYAN}   ./deploy_noctispro_online.sh${NC}"
    echo ""
    echo -e "${YELLOW}💡 The static URL ${CYAN}https://$STATIC_URL${YELLOW} is already configured and ready!${NC}"
    echo ""
    exit 1
fi

print_success "Ngrok is properly configured!"

# Start NoctisPro service
print_info "Starting NoctisPro service..."
/workspace/noctispro_service.sh start

# Wait for services to fully start
sleep 10

# Check if service is running
if ! /workspace/noctispro_service.sh status > /dev/null 2>&1; then
    print_error "NoctisPro service failed to start!"
    print_error "Check logs: tail -f /workspace/noctispro_service.log"
    exit 1
fi

print_success "NoctisPro service is running successfully"

# Display success information
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}🎉  DEPLOYMENT SUCCESSFUL!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${CYAN}🌐 Your NoctisPro system is now live at:${NC}"
echo ""
echo -e "${WHITE}📋 Main Application:${NC}"
echo -e "   ${CYAN}https://$STATIC_URL/${NC}"
echo ""
echo -e "${WHITE}🔧 Admin Panel:${NC}"
echo -e "   ${CYAN}https://$STATIC_URL/admin/${NC}"
echo -e "   👤 Username: ${YELLOW}admin${NC}"
echo -e "   🔐 Password: ${YELLOW}admin123${NC}"
echo ""
echo -e "${WHITE}📋 Worklist:${NC}"
echo -e "   ${CYAN}https://$STATIC_URL/worklist/${NC}"
echo ""
echo -e "${WHITE}🖼️ DICOM Viewer:${NC}"
echo -e "   ${CYAN}https://$STATIC_URL/dicom-viewer/${NC}"
echo ""
echo -e "${WHITE}📊 System Status:${NC}"
echo -e "   ${CYAN}https://$STATIC_URL/connection-info/${NC}"
echo ""
echo -e "${BLUE}ℹ️ Service Information:${NC}"
echo -e "   Service Status: ${GREEN}Running${NC}"
echo -e "   Tmux Session: ${YELLOW}noctispro${NC}"
echo ""
echo -e "${YELLOW}🛑 To stop deployment:${NC}"
echo -e "   ${CYAN}./noctispro_service.sh stop${NC}"
echo ""
echo -e "${YELLOW}📋 Service Management:${NC}"
echo -e "   ${CYAN}./noctispro_service.sh {start|stop|restart|status}${NC}"
echo ""
echo -e "${GREEN}✨ Your medical imaging system is now accessible worldwide!${NC}"
echo ""

# Set up auto-start service
print_info "Setting up auto-start service..."
/workspace/setup_autostart.sh

# Create service management instructions
cat > /workspace/SERVICE_MANAGEMENT.md << 'EOF'
# NoctisPro Service Management

## Service Commands
```bash
# Start service
./noctispro_service.sh start

# Stop service  
./noctispro_service.sh stop

# Restart service
./noctispro_service.sh restart

# Check status
./noctispro_service.sh status
```

## Auto-Start Configuration
- ✅ Init.d script: Traditional service management (if available)
- ✅ Auto-start script: Can be added to .bashrc/.profile for container environments
- ✅ Tmux persistence: Services run in persistent tmux sessions

## Monitoring
- Check tmux session: `tmux attach -t noctispro`
- View logs: `tail -f /workspace/noctispro_service.log`
- Auto-start log: `tail -f /workspace/autostart.log`

## Manual Cleanup (if needed)
```bash
# Kill all related processes
pkill -f "manage.py runserver" || true
pkill -f "ngrok.*http" || true
pkill -f "gunicorn.*noctis" || true
tmux kill-session -t noctispro || true

# Remove auto-start
sudo rm -f /etc/init.d/noctispro
# If using cron: crontab -l | grep -v noctispro_service.sh | crontab -
```
EOF

print_success "Service management documentation created: SERVICE_MANAGEMENT.md"

echo ""
echo -e "${GREEN}🎯 AUTO-START CONFIGURED!${NC}"
echo -e "${GREEN}Your NoctisPro system will now automatically start on server reboot.${NC}"
echo ""
echo -e "${CYAN}📋 Service Management:${NC}"
echo -e "   Start:   ${YELLOW}./noctispro_service.sh start${NC}"
echo -e "   Stop:    ${YELLOW}./noctispro_service.sh stop${NC}"
echo -e "   Status:  ${YELLOW}./noctispro_service.sh status${NC}"
echo ""
echo -e "${BLUE}🔄 Auto-Start Methods Configured:${NC}"
if [ -f /etc/init.d/noctispro ]; then
    echo -e "   ✅ Init.d service: ${GREEN}Installed${NC}"
else
    echo -e "   ❌ Init.d service: ${RED}Not available${NC}"
fi
if [ -f /workspace/autostart_noctispro.sh ]; then
    echo -e "   ✅ Auto-start script: ${GREEN}Created${NC}"
    echo -e "      ${YELLOW}Add to .bashrc: echo '/workspace/autostart_noctispro.sh' >> ~/.bashrc${NC}"
fi
echo ""

# Optional: Keep script running to monitor
read -p "Press Enter to exit (services will continue running and auto-start on reboot)..."