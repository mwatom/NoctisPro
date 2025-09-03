#!/bin/bash

# 🔧 Setup Auto-Start for NoctisPro
# This script helps configure auto-start in different environments

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

echo -e "${BLUE}🔧 Setting up NoctisPro Auto-Start...${NC}"
echo ""

# Method 1: Init.d (for traditional Linux systems)
if [ -w /etc/init.d/ ] 2>/dev/null; then
    print_info "Installing init.d service..."
    sudo cp /workspace/noctispro-init /etc/init.d/noctispro
    sudo chmod +x /etc/init.d/noctispro
    sudo update-rc.d noctispro defaults 2>/dev/null || true
    print_success "Init.d service installed"
else
    print_warning "Init.d not available (container environment or no sudo access)"
fi

# Method 2: Cron job (if available)
if command -v crontab > /dev/null 2>&1; then
    print_info "Setting up cron job..."
    (crontab -l 2>/dev/null; echo "@reboot /workspace/noctispro_service.sh start > /workspace/autostart.log 2>&1") | sort -u | crontab -
    print_success "Cron job installed"
else
    print_warning "Cron not available"
fi

# Method 3: Profile/bashrc auto-start (for containers)
print_info "Setting up profile auto-start..."
if [ -f ~/.bashrc ]; then
    # Remove any existing auto-start lines
    grep -v "autostart_noctispro.sh" ~/.bashrc > ~/.bashrc.tmp 2>/dev/null || cp ~/.bashrc ~/.bashrc.tmp
    # Add new auto-start line
    echo "" >> ~/.bashrc.tmp
    echo "# NoctisPro auto-start" >> ~/.bashrc.tmp
    echo "/workspace/autostart_noctispro.sh 2>/dev/null || true" >> ~/.bashrc.tmp
    mv ~/.bashrc.tmp ~/.bashrc
    print_success "Added auto-start to ~/.bashrc"
fi

if [ -f ~/.profile ]; then
    # Remove any existing auto-start lines
    grep -v "autostart_noctispro.sh" ~/.profile > ~/.profile.tmp 2>/dev/null || cp ~/.profile ~/.profile.tmp
    # Add new auto-start line
    echo "" >> ~/.profile.tmp
    echo "# NoctisPro auto-start" >> ~/.profile.tmp
    echo "/workspace/autostart_noctispro.sh 2>/dev/null || true" >> ~/.profile.tmp
    mv ~/.profile.tmp ~/.profile
    print_success "Added auto-start to ~/.profile"
fi

echo ""
print_success "Auto-start setup complete!"
echo ""
echo -e "${YELLOW}📋 Auto-start methods configured:${NC}"
[ -f /etc/init.d/noctispro ] && echo -e "   ✅ Init.d service"
command -v crontab > /dev/null 2>&1 && echo -e "   ✅ Cron job"
[ -f ~/.bashrc ] && echo -e "   ✅ Bashrc auto-start"
[ -f ~/.profile ] && echo -e "   ✅ Profile auto-start"
echo ""
echo -e "${BLUE}ℹ️ Your NoctisPro system will now start automatically!${NC}"