#!/bin/bash

# Install NoctisPro to start automatically on system boot
# Works with different init systems (systemd, rc.local, cron)

set -e

echo "🚀 Installing NoctisPro Boot Startup"
echo "===================================="

WORKSPACE_DIR="/workspace"
SERVICE_USER="ubuntu"

# Check if we have sudo access
if ! sudo -n true 2>/dev/null; then
    echo "❌ This script requires sudo access for system installation"
    echo "Please run: sudo $0"
    exit 1
fi

echo "✅ Sudo access confirmed"

# Create a system startup script
cat > /tmp/noctispro-startup << 'EOF'
#!/bin/bash

# NoctisPro System Startup Script
# This script starts NoctisPro service on system boot

WORKSPACE_DIR="/workspace"
SERVICE_USER="ubuntu"
LOG_FILE="/var/log/noctispro-startup.log"

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

log "🚀 Starting NoctisPro boot startup"

# Wait for network
sleep 10

# Change to service user and workspace directory
if [ "$(whoami)" = "root" ]; then
    # Running as root, switch to service user
    su - "$SERVICE_USER" -c "cd '$WORKSPACE_DIR' && ./start_noctispro_service.sh" >> "$LOG_FILE" 2>&1 &
    log "✅ Started NoctisPro service as user $SERVICE_USER"
else
    # Already running as correct user
    cd "$WORKSPACE_DIR"
    ./start_noctispro_service.sh >> "$LOG_FILE" 2>&1 &
    log "✅ Started NoctisPro service"
fi

log "🎉 NoctisPro boot startup completed"
EOF

chmod +x /tmp/noctispro-startup

# Try different startup methods based on what's available

# Method 1: systemd (preferred)
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet init 2>/dev/null; then
    echo "📋 Installing systemd service..."
    
    cat > /tmp/noctispro-boot.service << EOF
[Unit]
Description=NoctisPro Auto-Start Service
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=3

[Service]
Type=forking
User=root
ExecStart=/usr/local/bin/noctispro-startup
StandardOutput=journal
StandardError=journal
SyslogIdentifier=noctispro-boot
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    sudo cp /tmp/noctispro-startup /usr/local/bin/noctispro-startup
    sudo cp /tmp/noctispro-boot.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable noctispro-boot.service
    
    echo "✅ Systemd service installed and enabled"
    echo "📋 Service will start on next boot"
    echo "🔧 To start now: sudo systemctl start noctispro-boot.service"

# Method 2: rc.local (fallback)
elif [ -f /etc/rc.local ] || [ -d /etc/rc.d ]; then
    echo "📋 Installing rc.local startup..."
    
    sudo cp /tmp/noctispro-startup /usr/local/bin/noctispro-startup
    
    # Add to rc.local
    if [ -f /etc/rc.local ]; then
        # Backup existing rc.local
        sudo cp /etc/rc.local /etc/rc.local.backup
        
        # Remove exit 0 if it exists
        sudo sed -i '/^exit 0$/d' /etc/rc.local
        
        # Add our startup command
        echo "" | sudo tee -a /etc/rc.local
        echo "# NoctisPro Auto-Start" | sudo tee -a /etc/rc.local
        echo "/usr/local/bin/noctispro-startup &" | sudo tee -a /etc/rc.local
        echo "" | sudo tee -a /etc/rc.local
        echo "exit 0" | sudo tee -a /etc/rc.local
        
        sudo chmod +x /etc/rc.local
    else
        # Create rc.local
        cat << 'EOF' | sudo tee /etc/rc.local
#!/bin/bash

# NoctisPro Auto-Start
/usr/local/bin/noctispro-startup &

exit 0
EOF
        sudo chmod +x /etc/rc.local
    fi
    
    echo "✅ rc.local startup installed"

# Method 3: cron @reboot (last resort)
else
    echo "📋 Installing cron @reboot startup..."
    
    sudo cp /tmp/noctispro-startup /usr/local/bin/noctispro-startup
    
    # Add to root crontab
    (sudo crontab -l 2>/dev/null || echo ""; echo "@reboot /usr/local/bin/noctispro-startup") | sudo crontab -
    
    echo "✅ Cron @reboot startup installed"
fi

# Create management scripts
cat > "$WORKSPACE_DIR/manage_boot_service.sh" << 'EOF'
#!/bin/bash

# NoctisPro Boot Service Management

case "$1" in
    start)
        echo "🚀 Starting NoctisPro boot service..."
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl start noctispro-boot.service
        else
            sudo /usr/local/bin/noctispro-startup &
        fi
        ;;
    stop)
        echo "🛑 Stopping NoctisPro boot service..."
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl stop noctispro-boot.service
        fi
        # Also stop the main service
        ./stop_noctispro_service.sh
        ;;
    status)
        echo "📊 NoctisPro Boot Service Status"
        echo "================================"
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl status noctispro-boot.service
        fi
        echo ""
        echo "Current service status:"
        ./check_noctispro_service.sh
        ;;
    enable)
        echo "✅ Enabling NoctisPro boot service..."
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl enable noctispro-boot.service
        fi
        echo "Service will start on next boot"
        ;;
    disable)
        echo "❌ Disabling NoctisPro boot service..."
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl disable noctispro-boot.service
        fi
        echo "Service will NOT start on next boot"
        ;;
    *)
        echo "Usage: $0 {start|stop|status|enable|disable}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the boot service now"
        echo "  stop    - Stop the boot service"
        echo "  status  - Show service status"
        echo "  enable  - Enable auto-start on boot"
        echo "  disable - Disable auto-start on boot"
        exit 1
        ;;
esac
EOF

chmod +x "$WORKSPACE_DIR/manage_boot_service.sh"

# Clean up temporary files
rm -f /tmp/noctispro-startup /tmp/noctispro-boot.service

echo ""
echo "🎉 NoctisPro Boot Startup Installation Complete!"
echo "==============================================="
echo ""
echo "📋 Service Management:"
echo "  ./manage_boot_service.sh start    - Start service now"
echo "  ./manage_boot_service.sh stop     - Stop service"
echo "  ./manage_boot_service.sh status   - Check status"
echo "  ./manage_boot_service.sh enable   - Enable auto-start"
echo "  ./manage_boot_service.sh disable  - Disable auto-start"
echo ""
echo "📁 Key Files:"
echo "  /usr/local/bin/noctispro-startup   - System startup script"
echo "  /var/log/noctispro-startup.log     - Boot startup logs"
echo ""
echo "⚠️  REMEMBER: Configure your ngrok auth token in .env.production!"
echo ""
echo "✅ NoctisPro will now start automatically on system boot"