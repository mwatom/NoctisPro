#!/bin/bash

# Quick Ngrok Setup for NoctisPro

echo "🚀 Quick Ngrok Setup for NoctisPro"
echo "=================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Step 1: Check if NoctisPro is running
echo "1️⃣ Checking NoctisPro status..."
if curl -s -f http://localhost:8000 >/dev/null 2>&1; then
    echo "✅ NoctisPro is running on port 8000"
else
    echo "❌ NoctisPro is not running!"
    echo ""
    echo "Starting NoctisPro first..."
    ./fix_deployment.sh
    
    # Wait and check again
    sleep 3
    if curl -s -f http://localhost:8000 >/dev/null 2>&1; then
        echo "✅ NoctisPro is now running"
    else
        echo "❌ Failed to start NoctisPro. Please check the logs."
        exit 1
    fi
fi

echo ""

# Step 2: Check ngrok auth
echo "2️⃣ Checking ngrok authentication..."
if ./ngrok config check > /dev/null 2>&1; then
    echo "✅ Ngrok is already configured!"
    
    # Start tunnel directly
    echo ""
    echo "3️⃣ Starting ngrok tunnel..."
    ./start_ngrok_tunnel.sh
else
    echo "❌ Ngrok needs authentication setup"
    echo ""
    echo "📋 To get online access, you need a FREE ngrok account:"
    echo ""
    echo "🔗 Step 1: Visit https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "👤 Step 2: Sign up or log in (100% free)"
    echo "📋 Step 3: Copy your auth token"
    echo "⚙️  Step 4: Run this command with your token:"
    echo ""
    echo "   ./ngrok config add-authtoken YOUR_TOKEN_HERE"
    echo ""
    echo "🚀 Step 5: Then run this to get online:"
    echo ""
    echo "   ./start_ngrok_tunnel.sh"
    echo ""
    echo "💡 Or run the interactive setup:"
    echo ""
    echo "   ./configure_ngrok_auth.sh"
    echo ""
fi

echo ""
echo "📚 Helpful Commands:"
echo "• Check status: ./check_status.sh"
echo "• Get public URL: ./get_public_url.sh"
echo "• View instructions: cat setup_ngrok_instructions.md"