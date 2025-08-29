#!/bin/bash

# NoctisPro Auto-start Script for Server Boot
# This script ensures the application starts automatically when the server boots

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOG_FILE="autostart_noctispro.log"
PID_FILE="autostart_noctispro.pid"

# Logging function
log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Check if already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        log "NoctisPro is already running (PID: $PID)"
        exit 0
    else
        log "Removing stale PID file"
        rm -f "$PID_FILE"
    fi
fi

log "Starting NoctisPro auto-startup script..."

# Ensure Redis is running
if ! redis-cli ping >/dev/null 2>&1; then
    log "Starting Redis server..."
    redis-server --daemonize yes
    sleep 3
fi

# Wait for system to be ready
log "Waiting for system to be fully ready..."
sleep 10

# Activate virtual environment and run bulletproof deployment
log "Activating virtual environment..."
source venv/bin/activate

log "Running bulletproof deployment..."
./deploy_production_bulletproof.sh

# Store our PID
echo $$ > "$PID_FILE"

log "NoctisPro startup script completed successfully"

# Keep the script running to maintain the PID
while true; do
    sleep 60
    # Check if the main application is still running
    if ! pgrep -f "daphne.*noctis_pro" >/dev/null; then
        log "Application process died, restarting..."
        ./deploy_production_bulletproof.sh
    fi
done