#!/bin/bash

# One-liner to connect Django app to static ngrok URL
# Usage: ./connect_static_url.sh

pkill ngrok 2>/dev/null || true
sleep 1
echo "🚀 Connecting to mallard-shining-curiously.ngrok-free.app..."
nohup /workspace/ngrok http --url=mallard-shining-curiously.ngrok-free.app 8000 > /workspace/ngrok_connection.log 2>&1 &
echo "✅ Ngrok started! Your app is available at: https://mallard-shining-curiously.ngrok-free.app"
echo "📋 Process ID: $!"
echo "📋 Log file: /workspace/ngrok_connection.log"