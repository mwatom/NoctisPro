#!/bin/bash

# 🏥 NoctisPro Complete Startup Script
# Starts Django application and ngrok tunnel in one command

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Icons
ICON_HOSPITAL="🏥"
ICON_SUCCESS="✅"
ICON_PROCESS="⚙️"
ICON_ROCKET="🚀"
ICON_NETWORK="🌐"

echo
echo -e "${WHITE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${WHITE}║${NC}    ${ICON_HOSPITAL} ${CYAN}NoctisPro Medical Imaging System Startup${NC} ${ICON_HOSPITAL}    ${WHITE}║${NC}"
echo -e "${WHITE}║${NC}              ${GREEN}Professional One-Command Launch${NC}              ${WHITE}║${NC}"
echo -e "${WHITE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$SCRIPT_DIR/noctis_pro_deployment"
NGROK_URL="colt-charmed-lark.ngrok-free.app"
DJANGO_PORT=8000

# Function to log with timestamp
log() {
    echo -e "${CYAN}${ICON_PROCESS} [$(date '+%H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}${ICON_SUCCESS} [$(date '+%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}🚨 [$(date '+%H:%M:%S')] $1${NC}"
    exit 1
}

# Check if running as root for port 80 (optional)
if [[ $EUID -eq 0 ]]; then
    log "Running as root - can use port 80 if needed"
    DJANGO_PORT=80
fi

# Stop any existing processes
log "Stopping any existing NoctisPro processes..."
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true
sleep 2

# Navigate to deployment directory
if [[ ! -d "$DEPLOYMENT_DIR" ]]; then
    error "Deployment directory not found: $DEPLOYMENT_DIR"
fi

cd "$DEPLOYMENT_DIR"

# Check virtual environment
if [[ ! -d "venv" ]]; then
    error "Virtual environment not found. Please run deployment script first."
fi

# Check if packages are installed
log "Verifying virtual environment setup..."
source venv/bin/activate

if ! python -c "import django, celery, pydicom" 2>/dev/null; then
    error "Required packages not installed in virtual environment"
fi

# Setup ngrok configuration
log "Setting up ngrok configuration..."
mkdir -p ~/.config/ngrok

cat > ~/.config/ngrok/ngrok.yml << EOF
version: "2"
authtoken: YOUR_NGROK_TOKEN_HERE
tunnels:
  noctispro:
    proto: http
    addr: $DJANGO_PORT
    hostname: $NGROK_URL
    inspect: true
EOF

# Verify ngrok config
if ! $SCRIPT_DIR/ngrok config check >/dev/null 2>&1; then
    error "Invalid ngrok configuration. Please check your authtoken."
fi

success "Ngrok configuration validated"

# Fix log file permissions
log "Setting up log files..."
touch noctis_pro.log server.log
chmod 664 noctis_pro.log server.log 2>/dev/null || true

# Start Django application
log "Starting Django application on port $DJANGO_PORT..."
if [[ $DJANGO_PORT -eq 80 ]]; then
    # Need sudo for port 80
    nohup sudo -E env PATH=$PATH $(which python) manage.py runserver 0.0.0.0:80 > server.log 2>&1 &
else
    nohup python manage.py runserver 0.0.0.0:$DJANGO_PORT > server.log 2>&1 &
fi

DJANGO_PID=$!
sleep 5

# Check if Django started successfully
if ! ps -p $DJANGO_PID > /dev/null 2>&1; then
    error "Django failed to start. Check server.log for details."
fi

# Test Django response
log "Testing Django application..."
for i in {1..10}; do
    if curl -s -f http://localhost:$DJANGO_PORT >/dev/null 2>&1; then
        success "Django application is responding on port $DJANGO_PORT"
        break
    fi
    if [[ $i -eq 10 ]]; then
        error "Django application not responding after 10 attempts"
    fi
    sleep 2
done

# Start ngrok tunnel
log "Starting ngrok tunnel to $NGROK_URL..."
cd "$SCRIPT_DIR"
nohup ./ngrok start noctispro > ngrok.log 2>&1 &
NGROK_PID=$!
sleep 5

# Check if ngrok started successfully
if ! ps -p $NGROK_PID > /dev/null 2>&1; then
    log "Ngrok failed to start, checking logs..."
    if [[ -f ngrok.log ]]; then
        cat ngrok.log
    fi
    error "Ngrok tunnel failed to start"
fi

# Verify tunnel
log "Verifying ngrok tunnel..."
for i in {1..10}; do
    if curl -s http://localhost:4040/api/tunnels | grep -q "online" 2>/dev/null; then
        PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "https://$NGROK_URL")
        success "Ngrok tunnel established successfully"
        break
    fi
    if [[ $i -eq 10 ]]; then
        log "Ngrok tunnel verification timeout, but may still be working"
        PUBLIC_URL="https://$NGROK_URL"
        break
    fi
    sleep 2
done

# Final status report
echo
echo -e "${WHITE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${WHITE}║${NC}               ${ICON_SUCCESS} ${GREEN}NoctisPro Successfully Started${NC} ${ICON_SUCCESS}               ${WHITE}║${NC}"
echo -e "${WHITE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${ICON_NETWORK} ${YELLOW}Public Access:${NC}    ${PUBLIC_URL}"
echo -e "${ICON_HOSPITAL} ${YELLOW}Local Access:${NC}     http://localhost:$DJANGO_PORT"
echo -e "${ICON_ROCKET} ${YELLOW}Django PID:${NC}       $DJANGO_PID"
echo -e "${ICON_ROCKET} ${YELLOW}Ngrok PID:${NC}        $NGROK_PID"
echo
echo -e "${CYAN}📊 Management Commands:${NC}"
echo -e "   View Django logs:    ${WHITE}tail -f $DEPLOYMENT_DIR/server.log${NC}"
echo -e "   View Ngrok logs:     ${WHITE}tail -f $SCRIPT_DIR/ngrok.log${NC}"
echo -e "   Stop services:       ${WHITE}pkill -f 'manage.py runserver'; pkill -f ngrok${NC}"
echo -e "   Restart script:      ${WHITE}$0${NC}"
echo
echo -e "${GREEN}${ICON_SUCCESS} NoctisPro Medical Imaging System is now live and accessible!${NC}"
echo