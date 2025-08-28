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
