#!/bin/bash

# 🚀 One-liner deployment with autostart setup
# Deploys NoctisPro and ensures it runs on boot

set -e

echo "🚀 Complete NoctisPro Deployment + Autostart Setup..."

# 1. Run quick deploy
echo "📦 Running quick deployment..."
sudo ./quick_deploy_fixed.sh

# 2. Start the system
echo "🚀 Starting NoctisPro with static URL..."
./start_noctispro_static.sh &

# 3. Wait a bit for services to start
sleep 10

# 4. Set up autostart
echo "⚙️ Setting up autostart service..."
sudo cp noctispro-complete.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable noctispro-complete.service
sudo systemctl start noctispro-complete.service

# 5. Show status
echo "✅ Deployment complete! Services status:"
sudo systemctl status noctispro-complete.service --no-pager
echo ""
echo "🌐 Your NoctisPro is running at: https://colt-charmed-lark.ngrok-free.app"
echo "🔄 System will auto-start on reboot"
echo ""
echo "💡 To check status: sudo systemctl status noctispro-complete"
echo "💡 To restart: sudo systemctl restart noctispro-complete"