#!/bin/bash

# NoctisPro Ngrok Tunnel Script
# This script starts ngrok tunnel and updates the Django settings with the new URL

set -e

echo "🌐 Starting Ngrok tunnel for NoctisPro..."

# Kill any existing ngrok processes
pkill -f ngrok || true
sleep 2

# Start ngrok in background
echo "🚀 Starting ngrok tunnel on port 8000..."
nohup ngrok http 8000 > ngrok_output.log 2>&1 &

# Wait for ngrok to start
echo "⏳ Waiting for ngrok to initialize..."
sleep 5

# Get the public URL
NGROK_URL=""
for i in {1..10}; do
    NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if data['tunnels']:
        print(data['tunnels'][0]['public_url'])
    else:
        print('')
except:
    print('')
" 2>/dev/null || echo "")
    
    if [ ! -z "$NGROK_URL" ]; then
        break
    fi
    echo "⏳ Waiting for ngrok tunnel... (attempt $i/10)"
    sleep 2
done

if [ -z "$NGROK_URL" ]; then
    echo "❌ Failed to get ngrok URL. Check if ngrok is authenticated."
    echo "💡 Run: ngrok authtoken YOUR_TOKEN"
    exit 1
fi

echo "✅ Ngrok tunnel active: $NGROK_URL"
echo "$NGROK_URL" > current_ngrok_url.txt

# Extract domain from URL for Django settings
NGROK_DOMAIN=$(echo $NGROK_URL | sed 's|https\?://||g')

# Update environment file with new ngrok URL
sed -i "s|ALLOWED_HOSTS=.*|ALLOWED_HOSTS=*,$NGROK_DOMAIN,localhost,127.0.0.1,0.0.0.0|g" .env.production.fixed

echo "🔧 Updated Django settings with ngrok URL: $NGROK_DOMAIN"
echo "🌟 Your NoctisPro application is now accessible at: $NGROK_URL"
echo "🔑 Admin panel: $NGROK_URL/admin"
echo ""
echo "📋 To test the connection:"
echo "   curl -H \"ngrok-skip-browser-warning: 1\" $NGROK_URL"
echo ""
echo "🔄 Ngrok tunnel is running in background. Check ngrok_output.log for details."