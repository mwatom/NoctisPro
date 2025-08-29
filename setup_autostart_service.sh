#!/bin/bash

# NoctisPro Autostart Service Setup
# Creates a robust startup solution for environments without systemd

set -e

echo "🚀 Setting up NoctisPro Autostart Service"
echo "========================================="

WORKSPACE_DIR="/workspace"
cd "$WORKSPACE_DIR"

# Check if ngrok auth token is configured
if grep -q "your_ngrok_authtoken_here" .env.production 2>/dev/null; then
    echo "⚠️  NGROK_AUTHTOKEN needs to be configured in .env.production"
    echo ""
    echo "Please:"
    echo "1. Get your ngrok auth token from https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "2. Replace 'your_ngrok_authtoken_here' in .env.production with your actual token"
    echo ""
    echo "For now, I'll create a placeholder configuration..."
fi

# Update .env.production with proper settings
cat > .env.production << 'EOF'
# NoctisPro Production Environment Configuration
# Updated for autostart service

# Database Configuration (Use SQLite for now since PostgreSQL requires setup)
USE_SQLITE=true
DATABASE_URL=sqlite:///workspace/db.sqlite3

# Django Settings
DJANGO_DEBUG=false
DJANGO_SETTINGS_MODULE=noctis_pro.settings_development
SECRET_KEY=a7f9d8e2b4c6a1f3e8d7c5b9a2e4f6c8d1b3e5f7a9c2d4e6f8b1c3e5d7a9b2c4

# Allowed Hosts (including static ngrok domain)
ALLOWED_HOSTS=*,localhost,127.0.0.1,colt-charmed-lark.ngrok-free.app,*.ngrok.io,*.ngrok-free.app

# Server Configuration
DAPHNE_PORT=8000
DAPHNE_BIND=0.0.0.0
WORKERS=3

# Ngrok Configuration
NGROK_AUTHTOKEN=your_ngrok_authtoken_here
NGROK_STATIC_DOMAIN=colt-charmed-lark.ngrok-free.app

# Development/Production Settings
DJANGO_ENV=production
USE_DUMMY_CACHE=true
DISABLE_REDIS=true

# Security Settings (relaxed for development)
SECURE_SSL_REDIRECT=false
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https
SECURE_BROWSER_XSS_FILTER=true
SECURE_CONTENT_TYPE_NOSNIFF=true
X_FRAME_OPTIONS=DENY

# Performance Settings
COLLECTSTATIC_CLEAR=true
SERVE_MEDIA_FILES=true
HEALTH_CHECK_ENABLED=true
EOF

echo "✅ Updated .env.production"

# Create a robust startup script
cat > start_noctispro_service.sh << 'EOF'
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
EOF

chmod +x start_noctispro_service.sh
echo "✅ Created start_noctispro_service.sh"

# Create stop script
cat > stop_noctispro_service.sh << 'EOF'
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
EOF

chmod +x stop_noctispro_service.sh
echo "✅ Created stop_noctispro_service.sh"

# Create status check script
cat > check_noctispro_service.sh << 'EOF'
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
EOF

chmod +x check_noctispro_service.sh
echo "✅ Created check_noctispro_service.sh"

echo ""
echo "🎉 NoctisPro Autostart Service Setup Complete!"
echo "============================================="
echo ""
echo "📋 Next Steps:"
echo "1. Configure ngrok auth token in .env.production"
echo "2. Start the service: ./start_noctispro_service.sh"
echo "3. Check status: ./check_noctispro_service.sh"
echo "4. Stop service: ./stop_noctispro_service.sh"
echo ""
echo "📁 Files created:"
echo "  - start_noctispro_service.sh (main startup script)"
echo "  - stop_noctispro_service.sh (stop script)"
echo "  - check_noctispro_service.sh (status check)"
echo "  - .env.production (updated configuration)"
echo ""
echo "⚠️  IMPORTANT: You must configure your ngrok auth token!"
echo "   1. Get token from: https://dashboard.ngrok.com/get-started/your-authtoken"
echo "   2. Edit .env.production and replace 'your_ngrok_authtoken_here'"
echo ""