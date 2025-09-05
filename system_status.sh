#!/bin/bash
echo "🏥 NOCTIS PRO SYSTEM STATUS"
echo "=========================="
echo ""

# Check Django
if [ -f ".django_pid" ] && ps -p $(cat .django_pid) > /dev/null; then
    echo "✅ Django Server: Running (PID: $(cat .django_pid))"
else
    echo "❌ Django Server: Not running"
fi

# Check Cloudflare Tunnel
if [ -f ".tunnel_pid" ] && ps -p $(cat .tunnel_pid) > /dev/null; then
    echo "✅ Cloudflare Tunnel: Running (PID: $(cat .tunnel_pid))"
elif [ -f ".tunnel_pid" ]; then
    echo "❌ Cloudflare Tunnel: Not running"
fi

# Show URLs
if [ -f "/workspace/.duckdns_config" ]; then
    source /workspace/.duckdns_config
    echo ""
    echo "🌐 Access URLs:"
    echo "   https://${DUCKDNS_DOMAIN}.duckdns.org"
    echo "   http://localhost:8000"
fi

echo ""
echo "👤 Admin: admin / admin123"
