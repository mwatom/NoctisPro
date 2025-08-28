#!/bin/bash

echo "🔧 Ngrok Setup Helper"
echo "===================="
echo ""

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ Ngrok is not installed. Installing now..."
    
    # Install ngrok
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
    sudo apt update && sudo apt install ngrok
    
    if command -v ngrok &> /dev/null; then
        echo "✅ Ngrok installed successfully"
    else
        echo "❌ Failed to install ngrok"
        exit 1
    fi
else
    echo "✅ Ngrok is already installed"
fi

echo ""

# Check if ngrok is configured
if ngrok config check > /dev/null 2>&1; then
    echo "✅ Ngrok is already configured!"
    echo ""
    echo "🌐 You can now run: ./start_with_ngrok.sh"
else
    echo "❌ Ngrok is not configured yet"
    echo ""
    echo "📋 To configure ngrok:"
    echo ""
    echo "1. 🌐 Sign up for a free ngrok account:"
    echo "   https://dashboard.ngrok.com/signup"
    echo ""
    echo "2. 🔑 Get your authtoken:"
    echo "   https://dashboard.ngrok.com/get-started/your-authtoken"
    echo ""
    echo "3. 🛠️  Configure ngrok with your token:"
    echo "   ngrok config add-authtoken <your-token-here>"
    echo ""
    echo "4. 🚀 Then run: ./start_with_ngrok.sh"
    echo ""
    
    # Prompt for token if running interactively
    if [ -t 0 ]; then
        echo "💡 If you have your authtoken ready, you can enter it now:"
        read -p "Enter your ngrok authtoken (or press Enter to skip): " token
        
        if [ ! -z "$token" ]; then
            ngrok config add-authtoken "$token"
            if ngrok config check > /dev/null 2>&1; then
                echo "✅ Ngrok configured successfully!"
                echo "🚀 You can now run: ./start_with_ngrok.sh"
            else
                echo "❌ Failed to configure ngrok. Please check your token."
            fi
        fi
    fi
fi

echo ""
echo "📖 Alternative access methods:"
echo "   • Local: http://localhost:8000"
echo "   • Network: http://$(hostname -I | awk '{print $1}'):8000"
echo ""