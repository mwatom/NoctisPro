#!/bin/bash

# Quick Ngrok Fix Script
# This script will help you fix the ERR_NGROK_3200 error

echo "🔧 Ngrok ERR_NGROK_3200 Fix Script"
echo "=================================="
echo ""

# Check if Django is running
if ps aux | grep -q "manage.py runserver" | grep -v grep; then
    echo "✅ Django is running on port 8000"
else
    echo "❌ Django is not running. Starting Django..."
    source venv/bin/activate && python manage.py runserver 0.0.0.0:8000 &
    sleep 3
fi

echo ""
echo "🔑 STEP 1: Get your ngrok auth token"
echo "   Go to: https://dashboard.ngrok.com/get-started/your-authtoken"
echo ""
echo "🔧 STEP 2: Configure ngrok (replace YOUR_TOKEN with your actual token):"
echo "   /workspace/ngrok config add-authtoken YOUR_TOKEN"
echo ""
echo "🚀 STEP 3: Start the tunnel:"
echo "   ./start_ngrok_static.sh"
echo ""
echo "💡 Your static URL will be: https://mallard-shining-curiously.ngrok-free.app"
echo ""

# Check current ngrok status
echo "📊 Current Status:"
if /workspace/ngrok config check > /dev/null 2>&1; then
    echo "   ✅ Ngrok is authenticated"
    echo "   🚀 Ready to start tunnel!"
    echo ""
    echo "Run: ./start_ngrok_static.sh"
else
    echo "   ❌ Ngrok not authenticated"
    echo "   🔑 Please add your auth token first"
fi