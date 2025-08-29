#!/bin/bash

echo "📊 NoctisPro Service Status"
echo "=========================="

WORKSPACE_DIR="/workspace"
cd "$WORKSPACE_DIR"

# Check main service
if [ -f "noctispro_service.pid" ]; then
    MAIN_PID=$(cat noctispro_service.pid)
    if kill -0 "$MAIN_PID" 2>/dev/null; then
        echo "✅ Main service: Running (PID: $MAIN_PID)"
    else
        echo "❌ Main service: Not running (stale PID file)"
        rm -f noctispro_service.pid
    fi
else
    echo "❌ Main service: Not running"
fi

# Check Django
if [ -f "django_service.pid" ]; then
    DJANGO_PID=$(cat django_service.pid)
    if kill -0 "$DJANGO_PID" 2>/dev/null; then
        echo "✅ Django server: Running (PID: $DJANGO_PID)"
        echo "🌐 Local URL: http://localhost:8000"
    else
        echo "❌ Django server: Not running"
    fi
else
    echo "❌ Django server: Not running"
fi

# Check ngrok
if [ -f "ngrok_service.pid" ]; then
    NGROK_PID=$(cat ngrok_service.pid)
    if kill -0 "$NGROK_PID" 2>/dev/null; then
        echo "✅ Ngrok tunnel: Running (PID: $NGROK_PID)"
        
        # Try to get ngrok URL
        if command -v curl >/dev/null 2>&1; then
            NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*' | grep https | cut -d'"' -f4 | head -1)
            if [ -n "$NGROK_URL" ]; then
                echo "🌐 Public URL: $NGROK_URL"
            fi
        fi
    else
        echo "❌ Ngrok tunnel: Not running"
    fi
else
    echo "❌ Ngrok tunnel: Not running"
fi

echo ""
echo "Recent logs:"
if [ -f "logs/noctispro_service.log" ]; then
    tail -n 5 logs/noctispro_service.log
else
    echo "No logs found"
fi
