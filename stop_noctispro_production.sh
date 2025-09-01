#!/bin/bash

echo "🛑 Stopping NoctisPro Production System..."
echo "========================================="

# Stop Daphne process
if [ -f "daphne.pid" ]; then
    PID=$(cat daphne.pid)
    if kill -0 $PID 2>/dev/null; then
        echo "Stopping Daphne (PID: $PID)..."
        kill $PID
        sleep 2
        if kill -0 $PID 2>/dev/null; then
            echo "Force stopping Daphne..."
            kill -9 $PID
        fi
    fi
    rm -f daphne.pid
fi

# Stop any remaining daphne processes
pkill -f "daphne.*noctis_pro" 2>/dev/null || true

# Stop ngrok processes
pkill -f "ngrok" 2>/dev/null || true
rm -f ngrok.pid current_ngrok_url.txt

echo "✅ NoctisPro Production System stopped successfully"