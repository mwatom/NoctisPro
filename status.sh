#!/bin/bash
echo "🏥 NOCTIS PRO PACS v2.0 - STATUS CHECK"
echo "====================================="
echo ""

# Check services
nginx_status=$(pgrep -f nginx > /dev/null && echo "✅ RUNNING" || echo "❌ STOPPED")
gunicorn_status=$(pgrep -f "gunicorn.*noctis_pro" > /dev/null && echo "✅ RUNNING" || echo "❌ STOPPED")
ngrok_status=$(pgrep -f ngrok > /dev/null && echo "✅ RUNNING" || echo "❌ STOPPED")

echo "🌐 SERVICES:"
echo "   Nginx (port 80): $nginx_status"
echo "   Gunicorn (port 8000): $gunicorn_status"
echo "   Ngrok (public): $ngrok_status"
echo ""

echo "🔗 ACCESS URLS:"
echo "   Local: http://noctispro"
echo "   Public: https://mallard-shining-curiously.ngrok-free.app"
echo ""

echo "🔐 LOGIN:"
echo "   Username: admin"
echo "   Password: admin123"
