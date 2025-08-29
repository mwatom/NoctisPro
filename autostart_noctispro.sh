#!/bin/bash

# NoctisPro Auto-Startup Service with Static Ngrok URL
# Designed for container environment, preserves colt-charmed-lark.ngrok-free.app

set -e

# Set environment variables for container deployment
export USE_POSTGRESQL=true
export DISABLE_REDIS=true
export USE_DUMMY_CACHE=true
export DEBUG=false
export PATH="/home/ubuntu/.local/bin:$PATH"

WORKSPACE_DIR="/workspace"
STATIC_NGROK_URL="colt-charmed-lark.ngrok-free.app"
LOG_FILE="$WORKSPACE_DIR/autostart_noctispro.log"
PID_FILE="$WORKSPACE_DIR/autostart_noctispro.pid"
URL_FILE="$WORKSPACE_DIR/current_ngrok_url.txt"

# Redirect output to log file with timestamps
exec > >(while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee -a "$LOG_FILE") 2>&1

echo "🚀 Starting NoctisPro Auto-Startup Service"
echo "============================================"
echo "Static Ngrok URL: https://$STATIC_NGROK_URL"
echo "Workspace: $WORKSPACE_DIR"
echo "Started at: $(date)"

# Store PID for management
echo $$ > "$PID_FILE"

# Function to log with emoji
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
    local max_attempts=30
    local attempt=1
    
    log "🔍 Waiting for service at $url..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            log "✅ Service is ready at $url"
            return 0
        fi
        log "🔄 Attempt $attempt/$max_attempts: Service not ready, waiting 10s..."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    log "❌ Service failed to start after $max_attempts attempts"
    return 1
}

# Function to stop existing ngrok processes
stop_existing_ngrok() {
    log "🛑 Checking for existing ngrok processes..."
    if is_running "ngrok"; then
        log "⚠️  Found existing ngrok process, stopping it..."
        pkill -f "ngrok" || true
        sleep 5
        if is_running "ngrok"; then
            log "🔨 Force killing stubborn ngrok processes..."
            pkill -9 -f "ngrok" || true
            sleep 3
        fi
        log "✅ Existing ngrok processes stopped"
    else
        log "✅ No existing ngrok processes found"
    fi
}

# Function to start ngrok with retries and conflict resolution
start_ngrok_with_retries() {
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "🌐 Attempt $attempt/$max_attempts: Starting ngrok with static URL..."
        
        # Stop any existing ngrok processes first
        stop_existing_ngrok
        
        # Check if ngrok is authenticated
        if ! ngrok config check > /dev/null 2>&1; then
            log "⚠️  Ngrok not authenticated. Trying without custom domain..."
            # Start ngrok without custom domain
            nohup ngrok http 8000 --log=file > "$WORKSPACE_DIR/ngrok.log" 2>&1 &
        else
            # Start ngrok with custom domain
            nohup ngrok http --url=$STATIC_NGROK_URL ${DJANGO_PORT:-80} --log=file > "$WORKSPACE_DIR/ngrok.log" 2>&1 &
        fi
        local ngrok_pid=$!
        
        # Wait a bit for ngrok to start
        sleep 10
        
        # Check if ngrok is still running
        if kill -0 $ngrok_pid 2>/dev/null; then
            log "✅ Ngrok started successfully (PID: $ngrok_pid)"
            
            # Get the actual ngrok URL
            sleep 5  # Wait for ngrok to establish tunnel
            local ngrok_url
            if ngrok config check > /dev/null 2>&1; then
                # Using custom domain
                ngrok_url="https://$STATIC_NGROK_URL"
            else
                # Get dynamic URL from ngrok API
                ngrok_url=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data.get('tunnels', []):
        if tunnel.get('proto') == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
" 2>/dev/null)
                if [ -z "$ngrok_url" ]; then
                    ngrok_url="http://localhost:8000"
                    log "⚠️  Could not get ngrok URL, using localhost"
                fi
            fi
            
            echo "$ngrok_url" > "$URL_FILE"
            log "🌍 Tunnel URL: $ngrok_url"
            return 0
        else
            log "❌ Ngrok failed to start, checking logs..."
            if [ -f "$WORKSPACE_DIR/ngrok.log" ]; then
                tail -5 "$WORKSPACE_DIR/ngrok.log" | while read line; do
                    log "📄 Ngrok log: $line"
                done
            fi
            
            if [ $attempt -lt $max_attempts ]; then
                log "🔄 Retrying in 15 seconds..."
                sleep 15
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    log "❌ Failed to start ngrok after $max_attempts attempts"
    return 1
}

# Function to start Django
start_django() {
    log "🐍 Starting Django server..."
    
    # Add local bin to PATH for Django and other tools
    export PATH="/home/ubuntu/.local/bin:$PATH"
    
    # Check if Python packages are available
    if python3 -c "import django" 2>/dev/null; then
        log "✅ Django is available"
    else
        log "❌ Django not found in Python path"
        return 1
    fi
    
    # Run migrations
    log "🔄 Running database migrations..."
    cd "$WORKSPACE_DIR"
    python3 manage.py migrate --noinput
    
    # Collect static files
    log "📂 Collecting static files..."
    python3 manage.py collectstatic --noinput || true
    
    # Start Django with Daphne (ASGI server)
    log "🌐 Starting Django/Daphne server on port 8000..."
    nohup daphne -b 0.0.0.0 -p 8000 noctis_pro.asgi:application > "$WORKSPACE_DIR/django.log" 2>&1 &
    local django_pid=$!
    
    # Wait a bit for Django to start
    sleep 5
    
    # Check if Django is running
    if kill -0 $django_pid 2>/dev/null; then
        log "✅ Django started successfully (PID: $django_pid)"
        return 0
    else
        log "❌ Django failed to start"
        return 1
    fi
}

# Function to monitor services and restart if needed
monitor_services() {
    while true; do
        sleep 60  # Check every minute
        
        # Check Django
        if ! is_running "daphne.*noctis_pro"; then
            log "⚠️  Django is not running, restarting..."
            start_django
        fi
        
        # Check ngrok
        if ! is_running "ngrok"; then
            log "⚠️  Ngrok is not running, restarting..."
            start_ngrok_with_retries
        fi
        
        # Verify external access (if available)
        if [ -f "$URL_FILE" ]; then
            local current_url=$(cat "$URL_FILE")
            if [[ "$current_url" == http*://*.ngrok*.* ]]; then
                if ! curl -s -f "$current_url/health/simple/" > /dev/null 2>&1; then
                    log "⚠️  External access failed, services may need restart..."
                    # Could add more sophisticated restart logic here
                fi
            fi
        fi
    done
}

# Main startup sequence
main() {
    log "🏁 Starting main startup sequence..."
    
    # Start Django first
    if start_django; then
        log "✅ Django startup successful"
    else
        log "❌ Django startup failed, exiting"
        exit 1
    fi
    
    # Wait for Django to be ready
    if wait_for_service "http://localhost:8000/health/simple/"; then
        log "✅ Django is responding to health checks"
    else
        log "❌ Django health check failed"
        exit 1
    fi
    
    # Start ngrok (optional)
    if start_ngrok_with_retries; then
        log "✅ Ngrok startup successful"
    else
        log "⚠️  Ngrok startup failed - continuing without external tunnel"
        log "ℹ️  NoctisPro will run locally only. To enable external access:"
        log "ℹ️  1. Get a free ngrok account: https://dashboard.ngrok.com/signup"
        log "ℹ️  2. Get your auth token: https://dashboard.ngrok.com/get-started/your-authtoken"
        log "ℹ️  3. Run: ngrok config add-authtoken YOUR_TOKEN"
        log "ℹ️  4. Restart this service: ./manage_autostart.sh restart"
        echo "http://localhost:8000" > "$URL_FILE"
    fi
    
    # Get the current ngrok URL
    local current_url
    if [ -f "$URL_FILE" ]; then
        current_url=$(cat "$URL_FILE")
    else
        current_url="http://localhost:8000"
    fi
    
    # Wait for external access (only if we have an external URL)
    if [[ "$current_url" == http*://*.ngrok*.* ]]; then
        if wait_for_service "$current_url/health/simple/"; then
            log "🎉 External access confirmed!"
        else
            log "⚠️  External access not working, but services are running"
        fi
    else
        log "ℹ️  Running in local mode (no external tunnel)"
    fi
    
    # Display access information
    echo ""
    log "🌟 NoctisPro is now running!"
    log "🌍 External URL: $current_url"
    log "🏠 Local URL: http://localhost:8000"
    log "📊 Admin panel: $current_url/admin-panel/"
    log "🏥 DICOM viewer: $current_url/dicom-viewer/"
    log "📋 Worklist: $current_url/worklist/"
    echo ""
    
    # Start monitoring loop
    log "👁️  Starting service monitoring..."
    monitor_services
}

# Handle termination signals
cleanup() {
    log "🛑 Received termination signal, cleaning up..."
    
    # Stop ngrok
    if is_running "ngrok"; then
        log "🛑 Stopping ngrok..."
        pkill -f "ngrok" || true
    fi
    
    # Stop Django
    if is_running "daphne.*noctis_pro"; then
        log "🛑 Stopping Django..."
        pkill -f "daphne.*noctis_pro" || true
    fi
    
    # Remove PID file
    rm -f "$PID_FILE"
    
    log "✅ Cleanup complete"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Run main function
main