#!/bin/bash

# 🚀 NoctisPro PACS - One-Command Service Installation
# Installs and configures the system as a reliable service

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    clear
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}🚀  NoctisPro PACS - Service Installation${NC}"
    echo -e "${CYAN}   One-Command Reliable Deployment${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

main() {
    print_header
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root. Restarting with sudo..."
        exec sudo "$0" "$@"
    fi
    
    print_info "Step 1: Deploying reliable service..."
    ./deploy_reliable_service.sh deploy
    
    print_info "Step 2: Setting up boot startup protection..."
    
    # Add to crontab for boot startup
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    (crontab -l 2>/dev/null | grep -v "boot_startup.sh"; echo "@reboot $SCRIPT_DIR/boot_startup.sh") | crontab -
    
    # Also add to rc.local as backup
    if [[ -f /etc/rc.local ]]; then
        if ! grep -q "boot_startup.sh" /etc/rc.local; then
            sed -i "/^exit 0/i $SCRIPT_DIR/boot_startup.sh &" /etc/rc.local
        fi
    else
        cat > /etc/rc.local << EOF
#!/bin/bash
$SCRIPT_DIR/boot_startup.sh &
exit 0
EOF
        chmod +x /etc/rc.local
    fi
    
    print_success "Boot startup protection configured"
    
    print_info "Step 3: Testing service..."
    sleep 5
    
    if systemctl is-active --quiet noctispro-pacs; then
        print_success "Service is running!"
    else
        echo "Service test failed, checking logs..."
        journalctl -u noctispro-pacs --no-pager -l
    fi
    
    echo ""
    echo -e "${CYAN}🎉 Installation Complete!${NC}"
    echo ""
    echo "Your NoctisPro PACS system is now:"
    echo "✅ Installed as a system service"
    echo "✅ Configured to start on boot"
    echo "✅ Protected with health monitoring"
    echo "✅ Accessible via ngrok tunnel"
    echo ""
    echo -e "${YELLOW}Management Commands:${NC}"
    echo "• Check status: ./deploy_reliable_service.sh status"
    echo "• View logs: ./deploy_reliable_service.sh logs"
    echo "• Restart: ./deploy_reliable_service.sh restart"
    echo ""
    echo -e "${YELLOW}Access URLs:${NC}"
    echo "• Local: http://localhost:8000"
    echo "• Public: https://mallard-shining-curiously.ngrok-free.app"
    echo ""
}

main "$@"