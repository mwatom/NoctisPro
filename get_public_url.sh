#!/bin/bash

# Get Current Ngrok Public URL

echo "🔍 Checking Ngrok Public URL"
echo "============================"

cd /workspace

# Check if ngrok is running
if ! pgrep -f ngrok > /dev/null; then
    echo "❌ Ngrok is not running!"
    echo ""
    echo "Start ngrok with: ./start_ngrok_tunnel.sh"
    exit 1
fi

# Get URL from ngrok API
PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    tunnels = data.get('tunnels', [])
    if tunnels:
        tunnel = tunnels[0]
        print(tunnel['public_url'])
        print('DETAILS:')
        print(f'  Name: {tunnel.get(\"name\", \"N/A\")}')
        print(f'  Protocol: {tunnel.get(\"proto\", \"N/A\")}')
        print(f'  Local: {tunnel[\"config\"][\"addr\"]}')
        print(f'  Region: {tunnel.get(\"region\", \"N/A\")}')
    else:
        print('No active tunnels found')
except Exception as e:
    print(f'Error: {e}')
" 2>/dev/null)

if [ ! -z "$PUBLIC_URL" ] && [ "$PUBLIC_URL" != "No active tunnels found" ]; then
    echo "✅ Ngrok tunnel is active!"
    echo ""
    echo "$PUBLIC_URL"
    echo ""
    
    # Save URL
    CLEAN_URL=$(echo "$PUBLIC_URL" | head -1)
    echo "$CLEAN_URL" > current_ngrok_url.txt
    
    echo "🌐 Access URLs:"
    echo "• Main App: $CLEAN_URL"
    echo "• Health: $CLEAN_URL/health/"
    echo "• Admin: $CLEAN_URL/admin/"
    echo ""
    
    # Test the connection
    echo "🧪 Testing connection..."
    if curl -s -f "$CLEAN_URL" >/dev/null 2>&1; then
        echo "✅ Public URL is responding!"
    else
        echo "⚠️ Public URL might not be responding yet (check firewall/settings)"
    fi
else
    echo "❌ No active ngrok tunnels found!"
    echo ""
    echo "Troubleshooting:"
    echo "• Check if ngrok is running: ps aux | grep ngrok"
    echo "• Check ngrok logs: tail -f ngrok.log"
    echo "• Restart tunnel: ./start_ngrok_tunnel.sh"
fi