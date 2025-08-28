#!/bin/bash

# NoctisPro Complete System Stop Script
# Gracefully stops Django, DICOM receiver, and Ngrok

set -e

WORKSPACE_DIR="/workspace"
LOG_FILE="$WORKSPACE_DIR/noctispro_complete.log"
PID_FILE="$WORKSPACE_DIR/noctispro_complete.pid"

# Redirect output to log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "$(date): Stopping NoctisPro Complete System..."

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

# Function to safely kill process
safe_kill() {
    local pid="$1"
    local name="$2"
    
    if [ ! -z "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        log "Stopping $name (PID: $pid)..."
        kill -TERM "$pid" 2>/dev/null || true
        
        # Wait for graceful shutdown
        for i in {1..10}; do
            if ! kill -0 "$pid" 2>/dev/null; then
                log "$name stopped gracefully"
                return 0
            fi
            sleep 1
        done
        
        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            log "Force stopping $name..."
            kill -KILL "$pid" 2>/dev/null || true
        fi
    else
        log "$name is not running or PID invalid"
    fi
}

# Read PIDs from file if it exists
if [ -f "$PID_FILE" ]; then
    log "Reading process IDs from $PID_FILE..."
    PIDS=$(cat "$PID_FILE")
    IFS=',' read -r DJANGO_PID DICOM_PID NGROK_PID <<< "$PIDS"
    
    # Stop processes in reverse order
    safe_kill "$NGROK_PID" "Ngrok"
    safe_kill "$DICOM_PID" "DICOM Receiver"
    safe_kill "$DJANGO_PID" "Django"
    
    # Remove PID file
    rm -f "$PID_FILE"
    log "PID file removed"
else
    log "No PID file found, attempting to find and stop processes..."
    
    # Find and stop processes by name
    DJANGO_PID=$(pgrep -f "manage.py runserver" | head -1)
    DICOM_PID=$(pgrep -f "dicom_receiver.py" | head -1)
    NGROK_PID=$(pgrep ngrok | head -1)
    
    safe_kill "$NGROK_PID" "Ngrok"
    safe_kill "$DICOM_PID" "DICOM Receiver"
    safe_kill "$DJANGO_PID" "Django"
fi

# Remove URL file
if [ -f "$WORKSPACE_DIR/current_ngrok_url.txt" ]; then
    rm -f "$WORKSPACE_DIR/current_ngrok_url.txt"
    log "URL file removed"
fi

log "==================== SHUTDOWN COMPLETE ===================="
log "All NoctisPro services have been stopped"
log "=============================================================="