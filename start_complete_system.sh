#!/bin/bash

# NoctisPro Complete System Startup Script
# Starts Django and Ngrok together for seamless operation

set -e

WORKSPACE_DIR="/workspace"
LOG_FILE="$WORKSPACE_DIR/noctispro_complete.log"
PID_FILE="$WORKSPACE_DIR/noctispro_complete.pid"

# Redirect output to log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "$(date): Starting NoctisPro Complete System..."

# Change to workspace directory
cd "$WORKSPACE_DIR"

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

# Function to check if a process is running
is_running() {
    pgrep -f "$1" > /dev/null
}

# Function to wait for service
wait_for_service() {
    local url="$1"
    local max_attempts=30
    local attempt=1
    
    log "Waiting for service at $url..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            log "Service is ready at $url"
            return 0
        fi
        log "Attempt $attempt/$max_attempts: Service not ready, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log "Service failed to start after $max_attempts attempts"
    return 1
}

# Source environment files
if [ -f ".env.production" ]; then
    log "Loading production environment..."
    source .env.production
fi

if [ -f ".env.ngrok" ]; then
    log "Loading ngrok environment..."
    source .env.ngrok
fi

# Activate virtual environment
log "Activating virtual environment..."
source venv/bin/activate

# Check database connectivity
log "Checking database connectivity..."
python -c "
import django
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()
from django.db import connection
cursor = connection.cursor()
cursor.execute('SELECT 1')
print('Database connection successful')
" || {
    log "Database connection failed"
    exit 1
}

# Start Django application
log "Starting Django application..."
if is_running "manage.py runserver"; then
    log "Django is already running"
    DJANGO_PID=$(pgrep -f "manage.py runserver")
else
    python manage.py runserver 0.0.0.0:8000 &
    DJANGO_PID=$!
    log "Django started with PID $DJANGO_PID"
fi

# Wait for Django to be ready
wait_for_service "http://localhost:8000" || {
    log "Django failed to start properly"
    exit 1
}

# Start DICOM receiver if not running
log "Starting DICOM receiver..."
if is_running "dicom_receiver.py"; then
    log "DICOM receiver is already running"
    DICOM_PID=$(pgrep -f "dicom_receiver.py")
else
    python dicom_receiver.py &
    DICOM_PID=$!
    log "DICOM receiver started with PID $DICOM_PID"
fi

# Configure and start ngrok
log "Configuring ngrok..."

# Check if ngrok config exists, create if not
NGROK_CONFIG_DIR="$HOME/.config/ngrok"
NGROK_CONFIG_FILE="$NGROK_CONFIG_DIR/ngrok.yml"

mkdir -p "$NGROK_CONFIG_DIR"

# Create ngrok config if it doesn't exist
if [ ! -f "$NGROK_CONFIG_FILE" ]; then
    log "Creating ngrok configuration..."
    cat > "$NGROK_CONFIG_FILE" << EOF
version: "2"
authtoken: ${NGROK_AUTHTOKEN:-}
tunnels:
  noctispro-http:
    proto: http
    addr: 8000
    bind_tls: true
  noctispro-static:
    proto: http
    addr: 8000
    hostname: ${NGROK_STATIC_URL:-}
    bind_tls: true
  noctispro-subdomain:
    proto: http
    addr: 8000
    subdomain: ${NGROK_SUBDOMAIN:-}
    bind_tls: true
  noctispro-domain:
    proto: http
    addr: 8000
    hostname: ${NGROK_DOMAIN:-}
    bind_tls: true
EOF
else
    log "Ngrok config exists, updating static URL..."
    # Update the static URL in existing config if needed
    if [ ! -z "${NGROK_STATIC_URL:-}" ]; then
        sed -i "s/hostname: .*/hostname: ${NGROK_STATIC_URL}/" "$NGROK_CONFIG_FILE" 2>/dev/null || true
    fi
fi

# Start ngrok
log "Starting ngrok tunnel..."
if is_running "ngrok"; then
    log "Ngrok is already running"
    NGROK_PID=$(pgrep ngrok)
else
    # Determine which tunnel to use based on configuration
    if [ "${NGROK_USE_STATIC:-false}" = "true" ]; then
        if [ ! -z "${NGROK_STATIC_URL:-}" ]; then
            # Use static URL directly
            log "Using configured static URL: $NGROK_STATIC_URL"
            TUNNEL_NAME="noctispro-static"
        elif [ ! -z "${NGROK_DOMAIN:-}" ]; then
            TUNNEL_NAME="noctispro-domain"
        elif [ ! -z "${NGROK_SUBDOMAIN:-}" ]; then
            TUNNEL_NAME="noctispro-static"
        else
            TUNNEL_NAME="noctispro-http"
        fi
    else
        TUNNEL_NAME="${NGROK_TUNNEL_NAME:-noctispro-http}"
    fi
    
    log "Starting ngrok tunnel: $TUNNEL_NAME"
    ngrok start "$TUNNEL_NAME" --log=stdout &
    NGROK_PID=$!
    log "Ngrok started with PID $NGROK_PID"
fi

# Wait for ngrok to be ready and get URL
log "Waiting for ngrok to establish tunnel..."
sleep 10

# Get ngrok URL
NGROK_URL=""

# If static URL is configured, use it directly
if [ "${NGROK_USE_STATIC:-false}" = "true" ] && [ ! -z "${NGROK_STATIC_URL:-}" ]; then
    NGROK_URL="https://${NGROK_STATIC_URL}"
    log "✅ Using configured static URL: $NGROK_URL"
else
    # Try to get URL from ngrok API
    for i in {1..15}; do
        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data['tunnels']:
        if tunnel['proto'] == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
" 2>/dev/null)
        
        if [ ! -z "$NGROK_URL" ]; then
            log "✅ Ngrok tunnel active: $NGROK_URL"
            break
        else
            log "Waiting for ngrok tunnel... (attempt $i/15)"
            sleep 2
        fi
    done
fi

if [ -z "$NGROK_URL" ]; then
    log "⚠️  Could not get ngrok URL - check ngrok configuration"
    # Fallback to static URL if configured
    if [ ! -z "${NGROK_STATIC_URL:-}" ]; then
        NGROK_URL="https://${NGROK_STATIC_URL}"
        log "⚠️  Using fallback static URL: $NGROK_URL"
    fi
else
    # Save URL to file for easy access
    echo "$NGROK_URL" > "$WORKSPACE_DIR/current_ngrok_url.txt"
    log "✅ Current URL saved to: $WORKSPACE_DIR/current_ngrok_url.txt"
fi

# Create PID file with all process IDs
echo "$DJANGO_PID,$DICOM_PID,$NGROK_PID" > "$PID_FILE"

# Display startup summary
log "==================== STARTUP COMPLETE ===================="
log "Django Application: http://localhost:8000 (PID: $DJANGO_PID)"
log "DICOM Receiver: Running (PID: $DICOM_PID)"
log "Ngrok Tunnel: $NGROK_URL (PID: $NGROK_PID)"
log "Logs: $LOG_FILE"
log "PID File: $PID_FILE"
log "========================================================"

# Keep the script running (required for forking service)
wait