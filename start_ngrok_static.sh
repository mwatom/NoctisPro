#!/bin/bash

# Start ngrok with static URL for NoctisPro
set -euo pipefail

# Load configuration
if [ -f .env.ngrok ]; then
    source .env.ngrok
fi

STATIC_URL="${NGROK_STATIC_URL:-colt-charmed-lark.ngrok-free.app}"
TARGET_PORT="${NGROK_TARGET_PORT:-8000}"
PROTOCOL="${NGROK_PROTOCOL:-http}"

echo "🌐 Starting ngrok with static URL: https://$STATIC_URL"

# Kill any existing ngrok processes
pkill -f ngrok || true
sleep 2

# Start ngrok with static URL (free tier)
nohup ngrok $PROTOCOL --url=$STATIC_URL $TARGET_PORT > ngrok.log 2>&1 &

# Wait for ngrok to initialize
sleep 5

# Verify ngrok is running
if pgrep -f ngrok >/dev/null; then
    echo "✅ Ngrok started successfully with static URL: https://$STATIC_URL"
    echo "🔗 Your application is now accessible at: https://$STATIC_URL"
else
    echo "❌ Failed to start ngrok"
    cat ngrok.log
    exit 1
fi