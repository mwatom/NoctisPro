#!/bin/bash

# NoctisPro Auto-Start Installation Script for Containerized Environments
# Alternative to systemd when running in containers or environments without systemd

set -e

WORKSPACE_DIR="/workspace"
USER_HOME="/home/ubuntu"

echo "🚀 Installing NoctisPro Auto-Start Service (Container Mode)"
echo "=========================================================="
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
        echo "❌ This script requires sudo access for some operations"
        echo "Please run: sudo $0"
        exit 1
    fi
fi

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

log "Detected containerized environment (no systemd)"
log "Setting up alternative auto-start method..."

# Create startup script in /etc/init.d/
log "Creating init.d service script..."

$SUDO tee /etc/init.d/noctispro > /dev/null << 'EOF'
#!/bin/bash
### BEGIN INIT INFO
# Provides:          noctispro
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: NoctisPro Medical Imaging System
# Description:       Complete NoctisPro system with Ngrok tunneling
### END INIT INFO

USER="ubuntu"
DAEMON_PATH="/workspace"
DAEMON_NAME="noctispro"
PIDFILE="/var/run/${DAEMON_NAME}.pid"
LOGFILE="/var/log/${DAEMON_NAME}.log"

# Source function library (if available)
. /lib/lsb/init-functions 2>/dev/null || true

do_start() {
    echo "Starting $DAEMON_NAME..."
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "$DAEMON_NAME is already running (PID: $PID)"
            return 1
        else
            rm -f "$PIDFILE"
        fi
    fi
    
    # Change to workspace directory and start the system
    cd "$DAEMON_PATH"
    su -c "$DAEMON_PATH/start_complete_system.sh" "$USER" >> "$LOGFILE" 2>&1 &
    echo $! > "$PIDFILE"
    echo "$DAEMON_NAME started"
    return 0
}

do_stop() {
    echo "Stopping $DAEMON_NAME..."
    if [ -f "$PIDFILE" ]; then
        cd "$DAEMON_PATH"
        su -c "$DAEMON_PATH/stop_complete_system.sh" "$USER" >> "$LOGFILE" 2>&1
        rm -f "$PIDFILE"
        echo "$DAEMON_NAME stopped"
        return 0
    else
        echo "$DAEMON_NAME is not running"
        return 1
    fi
}

do_status() {
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "$DAEMON_NAME is running (PID: $PID)"
            return 0
        else
            echo "$DAEMON_NAME is not running (stale PID file)"
            return 1
        fi
    else
        echo "$DAEMON_NAME is not running"
        return 1
    fi
}

case "$1" in
    start)
        do_start
        ;;
    stop)
        do_stop
        ;;
    restart)
        do_stop
        do_start
        ;;
    status)
        do_status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit $?
EOF

# Make the script executable
$SUDO chmod +x /etc/init.d/noctispro

log "✅ Init script created at /etc/init.d/noctispro"

# Set up runlevel links for auto-start
log "Setting up runlevel links for auto-start..."

# Create symlinks in runlevel directories
for runlevel in 2 3 4 5; do
    if [ ! -L "/etc/rc${runlevel}.d/S99noctispro" ]; then
        $SUDO ln -sf /etc/init.d/noctispro "/etc/rc${runlevel}.d/S99noctispro"
    fi
done

# Create stop links for shutdown runlevels
for runlevel in 0 1 6; do
    if [ ! -L "/etc/rc${runlevel}.d/K01noctispro" ]; then
        $SUDO ln -sf /etc/init.d/noctispro "/etc/rc${runlevel}.d/K01noctispro"
    fi
done

log "✅ Runlevel links created for auto-start"

# Create a simple service management script
log "Creating service management script..."

cat > "$WORKSPACE_DIR/manage_service.sh" << 'EOF'
#!/bin/bash

SERVICE_NAME="noctispro"
INIT_SCRIPT="/etc/init.d/$SERVICE_NAME"

case "$1" in
    start)
        echo "Starting NoctisPro service..."
        sudo "$INIT_SCRIPT" start
        ;;
    stop)
        echo "Stopping NoctisPro service..."
        sudo "$INIT_SCRIPT" stop
        ;;
    restart)
        echo "Restarting NoctisPro service..."
        sudo "$INIT_SCRIPT" restart
        ;;
    status)
        sudo "$INIT_SCRIPT" status
        ;;
    enable)
        echo "Service auto-start is already enabled via runlevel links"
        ;;
    disable)
        echo "Disabling auto-start..."
        # Remove runlevel links
        for runlevel in 0 1 2 3 4 5 6; do
            sudo rm -f "/etc/rc${runlevel}.d/"*"noctispro"
        done
        echo "Auto-start disabled"
        ;;
    logs)
        echo "Showing recent logs..."
        tail -f /var/log/noctispro.log
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|enable|disable|logs}"
        echo ""
        echo "Commands:"
        echo "  start    - Start the NoctisPro service"
        echo "  stop     - Stop the NoctisPro service"
        echo "  restart  - Restart the NoctisPro service"
        echo "  status   - Show service status"
        echo "  enable   - Enable auto-start (already enabled)"
        echo "  disable  - Disable auto-start"
        echo "  logs     - Show service logs"
        exit 1
        ;;
esac
EOF

chmod +x "$WORKSPACE_DIR/manage_service.sh"

log "✅ Service management script created: $WORKSPACE_DIR/manage_service.sh"

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
echo "Container-compatible auto-start has been configured using:"
echo "  - Init script: /etc/init.d/noctispro"
echo "  - Runlevel links: Auto-start at boot"
echo "  - Management script: $WORKSPACE_DIR/manage_service.sh"
echo ""
echo "Available Commands:"
echo "  Start service:    ./manage_service.sh start"
echo "  Stop service:     ./manage_service.sh stop"
echo "  Check status:     ./manage_service.sh status"
echo "  View logs:        ./manage_service.sh logs"
echo "  Disable auto-start: ./manage_service.sh disable"
echo ""
echo "The system will now automatically start when the container restarts!"
echo ""

# Ask if user wants to start the service now
read -p "Do you want to start the service now? (y/N): " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Starting service..."
    /etc/init.d/noctispro start
    
    # Wait a moment for startup
    sleep 5
    
    # Check status
    if /etc/init.d/noctispro status; then
        log "✅ Service started successfully!"
        
        # Show the URL if available
        if [ -f "$WORKSPACE_DIR/current_ngrok_url.txt" ]; then
            URL=$(cat "$WORKSPACE_DIR/current_ngrok_url.txt")
            echo ""
            echo "🌐 NoctisPro is now accessible at: $URL"
        fi
    else
        log "❌ Service failed to start. Check logs with:"
        log "   ./manage_service.sh logs"
    fi
else
    echo ""
    echo "Service installed but not started."
    echo "You can start it manually with: ./manage_service.sh start"
    echo "Or it will start automatically on next container restart."
fi

echo ""
echo "📋 To check the ngrok URL after startup:"
echo "   cat $WORKSPACE_DIR/current_ngrok_url.txt"
echo ""