#!/bin/bash

echo "🔧 Ngrok Authentication Setup for NoctisPro"
echo "============================================"
echo ""

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ Ngrok is not installed!"
    echo "   Please install ngrok first by running:"
    echo "   curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null"
    echo "   echo 'deb https://ngrok-agent.s3.amazonaws.com buster main' | sudo tee /etc/apt/sources.list.d/ngrok.list"
    echo "   sudo apt update && sudo apt install ngrok"
    exit 1
fi

echo "✅ Ngrok is installed"
echo ""

# Check if auth token is already configured
if ngrok config check > /dev/null 2>&1; then
    echo "✅ Ngrok is already configured with an auth token"
    echo "   You can start the server with: ./start_with_ngrok.sh"
    exit 0
fi

echo "🔑 Ngrok authentication token is required"
echo ""
echo "📋 To get your auth token:"
echo "   1. Visit: https://dashboard.ngrok.com/signup"
echo "   2. Create a free account"
echo "   3. Go to: https://dashboard.ngrok.com/get-started/your-authtoken"
echo "   4. Copy your authtoken"
echo ""

# Prompt for auth token
read -p "Enter your ngrok auth token: " AUTH_TOKEN

if [ -z "$AUTH_TOKEN" ]; then
    echo "❌ No auth token provided. Exiting..."
    exit 1
fi

# Configure ngrok
echo "🔧 Configuring ngrok..."
ngrok config add-authtoken "$AUTH_TOKEN"

if [ $? -eq 0 ]; then
    echo "✅ Ngrok configured successfully!"
    echo ""
    echo "🚀 You can now start the server with ngrok:"
    echo "   ./start_with_ngrok.sh"
else
    echo "❌ Failed to configure ngrok. Please check your auth token."
    exit 1
fi