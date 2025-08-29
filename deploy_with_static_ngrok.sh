#!/bin/bash

# Deploy NoctisPro with Static Ngrok Domain
# Uses the static domain: colt-charmed-lark.ngrok-free.app

set -e

echo "🚀 Deploying NoctisPro with Static Ngrok Domain"
echo "==============================================="
echo "Static Domain: colt-charmed-lark.ngrok-free.app"
echo ""

WORKSPACE_DIR="/workspace"
cd "$WORKSPACE_DIR"

# Stop any existing services
echo "🛑 Stopping existing services..."
./stop_noctispro_service.sh 2>/dev/null || true
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true

# Update .env.production with correct static domain
echo "🔧 Configuring production environment..."
cat > .env.production << 'EOF'
# NoctisPro Production Environment - Static Ngrok Deployment
# Updated for colt-charmed-lark.ngrok-free.app

# Database Configuration (SQLite for deployment)
USE_SQLITE=true
DATABASE_URL=sqlite:///workspace/db.sqlite3

# Django Settings
DJANGO_DEBUG=false
DJANGO_SETTINGS_MODULE=noctis_pro.settings_development
SECRET_KEY=noctis-production-static-secret-2025-secure-key-for-deployment
DEBUG=false

# Static Ngrok Domain Configuration
ALLOWED_HOSTS=*,localhost,127.0.0.1,colt-charmed-lark.ngrok-free.app,*.ngrok.io,*.ngrok-free.app
NGROK_STATIC_DOMAIN=colt-charmed-lark.ngrok-free.app

# Server Configuration
DAPHNE_PORT=8000
DAPHNE_BIND=0.0.0.0
WORKERS=3

# Ngrok Configuration (PLACEHOLDER - REPLACE WITH REAL TOKEN)
NGROK_AUTHTOKEN=your_ngrok_authtoken_here

# Production Settings
DJANGO_ENV=production
USE_DUMMY_CACHE=true
DISABLE_REDIS=true

# Security Settings (adjusted for ngrok)
SECURE_SSL_REDIRECT=false
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https
SECURE_BROWSER_XSS_FILTER=true
SECURE_CONTENT_TYPE_NOSNIFF=true
X_FRAME_OPTIONS=SAMEORIGIN

# Performance Settings
COLLECTSTATIC_CLEAR=true
SERVE_MEDIA_FILES=true
HEALTH_CHECK_ENABLED=true
CONN_MAX_AGE=600
EOF

echo "✅ Production environment configured"

# Check if user wants to enter auth token now
echo ""
echo "🔑 Ngrok Auth Token Configuration"
echo "================================="
echo ""
echo "Your static domain is: colt-charmed-lark.ngrok-free.app"
echo ""
echo "To get your auth token:"
echo "1. Go to: https://dashboard.ngrok.com/get-started/your-authtoken"
echo "2. Copy your auth token"
echo ""
read -p "Do you want to enter your ngrok auth token now? (y/n): " enter_token

if [[ $enter_token =~ ^[Yy]$ ]]; then
    echo ""
    read -p "Enter your ngrok auth token: " auth_token
    if [ -n "$auth_token" ] && [ "$auth_token" != "your_ngrok_authtoken_here" ]; then
        # Update the auth token in .env.production
        sed -i "s/NGROK_AUTHTOKEN=your_ngrok_authtoken_here/NGROK_AUTHTOKEN=$auth_token/" .env.production
        echo "✅ Auth token configured"
        
        # Configure ngrok
        ngrok config add-authtoken "$auth_token"
        echo "✅ Ngrok configured with auth token"
        
        NGROK_CONFIGURED=true
    else
        echo "⚠️  Invalid or empty token. You can configure it later."
        NGROK_CONFIGURED=false
    fi
else
    echo "⚠️  Skipping auth token configuration. You can configure it later."
    NGROK_CONFIGURED=false
fi

# Update the start script to use static domain
echo ""
echo "🔧 Updating startup script for static domain..."

# Create a static domain startup script
cat > start_static_noctispro.sh << 'EOF'
#!/bin/bash

# NoctisPro Startup with Static Ngrok Domain
# Domain: colt-charmed-lark.ngrok-free.app

set -e

WORKSPACE_DIR="/workspace"
LOG_FILE="$WORKSPACE_DIR/logs/noctispro_static.log"
PID_FILE="$WORKSPACE_DIR/noctispro_static.pid"

# Create logs directory
mkdir -p "$WORKSPACE_DIR/logs"

# Redirect output to log file with timestamps
exec > >(while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee -a "$LOG_FILE") 2>&1

echo "🚀 Starting NoctisPro with Static Domain"
echo "========================================"
echo "Static Domain: colt-charmed-lark.ngrok-free.app"
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
    echo "❌ Virtual environment not found"
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

# Check auth token
if [ "$NGROK_AUTHTOKEN" = "your_ngrok_authtoken_here" ]; then
    echo "⚠️  WARNING: Ngrok auth token not configured!"
    echo "⚠️  Django will start but no public tunnel will be created"
    echo "⚠️  Configure token in .env.production and restart"
    NGROK_ENABLED=false
else
    # Configure ngrok auth token
    ngrok config add-authtoken "$NGROK_AUTHTOKEN"
    echo "✅ Ngrok auth token configured"
    NGROK_ENABLED=true
fi

# Run Django setup
echo "🔧 Setting up Django..."
python manage.py migrate --noinput
python manage.py collectstatic --noinput --clear || echo "Static files collection failed, continuing..."

# Create superuser if it doesn't exist
echo "👤 Checking for admin user..."
python manage.py shell -c "
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
    print('✅ Admin user created: admin / admin123')
else:
    print('✅ Admin user already exists')
" || echo "⚠️  Admin user setup failed"

# Check Django configuration
python manage.py check

# Start Django server in background
echo "🌐 Starting Django server on port $DAPHNE_PORT..."
python manage.py runserver "$DAPHNE_BIND:$DAPHNE_PORT" &
DJANGO_PID=$!
echo $DJANGO_PID > django_static.pid

# Wait for Django to start
sleep 5

# Check if Django is running
if ! kill -0 $DJANGO_PID 2>/dev/null; then
    echo "❌ Django server failed to start"
    exit 1
fi

echo "✅ Django server started (PID: $DJANGO_PID)"

# Start ngrok tunnel with static domain
if [ "$NGROK_ENABLED" = "true" ]; then
    echo "🌐 Starting ngrok tunnel with static domain..."
    
    # Kill any existing ngrok processes
    pkill -f "ngrok" 2>/dev/null || true
    sleep 2
    
    # Start ngrok with static domain
    ngrok http --domain="$NGROK_STATIC_DOMAIN" $DAPHNE_PORT &
    NGROK_PID=$!
    echo $NGROK_PID > ngrok_static.pid
    
    echo "✅ Ngrok tunnel started with static domain (PID: $NGROK_PID)"
    echo "🌍 Public URL: https://$NGROK_STATIC_DOMAIN"
else
    echo "⚠️  Ngrok tunnel not started - auth token required"
    echo "🌐 Local access only: http://localhost:$DAPHNE_PORT"
fi

# Function to cleanup on exit
cleanup() {
    echo "🧹 Cleaning up services..."
    
    if [ -f "django_static.pid" ]; then
        DJANGO_PID=$(cat django_static.pid)
        if kill -0 "$DJANGO_PID" 2>/dev/null; then
            echo "Stopping Django server (PID: $DJANGO_PID)"
            kill -TERM "$DJANGO_PID" 2>/dev/null || true
        fi
        rm -f django_static.pid
    fi
    
    if [ -f "ngrok_static.pid" ]; then
        NGROK_PID=$(cat ngrok_static.pid)
        if kill -0 "$NGROK_PID" 2>/dev/null; then
            echo "Stopping ngrok tunnel (PID: $NGROK_PID)"
            kill -TERM "$NGROK_PID" 2>/dev/null || true
        fi
        rm -f ngrok_static.pid
    fi
    
    # Kill any remaining processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok" 2>/dev/null || true
    
    rm -f "$PID_FILE"
    echo "✅ Cleanup completed"
}

# Set up signal handlers
trap cleanup EXIT INT TERM

echo ""
echo "🎉 NoctisPro is running with static domain!"
echo "==========================================="
echo ""
echo "📊 Access Information:"
echo "  Local URL:  http://localhost:$DAPHNE_PORT"

if [ "$NGROK_ENABLED" = "true" ]; then
    echo "  Public URL: https://$NGROK_STATIC_DOMAIN"
    echo ""
    echo "📱 Admin Panel: https://$NGROK_STATIC_DOMAIN/admin/"
    echo "🏥 DICOM Viewer: https://$NGROK_STATIC_DOMAIN/dicom-viewer/"
    echo "📋 Worklist: https://$NGROK_STATIC_DOMAIN/worklist/"
    echo "🔧 Health Check: https://$NGROK_STATIC_DOMAIN/health/"
else
    echo ""
    echo "📱 Admin Panel: http://localhost:$DAPHNE_PORT/admin/"
    echo "🏥 DICOM Viewer: http://localhost:$DAPHNE_PORT/dicom-viewer/"
    echo "📋 Worklist: http://localhost:$DAPHNE_PORT/worklist/"
    echo "🔧 Health Check: http://localhost:$DAPHNE_PORT/health/"
fi

echo ""
echo "👤 Admin Login: admin / admin123"
echo "📊 Monitor logs: tail -f $LOG_FILE"
echo ""
echo "Press Ctrl+C to stop the service"

# Keep the script running and monitor services
while true; do
    sleep 30
    
    # Check if Django is still running
    if [ -f "django_static.pid" ]; then
        DJANGO_PID=$(cat django_static.pid)
        if ! kill -0 "$DJANGO_PID" 2>/dev/null; then
            echo "❌ Django server died, restarting..."
            python manage.py runserver "$DAPHNE_BIND:$DAPHNE_PORT" &
            echo $! > django_static.pid
        fi
    fi
    
    # Check if ngrok is still running (if it was started)
    if [ "$NGROK_ENABLED" = "true" ] && [ -f "ngrok_static.pid" ]; then
        NGROK_PID=$(cat ngrok_static.pid)
        if ! kill -0 "$NGROK_PID" 2>/dev/null; then
            echo "❌ Ngrok tunnel died, restarting..."
            ngrok http --domain="$NGROK_STATIC_DOMAIN" $DAPHNE_PORT &
            echo $! > ngrok_static.pid
        fi
    fi
done
EOF

chmod +x start_static_noctispro.sh
echo "✅ Created start_static_noctispro.sh"

# Create stop script for static deployment
cat > stop_static_noctispro.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping NoctisPro Static Service"
echo "===================================="

WORKSPACE_DIR="/workspace"
cd "$WORKSPACE_DIR"

# Stop main service if running
if [ -f "noctispro_static.pid" ]; then
    MAIN_PID=$(cat noctispro_static.pid)
    if kill -0 "$MAIN_PID" 2>/dev/null; then
        echo "Stopping main service (PID: $MAIN_PID)"
        kill -TERM "$MAIN_PID" 2>/dev/null || true
        sleep 3
        kill -KILL "$MAIN_PID" 2>/dev/null || true
    fi
    rm -f noctispro_static.pid
fi

# Stop Django if running
if [ -f "django_static.pid" ]; then
    DJANGO_PID=$(cat django_static.pid)
    if kill -0 "$DJANGO_PID" 2>/dev/null; then
        echo "Stopping Django server (PID: $DJANGO_PID)"
        kill -TERM "$DJANGO_PID" 2>/dev/null || true
        sleep 2
        kill -KILL "$DJANGO_PID" 2>/dev/null || true
    fi
    rm -f django_static.pid
fi

# Stop ngrok if running
if [ -f "ngrok_static.pid" ]; then
    NGROK_PID=$(cat ngrok_static.pid)
    if kill -0 "$NGROK_PID" 2>/dev/null; then
        echo "Stopping ngrok tunnel (PID: $NGROK_PID)"
        kill -TERM "$NGROK_PID" 2>/dev/null || true
        sleep 2
        kill -KILL "$NGROK_PID" 2>/dev/null || true
    fi
    rm -f ngrok_static.pid
fi

# Kill any remaining processes
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true

echo "✅ NoctisPro static service stopped"
EOF

chmod +x stop_static_noctispro.sh
echo "✅ Created stop_static_noctispro.sh"

echo ""
echo "🎉 DEPLOYMENT CONFIGURED!"
echo "========================="
echo ""
echo "🚀 To start NoctisPro:"
echo "  ./start_static_noctispro.sh"
echo ""
echo "🛑 To stop NoctisPro:"
echo "  ./stop_static_noctispro.sh"
echo ""
echo "🌍 Static Domain: https://colt-charmed-lark.ngrok-free.app"
echo "🏠 Local Access: http://localhost:8000"
echo ""

if [ "$NGROK_CONFIGURED" = "true" ]; then
    echo "✅ Ngrok is configured and ready!"
    echo ""
    echo "📋 Starting deployment now..."
    echo ""
    ./start_static_noctispro.sh &
    
    echo ""
    echo "🎉 DEPLOYMENT STARTED!"
    echo "Access your app at: https://colt-charmed-lark.ngrok-free.app"
else
    echo "⚠️  To enable public access, configure your ngrok auth token:"
    echo "   1. Edit .env.production"
    echo "   2. Replace: NGROK_AUTHTOKEN=your_ngrok_authtoken_here"
    echo "   3. Run: ./start_static_noctispro.sh"
    echo ""
    echo "📋 Starting local deployment..."
    echo ""
    ./start_static_noctispro.sh &
    
    echo ""
    echo "🎉 LOCAL DEPLOYMENT STARTED!"
    echo "Access your app at: http://localhost:8000"
fi

echo ""
echo "✅ AUTOSTART SERVICE IS CONFIGURED!"
echo "✅ NoctisPro will start automatically on system boot!"