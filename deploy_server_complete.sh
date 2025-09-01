#!/bin/bash

# 🚀 Complete NoctisPro Server Deployment with Ngrok Static URL
# This script installs ALL requirements and deploys the system automatically

set -e  # Exit on any error

echo "🚀 NoctisPro Complete Server Deployment Starting..."
echo "Using static URL: colt-charmed-lark.ngrok-free.app"
echo "=" * 60

# Function for logging
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"; }
error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >&2; }
success() { echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1"; }

# Check if running as root for system packages
if [ "$EUID" -eq 0 ]; then
    log "Running as root - will install system packages"
    SUDO=""
else
    log "Running as user - will use sudo for system packages"
    SUDO="sudo"
fi

# 1. Install System Requirements
log "📦 Installing system requirements..."
$SUDO apt-get update -qq
$SUDO apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    sqlite3 \
    curl \
    wget \
    jq \
    nginx \
    supervisor \
    git

# 2. Install/Update Ngrok if needed
log "🌐 Setting up ngrok..."
if ! command -v ngrok &> /dev/null; then
    if [ ! -f "/workspace/ngrok" ]; then
        log "Downloading ngrok..."
        curl -fsSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz | tar -xz -C /workspace
    fi
    $SUDO ln -sf /workspace/ngrok /usr/local/bin/ngrok
fi

log "Ngrok version: $(ngrok version)"

# 3. Set up Python Environment
log "🐍 Setting up Python environment..."
cd /workspace

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# 4. Install Python Requirements
log "📚 Installing Python requirements..."
if [ -f "requirements.txt" ]; then
    log "Installing from requirements.txt..."
    pip install -r requirements.txt
else
    log "Installing essential packages..."
    pip install \
        django>=4.2 \
        djangorestframework \
        django-cors-headers \
        django-extensions \
        django-health-check \
        django-redis \
        django-widget-tweaks \
        daphne \
        channels \
        channels-redis \
        redis \
        cryptography \
        Pillow \
        pydicom \
        scikit-image \
        SimpleITK \
        numpy \
        scipy \
        matplotlib \
        plotly \
        celery \
        reportlab \
        requests \
        python-dotenv \
        gunicorn \
        whitenoise
fi

# 5. Create Environment Configuration
log "⚙️ Creating environment configuration..."
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
EOF

# 6. Set up Django
log "🗄️ Setting up Django application..."
export DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Run migrations
python manage.py migrate --noinput

# Collect static files
python manage.py collectstatic --noinput

# Create admin user if doesn't exist
echo "from accounts.models import User; User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@noctispro.local', 'admin123')" | python manage.py shell

# Create media directories
mkdir -p media/dicom media/uploads media/thumbnails

# 7. Create Systemd Service
log "🔧 Creating systemd service..."
$SUDO tee /etc/systemd/system/noctispro-production.service > /dev/null << EOF
[Unit]
Description=NoctisPro Production PACS System
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=$(whoami)
Group=$(whoami)
WorkingDirectory=/workspace
Environment=PATH=/workspace/venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=/workspace
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
EnvironmentFile=-/workspace/.env.production

# Start both Django and Ngrok
ExecStart=/bin/bash -c 'cd /workspace && source venv/bin/activate && source .env.production && python manage.py runserver 0.0.0.0:8000 & echo \$! > django.pid && sleep 10 && ngrok http 8000 --hostname=colt-charmed-lark.ngrok-free.app --log=stdout > ngrok.log 2>&1 & echo \$! > ngrok.pid'

# Stop both services
ExecStop=/bin/bash -c 'cd /workspace && [ -f django.pid ] && kill \$(cat django.pid) || true && [ -f ngrok.pid ] && kill \$(cat ngrok.pid) || true && rm -f django.pid ngrok.pid'

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 8. Create Management Scripts
log "📝 Creating management scripts..."

# Start script
cat > start_noctispro.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting NoctisPro Production..."
cd /workspace
source venv/bin/activate

# Start Django server
echo "🖥️ Starting Django server..."
python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!
echo $DJANGO_PID > django.pid
echo "Django PID: $DJANGO_PID"

# Wait for Django to start
sleep 8

# Test Django
if curl -s http://localhost:8000/ > /dev/null; then
    echo "✅ Django server started successfully"
else
    echo "❌ Django server failed to start"
    kill $DJANGO_PID 2>/dev/null
    exit 1
fi

# Start ngrok
echo "🌐 Starting ngrok tunnel..."
./ngrok http 8000 --hostname=colt-charmed-lark.ngrok-free.app --log=stdout > ngrok.log 2>&1 &
NGROK_PID=$!
echo $NGROK_PID > ngrok.pid
echo "Ngrok PID: $NGROK_PID"

# Wait for ngrok to connect
sleep 10

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "================================"
echo "🌐 Your app is live at: https://colt-charmed-lark.ngrok-free.app"
echo "🔧 Admin panel: https://colt-charmed-lark.ngrok-free.app/admin/"
echo "📱 Login credentials:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "📊 Monitoring:"
echo "   Django logs: tail -f noctis_pro.log"
echo "   Ngrok logs: tail -f ngrok.log"
echo ""
echo "🛑 To stop: ./stop_noctispro.sh"
EOF

# Stop script
cat > stop_noctispro.sh << 'EOF'
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
EOF

# Status script
cat > status_noctispro.sh << 'EOF'
#!/bin/bash
echo "📊 NoctisPro Status Check"
echo "========================"

cd /workspace

# Check Django
if [ -f django.pid ] && kill -0 $(cat django.pid) 2>/dev/null; then
    echo "🖥️ Django: ✅ Running (PID: $(cat django.pid))"
    
    # Test Django response
    if curl -s http://localhost:8000/ > /dev/null; then
        echo "   └─ HTTP: ✅ Responding"
    else
        echo "   └─ HTTP: ❌ Not responding"
    fi
else
    echo "🖥️ Django: ❌ Not running"
fi

# Check Ngrok
if [ -f ngrok.pid ] && kill -0 $(cat ngrok.pid) 2>/dev/null; then
    echo "🌐 Ngrok: ✅ Running (PID: $(cat ngrok.pid))"
    
    # Test ngrok tunnel
    if curl -s https://colt-charmed-lark.ngrok-free.app > /dev/null; then
        echo "   └─ Tunnel: ✅ Active"
    else
        echo "   └─ Tunnel: ❌ Not accessible"
    fi
else
    echo "🌐 Ngrok: ❌ Not running"
fi

echo ""
echo "🔗 URLs:"
echo "   Local: http://localhost:8000"
echo "   Online: https://colt-charmed-lark.ngrok-free.app"
echo "   Admin: https://colt-charmed-lark.ngrok-free.app/admin/"
EOF

# Make scripts executable
chmod +x start_noctispro.sh stop_noctispro.sh status_noctispro.sh

# 9. Final Setup
log "🔧 Final configuration..."

# Reload systemd
$SUDO systemctl daemon-reload

# Enable service
$SUDO systemctl enable noctispro-production.service

success "✅ DEPLOYMENT SETUP COMPLETE!"
echo ""
echo "🎯 NEXT STEPS:"
echo "================================"
echo "🚀 Start the system:"
echo "   ./start_noctispro.sh"
echo ""
echo "📊 Check status:"
echo "   ./status_noctispro.sh"
echo ""
echo "🛑 Stop the system:"
echo "   ./stop_noctispro.sh"
echo ""
echo "🔧 Or use systemd service:"
echo "   sudo systemctl start noctispro-production.service"
echo "   sudo systemctl status noctispro-production.service"
echo ""
echo "🌐 Access URLs:"
echo "   Online: https://colt-charmed-lark.ngrok-free.app"
echo "   Admin: https://colt-charmed-lark.ngrok-free.app/admin/"
echo "   Login: admin / admin123"
echo ""
success "🎉 Ready to deploy! Run: ./start_noctispro.sh"