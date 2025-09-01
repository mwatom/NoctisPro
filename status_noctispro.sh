#!/bin/bash
echo "📊 NoctisPro Status Check"
echo "========================"

cd /workspace

# Check Django
if [ -f django.pid ] && kill -0 $(cat django.pid) 2>/dev/null; then
    echo "🖥️ Django: ✅ Running (PID: $(cat django.pid))"
    
    # Test Django response
    if curl -s http://localhost:8000/ > /dev/null; then
        echo "   └─ HTTP: ✅ Responding"
    else
        echo "   └─ HTTP: ❌ Not responding"
    fi
else
    echo "🖥️ Django: ❌ Not running"
fi

# Check Ngrok
if [ -f ngrok.pid ] && kill -0 $(cat ngrok.pid) 2>/dev/null; then
    echo "🌐 Ngrok: ✅ Running (PID: $(cat ngrok.pid))"
    
    # Test ngrok tunnel
    if curl -s https://colt-charmed-lark.ngrok-free.app > /dev/null; then
        echo "   └─ Tunnel: ✅ Active"
    else
        echo "   └─ Tunnel: ❌ Not accessible"
    fi
else
    echo "🌐 Ngrok: ❌ Not running"
fi

echo ""
echo "🔗 URLs:"
echo "   Local: http://localhost:8000"
echo "   Online: https://colt-charmed-lark.ngrok-free.app"
echo "   Admin: https://colt-charmed-lark.ngrok-free.app/admin/"
