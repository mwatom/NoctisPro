#!/bin/bash

echo "🌟 NoctisPro - ngrok Setup Script"
echo "=================================="
echo ""

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok is not installed. Installing now..."
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
    sudo apt update && sudo apt install ngrok
else
    echo "✅ ngrok is already installed"
fi

echo ""
echo "🔧 Setting up ngrok for NoctisPro..."
echo ""
echo "To complete the setup, you need to:"
echo ""
echo "1. 📝 Sign up for a free ngrok account:"
echo "   https://dashboard.ngrok.com/signup"
echo ""
echo "2. 🔑 Get your authtoken:"
echo "   https://dashboard.ngrok.com/get-started/your-authtoken"
echo ""
echo "3. 💾 Install your authtoken:"
echo "   ngrok config add-authtoken YOUR_TOKEN_HERE"
echo ""
echo "4. 🚀 Start the tunnel:"
echo "   ngrok http 8000"
echo ""
echo "💡 Example commands:"
echo "   # Replace YOUR_TOKEN with your actual token"
echo "   ngrok config add-authtoken 2a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t"
echo "   ngrok http 8000"
echo ""

# Check if Django is running
if curl -s http://localhost:8000/health/ | grep -q "OK"; then
    echo "✅ Django server is running on http://localhost:8000"
    echo "   Health check: http://localhost:8000/health/"
    echo "   Main page: http://localhost:8000/"
    echo "   Admin: http://localhost:8000/admin/"
else
    echo "❌ Django server is not running. Starting it now..."
    echo ""
    
    # Change to the correct directory and start Django
    cd /workspace
    source venv/bin/activate
    export DJANGO_SETTINGS_MODULE=noctis_pro.settings_simple
    
    echo "🔄 Starting Django server..."
    nohup python manage.py runserver 0.0.0.0:8000 > django.log 2>&1 &
    
    sleep 3
    
    if curl -s http://localhost:8000/health/ | grep -q "OK"; then
        echo "✅ Django server started successfully!"
    else
        echo "❌ Failed to start Django server. Check django.log for details."
    fi
fi

echo ""
echo "🎯 Quick Start:"
echo "1. Get your ngrok authtoken from: https://dashboard.ngrok.com/get-started/your-authtoken"
echo "2. Run: ngrok config add-authtoken YOUR_TOKEN"
echo "3. Run: ngrok http 8000"
echo "4. Access your app via the ngrok URL!"
echo ""
echo "📋 Local access (for testing):"
echo "   - Application: http://localhost:8000"
echo "   - Health check: http://localhost:8000/health/"
echo "   - Django admin: http://localhost:8000/admin/"
echo ""