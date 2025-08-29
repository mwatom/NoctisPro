#!/bin/bash

# Create a simple startup solution for NoctisPro

echo "🚀 Creating NoctisPro Startup Solution"
echo "======================================"

WORKSPACE_DIR="/workspace"

# Create the main startup script
sudo cp /tmp/noctispro-startup /usr/local/bin/noctispro-startup 2>/dev/null || {
    cat > /tmp/noctispro-startup << 'EOF'
#!/bin/bash

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
    su - "$SERVICE_USER" -c "cd '$WORKSPACE_DIR' && ./start_noctispro_service.sh" >> "$LOG_FILE" 2>&1 &
    log "✅ Started NoctisPro service as user $SERVICE_USER"
else
    cd "$WORKSPACE_DIR"
    ./start_noctispro_service.sh >> "$LOG_FILE" 2>&1 &
    log "✅ Started NoctisPro service"
fi

log "🎉 NoctisPro boot startup completed"
EOF

    sudo cp /tmp/noctispro-startup /usr/local/bin/noctispro-startup
    sudo chmod +x /usr/local/bin/noctispro-startup
}

# Create a simple rc.local style startup
if [ -f /etc/rc.local ]; then
    echo "📋 Adding to existing rc.local..."
    sudo cp /etc/rc.local /etc/rc.local.backup
    sudo sed -i '/^exit 0$/d' /etc/rc.local
    echo "" | sudo tee -a /etc/rc.local
    echo "# NoctisPro Auto-Start" | sudo tee -a /etc/rc.local
    echo "/usr/local/bin/noctispro-startup &" | sudo tee -a /etc/rc.local
    echo "" | sudo tee -a /etc/rc.local
    echo "exit 0" | sudo tee -a /etc/rc.local
    sudo chmod +x /etc/rc.local
else
    echo "📋 Creating rc.local..."
    cat << 'EOF' | sudo tee /etc/rc.local
#!/bin/bash

# NoctisPro Auto-Start
/usr/local/bin/noctispro-startup &

exit 0
EOF
    sudo chmod +x /etc/rc.local
fi

echo "✅ Startup script installed"
echo ""
echo "🎉 NoctisPro will now start automatically on system boot!"
echo ""
echo "📋 To start manually: sudo /usr/local/bin/noctispro-startup"
echo "📋 To check logs: sudo tail -f /var/log/noctispro-startup.log"