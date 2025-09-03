#!/bin/bash
# Auto-start script for NoctisPro Masterpiece

# Check if already running
if tmux has-session -t noctispro-masterpiece 2>/dev/null; then
    echo "Service already running"
    exit 0
fi

# Wait for system to be ready
sleep 10

# Start the service
cd /workspace
./deploy_masterpiece_service.sh start > /workspace/autostart_noctispro-masterpiece.log 2>&1 &

echo "Auto-start initiated"
