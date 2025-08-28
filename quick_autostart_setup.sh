#!/bin/bash

# Quick Autostart Setup - One command to rule them all!

echo "🚀 NoctisPro Quick Autostart Setup"
echo "=================================="
echo ""
echo "This will set up your NoctisPro system to start automatically on boot,"
echo "including after power outages, with robust error recovery."
echo ""

# Check if we need sudo
if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    echo "❌ This script requires sudo access"
    echo "Please run: sudo ./quick_autostart_setup.sh"
    exit 1
fi

# Step 1: Check ngrok auth
echo "Step 1: Checking ngrok authentication..."
if ! ngrok config check > /dev/null 2>&1; then
    echo "❌ Ngrok auth token not configured!"
    echo ""
    echo "Running ngrok configuration setup..."
    ./configure_ngrok_auth.sh
    
    # Check again
    if ! ngrok config check > /dev/null 2>&1; then
        echo "❌ Ngrok configuration failed. Cannot continue."
        exit 1
    fi
fi
echo "✅ Ngrok is configured"

# Step 2: Run complete autostart setup
echo ""
echo "Step 2: Setting up complete autostart system..."
./setup_complete_autostart.sh

echo ""
echo "🎉 Quick Setup Complete!"
echo ""
echo "Your NoctisPro system is now configured for automatic startup!"
echo ""
echo "Key features enabled:"
echo "✅ Automatic startup on boot"
echo "✅ Auto-recovery after power outages"  
echo "✅ Ngrok tunnel with retry logic"
echo "✅ Service monitoring and auto-restart"
echo "✅ Comprehensive logging"
echo ""
echo "🔧 Quick Commands:"
echo "  Check status:  sudo systemctl status noctispro-complete"
echo "  View logs:     sudo journalctl -u noctispro-complete -f"
echo "  Get URL:       cat /workspace/current_ngrok_url.txt"
echo ""
echo "🌍 Your system will start automatically on every boot!"