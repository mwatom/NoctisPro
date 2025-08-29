#!/bin/bash
echo "📊 NoctisPro Production Status"
echo "============================"
echo ""

echo "🎯 Process Status:"
if pgrep -f "manage.py runserver" > /dev/null; then
    echo "   ✅ Django server is running"
    DJANGO_PID=$(pgrep -f "manage.py runserver")
    echo "   📋 Django PID: $DJANGO_PID"
else
    echo "   ❌ Django server is not running"
fi

if pgrep -f "ngrok" > /dev/null; then
    echo "   ✅ Ngrok tunnel is running"
    NGROK_PID=$(pgrep -f "ngrok")
    echo "   📋 Ngrok PID: $NGROK_PID"
else
    echo "   ❌ Ngrok tunnel is not running"
fi

echo ""
echo "🌐 Ngrok Tunnel Info:"
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "Not available")
echo "   Current URL: $NGROK_URL"

echo ""
echo "📱 Quick Access:"
echo "   Application: https://colt-charmed-lark.ngrok-free.app"
echo "   Admin Panel: https://colt-charmed-lark.ngrok-free.app/admin/"
echo "   Local: http://localhost:8000"

echo ""
echo "🔧 Management:"
echo "   Start:   ./start_production.sh"
echo "   Stop:    ./stop_production.sh"
echo "   Status:  ./check_status.sh"
