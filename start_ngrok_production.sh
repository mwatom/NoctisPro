#!/bin/bash

# Production ngrok startup script for NoctisPro
set -euo pipefail

TARGET_PORT="${1:-8000}"
STATIC_URL="colt-charmed-lark.ngrok-free.app"

echo "🌐 Starting ngrok tunnel for port $TARGET_PORT..."

# Kill any existing ngrok processes
pkill -f ngrok 2>/dev/null || true
sleep 2

# Try static URL first, fallback to dynamic if it fails
echo "🔗 Attempting to use static URL: $STATIC_URL"
if timeout 15 ngrok http --url=$STATIC_URL $TARGET_PORT --log stdout > ngrok.log 2>&1 &
then
    NGROK_PID=$!
    sleep 8
    
    # Check if ngrok is still running with static URL
    if kill -0 $NGROK_PID 2>/dev/null; then
        echo "✅ Ngrok started with static URL: https://$STATIC_URL"
        echo "https://$STATIC_URL" > current_ngrok_url.txt
        echo $NGROK_PID > ngrok.pid
        exit 0
    fi
fi

# Fallback to dynamic URL
echo "⚠️  Static URL failed, starting with dynamic URL..."
pkill -f ngrok 2>/dev/null || true
sleep 2

nohup ngrok http $TARGET_PORT --log stdout > ngrok.log 2>&1 &
NGROK_PID=$!
echo $NGROK_PID > ngrok.pid

sleep 5

# Get the dynamic URL
if curl -s http://localhost:4040/api/tunnels >/dev/null 2>&1; then
    TUNNEL_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | cut -d'"' -f4)
    if [ ! -z "$TUNNEL_URL" ]; then
        echo "✅ Ngrok started with dynamic URL: $TUNNEL_URL"
        echo "$TUNNEL_URL" > current_ngrok_url.txt
    else
        echo "⚠️  Could not retrieve tunnel URL"
    fi
else
    echo "⚠️  Ngrok API not accessible"
fi