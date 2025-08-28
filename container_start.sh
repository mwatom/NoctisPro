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
        nohup ngrok http --url=colt-charmed-lark.ngrok-free.app 80 --log=stdout > "$WORKSPACE_DIR/ngrok.log" 2>&1 &
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
