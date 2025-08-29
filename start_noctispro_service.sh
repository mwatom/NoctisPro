#!/bin/bash

# NoctisPro Service Startup Script
# Designed to work in any environment

set -e

WORKSPACE_DIR="/workspace"
LOG_FILE="$WORKSPACE_DIR/logs/noctispro_service.log"
PID_FILE="$WORKSPACE_DIR/noctispro_service.pid"

# Create logs directory
mkdir -p "$WORKSPACE_DIR/logs"

# Redirect output to log file with timestamps
exec > >(while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee -a "$LOG_FILE") 2>&1

echo "🚀 Starting NoctisPro Service"
echo "=============================="
echo "Workspace: $WORKSPACE_DIR"
echo "Started at: $(date)"

# Store main process PID
echo $$ > "$PID_FILE"

# Change to workspace directory
cd "$WORKSPACE_DIR"

# Activate virtual environment
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    echo "✅ Virtual environment activated"
else
    echo "❌ Virtual environment not found at venv/bin/activate"
    exit 1
fi

# Load environment
if [ -f ".env.production" ]; then
    source .env.production
    echo "✅ Production environment loaded"
else
    echo "❌ .env.production not found"
    exit 1
fi

# Set Django settings
export DJANGO_SETTINGS_MODULE=noctis_pro.settings_development

# Check if ngrok auth token is configured
if [ "$NGROK_AUTHTOKEN" = "your_ngrok_authtoken_here" ]; then
    echo "⚠️  WARNING: Ngrok auth token not configured!"
    echo "⚠️  Service will start but ngrok tunnel will fail"
    echo "⚠️  Please update NGROK_AUTHTOKEN in .env.production"
else
    # Configure ngrok auth token
    ngrok config add-authtoken "$NGROK_AUTHTOKEN"
    echo "✅ Ngrok auth token configured"
fi

# Run Django setup
echo "🔧 Setting up Django..."
python manage.py migrate --noinput
python manage.py collectstatic --noinput --clear || echo "Static files collection failed, continuing..."
python manage.py check

# Start Django server in background
echo "🌐 Starting Django server on port $DAPHNE_PORT..."
python manage.py runserver "$DAPHNE_BIND:$DAPHNE_PORT" &
DJANGO_PID=$!
echo $DJANGO_PID > django_service.pid

# Wait a moment for Django to start
sleep 5

# Check if Django is running
if ! kill -0 $DJANGO_PID 2>/dev/null; then
    echo "❌ Django server failed to start"
    exit 1
fi

echo "✅ Django server started (PID: $DJANGO_PID)"

# Start ngrok tunnel if auth token is configured
if [ "$NGROK_AUTHTOKEN" != "your_ngrok_authtoken_here" ]; then
    echo "🌐 Starting ngrok tunnel..."
    
    # Use static domain if configured, otherwise use dynamic
    if [ -n "$NGROK_STATIC_DOMAIN" ] && [ "$NGROK_STATIC_DOMAIN" != "your-static-domain.ngrok-free.app" ]; then
        ngrok http --domain="$NGROK_STATIC_DOMAIN" $DAPHNE_PORT &
        NGROK_PID=$!
        echo "✅ Ngrok tunnel started with static domain: https://$NGROK_STATIC_DOMAIN (PID: $NGROK_PID)"
    else
        ngrok http $DAPHNE_PORT &
        NGROK_PID=$!
        echo "✅ Ngrok tunnel started with dynamic domain (PID: $NGROK_PID)"
    fi
    
    echo $NGROK_PID > ngrok_service.pid
else
    echo "⚠️  Ngrok tunnel not started - auth token not configured"
    echo "⚠️  Django server is running on http://localhost:$DAPHNE_PORT"
fi

# Function to cleanup on exit
cleanup() {
    echo "🧹 Cleaning up services..."
    
    if [ -f "django_service.pid" ]; then
        DJANGO_PID=$(cat django_service.pid)
        if kill -0 "$DJANGO_PID" 2>/dev/null; then
            echo "Stopping Django server (PID: $DJANGO_PID)"
            kill -TERM "$DJANGO_PID" 2>/dev/null || true
        fi
        rm -f django_service.pid
    fi
    
    if [ -f "ngrok_service.pid" ]; then
        NGROK_PID=$(cat ngrok_service.pid)
        if kill -0 "$NGROK_PID" 2>/dev/null; then
            echo "Stopping ngrok tunnel (PID: $NGROK_PID)"
            kill -TERM "$NGROK_PID" 2>/dev/null || true
        fi
        rm -f ngrok_service.pid
    fi
    
    # Kill any remaining processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok" 2>/dev/null || true
    
    rm -f "$PID_FILE"
    echo "✅ Cleanup completed"
}

# Set up signal handlers
trap cleanup EXIT INT TERM

echo "🎉 NoctisPro service is running!"
echo "📊 Monitor logs: tail -f $LOG_FILE"
echo "🔗 Local access: http://localhost:$DAPHNE_PORT"

if [ "$NGROK_AUTHTOKEN" != "your_ngrok_authtoken_here" ] && [ -n "$NGROK_STATIC_DOMAIN" ] && [ "$NGROK_STATIC_DOMAIN" != "your-static-domain.ngrok-free.app" ]; then
    echo "🌐 Public access: https://$NGROK_STATIC_DOMAIN"
else
    echo "🌐 Get ngrok URL: curl http://localhost:4040/api/tunnels"
fi

echo ""
echo "Press Ctrl+C to stop the service"

# Keep the script running
while true; do
    sleep 30
    
    # Check if Django is still running
    if [ -f "django_service.pid" ]; then
        DJANGO_PID=$(cat django_service.pid)
        if ! kill -0 "$DJANGO_PID" 2>/dev/null; then
            echo "❌ Django server died, restarting..."
            python manage.py runserver "$DAPHNE_BIND:$DAPHNE_PORT" &
            echo $! > django_service.pid
        fi
    fi
    
    # Check if ngrok is still running (if it was started)
    if [ -f "ngrok_service.pid" ]; then
        NGROK_PID=$(cat ngrok_service.pid)
        if ! kill -0 "$NGROK_PID" 2>/dev/null; then
            echo "❌ Ngrok tunnel died, restarting..."
            if [ -n "$NGROK_STATIC_DOMAIN" ] && [ "$NGROK_STATIC_DOMAIN" != "your-static-domain.ngrok-free.app" ]; then
                ngrok http --domain="$NGROK_STATIC_DOMAIN" $DAPHNE_PORT &
            else
                ngrok http $DAPHNE_PORT &
            fi
            echo $! > ngrok_service.pid
        fi
    fi
done
