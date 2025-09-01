#!/bin/bash

# Noctis Pro PACS - System Restart Deployment Script
# This script safely stops all running services and starts fresh instances

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Configuration
PROJECT_DIR="/workspace"
VENV_PATH="$PROJECT_DIR/venv"
PYTHON_PATH="$VENV_PATH/bin/python"
MANAGE_PY="$PROJECT_DIR/manage.py"
REQUIREMENTS_FILE="$PROJECT_DIR/requirements.txt"

# Service names to check and stop
SERVICE_NAMES=(
    "noctispro"
    "noctispro-production"
    "noctispro-complete" 
    "noctispro-django"
    "noctispro-ngrok"
    "noctispro-production-complete"
    "noctispro-production-bulletproof"
    "noctispro-production-current"
)

# Process names to kill
PROCESS_NAMES=(
    "python.*manage.py"
    "daphne"
    "gunicorn"
    "celery"
    "redis-server"
    "ngrok"
)

# Port numbers to free up
PORTS=(8000 8001 8080 9000 3000 5000 6379)

log "🚀 Starting Noctis Pro PACS System Restart Deployment"
log "Project directory: $PROJECT_DIR"

# Step 1: Stop all systemd services
log "📋 Step 1: Stopping all systemd services..."
for service in "${SERVICE_NAMES[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        log "Stopping service: $service"
        sudo systemctl stop "$service" || warn "Failed to stop $service"
        sudo systemctl disable "$service" || warn "Failed to disable $service"
    else
        log "Service $service is not running"
    fi
done

# Step 2: Kill any remaining processes
log "🔪 Step 2: Killing remaining processes..."
for process in "${PROCESS_NAMES[@]}"; do
    log "Killing processes matching: $process"
    pkill -f "$process" || log "No processes found matching: $process"
done

# Step 3: Free up ports
log "🔌 Step 3: Freeing up ports..."
for port in "${PORTS[@]}"; do
    log "Checking port $port..."
    if lsof -ti:$port >/dev/null 2>&1; then
        log "Killing processes on port $port"
        lsof -ti:$port | xargs kill -9 || warn "Failed to kill processes on port $port"
    fi
done

# Step 4: Clean up PID files
log "🧹 Step 4: Cleaning up PID files..."
find "$PROJECT_DIR" -name "*.pid" -type f -delete || warn "Failed to clean some PID files"
rm -f /tmp/noctispro*.pid || warn "Failed to clean temp PID files"

# Step 5: Update system packages
log "📦 Step 5: Updating system packages..."
sudo apt update && sudo apt upgrade -y || warn "Package update failed"

# Step 6: Set up Python virtual environment
log "🐍 Step 6: Setting up Python virtual environment..."
if [ ! -d "$VENV_PATH" ]; then
    log "Creating virtual environment..."
    python3 -m venv "$VENV_PATH"
fi

# Activate virtual environment
source "$VENV_PATH/bin/activate"

# Step 7: Install/Update Python dependencies
log "📚 Step 7: Installing Python dependencies..."
if [ -f "$REQUIREMENTS_FILE" ]; then
    pip install --upgrade pip
    pip install -r "$REQUIREMENTS_FILE" || error "Failed to install requirements"
else
    warn "Requirements file not found at $REQUIREMENTS_FILE"
fi

# Step 8: Database migrations
log "🗃️  Step 8: Running database migrations..."
cd "$PROJECT_DIR"
if [ -f "$MANAGE_PY" ]; then
    $PYTHON_PATH "$MANAGE_PY" makemigrations || warn "Make migrations failed"
    $PYTHON_PATH "$MANAGE_PY" migrate || warn "Migration failed"
    $PYTHON_PATH "$MANAGE_PY" collectstatic --noinput || warn "Collect static failed"
else
    error "manage.py not found at $MANAGE_PY"
fi

# Step 9: Create optimized service file
log "⚙️  Step 9: Creating optimized service file..."
SERVICE_FILE="/etc/systemd/system/noctispro-optimized.service"
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Noctis Pro PACS - Optimized Production Service
After=network.target
Wants=network.target

[Service]
Type=exec
User=root
Group=root
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$VENV_PATH/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
Environment=PYTHONPATH=$PROJECT_DIR
Environment=PYTHONUNBUFFERED=1

# Main Django application
ExecStart=$PYTHON_PATH -m daphne -b 0.0.0.0 -p 8000 noctis_pro.asgi:application

# Restart policy
Restart=always
RestartSec=3
StartLimitInterval=60s
StartLimitBurst=3

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

# Security settings
NoNewPrivileges=yes
ProtectSystem=strict
ReadWritePaths=$PROJECT_DIR

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=noctispro-optimized

[Install]
WantedBy=multi-user.target
EOF

# Step 10: Create ngrok service if needed
log "🌐 Step 10: Setting up ngrok service..."
if [ -f "$PROJECT_DIR/ngrok" ]; then
    NGROK_SERVICE_FILE="/etc/systemd/system/noctispro-ngrok-optimized.service"
    sudo tee "$NGROK_SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Ngrok tunnel for Noctis Pro PACS
After=noctispro-optimized.service
Requires=noctispro-optimized.service

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/ngrok http 8000 --log stdout
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
fi

# Step 11: Reload systemd and start services
log "🔄 Step 11: Starting optimized services..."
sudo systemctl daemon-reload

# Start main service
sudo systemctl enable noctispro-optimized
sudo systemctl start noctispro-optimized

# Start ngrok if available
if [ -f "$NGROK_SERVICE_FILE" ]; then
    sudo systemctl enable noctispro-ngrok-optimized
    sudo systemctl start noctispro-ngrok-optimized
fi

# Step 12: Health checks
log "🏥 Step 12: Running health checks..."
sleep 10

# Check if main service is running
if systemctl is-active --quiet noctispro-optimized; then
    log "✅ Main service is running"
else
    error "❌ Main service failed to start"
    sudo journalctl -u noctispro-optimized --no-pager -n 20
fi

# Check if port 8000 is responding
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health/ | grep -q "200\|302"; then
    log "✅ HTTP service is responding"
else
    warn "⚠️  HTTP service may not be responding properly"
fi

# Step 13: Display status and URLs
log "📊 Step 13: Deployment complete! Service status:"
echo ""
echo "=== SERVICE STATUS ==="
systemctl status noctispro-optimized --no-pager -l
echo ""

if systemctl is-active --quiet noctispro-ngrok-optimized; then
    echo "=== NGROK STATUS ==="
    systemctl status noctispro-ngrok-optimized --no-pager -l
    echo ""
    
    # Try to get ngrok URL
    sleep 5
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o 'https://[^"]*\.ngrok\.io' | head -1 2>/dev/null || echo "Not available yet")
    echo "🌐 Public URL: $NGROK_URL"
fi

echo "🏠 Local URL: http://localhost:8000"
echo "🏥 Health Check: http://localhost:8000/health/"
echo ""

# Step 14: Create monitoring script
log "📈 Step 14: Creating monitoring script..."
MONITOR_SCRIPT="$PROJECT_DIR/monitor_system.sh"
cat > "$MONITOR_SCRIPT" <<'EOF'
#!/bin/bash
# System monitoring script for Noctis Pro PACS

while true; do
    echo "=== $(date) ==="
    echo "Main Service: $(systemctl is-active noctispro-optimized)"
    echo "Ngrok Service: $(systemctl is-active noctispro-ngrok-optimized 2>/dev/null || echo 'not configured')"
    echo "Memory Usage: $(free -h | grep Mem | awk '{print $3"/"$2}')"
    echo "Disk Usage: $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5" used)"}')"
    echo "CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo "Active Connections: $(netstat -an | grep :8000 | grep ESTABLISHED | wc -l)"
    echo "---"
    sleep 30
done
EOF
chmod +x "$MONITOR_SCRIPT"

log "🎉 Deployment completed successfully!"
log "📝 Logs can be viewed with: sudo journalctl -u noctispro-optimized -f"
log "🔍 Monitor system with: $MONITOR_SCRIPT"
log "🛑 Stop services with: sudo systemctl stop noctispro-optimized noctispro-ngrok-optimized"

echo ""
echo -e "${GREEN}🚀 Noctis Pro PACS is now running with optimized configuration!${NC}"
echo -e "${BLUE}📖 Access the application at: http://localhost:8000${NC}"