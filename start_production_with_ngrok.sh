#!/bin/bash

# NoctisPro Production Startup with Ngrok Static URL
# Optimized for Ubuntu Server production deployment

set -e

WORKSPACE_DIR="/workspace"
LOG_FILE="$WORKSPACE_DIR/noctispro_production.log"
PID_FILE="$WORKSPACE_DIR/noctispro_production.pid"
DJANGO_PID_FILE="$WORKSPACE_DIR/django_production.pid"
NGROK_PID_FILE="$WORKSPACE_DIR/ngrok_production.pid"

# Redirect output to log file with timestamps
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

# Function to cleanup on exit
cleanup() {
    log "🧹 Cleaning up processes..."
    if [ -f "$DJANGO_PID_FILE" ]; then
        DJANGO_PID=$(cat "$DJANGO_PID_FILE")
        if kill -0 "$DJANGO_PID" 2>/dev/null; then
            log "Stopping Django server (PID: $DJANGO_PID)"
            kill -TERM "$DJANGO_PID" 2>/dev/null || true
            sleep 3
            kill -KILL "$DJANGO_PID" 2>/dev/null || true
        fi
        rm -f "$DJANGO_PID_FILE"
    fi
    
    if [ -f "$NGROK_PID_FILE" ]; then
        NGROK_PID=$(cat "$NGROK_PID_FILE")
        if kill -0 "$NGROK_PID" 2>/dev/null; then
            log "Stopping Ngrok tunnel (PID: $NGROK_PID)"
            kill -TERM "$NGROK_PID" 2>/dev/null || true
            sleep 2
            kill -KILL "$NGROK_PID" 2>/dev/null || true
        fi
        rm -f "$NGROK_PID_FILE"
    fi
    
    # Kill any remaining processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok" 2>/dev/null || true
    
    rm -f "$PID_FILE"
    log "🏁 Cleanup completed"
}

# Set up signal handlers
trap cleanup EXIT TERM INT

log "🚀 Starting NoctisPro Production System with Ngrok Static URL"
log "=============================================================="

# Change to workspace directory
cd "$WORKSPACE_DIR"

# Load environment variables
if [ -f ".env.production" ]; then
    log "📋 Loading production environment..."
    source .env.production
fi

if [ -f ".env.ngrok" ]; then
    log "🔗 Loading ngrok environment..."
    source .env.ngrok
fi

# Activate virtual environment
if [ -d "venv" ]; then
    log "🐍 Activating Python virtual environment..."
    source venv/bin/activate
else
    log "❌ Virtual environment not found at venv/"
    exit 1
fi

# Verify dependencies
log "🔍 Verifying system dependencies..."

# Check if PostgreSQL is running
if ! systemctl is-active postgresql >/dev/null 2>&1; then
    log "❌ PostgreSQL is not running"
    exit 1
fi

# Check if Redis is running
if ! systemctl is-active redis-server >/dev/null 2>&1; then
    log "❌ Redis is not running"
    exit 1
fi

# Check Django setup
log "🔧 Verifying Django configuration..."
if ! python manage.py check --deploy >/dev/null 2>&1; then
    log "❌ Django configuration check failed"
    exit 1
fi

# Check ngrok authentication
log "🔐 Verifying ngrok authentication..."
if ! ngrok config check >/dev/null 2>&1; then
    log "❌ Ngrok authentication not configured"
    log "   Run: ngrok config add-authtoken <your-token>"
    exit 1
fi

# Determine ngrok command based on configuration
NGROK_CMD="ngrok http 8000"

if [ "$NGROK_USE_STATIC" = "true" ]; then
    if [ ! -z "$NGROK_STATIC_URL" ]; then
        log "🌐 Using static ngrok URL: https://$NGROK_STATIC_URL"
        NGROK_CMD="ngrok http --url=$NGROK_STATIC_URL 8000"
    elif [ ! -z "$NGROK_SUBDOMAIN" ]; then
        log "🌐 Using static subdomain: $NGROK_SUBDOMAIN.ngrok.io"
        NGROK_CMD="ngrok http --subdomain=$NGROK_SUBDOMAIN 8000"
    elif [ ! -z "$NGROK_DOMAIN" ]; then
        log "🌐 Using custom domain: $NGROK_DOMAIN"
        NGROK_CMD="ngrok http --hostname=$NGROK_DOMAIN 8000"
    fi
fi

# Add region if specified
if [ ! -z "$NGROK_REGION" ]; then
    NGROK_CMD="$NGROK_CMD --region=$NGROK_REGION"
fi

log "📡 Ngrok command: $NGROK_CMD"

# Start Django server
log "🌟 Starting Django production server..."
nohup python manage.py runserver 0.0.0.0:8000 \
    --noreload \
    --nothreading \
    > "$WORKSPACE_DIR/django_production.log" 2>&1 &

DJANGO_PID=$!
echo $DJANGO_PID > "$DJANGO_PID_FILE"
log "✅ Django server started (PID: $DJANGO_PID)"

# Wait for Django to be ready
log "⏳ Waiting for Django server to be ready..."
for i in {1..30}; do
    if curl -s -f http://localhost:8000 >/dev/null 2>&1; then
        log "✅ Django server is responding"
        break
    fi
    if [ $i -eq 30 ]; then
        log "❌ Django server failed to start within 30 seconds"
        exit 1
    fi
    sleep 1
done

# Start ngrok tunnel
log "🔗 Starting ngrok tunnel..."
nohup $NGROK_CMD \
    --log=stdout \
    --log-level=info \
    > "$WORKSPACE_DIR/ngrok_production.log" 2>&1 &

NGROK_PID=$!
echo $NGROK_PID > "$NGROK_PID_FILE"
log "✅ Ngrok tunnel started (PID: $NGROK_PID)"

# Wait for ngrok to be ready and get the URL
log "⏳ Waiting for ngrok tunnel to be established..."
sleep 5

# Try to get the ngrok URL
NGROK_URL=""
for i in {1..20}; do
    if NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data.get('tunnels', []):
        if tunnel.get('proto') == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
" 2>/dev/null); then
        if [ ! -z "$NGROK_URL" ]; then
            log "🌍 Ngrok tunnel established: $NGROK_URL"
            break
        fi
    fi
    if [ $i -eq 20 ]; then
        log "⚠️  Could not retrieve ngrok URL from API, but tunnel may still be running"
    fi
    sleep 2
done

# Store main PID for systemd
echo $$ > "$PID_FILE"

# Health check function
health_check() {
    # Check Django
    if ! kill -0 "$DJANGO_PID" 2>/dev/null; then
        log "❌ Django server died, restarting..."
        return 1
    fi
    
    # Check ngrok
    if ! kill -0 "$NGROK_PID" 2>/dev/null; then
        log "❌ Ngrok tunnel died, restarting..."
        return 1
    fi
    
    # Check HTTP response
    if ! curl -s -f http://localhost:8000 >/dev/null 2>&1; then
        log "❌ Django server not responding"
        return 1
    fi
    
    return 0
}

log "✅ NoctisPro Production System started successfully!"
log "📊 System Status:"
log "   - Django Server: Running (PID: $DJANGO_PID)"
log "   - Ngrok Tunnel: Running (PID: $NGROK_PID)"
if [ ! -z "$NGROK_URL" ]; then
    log "   - Public URL: $NGROK_URL"
fi
log "   - Local URL: http://localhost:8000"
log "   - Ngrok Web UI: http://localhost:4040"

# Keep the script running and monitor processes
while true; do
    if health_check; then
        log "💚 Health check passed"
    else
        log "💔 Health check failed - system will restart"
        exit 1
    fi
    sleep 30
done