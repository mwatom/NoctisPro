#!/bin/bash

# Start Ngrok Tunnel for NoctisPro

echo "🌐 Starting Ngrok Tunnel for NoctisPro"
echo "======================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if ngrok is configured
if ! ./ngrok config check > /dev/null 2>&1; then
    echo "❌ Ngrok is not configured with an auth token!"
    echo ""
    echo "Please run one of these commands first:"
    echo "  1. ./configure_ngrok_auth.sh  (interactive setup)"
    echo "  2. ./ngrok config add-authtoken YOUR_TOKEN  (quick setup)"
    echo ""
    echo "Get your auth token from: https://dashboard.ngrok.com/get-started/your-authtoken"
    exit 1
fi

# Check if NoctisPro is running
if ! curl -s -f http://localhost:8000 >/dev/null 2>&1; then
    echo "❌ NoctisPro is not running on port 8000!"
    echo ""
    echo "Please start NoctisPro first:"
    echo "  ./fix_deployment.sh"
    echo ""
    exit 1
fi

# Kill any existing ngrok processes
pkill -f ngrok

# Start ngrok tunnel
echo "🚀 Starting ngrok tunnel..."
./ngrok http 8000 --log stdout > ngrok.log 2>&1 &
NGROK_PID=$!

echo "⏳ Waiting for ngrok to start..."
sleep 5

# Check if ngrok started successfully
if ps -p $NGROK_PID > /dev/null; then
    echo "✅ Ngrok tunnel started successfully!"
    
    # Get the public URL
    sleep 2
    PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['tunnels'][0]['public_url'] if data.get('tunnels') else '')
except:
    print('')
" 2>/dev/null)
    
    if [ ! -z "$PUBLIC_URL" ]; then
        echo ""
        echo "🎉 Your NoctisPro is now online!"
        echo "================================"
        echo "🌐 Public URL: $PUBLIC_URL"
        echo "🏥 Health Check: $PUBLIC_URL/health/"
        echo "👤 Admin Panel: $PUBLIC_URL/admin/"
        echo ""
        echo "📋 Management:"
        echo "• Check status: ./check_status.sh"
        echo "• View logs: tail -f ngrok.log"
        echo "• Stop ngrok: pkill -f ngrok"
        echo ""
        
        # Save URL for other scripts
        echo "$PUBLIC_URL" > current_ngrok_url.txt
    else
        echo "⚠️ Ngrok started but couldn't get public URL. Check logs:"
        tail -10 ngrok.log
    fi
else
    echo "❌ Ngrok failed to start. Check logs:"
    tail -10 ngrok.log
    exit 1
fi