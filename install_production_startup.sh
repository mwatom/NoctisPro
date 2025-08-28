#!/bin/bash

# NoctisPro Production Startup Service Installation
# Sets up systemd service for Ubuntu Server with ngrok static URL

set -e

echo "🚀 NoctisPro Production Startup Service Installation"
echo "==================================================="
echo ""

WORKSPACE_DIR="/workspace"
SERVICE_NAME="noctispro-production-startup"
SERVICE_FILE="$SERVICE_NAME.service"

# Check if running as root or with sudo access
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    if ! sudo -n true 2>/dev/null; then
        echo "❌ This script requires sudo access"
        echo "Please run: sudo $0"
        exit 1
    fi
    SUDO="sudo"
fi

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

echo "Step 1: Verifying Prerequisites"
echo "==============================="

# Check if workspace exists
if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "❌ Workspace directory not found: $WORKSPACE_DIR"
    exit 1
fi

# Check if service file exists
if [ ! -f "$WORKSPACE_DIR/$SERVICE_FILE" ]; then
    echo "❌ Service file not found: $WORKSPACE_DIR/$SERVICE_FILE"
    exit 1
fi

# Check if startup script exists
if [ ! -f "$WORKSPACE_DIR/start_production_with_ngrok.sh" ]; then
    echo "❌ Startup script not found: $WORKSPACE_DIR/start_production_with_ngrok.sh"
    exit 1
fi

# Check if stop script exists
if [ ! -f "$WORKSPACE_DIR/stop_production_system.sh" ]; then
    echo "❌ Stop script not found: $WORKSPACE_DIR/stop_production_system.sh"
    exit 1
fi

echo "✅ All prerequisite files found"
echo ""

echo "Step 2: Checking System Dependencies"
echo "===================================="

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ Ngrok is not installed"
    echo "   Install ngrok: https://ngrok.com/download"
    exit 1
fi

# Check if Python virtual environment exists
if [ ! -d "$WORKSPACE_DIR/venv" ]; then
    echo "❌ Python virtual environment not found at $WORKSPACE_DIR/venv"
    echo "   Please create virtual environment first"
    exit 1
fi

# Check if PostgreSQL is available
if ! systemctl list-unit-files | grep -q postgresql; then
    echo "⚠️  PostgreSQL service not found. Installing..."
    $SUDO apt update
    $SUDO apt install -y postgresql postgresql-contrib
fi

# Check if Redis is available
if ! systemctl list-unit-files | grep -q redis-server; then
    echo "⚠️  Redis service not found. Installing..."
    $SUDO apt update
    $SUDO apt install -y redis-server
fi

echo "✅ System dependencies verified"
echo ""

echo "Step 3: Configuring Ngrok"
echo "========================="

# Check if ngrok auth token is configured
if ! ngrok config check >/dev/null 2>&1; then
    echo "⚠️  Ngrok auth token not configured!"
    echo ""
    echo "📋 To configure ngrok:"
    echo "   1. Visit: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "   2. Copy your auth token"
    echo "   3. Run: ngrok config add-authtoken <your-token>"
    echo ""
    read -p "Have you configured your ngrok auth token? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please configure ngrok auth token first, then run this script again."
        exit 1
    fi
    
    # Verify again
    if ! ngrok config check >/dev/null 2>&1; then
        echo "❌ Ngrok configuration still invalid"
        exit 1
    fi
fi

echo "✅ Ngrok authentication configured"

# Check static URL configuration
if [ -f "$WORKSPACE_DIR/.env.ngrok" ]; then
    source "$WORKSPACE_DIR/.env.ngrok"
    
    if [ "$NGROK_USE_STATIC" = "true" ]; then
        if [ ! -z "$NGROK_STATIC_URL" ]; then
            echo "✅ Static URL configured: https://$NGROK_STATIC_URL"
        elif [ ! -z "$NGROK_SUBDOMAIN" ]; then
            echo "✅ Static subdomain configured: https://$NGROK_SUBDOMAIN.ngrok.io"
        elif [ ! -z "$NGROK_DOMAIN" ]; then
            echo "✅ Custom domain configured: https://$NGROK_DOMAIN"
        else
            echo "⚠️  Static URL enabled but no URL/subdomain/domain configured"
            echo "   Edit $WORKSPACE_DIR/.env.ngrok to set NGROK_STATIC_URL, NGROK_SUBDOMAIN, or NGROK_DOMAIN"
        fi
    else
        echo "ℹ️  Using dynamic ngrok URLs (random URLs will be generated)"
    fi
else
    echo "⚠️  Ngrok environment file not found: $WORKSPACE_DIR/.env.ngrok"
    echo "   Creating default configuration..."
    
    cat > "$WORKSPACE_DIR/.env.ngrok" << EOF
# NoctisPro Ngrok Environment Configuration
NGROK_USE_STATIC=false
# NGROK_STATIC_URL=your-static-url.ngrok-free.app
# NGROK_SUBDOMAIN=your-subdomain
# NGROK_DOMAIN=your.custom.domain
NGROK_REGION=us
NGROK_TUNNEL_NAME=noctispro-http
NGROK_WEB_ADDR=localhost:4040
DJANGO_PORT=8000
DJANGO_HOST=0.0.0.0
ALLOWED_HOSTS="*"
DEBUG=False
USE_TZ=True
SECRET_KEY="noctis-pro-ngrok-secret-key-change-in-production"
EOF
    
    echo "   Default configuration created. Edit .env.ngrok to customize."
fi

echo ""

echo "Step 4: Installing Systemd Service"
echo "=================================="

# Stop existing service if running
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    log "Stopping existing $SERVICE_NAME service..."
    $SUDO systemctl stop "$SERVICE_NAME"
fi

# Copy service file
log "Installing service file..."
$SUDO cp "$WORKSPACE_DIR/$SERVICE_FILE" "/etc/systemd/system/"

# Set proper permissions
$SUDO chmod 644 "/etc/systemd/system/$SERVICE_FILE"

# Make scripts executable
log "Setting script permissions..."
chmod +x "$WORKSPACE_DIR/start_production_with_ngrok.sh"
chmod +x "$WORKSPACE_DIR/stop_production_system.sh"

# Reload systemd
log "Reloading systemd daemon..."
$SUDO systemctl daemon-reload

# Enable service for autostart
log "Enabling service for autostart..."
$SUDO systemctl enable "$SERVICE_NAME"

echo "✅ Service installed and enabled"
echo ""

echo "Step 5: Starting Dependencies"
echo "============================="

# Start and enable PostgreSQL
log "Starting PostgreSQL..."
$SUDO systemctl enable postgresql
$SUDO systemctl start postgresql

# Start and enable Redis
log "Starting Redis..."
$SUDO systemctl enable redis-server
$SUDO systemctl start redis-server

# Wait a moment for services to be ready
sleep 3

echo "✅ Dependencies started"
echo ""

echo "Step 6: Testing Service"
echo "======================"

# Test service start
log "Testing service start..."
if $SUDO systemctl start "$SERVICE_NAME"; then
    echo "✅ Service started successfully"
    
    # Wait a moment and check status
    sleep 10
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "✅ Service is running"
        
        # Try to get status
        echo ""
        echo "📊 Service Status:"
        echo "=================="
        systemctl status "$SERVICE_NAME" --no-pager -l
        
    else
        echo "❌ Service failed to stay running"
        echo "📋 Service logs:"
        journalctl -u "$SERVICE_NAME" --no-pager -l --since "5 minutes ago"
    fi
else
    echo "❌ Service failed to start"
    echo "📋 Service logs:"
    journalctl -u "$SERVICE_NAME" --no-pager -l --since "5 minutes ago"
fi

echo ""
echo "🎉 Installation Complete!"
echo "========================="
echo ""
echo "📋 Service Management Commands:"
echo "   Start:    sudo systemctl start $SERVICE_NAME"
echo "   Stop:     sudo systemctl stop $SERVICE_NAME"
echo "   Restart:  sudo systemctl restart $SERVICE_NAME"
echo "   Status:   sudo systemctl status $SERVICE_NAME"
echo "   Logs:     sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "📋 Configuration Files:"
echo "   Service:  /etc/systemd/system/$SERVICE_FILE"
echo "   Startup:  $WORKSPACE_DIR/start_production_with_ngrok.sh"
echo "   Stop:     $WORKSPACE_DIR/stop_production_system.sh"
echo "   Ngrok:    $WORKSPACE_DIR/.env.ngrok"
echo ""
echo "🔧 To modify configuration:"
echo "   1. Edit $WORKSPACE_DIR/.env.ngrok"
echo "   2. Run: sudo systemctl restart $SERVICE_NAME"
echo ""
echo "🌍 Access URLs:"
echo "   Local:    http://localhost:8000"
echo "   Ngrok UI: http://localhost:4040"

# Show ngrok URL if service is running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo ""
    echo "⏳ Checking for ngrok tunnel URL..."
    sleep 5
    
    # Try to get ngrok URL
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data.get('tunnels', []):
        if tunnel.get('proto') == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
" 2>/dev/null || true)
    
    if [ ! -z "$NGROK_URL" ]; then
        echo "   Public:   $NGROK_URL"
    else
        echo "   Public:   Check ngrok logs for URL"
    fi
fi

echo ""
echo "✅ NoctisPro Production Startup Service is now configured for boot!"
echo "   Your system will automatically start NoctisPro with ngrok on boot."