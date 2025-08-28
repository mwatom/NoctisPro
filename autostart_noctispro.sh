#!/bin/bash

# NoctisPro Auto-Startup Service with Static Ngrok URL
# Designed for container environment, preserves colt-charmed-lark.ngrok-free.app

set -e

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
        
        # Start ngrok in background (log to file to avoid console UI conflicts)
        nohup ngrok http --url=https://$STATIC_NGROK_URL 8000 --log=file > "$WORKSPACE_DIR/ngrok.log" 2>&1 &
        local ngrok_pid=$!
        
        # Wait a bit for ngrok to start
        sleep 10
        
        # Check if ngrok is still running
        if kill -0 $ngrok_pid 2>/dev/null; then
            log "✅ Ngrok started successfully (PID: $ngrok_pid)"
            echo "https://$STATIC_NGROK_URL" > "$URL_FILE"
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
    
    # Activate virtual environment
    if [ -f "$WORKSPACE_DIR/venv/bin/activate" ]; then
        source "$WORKSPACE_DIR/venv/bin/activate"
        log "✅ Virtual environment activated"
    else
        log "❌ Virtual environment not found"
        return 1
    fi
    
    # Run migrations
    log "🔄 Running database migrations..."
    cd "$WORKSPACE_DIR"
    python manage.py migrate --noinput
    
    # Collect static files
    log "📂 Collecting static files..."
    python manage.py collectstatic --noinput || true
    
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
        
        # Verify external access
        if ! curl -s -f "https://$STATIC_NGROK_URL/health/simple/" > /dev/null 2>&1; then
            log "⚠️  External access failed, services may need restart..."
            # Could add more sophisticated restart logic here
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
    
    # Start ngrok
    if start_ngrok_with_retries; then
        log "✅ Ngrok startup successful"
    else
        log "❌ Ngrok startup failed, exiting"
        exit 1
    fi
    
    # Wait for external access
    if wait_for_service "https://$STATIC_NGROK_URL/health/simple/"; then
        log "🎉 External access confirmed!"
    else
        log "⚠️  External access not working, but services are running"
    fi
    
    # Display access information
    echo ""
    log "🌟 NoctisPro is now running!"
    log "🌍 Static URL: https://$STATIC_NGROK_URL"
    log "🏠 Local URL: http://localhost:8000"
    log "📊 Admin panel: https://$STATIC_NGROK_URL/admin-panel/"
    log "🏥 DICOM viewer: https://$STATIC_NGROK_URL/dicom-viewer/"
    log "📋 Worklist: https://$STATIC_NGROK_URL/worklist/"
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