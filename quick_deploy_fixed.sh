#!/bin/bash

# 🚀 NoctisPro Quick Deploy - FIXED VERSION
# Single command for complete production deployment with ngrok static URL
# Works in container environments without systemd

set -e  # Exit on any error

echo "🚀 NoctisPro Quick Deploy Starting (Fixed Version)..."
echo "Using static URL from previous charts: colt-charmed-lark.ngrok-free.app"

# Install ngrok and dependencies
echo "📦 Installing dependencies..."
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt-get update -qq
sudo apt-get install -y ngrok python3 python3-pip python3-venv jq

# Setup Python environment
echo "🐍 Setting up Python environment..."
cd /workspace
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip

# Install all requirements
echo "📚 Installing Python dependencies..."
pip install -r requirements.txt

# Create production environment file
echo "⚙️ Creating environment configuration..."
cat > .env.production << 'EOF'
DEBUG=False
SECRET_KEY=noctis-production-secret-2024-change-me
DJANGO_SETTINGS_MODULE=noctis_pro.settings
ALLOWED_HOSTS=*,colt-charmed-lark.ngrok-free.app,localhost,127.0.0.1
USE_SQLITE=True
STATIC_ROOT=/workspace/staticfiles
MEDIA_ROOT=/workspace/media
SERVE_MEDIA_FILES=True
BUILD_TARGET=production
ENVIRONMENT=production
HEALTH_CHECK_ENABLED=True
TIME_ZONE=UTC
USE_TZ=True
DICOM_STORAGE_PATH=/workspace/media/dicom
DISABLE_REDIS=True
USE_DUMMY_CACHE=True
EOF

# Create ngrok environment file with static URL
cat > .env.ngrok << 'EOF'
NGROK_USE_STATIC=true
NGROK_STATIC_URL=colt-charmed-lark.ngrok-free.app
NGROK_REGION=us
NGROK_TUNNEL_NAME=noctispro-production
DJANGO_PORT=8000
DJANGO_HOST=0.0.0.0
ALLOWED_HOSTS=*,colt-charmed-lark.ngrok-free.app,localhost,127.0.0.1
DEBUG=False
SECURE_SSL_REDIRECT=False
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https
SERVE_MEDIA_FILES=True
HEALTH_CHECK_ENABLED=True
EOF

# Set environment for Django commands
export USE_SQLITE=true
export DEBUG=False
export ALLOWED_HOSTS=*
export DISABLE_REDIS=true
export USE_DUMMY_CACHE=true

# Create necessary directories
mkdir -p media/dicom staticfiles

# Setup Django
echo "🗄️ Setting up Django..."
python manage.py collectstatic --noinput
python manage.py migrate --noinput

# Create admin user
echo "👤 Creating admin user..."
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@noctispro.local', 'admin123')" | python manage.py shell

# Create the simple start script (no systemd)
echo "📝 Creating start script..."
cat > start_production.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting NoctisPro Production..."

cd /workspace
source venv/bin/activate

# Load environment variables
source .env.production
source .env.ngrok

# Create necessary directories
mkdir -p media/dicom staticfiles

# Start Django server in background
echo "🌐 Starting Django server on port 8000..."
python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!
echo "Django PID: $DJANGO_PID"

# Wait a bit for Django to start
sleep 10

# Start ngrok tunnel
echo "🚇 Starting ngrok tunnel..."
if [ "$NGROK_USE_STATIC" = "true" ] && [ ! -z "$NGROK_STATIC_URL" ]; then
    ngrok http 8000 --hostname=$NGROK_STATIC_URL --log=stdout &
else
    ngrok http 8000 --log=stdout &
fi
NGROK_PID=$!
echo "Ngrok PID: $NGROK_PID"

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down services..."
    kill $DJANGO_PID 2>/dev/null || true
    kill $NGROK_PID 2>/dev/null || true
    echo "✅ Services stopped"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

echo ""
echo "🎉 SERVICES STARTED!"
echo ""
echo "🌐 Application URLs:"
echo "✅ Main App: https://colt-charmed-lark.ngrok-free.app"
echo "🔧 Admin Panel: https://colt-charmed-lark.ngrok-free.app/admin/"
echo "📱 DICOM Viewer: https://colt-charmed-lark.ngrok-free.app/dicom-viewer/"
echo "📋 Worklist: https://colt-charmed-lark.ngrok-free.app/worklist/"
echo "🏠 Local Access: http://localhost:8000"
echo ""
echo "🔑 Admin Credentials:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "📝 Press Ctrl+C to stop all services"
echo ""

# Wait for background processes
wait
EOF

chmod +x start_production.sh

# Create stop script
cat > stop_production.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping NoctisPro Production..."
pkill -f "manage.py runserver" || echo "Django server not running"
pkill -f "ngrok" || echo "Ngrok not running"
echo "✅ Services stopped"
EOF

chmod +x stop_production.sh

# Create status check script
cat > check_status.sh << 'EOF'
#!/bin/bash
echo "📊 NoctisPro Production Status"
echo "============================"
echo ""

echo "🎯 Process Status:"
if pgrep -f "manage.py runserver" > /dev/null; then
    echo "   ✅ Django server is running"
    DJANGO_PID=$(pgrep -f "manage.py runserver")
    echo "   📋 Django PID: $DJANGO_PID"
else
    echo "   ❌ Django server is not running"
fi

if pgrep -f "ngrok" > /dev/null; then
    echo "   ✅ Ngrok tunnel is running"
    NGROK_PID=$(pgrep -f "ngrok")
    echo "   📋 Ngrok PID: $NGROK_PID"
else
    echo "   ❌ Ngrok tunnel is not running"
fi

echo ""
echo "🌐 Ngrok Tunnel Info:"
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "Not available")
echo "   Current URL: $NGROK_URL"

echo ""
echo "📱 Quick Access:"
echo "   Application: https://colt-charmed-lark.ngrok-free.app"
echo "   Admin Panel: https://colt-charmed-lark.ngrok-free.app/admin/"
echo "   Local: http://localhost:8000"

echo ""
echo "🔧 Management:"
echo "   Start:   ./start_production.sh"
echo "   Stop:    ./stop_production.sh"
echo "   Status:  ./check_status.sh"
EOF

chmod +x check_status.sh

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo ""
echo "📋 Next Steps:"
echo "1. Configure ngrok auth token: ngrok config add-authtoken YOUR_TOKEN"
echo "   Get your free token from: https://dashboard.ngrok.com/get-started/your-authtoken"
echo "2. Start application: ./start_production.sh"
echo "3. Access at: https://colt-charmed-lark.ngrok-free.app"
echo ""
echo "🔑 Default Admin Login:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "📱 Available Commands:"
echo "   ./start_production.sh  - Start all services"
echo "   ./stop_production.sh   - Stop all services"
echo "   ./check_status.sh      - Check system status"
echo ""
echo "🚀 Quick start (without ngrok auth token setup):"
echo "   ./start_noctispro_simple.sh"
echo ""