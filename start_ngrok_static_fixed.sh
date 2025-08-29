#!/bin/bash

# Start ngrok with static URL using your exact command
set -euo pipefail

STATIC_URL="colt-charmed-lark.ngrok-free.app"
TARGET_PORT="8000"

echo "🌐 Starting ngrok with static URL: https://$STATIC_URL"

# Kill any existing ngrok processes
pkill -f ngrok || true
sleep 2

# Start ngrok with your exact command format
nohup ngrok http --url=$STATIC_URL $TARGET_PORT > ngrok.log 2>&1 &

# Wait for ngrok to initialize
sleep 5

# Verify ngrok is running
if pgrep -f ngrok >/dev/null; then
    echo "✅ Ngrok started successfully with static URL: https://$STATIC_URL"
    echo "🔗 Your application is now accessible at: https://$STATIC_URL"
    
    # Try to get the actual URL from ngrok API
    if curl -s http://localhost:4040/api/tunnels >/dev/null 2>&1; then
        ACTUAL_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | grep https | cut -d'"' -f4)
        if [ ! -z "$ACTUAL_URL" ]; then
            echo "📡 Ngrok tunnel URL: $ACTUAL_URL"
            echo "$ACTUAL_URL" > current_ngrok_url.txt
        fi
    fi
else
    echo "❌ Failed to start ngrok"
    cat ngrok.log
    exit 1
fi