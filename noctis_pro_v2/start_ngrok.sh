#!/bin/bash

# 🌐 NoctisPro V2 - Ngrok Tunnel Script
# Starts ngrok tunnel with static URL

echo "🌐 Starting ngrok tunnel..."
echo "📡 Static URL: colt-charmed-lark.ngrok-free.app"
echo "🎯 Target: localhost:8000"
echo ""

# Check if ngrok exists
if [ ! -f "/workspace/ngrok" ]; then
    echo "❌ Ngrok not found at /workspace/ngrok"
    echo "Please ensure ngrok is installed and available"
    exit 1
fi

# Make ngrok executable
chmod +x /workspace/ngrok

# Start ngrok with static URL
echo "🚀 Starting ngrok tunnel..."
/workspace/ngrok http 8000 --hostname=colt-charmed-lark.ngrok-free.app --log=stdout