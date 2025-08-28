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
