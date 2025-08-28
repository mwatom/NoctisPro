#!/bin/bash

# NoctisPro Production System Stop Script

WORKSPACE_DIR="/workspace"
LOG_FILE="$WORKSPACE_DIR/noctispro_production.log"
PID_FILE="$WORKSPACE_DIR/noctispro_production.pid"
DJANGO_PID_FILE="$WORKSPACE_DIR/django_production.pid"
NGROK_PID_FILE="$WORKSPACE_DIR/ngrok_production.pid"

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

log "🛑 Stopping NoctisPro Production System..."

# Stop Django server
if [ -f "$DJANGO_PID_FILE" ]; then
    DJANGO_PID=$(cat "$DJANGO_PID_FILE")
    if kill -0 "$DJANGO_PID" 2>/dev/null; then
        log "🔄 Stopping Django server (PID: $DJANGO_PID)..."
        kill -TERM "$DJANGO_PID" 2>/dev/null || true
        
        # Wait for graceful shutdown
        for i in {1..10}; do
            if ! kill -0 "$DJANGO_PID" 2>/dev/null; then
                break
            fi
            sleep 1
        done
        
        # Force kill if still running
        if kill -0 "$DJANGO_PID" 2>/dev/null; then
            log "🔨 Force stopping Django server..."
            kill -KILL "$DJANGO_PID" 2>/dev/null || true
        fi
        
        log "✅ Django server stopped"
    fi
    rm -f "$DJANGO_PID_FILE"
fi

# Stop ngrok tunnel
if [ -f "$NGROK_PID_FILE" ]; then
    NGROK_PID=$(cat "$NGROK_PID_FILE")
    if kill -0 "$NGROK_PID" 2>/dev/null; then
        log "🔄 Stopping Ngrok tunnel (PID: $NGROK_PID)..."
        kill -TERM "$NGROK_PID" 2>/dev/null || true
        
        # Wait for graceful shutdown
        for i in {1..5}; do
            if ! kill -0 "$NGROK_PID" 2>/dev/null; then
                break
            fi
            sleep 1
        done
        
        # Force kill if still running
        if kill -0 "$NGROK_PID" 2>/dev/null; then
            log "🔨 Force stopping Ngrok tunnel..."
            kill -KILL "$NGROK_PID" 2>/dev/null || true
        fi
        
        log "✅ Ngrok tunnel stopped"
    fi
    rm -f "$NGROK_PID_FILE"
fi

# Kill any remaining processes
log "🧹 Cleaning up remaining processes..."
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true

# Remove main PID file
rm -f "$PID_FILE"

log "✅ NoctisPro Production System stopped successfully"