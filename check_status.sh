#!/bin/bash
echo "📊 NoctisPro Production Status"
echo "============================"
echo ""

echo "🎯 Service Status:"
sudo systemctl status noctispro-production.service --no-pager -l

echo ""
echo "🌐 Ngrok Tunnel:"
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "Not available")
echo "   Current URL: $NGROK_URL"

echo ""
echo "📱 Quick Access:"
echo "   Application: https://colt-charmed-lark.ngrok-free.app"
echo "   Admin Panel: https://colt-charmed-lark.ngrok-free.app/admin/"

echo ""
echo "🔧 Management:"
echo "   Start:   ./start_production.sh"
echo "   Stop:    ./stop_production.sh"
echo "   Restart: sudo systemctl restart noctispro-production.service"
echo "   Logs:    sudo journalctl -u noctispro-production.service -f"
