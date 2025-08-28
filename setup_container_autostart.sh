#!/bin/bash

# Container Autostart Setup for NoctisPro with Ngrok
# This version works in containerized environments without systemd

echo "🐳 Container Autostart Setup for NoctisPro with Ngrok"
echo "======================================================"
echo ""

WORKSPACE_DIR="/workspace"

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

echo "Step 1: Verifying ngrok configuration..."
echo "========================================"

# Check if ngrok is configured
if ngrok config check > /dev/null 2>&1; then
    log "✅ Ngrok is configured"
else
    log "❌ Ngrok not configured - configuring now..."
    ngrok config add-authtoken 31Ru57qNtsoaFXnGZDyosoqQBKi_2RV15cXnsTifpKjae1N36
    if ngrok config check > /dev/null 2>&1; then
        log "✅ Ngrok configured successfully"
    else
        log "❌ Failed to configure ngrok"
        exit 1
    fi
fi

echo ""
echo "Step 2: Creating container startup script..."
echo "==========================================="

# Create the main startup script for containers
cat > "$WORKSPACE_DIR/container_start.sh" << 'EOF'
#!/bin/bash

# Container Startup Script for NoctisPro with Ngrok
# Designed to work in containerized environments

WORKSPACE_DIR="/workspace"
LOG_FILE="$WORKSPACE_DIR/container_startup.log"
URL_FILE="$WORKSPACE_DIR/current_ngrok_url.txt"

# Redirect output to log file and console
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

# Function to check if a process is running
is_running() {
    pgrep -f "$1" > /dev/null 2>&1
}

# Function to wait for service with retries
wait_for_service() {
    local url="$1"
    local max_attempts=30
    local attempt=1
    
    log "Waiting for service at $url..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            log "✅ Service is ready at $url"
            return 0
        fi
        log "Attempt $attempt/$max_attempts: Service not ready, waiting 5s..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    log "❌ Service failed to start after $max_attempts attempts"
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
        sleep 3
        
        # Load ngrok environment
        if [ -f "$WORKSPACE_DIR/.env.ngrok" ]; then
            source "$WORKSPACE_DIR/.env.ngrok"
        fi
        
        # Start ngrok with static URL
        log "Starting ngrok with static URL: colt-charmed-lark.ngrok-free.app"
        nohup ngrok http --url=https://colt-charmed-lark.ngrok-free.app 80 --log=stdout > "$WORKSPACE_DIR/ngrok.log" 2>&1 &
        NGROK_PID=$!
        log "Ngrok started with PID: $NGROK_PID"
        
        # Wait for ngrok to initialize
        sleep 15
        
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
            sleep 3
        done
        
        if [ ! -z "$ngrok_url" ]; then
            log "✅ Ngrok tunnel active: $ngrok_url"
            echo "$ngrok_url" > "$URL_FILE"
            return 0
        else
            log "⚠️  Failed to get ngrok URL on attempt $attempt"
            if ps -p $NGROK_PID > /dev/null 2>&1; then
                kill $NGROK_PID 2>/dev/null || true
            fi
            sleep 5
            attempt=$((attempt + 1))
        fi
    done
    
    log "❌ Failed to start ngrok after $max_attempts attempts"
    # Continue without ngrok rather than failing completely
    echo "LOCAL_ONLY" > "$URL_FILE"
    return 1
}

# Function to monitor and restart services
monitor_services() {
    log "Starting service monitoring..."
    
    while true; do
        sleep 60
        
        # Check Django health
        if ! is_running "manage.py runserver"; then
            log "⚠️  Django process died - restarting..."
            cd "$WORKSPACE_DIR"
            source venv/bin/activate
            source .env.production 2>/dev/null || true
            nohup python manage.py runserver 0.0.0.0:80 > "$WORKSPACE_DIR/django.log" 2>&1 &
            log "Django restarted with PID: $!"
        fi
        
        # Check ngrok health
        if ! is_running "ngrok"; then
            log "⚠️  Ngrok process died - restarting..."
            start_ngrok_with_retries
        fi
        
        # Update URL file if needed
        if is_running "ngrok"; then
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
            
            if [ ! -z "$ngrok_url" ] && [ "$ngrok_url" != "$(cat $URL_FILE 2>/dev/null)" ]; then
                echo "$ngrok_url" > "$URL_FILE"
                log "Updated URL: $ngrok_url"
            fi
        fi
    done
}

log "=== Starting NoctisPro Container System ==="

# Change to workspace directory
cd "$WORKSPACE_DIR"

# Wait for network connectivity
log "Checking network connectivity..."
for i in {1..10}; do
    if ping -c 1 google.com >/dev/null 2>&1; then
        log "✅ Network is available"
        break
    fi
    log "Waiting for network... (attempt $i/10)"
    sleep 5
done

# Setup virtual environment
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    log "✅ Virtual environment activated"
else
    log "❌ Virtual environment not found!"
    exit 1
fi

# Load environment
if [ -f ".env.production" ]; then
    source .env.production
    log "✅ Production environment loaded"
fi

# Run database setup
log "Running database migrations..."
python manage.py migrate --noinput || log "⚠️  Migration failed, continuing..."

log "Collecting static files..."
python manage.py collectstatic --noinput || log "⚠️  Static collection failed, continuing..."

# Stop any existing processes
log "Cleaning up existing processes..."
pkill -f "manage.py runserver" || true
pkill -f "ngrok" || true
sleep 3

# Start Django
log "Starting Django application..."
nohup python manage.py runserver 0.0.0.0:80 > "$WORKSPACE_DIR/django.log" 2>&1 &
DJANGO_PID=$!
log "Django started with PID: $DJANGO_PID"

# Wait for Django to be ready
if wait_for_service "http://localhost:80"; then
    log "✅ Django is ready"
else
    log "⚠️  Django may not be fully ready, continuing..."
fi

# Start ngrok
if start_ngrok_with_retries; then
    log "✅ Ngrok started successfully"
else
    log "⚠️  Ngrok failed to start, continuing with local access only"
fi

log "=== NoctisPro Container System Started ==="
log "Local access: http://localhost:80"
if [ -f "$URL_FILE" ] && [ "$(cat $URL_FILE)" != "LOCAL_ONLY" ]; then
    NGROK_URL=$(cat "$URL_FILE")
    log "Remote access: $NGROK_URL"
fi

# Start monitoring in background
monitor_services &
MONITOR_PID=$!
log "Service monitoring started with PID: $MONITOR_PID"

# Keep main process alive
log "Container startup complete. Monitoring services..."
wait $MONITOR_PID
EOF

chmod +x "$WORKSPACE_DIR/container_start.sh"
log "✅ Container startup script created"

echo ""
echo "Step 3: Creating quick start script..."
echo "===================================="

# Create simple start script
cat > "$WORKSPACE_DIR/start_noctispro.sh" << 'EOF'
#!/bin/bash

echo "🚀 Starting NoctisPro with Ngrok..."
echo "=================================="

cd /workspace

# Run the container startup script
./container_start.sh
EOF

chmod +x "$WORKSPACE_DIR/start_noctispro.sh"
log "✅ Quick start script created"

echo ""
echo "Step 4: Creating Docker Compose override for autostart..."
echo "========================================================"

# Create a docker-compose override that runs the startup script
cat > "$WORKSPACE_DIR/docker-compose.autostart.yml" << 'EOF'
version: '3.8'

services:
  noctispro:
    command: ["/bin/bash", "-c", "cd /workspace && ./container_start.sh"]
    restart: unless-stopped
    environment:
      - PYTHONUNBUFFERED=1
    volumes:
      - .:/workspace
    ports:
      - "80:80"
      - "4040:4040"  # ngrok web interface
EOF

log "✅ Docker Compose autostart configuration created"

echo ""
echo "Step 5: Creating simple status checker..."
echo "======================================="

cat > "$WORKSPACE_DIR/check_status.sh" << 'EOF'
#!/bin/bash

echo "🔍 NoctisPro Status Check"
echo "========================"
echo ""

# Check processes
echo "📊 Process Status:"
if pgrep -f "manage.py runserver" > /dev/null; then
    echo "✅ Django: Running"
else
    echo "❌ Django: Not Running"
fi

if pgrep -f "ngrok" > /dev/null; then
    echo "✅ Ngrok: Running"
else
    echo "❌ Ngrok: Not Running"
fi

echo ""
echo "🌐 Access URLs:"
echo "   Local: http://localhost:80"

if [ -f "/workspace/current_ngrok_url.txt" ]; then
    URL=$(cat "/workspace/current_ngrok_url.txt" 2>/dev/null)
    if [ ! -z "$URL" ] && [ "$URL" != "LOCAL_ONLY" ]; then
        echo "   Remote: $URL"
    else
        echo "   Remote: Not available"
    fi
else
    echo "   Remote: Not available"
fi

echo ""
echo "📝 Logs:"
echo "   Container logs: tail -f /workspace/container_startup.log"
echo "   Django logs:    tail -f /workspace/django.log"
echo "   Ngrok logs:     tail -f /workspace/ngrok.log"
EOF

chmod +x "$WORKSPACE_DIR/check_status.sh"
log "✅ Status checker created"

echo ""
echo "🎉 Container Autostart Setup Complete!"
echo "====================================="
echo ""
echo "🚀 How to use:"
echo ""
echo "1. **Start manually (for testing):**"
echo "   ./start_noctispro.sh"
echo ""
echo "2. **Use with Docker Compose (recommended for autostart):**"
echo "   docker-compose -f docker-compose.yml -f docker-compose.autostart.yml up -d"
echo ""
echo "3. **Check status:**"
echo "   ./check_status.sh"
echo ""
echo "4. **Get current URL:**"
echo "   cat /workspace/current_ngrok_url.txt"
echo ""
echo "🔧 Features:"
echo "✅ Automatic startup with Docker"
echo "✅ Auto-restart on failures (restart: unless-stopped)"
echo "✅ Ngrok with your static URL: https://colt-charmed-lark.ngrok-free.app"
echo "✅ Service monitoring and recovery"
echo "✅ Comprehensive logging"
echo "✅ Survives container restarts"
echo ""
echo "🌍 Your static URL: https://colt-charmed-lark.ngrok-free.app"
echo ""

read -p "Do you want to start NoctisPro now? (y/N): " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Starting NoctisPro..."
    ./start_noctispro.sh
else
    echo ""
    echo "Ready to start! Run: ./start_noctispro.sh"
fi