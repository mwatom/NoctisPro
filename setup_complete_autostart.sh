#!/bin/bash

# Complete Autostart Setup for NoctisPro with Ngrok
# This script sets up robust automatic startup that survives power outages

set -e

echo "🚀 Setting up Complete Autostart for NoctisPro with Ngrok"
echo "=========================================================="
echo ""

WORKSPACE_DIR="/workspace"
SERVICE_NAME="noctispro-complete"
NGROK_SERVICE_NAME="noctispro-ngrok"

# Check if running as root or with sudo
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

echo "Step 1: Checking ngrok authentication..."
echo "======================================="

# Check if ngrok auth token is configured
if ! ngrok config check > /dev/null 2>&1; then
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
    if ! ngrok config check > /dev/null 2>&1; then
        echo "❌ Ngrok still not configured. Please check your auth token."
        exit 1
    fi
fi

echo "✅ Ngrok auth token is configured"
echo ""

echo "Step 2: Creating robust startup scripts..."
echo "=========================================="

# Create enhanced startup script with error handling
cat > "$WORKSPACE_DIR/start_robust_system.sh" << 'EOF'
#!/bin/bash

# Robust NoctisPro Startup Script with Auto-Recovery
set -e

WORKSPACE_DIR="/workspace"
LOG_FILE="$WORKSPACE_DIR/noctispro_complete.log"
PID_FILE="$WORKSPACE_DIR/noctispro_complete.pid"
URL_FILE="$WORKSPACE_DIR/current_ngrok_url.txt"

# Redirect output to log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

# Function to check if a process is running
is_running() {
    pgrep -f "$1" > /dev/null
}

# Function to wait for service with retries
wait_for_service() {
    local url="$1"
    local max_attempts=60
    local attempt=1
    
    log "Waiting for service at $url..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            log "Service is ready at $url"
            return 0
        fi
        log "Attempt $attempt/$max_attempts: Service not ready, waiting 5s..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    log "Service failed to start after $max_attempts attempts"
    return 1
}

# Function to start ngrok with retries
start_ngrok_with_retries() {
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "Starting ngrok (attempt $attempt/$max_attempts)..."
        
        # Kill any existing ngrok processes
        pkill -f ngrok || true
        sleep 2
        
        # Load ngrok environment
        if [ -f "$WORKSPACE_DIR/.env.ngrok" ]; then
            source "$WORKSPACE_DIR/.env.ngrok"
        fi
        
        # Start ngrok based on configuration
        if [ "${NGROK_USE_STATIC:-false}" = "true" ] && [ ! -z "${NGROK_STATIC_URL:-}" ]; then
            log "Starting ngrok with static URL: $NGROK_STATIC_URL"
            nohup ngrok http --url=https://$NGROK_STATIC_URL ${DJANGO_PORT:-80} --log=stdout > "$WORKSPACE_DIR/ngrok.log" 2>&1 &
            EXPECTED_URL="https://$NGROK_STATIC_URL"
        else
            log "Starting ngrok with random URL"
            nohup ngrok http ${DJANGO_PORT:-80} --log=stdout > "$WORKSPACE_DIR/ngrok.log" 2>&1 &
            EXPECTED_URL="(dynamic)"
        fi
        
        NGROK_PID=$!
        log "Ngrok started with PID: $NGROK_PID"
        
        # Wait for ngrok to initialize
        sleep 10
        
        # Try to get ngrok URL
        local ngrok_url=""
        for i in {1..20}; do
            ngrok_url=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data['tunnels']:
        if tunnel['proto'] == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
" 2>/dev/null || echo "")
            
            if [ ! -z "$ngrok_url" ]; then
                break
            fi
            sleep 2
        done
        
        if [ ! -z "$ngrok_url" ]; then
            log "✅ Ngrok tunnel active: $ngrok_url"
            echo "$ngrok_url" > "$URL_FILE"
            return 0
        else
            log "⚠️  Failed to get ngrok URL on attempt $attempt"
            kill $NGROK_PID 2>/dev/null || true
            sleep 5
            attempt=$((attempt + 1))
        fi
    done
    
    log "❌ Failed to start ngrok after $max_attempts attempts"
    return 1
}

log "=== Starting NoctisPro Robust System ==="

# Change to workspace directory
cd "$WORKSPACE_DIR"

# Ensure required services are running
log "Checking and starting required services..."

# Start PostgreSQL if not running
if ! systemctl is-active postgresql > /dev/null 2>&1; then
    log "Starting PostgreSQL..."
    systemctl start postgresql
fi

# Start Redis if not running  
if ! systemctl is-active redis-server > /dev/null 2>&1; then
    log "Starting Redis..."
    systemctl start redis-server
fi

# Wait for database services
log "Waiting for database services..."
sleep 10

# Load environment
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    log "✅ Virtual environment activated"
else
    log "❌ Virtual environment not found!"
    exit 1
fi

if [ -f ".env.production" ]; then
    source .env.production
    log "✅ Production environment loaded"
fi

# Run database setup
log "Running database migrations..."
python manage.py migrate --noinput

log "Collecting static files..."
python manage.py collectstatic --noinput

# Check if Django is already running
if is_running "manage.py runserver"; then
    log "Django is already running - stopping it first"
    pkill -f "manage.py runserver" || true
    sleep 5
fi

# Start Django in background
log "Starting Django application..."
nohup python manage.py runserver ${DJANGO_HOST:-0.0.0.0}:${DJANGO_PORT:-80} > "$WORKSPACE_DIR/django.log" 2>&1 &
DJANGO_PID=$!
log "Django started with PID: $DJANGO_PID"

# Wait for Django to be ready
if wait_for_service "http://localhost:${DJANGO_PORT:-80}"; then
    log "✅ Django is ready"
else
    log "❌ Django failed to start"
    exit 1
fi

# Start ngrok
if start_ngrok_with_retries; then
    log "✅ Ngrok started successfully"
else
    log "⚠️  Ngrok failed to start, continuing with local access only"
fi

# Save PIDs for cleanup
echo "$DJANGO_PID" > "$PID_FILE.django"
if [ ! -z "${NGROK_PID:-}" ]; then
    echo "$NGROK_PID" > "$PID_FILE.ngrok"
fi

log "=== NoctisPro System Started Successfully ==="
log "Django: http://localhost:${DJANGO_PORT:-80}"
if [ -f "$URL_FILE" ]; then
    NGROK_URL=$(cat "$URL_FILE")
    log "Ngrok: $NGROK_URL"
fi

# Keep script running to maintain services
while true; do
    sleep 60
    
    # Check Django health
    if ! is_running "manage.py runserver"; then
        log "⚠️  Django process died - restarting..."
        nohup python manage.py runserver ${DJANGO_HOST:-0.0.0.0}:${DJANGO_PORT:-80} > "$WORKSPACE_DIR/django.log" 2>&1 &
        echo "$!" > "$PID_FILE.django"
    fi
    
    # Check ngrok health
    if [ -f "$PID_FILE.ngrok" ] && ! is_running "ngrok"; then
        log "⚠️  Ngrok process died - restarting..."
        start_ngrok_with_retries
    fi
done
EOF

chmod +x "$WORKSPACE_DIR/start_robust_system.sh"
log "✅ Robust startup script created"

# Create stop script
cat > "$WORKSPACE_DIR/stop_robust_system.sh" << 'EOF'
#!/bin/bash

# Stop NoctisPro System
WORKSPACE_DIR="/workspace"
LOG_FILE="$WORKSPACE_DIR/noctispro_complete.log"
PID_FILE="$WORKSPACE_DIR/noctispro_complete.pid"

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

log "=== Stopping NoctisPro System ==="

# Stop Django
if [ -f "$PID_FILE.django" ]; then
    DJANGO_PID=$(cat "$PID_FILE.django")
    if kill $DJANGO_PID 2>/dev/null; then
        log "✅ Django stopped (PID: $DJANGO_PID)"
    fi
    rm -f "$PID_FILE.django"
fi

# Stop ngrok
if [ -f "$PID_FILE.ngrok" ]; then
    NGROK_PID=$(cat "$PID_FILE.ngrok")
    if kill $NGROK_PID 2>/dev/null; then
        log "✅ Ngrok stopped (PID: $NGROK_PID)"
    fi
    rm -f "$PID_FILE.ngrok"
fi

# Kill any remaining processes
pkill -f "manage.py runserver" || true
pkill -f "ngrok" || true

log "=== NoctisPro System Stopped ==="
EOF

chmod +x "$WORKSPACE_DIR/stop_robust_system.sh"
log "✅ Stop script created"

echo ""
echo "Step 3: Creating enhanced systemd service..."
echo "==========================================="

# Create enhanced systemd service
cat > "/tmp/${SERVICE_NAME}.service" << EOF
[Unit]
Description=NoctisPro Complete System with Ngrok Auto-Recovery
After=network-online.target postgresql.service redis-server.service
Wants=network-online.target postgresql.service redis-server.service
StartLimitIntervalSec=0

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=$WORKSPACE_DIR
Environment=PATH=$WORKSPACE_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=HOME=/home/ubuntu
EnvironmentFile=-$WORKSPACE_DIR/.env.production
EnvironmentFile=-$WORKSPACE_DIR/.env.ngrok

# Pre-start: ensure services are running
ExecStartPre=/bin/bash -c 'systemctl is-active postgresql || systemctl start postgresql'
ExecStartPre=/bin/bash -c 'systemctl is-active redis-server || systemctl start redis-server'
ExecStartPre=/bin/sleep 15

# Start the robust system
ExecStart=$WORKSPACE_DIR/start_robust_system.sh

# Stop command
ExecStop=$WORKSPACE_DIR/stop_robust_system.sh
ExecStopPost=/bin/bash -c 'pkill -f "manage.py runserver" || true'
ExecStopPost=/bin/bash -c 'pkill -f "ngrok" || true'

# Auto-restart on failure
Restart=always
RestartSec=30
TimeoutStartSec=600
TimeoutStopSec=60

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=noctispro-complete

# Security
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Install the service
$SUDO cp "/tmp/${SERVICE_NAME}.service" "/etc/systemd/system/"
$SUDO chmod 644 "/etc/systemd/system/${SERVICE_NAME}.service"
log "✅ Service file installed"

# Reload systemd and enable service
$SUDO systemctl daemon-reload
log "✅ Systemd daemon reloaded"

$SUDO systemctl enable "$SERVICE_NAME"
log "✅ Service enabled for auto-start"

echo ""
echo "Step 4: Creating ngrok watchdog..."
echo "=================================="

# Create ngrok monitoring script
cat > "$WORKSPACE_DIR/ngrok_watchdog.sh" << 'EOF'
#!/bin/bash

# Ngrok Watchdog - Monitors and restarts ngrok if needed
WORKSPACE_DIR="/workspace"
URL_FILE="$WORKSPACE_DIR/current_ngrok_url.txt"
LOG_FILE="$WORKSPACE_DIR/ngrok_watchdog.log"

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

# Function to check if ngrok is responding
check_ngrok() {
    local status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4040/api/tunnels 2>/dev/null || echo "000")
    [ "$status" = "200" ]
}

# Function to restart ngrok
restart_ngrok() {
    log "Restarting ngrok..."
    
    # Kill existing ngrok
    pkill -f ngrok || true
    sleep 5
    
    cd "$WORKSPACE_DIR"
    
    # Load environment
    if [ -f ".env.ngrok" ]; then
        source .env.ngrok
    fi
    
    # Start ngrok
    if [ "${NGROK_USE_STATIC:-false}" = "true" ] && [ ! -z "${NGROK_STATIC_URL:-}" ]; then
        nohup ngrok http --url=https://$NGROK_STATIC_URL ${DJANGO_PORT:-80} --log=stdout > ngrok.log 2>&1 &
    else
        nohup ngrok http ${DJANGO_PORT:-80} --log=stdout > ngrok.log 2>&1 &
    fi
    
    sleep 10
    
    # Update URL file
    local ngrok_url=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data['tunnels']:
        if tunnel['proto'] == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
" 2>/dev/null || echo "")
    
    if [ ! -z "$ngrok_url" ]; then
        echo "$ngrok_url" > "$URL_FILE"
        log "✅ Ngrok restarted: $ngrok_url"
    else
        log "❌ Failed to restart ngrok"
    fi
}

# Main monitoring loop
while true; do
    if ! check_ngrok; then
        log "⚠️  Ngrok not responding - attempting restart"
        restart_ngrok
    fi
    
    sleep 60
done
EOF

chmod +x "$WORKSPACE_DIR/ngrok_watchdog.sh"
log "✅ Ngrok watchdog created"

echo ""
echo "Step 5: Testing the setup..."
echo "==========================="

# Check current service status
SERVICE_STATUS=$($SUDO systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || echo "unknown")
log "Service status: $SERVICE_STATUS"

if [ "$SERVICE_STATUS" = "enabled" ]; then
    echo "✅ Service is enabled for autostart"
else
    echo "❌ Service enablement may have failed"
fi

echo ""
echo "🎉 Complete Autostart Setup Finished!"
echo "===================================="
echo ""
echo "Your NoctisPro system is now configured to:"
echo "✅ Start automatically on boot"
echo "✅ Restart after power outages"
echo "✅ Auto-recover from failures"
echo "✅ Monitor and restart ngrok if it fails"
echo ""
echo "🔧 Available Commands:"
echo "  Start service:    sudo systemctl start $SERVICE_NAME"
echo "  Stop service:     sudo systemctl stop $SERVICE_NAME"
echo "  Check status:     sudo systemctl status $SERVICE_NAME"
echo "  View logs:        sudo journalctl -u $SERVICE_NAME -f"
echo "  Disable autostart: sudo systemctl disable $SERVICE_NAME"
echo ""
echo "📊 Monitor Files:"
echo "  Current URL:      cat $WORKSPACE_DIR/current_ngrok_url.txt"
echo "  System logs:      tail -f $WORKSPACE_DIR/noctispro_complete.log"
echo "  Ngrok logs:       tail -f $WORKSPACE_DIR/ngrok.log"
echo "  Django logs:      tail -f $WORKSPACE_DIR/django.log"
echo ""

# Ask if user wants to start now
read -p "Do you want to start the service now? (y/N): " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Starting service..."
    $SUDO systemctl start "$SERVICE_NAME"
    
    sleep 10
    
    if $SUDO systemctl is-active --quiet "$SERVICE_NAME"; then
        log "✅ Service started successfully!"
        
        # Show status
        echo ""
        echo "🌐 Service Status:"
        $SUDO systemctl status "$SERVICE_NAME" --no-pager -l
        
        # Check for URL
        sleep 15
        if [ -f "$WORKSPACE_DIR/current_ngrok_url.txt" ]; then
            URL=$(cat "$WORKSPACE_DIR/current_ngrok_url.txt")
            echo ""
            echo "🌍 NoctisPro is accessible at: $URL"
        else
            echo ""
            echo "🔄 Ngrok URL will be available shortly. Check: cat $WORKSPACE_DIR/current_ngrok_url.txt"
        fi
    else
        log "❌ Service failed to start. Check logs:"
        echo ""
        $SUDO journalctl -u "$SERVICE_NAME" -n 20 --no-pager
    fi
else
    echo ""
    echo "Service is ready but not started."
    echo "It will start automatically on next boot."
    echo "To start manually: sudo systemctl start $SERVICE_NAME"
fi

echo ""
echo "🎯 Setup Complete! Your system will now start automatically on every boot."