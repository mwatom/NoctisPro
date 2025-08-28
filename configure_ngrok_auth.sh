#!/bin/bash

# Script to configure ngrok authentication token

echo "🔑 Ngrok Authentication Setup"
echo "============================="
echo ""

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ Ngrok is not installed!"
    echo ""
    echo "To install ngrok:"
    echo "  1. Download from: https://ngrok.com/download"
    echo "  2. Or run: curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && echo \"deb https://ngrok-agent.s3.amazonaws.com buster main\" | sudo tee /etc/apt/sources.list.d/ngrok.list && sudo apt update && sudo apt install ngrok"
    exit 1
fi

# Check current auth status
echo "Checking current ngrok configuration..."
if ngrok config check > /dev/null 2>&1; then
    echo "✅ Ngrok is already configured with an auth token!"
    
    # Show current config
    echo ""
    echo "Current ngrok configuration:"
    ngrok config check
    
    echo ""
    read -p "Do you want to update your auth token? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping current configuration."
        exit 0
    fi
fi

echo ""
echo "❌ Ngrok auth token not configured or needs updating."
echo ""
echo "📋 To get your ngrok auth token:"
echo "   1. Visit: https://dashboard.ngrok.com/get-started/your-authtoken"
echo "   2. Sign up or log in to your ngrok account"
echo "   3. Copy your auth token from the dashboard"
echo ""

# Prompt for auth token
while true; do
    read -p "Enter your ngrok auth token (or 'q' to quit): " -r
    
    if [[ $REPLY = "q" || $REPLY = "Q" ]]; then
        echo "Exiting without configuring ngrok."
        exit 1
    fi
    
    if [[ -z $REPLY ]]; then
        echo "❌ Please enter a valid auth token."
        continue
    fi
    
    # Try to configure the auth token
    echo "Configuring ngrok with provided token..."
    if ngrok config add-authtoken "$REPLY" > /dev/null 2>&1; then
        echo "✅ Ngrok auth token configured successfully!"
        break
    else
        echo "❌ Failed to configure auth token. Please check the token and try again."
    fi
done

# Verify configuration
echo ""
echo "Verifying configuration..."
if ngrok config check > /dev/null 2>&1; then
    echo "✅ Ngrok is now properly configured!"
    echo ""
    echo "Configuration details:"
    ngrok config check
    echo ""
    echo "🎉 You can now run the autostart setup:"
    echo "   sudo ./setup_complete_autostart.sh"
else
    echo "❌ Configuration verification failed. Please try again."
    exit 1
fi