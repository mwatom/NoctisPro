#!/bin/bash

# 🚀 Deploy NoctisPro as Production Service with Static Ngrok URL
echo "🚀 Deploying NoctisPro as systemd service..."

# Check if running as root/sudo
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root or with sudo"
   echo "   Run: sudo bash deploy_as_service.sh"
   exit 1
fi

echo "📋 Setting up NoctisPro production service deployment..."

# Ensure ngrok authtoken is configured
if [ ! -f /home/ubuntu/.config/ngrok/ngrok.yml ]; then
    echo ""
    echo "⚠️  IMPORTANT: Ngrok authtoken not configured!"
    echo "   1. Get your authtoken: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "   2. Run as ubuntu user: ./ngrok config add-authtoken YOUR_TOKEN"
    echo "   3. Then run this script again"
    echo ""
    exit 1
fi

# Stop any running instances
echo "🛑 Stopping any existing services..."
systemctl stop noctispro-django 2>/dev/null || true
systemctl stop noctispro-ngrok 2>/dev/null || true
pkill -f "runserver" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true

# Copy service files
echo "📁 Installing service files..."
cp /workspace/noctispro-django.service /etc/systemd/system/
cp /workspace/noctispro-ngrok.service /etc/systemd/system/

# Set proper permissions
chown root:root /etc/systemd/system/noctispro-*.service
chmod 644 /etc/systemd/system/noctispro-*.service

# Reload systemd
echo "🔄 Reloading systemd..."
systemctl daemon-reload

# Enable services to start on boot
echo "🚀 Enabling services..."
systemctl enable noctispro-django
systemctl enable noctispro-ngrok

# Start services
echo "▶️  Starting Django service..."
systemctl start noctispro-django
sleep 5

echo "▶️  Starting Ngrok service..."
systemctl start noctispro-ngrok
sleep 10

# Check status
echo ""
echo "📊 Service Status:"
echo "=================="
systemctl status noctispro-django --no-pager -l
echo ""
systemctl status noctispro-ngrok --no-pager -l

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "======================="
echo "🌐 Your app is live at: https://colt-charmed-lark.ngrok-free.app"
echo "🔧 Admin panel: https://colt-charmed-lark.ngrok-free.app/admin/"
echo "👤 Login: admin / admin123"
echo ""
echo "📊 Monitor services:"
echo "   sudo systemctl status noctispro-django"
echo "   sudo systemctl status noctispro-ngrok"
echo ""
echo "🔄 Restart services:"
echo "   sudo systemctl restart noctispro-django"
echo "   sudo systemctl restart noctispro-ngrok"
echo ""
echo "📋 View logs:"
echo "   sudo journalctl -u noctispro-django -f"
echo "   sudo journalctl -u noctispro-ngrok -f"
echo ""
echo "🛑 Stop services:"
echo "   sudo systemctl stop noctispro-django noctispro-ngrok"