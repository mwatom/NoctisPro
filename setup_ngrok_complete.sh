#!/bin/bash

# 🚀 Complete Ngrok Setup - Access From Anywhere
# This script sets up ngrok properly for global access
# Usage: ./setup_ngrok_complete.sh [YOUR_AUTH_TOKEN]

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
NGROK_BINARY="/workspace/ngrok"
DJANGO_DIR="/workspace/noctis_pro_deployment"
DJANGO_PORT=8000
STATIC_DOMAIN="mallard-shining-curiously.ngrok-free.app"
CURRENT_URL_FILE="/workspace/current_ngrok_url.txt"

echo -e "${CYAN}${BOLD}🚀 NoctisPro - Complete Ngrok Setup${NC}"
echo -e "${CYAN}${BOLD}   Access Your App From Anywhere${NC}"
echo "=================================================="
echo ""

# Function to print section headers
print_section() {
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo "$(printf '=%.0s' {1..50})"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if Django is running
check_django() {
    curl -s -o /dev/null -w "%{http_code}" http://localhost:$DJANGO_PORT 2>/dev/null
}

# Function to start Django server
start_django() {
    echo -e "${YELLOW}Starting Django server...${NC}"
    cd "$DJANGO_DIR"
    
    # Activate virtual environment if it exists
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    
    # Kill any existing Django processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    sleep 2
    
    # Start Django server in background
    nohup python manage.py runserver 0.0.0.0:$DJANGO_PORT > /workspace/django_server.log 2>&1 &
    
    # Wait for server to start
    echo -e "${YELLOW}Waiting for Django server to start...${NC}"
    for i in {1..10}; do
        sleep 2
        if [ "$(check_django)" = "200" ]; then
            echo -e "${GREEN}✅ Django server started successfully${NC}"
            return 0
        fi
    done
    
    echo -e "${RED}❌ Failed to start Django server${NC}"
    return 1
}

# Function to setup ngrok authentication
setup_ngrok_auth() {
    local auth_token="$1"
    
    echo -e "${YELLOW}Setting up ngrok authentication...${NC}"
    
    # Create ngrok config directory
    mkdir -p ~/.config/ngrok
    
    # Configure authentication
    "$NGROK_BINARY" config add-authtoken "$auth_token"
    
    # Verify configuration
    if "$NGROK_BINARY" config check > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Ngrok authentication configured successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to configure ngrok authentication${NC}"
        return 1
    fi
}

# Function to start ngrok tunnel
start_ngrok_tunnel() {
    echo -e "${YELLOW}Starting ngrok tunnel...${NC}"
    
    # Kill any existing ngrok processes
    pkill -f ngrok 2>/dev/null || true
    sleep 2
    
    # Start ngrok with static domain
    echo -e "${CYAN}Using static domain: $STATIC_DOMAIN${NC}"
    nohup "$NGROK_BINARY" http --url="$STATIC_DOMAIN" $DJANGO_PORT > /workspace/ngrok_tunnel.log 2>&1 &
    
    # Wait for tunnel to establish
    echo -e "${YELLOW}Waiting for tunnel to establish...${NC}"
    for i in {1..15}; do
        sleep 2
        if curl -s "https://$STATIC_DOMAIN" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Ngrok tunnel established successfully${NC}"
            echo "https://$STATIC_DOMAIN" > "$CURRENT_URL_FILE"
            return 0
        fi
    done
    
    echo -e "${RED}❌ Failed to establish ngrok tunnel${NC}"
    echo "Check logs: /workspace/ngrok_tunnel.log"
    return 1
}

# Function to create autostart service
create_autostart_service() {
    echo -e "${YELLOW}Creating autostart service...${NC}"
    
    cat > /workspace/noctispro-autostart.sh << 'EOF'
#!/bin/bash
# NoctisPro Autostart Script

cd /workspace

# Start Django server
cd /workspace/noctis_pro_deployment
if [ -d "venv" ]; then
    source venv/bin/activate
fi
nohup python manage.py runserver 0.0.0.0:8000 > /workspace/django_server.log 2>&1 &

# Wait for Django to start
sleep 5

# Start ngrok tunnel
cd /workspace
nohup ./ngrok http --url=mallard-shining-curiously.ngrok-free.app 8000 > /workspace/ngrok_tunnel.log 2>&1 &

echo "NoctisPro started successfully!"
echo "Access at: https://mallard-shining-curiously.ngrok-free.app"
EOF

    chmod +x /workspace/noctispro-autostart.sh
    echo -e "${GREEN}✅ Autostart script created: /workspace/noctispro-autostart.sh${NC}"
}

# Main execution
print_section "📋 Pre-flight Checks"

# Check if ngrok binary exists
if [ ! -f "$NGROK_BINARY" ]; then
    echo -e "${RED}❌ Ngrok binary not found at $NGROK_BINARY${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Ngrok binary found${NC}"

# Check if Django directory exists
if [ ! -d "$DJANGO_DIR" ]; then
    echo -e "${RED}❌ Django directory not found at $DJANGO_DIR${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Django directory found${NC}"

echo ""

# Handle authentication
print_section "🔐 Ngrok Authentication Setup"

if [ $# -eq 0 ]; then
    # Check if already authenticated
    if "$NGROK_BINARY" config check > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Ngrok is already authenticated${NC}"
    else
        echo -e "${YELLOW}⚠️  Ngrok authentication required${NC}"
        echo ""
        echo "To get your auth token:"
        echo -e "1. Visit: ${CYAN}https://dashboard.ngrok.com/signup${NC}"
        echo -e "2. Create a free account"
        echo -e "3. Get your auth token: ${CYAN}https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
        echo ""
        echo -e "Then run: ${BLUE}./setup_ngrok_complete.sh YOUR_AUTH_TOKEN${NC}"
        echo ""
        echo -e "${CYAN}💡 Or continue with manual setup (ngrok will prompt for auth)${NC}"
        read -p "Continue without auth token? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
else
    AUTH_TOKEN="$1"
    if ! setup_ngrok_auth "$AUTH_TOKEN"; then
        exit 1
    fi
fi

echo ""

# Start Django server
print_section "🐍 Django Server Setup"

if [ "$(check_django)" = "200" ]; then
    echo -e "${GREEN}✅ Django server is already running${NC}"
else
    if ! start_django; then
        exit 1
    fi
fi

echo ""

# Start ngrok tunnel
print_section "🌐 Ngrok Tunnel Setup"

if ! start_ngrok_tunnel; then
    echo -e "${YELLOW}⚠️  Tunnel setup failed, but you can start manually:${NC}"
    echo -e "${BLUE}$NGROK_BINARY http --url=$STATIC_DOMAIN $DJANGO_PORT${NC}"
fi

echo ""

# Create autostart service
print_section "🚀 Autostart Setup"
create_autostart_service

echo ""

# Final status and instructions
print_section "✅ Setup Complete!"

echo -e "${GREEN}${BOLD}🎉 NoctisPro is now accessible from anywhere!${NC}"
echo ""
echo -e "${CYAN}${BOLD}Access URLs:${NC}"
echo -e "🌐 Public URL: ${GREEN}https://$STATIC_DOMAIN${NC}"
echo -e "🏠 Local URL:  ${YELLOW}http://localhost:$DJANGO_PORT${NC}"
echo ""

echo -e "${CYAN}${BOLD}Quick Commands:${NC}"
echo -e "🚀 Restart everything: ${BLUE}./noctispro-autostart.sh${NC}"
echo -e "📊 Check Django:       ${BLUE}curl http://localhost:$DJANGO_PORT${NC}"
echo -e "🔍 Check tunnel:       ${BLUE}curl https://$STATIC_DOMAIN${NC}"
echo -e "📝 View Django logs:   ${BLUE}tail -f /workspace/django_server.log${NC}"
echo -e "📝 View ngrok logs:    ${BLUE}tail -f /workspace/ngrok_tunnel.log${NC}"
echo ""

echo -e "${CYAN}${BOLD}Process Management:${NC}"
echo -e "🛑 Stop all:           ${BLUE}pkill -f 'manage.py\\|ngrok'${NC}"
echo -e "🔄 Restart Django:     ${BLUE}pkill -f manage.py && cd $DJANGO_DIR && python manage.py runserver 0.0.0.0:$DJANGO_PORT &${NC}"
echo -e "🔄 Restart ngrok:      ${BLUE}pkill -f ngrok && $NGROK_BINARY http --url=$STATIC_DOMAIN $DJANGO_PORT &${NC}"
echo ""

echo -e "${GREEN}${BOLD}🎯 Your app is now live and accessible from anywhere in the world!${NC}"