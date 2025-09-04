#!/bin/bash

# 🔧 Ngrok Authentication Setup Script
# This script helps set up ngrok authentication for static URLs

echo "🔧 Ngrok Authentication Setup"
echo "================================"
echo ""

# Check if ngrok is available
if [ ! -f "/workspace/ngrok" ]; then
    echo "❌ Error: ngrok binary not found at /workspace/ngrok"
    exit 1
fi

echo "📝 To use the static URL 'mallard-shining-curiously.ngrok-free.app', you need:"
echo "   1. An ngrok account (free or paid)"
echo "   2. Your ngrok auth token"
echo ""
echo "🌐 Get your auth token from: https://dashboard.ngrok.com/get-started/your-authtoken"
echo ""

# Check if already configured
if /workspace/ngrok config check > /dev/null 2>&1; then
    echo "✅ Ngrok is already configured!"
    echo ""
    echo "🚀 You can now run: ./deploy_masterpiece_service.sh deploy"
    exit 0
fi

echo "⚠️  Ngrok is not configured yet."
echo ""
echo "Please follow these steps:"
echo "1. Go to: https://dashboard.ngrok.com/get-started/your-authtoken"
echo "2. Copy your auth token"
echo "3. Run: /workspace/ngrok config add-authtoken YOUR_TOKEN_HERE"
echo "4. Then run: ./deploy_masterpiece_service.sh deploy"
echo ""
echo "💡 Alternatively, you can add your token to a .env file:"
echo "   echo 'NGROK_AUTHTOKEN=your_token_here' >> .env.production"
echo ""

# Offer to set up token interactively if running in interactive mode
if [ -t 0 ]; then
    echo -n "Do you want to enter your auth token now? (y/n): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -n "Enter your ngrok auth token: "
        read -r token
        if [ -n "$token" ]; then
            /workspace/ngrok config add-authtoken "$token"
            if /workspace/ngrok config check > /dev/null 2>&1; then
                echo "✅ Ngrok configured successfully!"
                echo "🚀 You can now run: ./deploy_masterpiece_service.sh deploy"
            else
                echo "❌ Failed to configure ngrok. Please check your token."
            fi
        fi
    fi
fi