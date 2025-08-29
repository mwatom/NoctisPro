#!/bin/bash

echo "🛑 Stopping NoctisPro Service"
echo "============================="

WORKSPACE_DIR="/workspace"
cd "$WORKSPACE_DIR"

# Stop main service if running
if [ -f "noctispro_service.pid" ]; then
    MAIN_PID=$(cat noctispro_service.pid)
    if kill -0 "$MAIN_PID" 2>/dev/null; then
        echo "Stopping main service (PID: $MAIN_PID)"
        kill -TERM "$MAIN_PID" 2>/dev/null || true
        sleep 3
        kill -KILL "$MAIN_PID" 2>/dev/null || true
    fi
    rm -f noctispro_service.pid
fi

# Stop Django if running
if [ -f "django_service.pid" ]; then
    DJANGO_PID=$(cat django_service.pid)
    if kill -0 "$DJANGO_PID" 2>/dev/null; then
        echo "Stopping Django server (PID: $DJANGO_PID)"
        kill -TERM "$DJANGO_PID" 2>/dev/null || true
        sleep 2
        kill -KILL "$DJANGO_PID" 2>/dev/null || true
    fi
    rm -f django_service.pid
fi

# Stop ngrok if running
if [ -f "ngrok_service.pid" ]; then
    NGROK_PID=$(cat ngrok_service.pid)
    if kill -0 "$NGROK_PID" 2>/dev/null; then
        echo "Stopping ngrok tunnel (PID: $NGROK_PID)"
        kill -TERM "$NGROK_PID" 2>/dev/null || true
        sleep 2
        kill -KILL "$NGROK_PID" 2>/dev/null || true
    fi
    rm -f ngrok_service.pid
fi

# Kill any remaining processes
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true

echo "✅ NoctisPro service stopped"
