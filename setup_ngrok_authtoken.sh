#!/bin/bash

# 🔑 Setup Ngrok Authtoken for Static URL
echo "🔑 Setting up Ngrok authtoken for static URL deployment..."

if [ -z "$1" ]; then
    echo ""
    echo "❌ Usage: ./setup_ngrok_authtoken.sh YOUR_AUTHTOKEN"
    echo ""
    echo "📋 Steps to get your authtoken:"
    echo "   1. Go to: https://dashboard.ngrok.com/signup"
    echo "   2. Create free account (if needed)"
    echo "   3. Get authtoken: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "   4. Run: ./setup_ngrok_authtoken.sh YOUR_TOKEN_HERE"
    echo ""
    exit 1
fi

AUTHTOKEN="$1"

echo "🔧 Configuring ngrok with authtoken..."
cd /workspace
./ngrok config add-authtoken "$AUTHTOKEN"

if [ $? -eq 0 ]; then
    echo "✅ Ngrok authtoken configured successfully!"
    echo ""
    echo "🚀 Now you can deploy as service:"
    echo "   sudo bash deploy_as_service.sh"
    echo ""
    echo "🌐 Your static URL will be: https://colt-charmed-lark.ngrok-free.app"
else
    echo "❌ Failed to configure authtoken"
    exit 1
fi