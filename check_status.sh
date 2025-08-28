#!/bin/bash

echo "🔍 NoctisPro Status Check"
echo "========================"
echo ""

# Check processes
echo "📊 Process Status:"
if pgrep -f "manage.py runserver" > /dev/null; then
    echo "✅ Django: Running"
else
    echo "❌ Django: Not Running"
fi

if pgrep -f "ngrok" > /dev/null; then
    echo "✅ Ngrok: Running"
else
    echo "❌ Ngrok: Not Running"
fi

echo ""
echo "🌐 Access URLs:"
echo "   Local: http://localhost:80"

if [ -f "/workspace/current_ngrok_url.txt" ]; then
    URL=$(cat "/workspace/current_ngrok_url.txt" 2>/dev/null)
    if [ ! -z "$URL" ] && [ "$URL" != "LOCAL_ONLY" ]; then
        echo "   Remote: $URL"
    else
        echo "   Remote: Not available"
    fi
else
    echo "   Remote: Not available"
fi

echo ""
echo "📝 Logs:"
echo "   Container logs: tail -f /workspace/container_startup.log"
echo "   Django logs:    tail -f /workspace/django.log"
echo "   Ngrok logs:     tail -f /workspace/ngrok.log"
