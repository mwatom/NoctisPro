#!/bin/bash
echo "🛑 Stopping NoctisPro..."
cd /workspace

if [ -f django.pid ]; then
    DJANGO_PID=$(cat django.pid)
    echo "Stopping Django (PID: $DJANGO_PID)..."
    kill $DJANGO_PID 2>/dev/null || true
    rm -f django.pid
fi

if [ -f ngrok.pid ]; then
    NGROK_PID=$(cat ngrok.pid)
    echo "Stopping Ngrok (PID: $NGROK_PID)..."
    kill $NGROK_PID 2>/dev/null || true
    rm -f ngrok.pid
fi

# Kill any remaining processes
pkill -f "manage.py runserver" || true
pkill -f "ngrok http" || true

echo "✅ NoctisPro stopped"
