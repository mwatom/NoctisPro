#!/bin/bash
echo "🚀 Starting NoctisPro Production..."
sudo systemctl start noctispro-production.service
echo "⏳ Waiting for services to start..."
sleep 20

echo "📊 Service Status:"
sudo systemctl status noctispro-production.service --no-pager -l

echo ""
echo "🌐 Application URLs:"
echo "✅ Main App: https://colt-charmed-lark.ngrok-free.app"
echo "🔧 Admin Panel: https://colt-charmed-lark.ngrok-free.app/admin/"
echo "📱 DICOM Viewer: https://colt-charmed-lark.ngrok-free.app/dicom-viewer/"
echo "📋 Worklist: https://colt-charmed-lark.ngrok-free.app/worklist/"
echo ""
echo "🔑 Admin Credentials:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "📝 Management Commands:"
echo "   Stop:    ./stop_production.sh"
echo "   Status:  sudo systemctl status noctispro-production.service"
echo "   Logs:    sudo journalctl -u noctispro-production.service -f"
