#!/bin/bash

# NoctisPro Auto-Start Installation Script
# Sets up systemd service for automatic startup on boot

set -e

WORKSPACE_DIR="/workspace"
SERVICE_NAME="noctispro-complete"
SERVICE_FILE="${SERVICE_NAME}.service"

echo "🚀 Installing NoctisPro Auto-Start Service"
echo "==========================================="
echo ""

# Check if running as root or with sudo
if [ "$EUID" -eq 0 ]; then
    echo "ℹ️  Running as root"
    SUDO=""
else
    echo "ℹ️  Checking sudo access..."
    if sudo -n true 2>/dev/null; then
        SUDO="sudo"
    else
        echo "❌ This script requires sudo access for systemd service installation"
        echo "Please run: sudo $0"
        exit 1
    fi
fi

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

# Check if service file exists
if [ ! -f "$WORKSPACE_DIR/$SERVICE_FILE" ]; then
    echo "❌ Service file $SERVICE_FILE not found in $WORKSPACE_DIR"
    exit 1
fi

log "Installing systemd service..."

# Copy service file to systemd directory
$SUDO cp "$WORKSPACE_DIR/$SERVICE_FILE" "/etc/systemd/system/"
log "✅ Service file copied to /etc/systemd/system/"

# Set correct permissions
$SUDO chmod 644 "/etc/systemd/system/$SERVICE_FILE"
log "✅ Service file permissions set"

# Reload systemd daemon
$SUDO systemctl daemon-reload
log "✅ Systemd daemon reloaded"

# Enable the service
$SUDO systemctl enable "$SERVICE_NAME"
log "✅ Service enabled for auto-start"

# Check if ngrok auth token is configured
log "Checking ngrok configuration..."
if [ -f "$WORKSPACE_DIR/.env.ngrok" ]; then
    if grep -q "NGROK_AUTHTOKEN=" "$WORKSPACE_DIR/.env.ngrok" && ! grep -q "NGROK_AUTHTOKEN=$" "$WORKSPACE_DIR/.env.ngrok"; then
        log "✅ Ngrok auth token appears to be configured"
    else
        log "⚠️  Warning: Ngrok auth token may not be configured"
        log "   Please set NGROK_AUTHTOKEN in $WORKSPACE_DIR/.env.ngrok"
    fi
    
    if grep -q "NGROK_USE_STATIC=true" "$WORKSPACE_DIR/.env.ngrok"; then
        STATIC_URL=$(grep "NGROK_STATIC_URL=" "$WORKSPACE_DIR/.env.ngrok" | cut -d'=' -f2 | tr -d ' "')
        if [ ! -z "$STATIC_URL" ]; then
            log "✅ Static URL configured: https://$STATIC_URL"
        else
            log "⚠️  Warning: NGROK_USE_STATIC=true but no NGROK_STATIC_URL set"
        fi
    fi
else
    log "❌ Ngrok environment file not found: $WORKSPACE_DIR/.env.ngrok"
    log "   Please run ./setup_ngrok_static.sh first"
fi

# Check if startup scripts are executable
if [ -x "$WORKSPACE_DIR/start_complete_system.sh" ] && [ -x "$WORKSPACE_DIR/stop_complete_system.sh" ]; then
    log "✅ Startup scripts are executable"
else
    log "Making startup scripts executable..."
    chmod +x "$WORKSPACE_DIR/start_complete_system.sh" "$WORKSPACE_DIR/stop_complete_system.sh"
    log "✅ Startup scripts made executable"
fi

echo ""
echo "🎉 Installation Complete!"
echo "========================"
echo ""
echo "Service Status:"
echo "  Name: $SERVICE_NAME"
echo "  File: /etc/systemd/system/$SERVICE_FILE"
echo "  Status: Enabled for auto-start"
echo ""
echo "Available Commands:"
echo "  Start service:    sudo systemctl start $SERVICE_NAME"
echo "  Stop service:     sudo systemctl stop $SERVICE_NAME"
echo "  Check status:     sudo systemctl status $SERVICE_NAME"
echo "  View logs:        sudo journalctl -u $SERVICE_NAME -f"
echo "  Disable auto-start: sudo systemctl disable $SERVICE_NAME"
echo ""
echo "The system will now automatically start on boot!"
echo ""

# Ask if user wants to start the service now
read -p "Do you want to start the service now? (y/N): " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Starting service..."
    $SUDO systemctl start "$SERVICE_NAME"
    
    # Wait a moment for startup
    sleep 5
    
    # Check status
    if $SUDO systemctl is-active --quiet "$SERVICE_NAME"; then
        log "✅ Service started successfully!"
        
        # Show the URL if available
        if [ -f "$WORKSPACE_DIR/current_ngrok_url.txt" ]; then
            URL=$(cat "$WORKSPACE_DIR/current_ngrok_url.txt")
            echo ""
            echo "🌐 NoctisPro is now accessible at: $URL"
        fi
    else
        log "❌ Service failed to start. Check logs with:"
        log "   sudo journalctl -u $SERVICE_NAME -n 50"
    fi
else
    echo ""
    echo "Service installed but not started."
    echo "You can start it manually with: sudo systemctl start $SERVICE_NAME"
    echo "Or it will start automatically on next boot."
fi

echo ""
echo "📋 To check the ngrok URL after startup:"
echo "   cat $WORKSPACE_DIR/current_ngrok_url.txt"
echo ""