#!/bin/bash

# Setup Ngrok with Static URL for NoctisPro
echo "🌐 Setting up Ngrok Static URL for NoctisPro"
echo "============================================"

if [ -z "$1" ]; then
    echo ""
    echo "❌ Error: Ngrok authtoken required"
    echo ""
    echo "📋 To get your FREE ngrok authtoken:"
    echo "1. Visit: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "2. Sign up or log in (100% FREE)"
    echo "3. Copy your authtoken"
    echo "4. Run this script with your token:"
    echo ""
    echo "   ./setup_ngrok_static_url.sh YOUR_AUTHTOKEN_HERE"
    echo ""
    echo "📝 Example:"
    echo "   ./setup_ngrok_static_url.sh 2abc123def456ghi789jkl"
    echo ""
    exit 1
fi

AUTHTOKEN="$1"
STATIC_URL="colt-charmed-lark.ngrok-free.app"

echo "🔧 Configuring ngrok with authtoken..."
ngrok config add-authtoken "$AUTHTOKEN"

if [ $? -eq 0 ]; then
    echo "✅ Authtoken configured successfully"
    echo ""
    echo "🚀 Starting ngrok with static URL: https://$STATIC_URL"
    
    # Stop any existing ngrok processes
    pkill -f ngrok 2>/dev/null || true
    sleep 2
    
    # Start ngrok with static URL
    mkdir -p logs
    ngrok http --url="$STATIC_URL" 8000 --log stdout > logs/ngrok.log 2>&1 &
    NGROK_PID=$!
    echo $NGROK_PID > ngrok.pid
    
    echo "⏳ Waiting for ngrok to connect..."
    sleep 10
    
    # Check if ngrok is running
    if kill -0 $NGROK_PID 2>/dev/null; then
        echo "✅ Ngrok started successfully!"
        echo "https://$STATIC_URL" > current_ngrok_url.txt
        
        echo ""
        echo "🎉 NoctisPro is now publicly accessible!"
        echo "======================================"
        echo "🌍 Public URL: https://$STATIC_URL"
        echo "🏥 Health Check: https://$STATIC_URL/health/"
        echo "👤 Login Page: https://$STATIC_URL/login/"
        echo "🔧 Admin Panel: https://$STATIC_URL/admin/"
        echo ""
        echo "📊 System Status:"
        ./status_noctispro_production.sh
        echo ""
        echo "📋 Management Commands:"
        echo "• Check status: ./status_noctispro_production.sh"
        echo "• Stop system: ./stop_noctispro_production.sh"
        echo "• View logs: tail -f logs/ngrok.log"
    else
        echo "❌ Ngrok failed to start. Check logs:"
        tail -20 logs/ngrok.log
        exit 1
    fi
else
    echo "❌ Failed to configure authtoken"
    exit 1
fi