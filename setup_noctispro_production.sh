#!/bin/bash

# NoctisPro Production Setup Script
# Complete production setup for Ubuntu Server with ngrok static URL

set -e

echo "🚀 NoctisPro Production Setup for Ubuntu Server"
echo "================================================"
echo "This script will configure NoctisPro for production use with:"
echo "  ✅ Systemd autostart service"
echo "  ✅ Ngrok static URL integration"
echo "  ✅ PostgreSQL database"
echo "  ✅ Redis caching"
echo "  ✅ Production-optimized settings"
echo ""

WORKSPACE_DIR="/workspace"
SERVICE_NAME="noctispro-production-startup"

# Check if running as root or with sudo access
if [ "$EUID" -eq 0 ]; then
    SUDO=""
    USER_HOME="/home/ubuntu"
else
    if ! sudo -n true 2>/dev/null; then
        echo "❌ This script requires sudo access"
        echo "Please run: sudo $0"
        exit 1
    fi
    SUDO="sudo"
    USER_HOME="$HOME"
fi

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

# Function to prompt for input with default
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    read -p "$prompt [$default]: " input
    if [ -z "$input" ]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$input\""
    fi
}

echo "Step 1: System Dependencies"
echo "==========================="

log "Updating package lists..."
$SUDO apt update

log "Installing system dependencies..."
$SUDO apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    postgresql \
    postgresql-contrib \
    redis-server \
    nginx \
    curl \
    wget \
    unzip \
    git \
    build-essential \
    libpq-dev \
    python3-dev

echo "✅ System dependencies installed"
echo ""

echo "Step 2: Ngrok Installation"
echo "=========================="

if ! command -v ngrok &> /dev/null; then
    log "Installing ngrok..."
    
    # Download and install ngrok
    cd /tmp
    wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    tar xzf ngrok-v3-stable-linux-amd64.tgz
    $SUDO mv ngrok /usr/local/bin/
    rm -f ngrok-v3-stable-linux-amd64.tgz
    
    echo "✅ Ngrok installed"
else
    echo "✅ Ngrok already installed"
fi

# Configure ngrok auth token
echo ""
if ! ngrok config check >/dev/null 2>&1; then
    echo "🔑 Ngrok Authentication Required"
    echo "================================"
    echo "You need to configure your ngrok auth token."
    echo ""
    echo "Steps:"
    echo "1. Visit: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "2. Sign up/login to ngrok"
    echo "3. Copy your auth token"
    echo ""
    
    read -p "Enter your ngrok auth token: " NGROK_TOKEN
    
    if [ ! -z "$NGROK_TOKEN" ]; then
        ngrok config add-authtoken "$NGROK_TOKEN"
        echo "✅ Ngrok auth token configured"
    else
        echo "❌ Auth token cannot be empty"
        exit 1
    fi
else
    echo "✅ Ngrok authentication already configured"
fi

echo ""

echo "Step 3: Database Setup"
echo "======================"

log "Starting PostgreSQL..."
$SUDO systemctl enable postgresql
$SUDO systemctl start postgresql

# Configure PostgreSQL
log "Configuring PostgreSQL database..."

# Create database user and database
$SUDO -u postgres psql -c "SELECT 1 FROM pg_user WHERE usename = 'noctis_user';" | grep -q 1 || $SUDO -u postgres createuser --createdb --no-createrole --no-superuser noctis_user

$SUDO -u postgres psql -c "ALTER USER noctis_user PASSWORD 'noctis_secure_password_2025';"

$SUDO -u postgres psql -c "SELECT 1 FROM pg_database WHERE datname = 'noctis_pro';" | grep -q 1 || $SUDO -u postgres createdb -O noctis_user noctis_pro

echo "✅ PostgreSQL configured"
echo ""

echo "Step 4: Redis Setup"
echo "==================="

log "Starting Redis..."
$SUDO systemctl enable redis-server
$SUDO systemctl start redis-server

echo "✅ Redis configured"
echo ""

echo "Step 5: Python Environment"
echo "=========================="

cd "$WORKSPACE_DIR"

if [ ! -d "venv" ]; then
    log "Creating Python virtual environment..."
    python3 -m venv venv
else
    log "Virtual environment already exists"
fi

log "Activating virtual environment..."
source venv/bin/activate

log "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "✅ Python environment configured"
echo ""

echo "Step 6: Django Setup"
echo "===================="

log "Running Django migrations..."
python manage.py migrate --noinput

log "Collecting static files..."
python manage.py collectstatic --noinput --clear

# Create admin user if it doesn't exist
log "Setting up admin user..."
python manage.py shell -c "
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.local', 'admin123')
    print('Admin user created: admin/admin123')
else:
    print('Admin user already exists')
"

echo "✅ Django configured"
echo ""

echo "Step 7: Ngrok Static URL Configuration"
echo "======================================"

echo "Current ngrok configuration:"
if [ -f ".env.ngrok" ]; then
    source .env.ngrok
    echo "  Static URL enabled: $NGROK_USE_STATIC"
    echo "  Static URL: $NGROK_STATIC_URL"
else
    echo "  No ngrok configuration found"
fi

echo ""
echo "Configure your static URL options:"
echo "1. Keep current configuration (colt-charmed-lark.ngrok-free.app)"
echo "2. Use a different static URL"
echo "3. Use dynamic URLs (random each time)"
echo ""

read -p "Choose option [1/2/3]: " choice

case $choice in
    1)
        echo "✅ Keeping current static URL configuration"
        ;;
    2)
        read -p "Enter your static URL (without https://): " NEW_STATIC_URL
        if [ ! -z "$NEW_STATIC_URL" ]; then
            sed -i "s/NGROK_STATIC_URL=.*/NGROK_STATIC_URL=$NEW_STATIC_URL/" .env.ngrok
            sed -i "s/ALLOWED_HOSTS=.*/ALLOWED_HOSTS=\"*,$NEW_STATIC_URL,localhost,127.0.0.1\"/" .env.production
            echo "✅ Updated static URL to: $NEW_STATIC_URL"
        fi
        ;;
    3)
        sed -i "s/NGROK_USE_STATIC=true/NGROK_USE_STATIC=false/" .env.ngrok
        echo "✅ Configured for dynamic URLs"
        ;;
    *)
        echo "✅ Keeping current configuration"
        ;;
esac

echo ""

echo "Step 8: Service Installation"
echo "============================"

# Install the systemd service
log "Installing systemd service..."
./install_production_startup.sh

echo "✅ Service installed and configured"
echo ""

echo "Step 9: Final Configuration"
echo "==========================="

# Set proper ownership
log "Setting file permissions..."
$SUDO chown -R ubuntu:ubuntu "$WORKSPACE_DIR"
chmod +x "$WORKSPACE_DIR"/*.sh

# Create required directories
mkdir -p "$WORKSPACE_DIR/staticfiles"
mkdir -p "$WORKSPACE_DIR/media"
mkdir -p "$WORKSPACE_DIR/backups"
mkdir -p "$WORKSPACE_DIR/logs"

echo "✅ Configuration completed"
echo ""

echo "🎉 NoctisPro Production Setup Complete!"
echo "========================================"
echo ""
echo "📋 Installation Summary:"
echo "   ✅ System dependencies installed"
echo "   ✅ Ngrok installed and configured"
echo "   ✅ PostgreSQL database ready"
echo "   ✅ Redis caching ready"
echo "   ✅ Python environment configured"
echo "   ✅ Django application ready"
echo "   ✅ Systemd service installed"
echo ""
echo "🚀 Service Management:"
echo "   Start:    sudo systemctl start $SERVICE_NAME"
echo "   Stop:     sudo systemctl stop $SERVICE_NAME"
echo "   Restart:  sudo systemctl restart $SERVICE_NAME"
echo "   Status:   sudo systemctl status $SERVICE_NAME"
echo "   Logs:     sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "🌍 Access Information:"
echo "   Local URL: http://localhost:8000"
echo "   Ngrok UI:  http://localhost:4040"

# Show ngrok URL if static is configured
if [ -f ".env.ngrok" ]; then
    source .env.ngrok
    if [ "$NGROK_USE_STATIC" = "true" ] && [ ! -z "$NGROK_STATIC_URL" ]; then
        echo "   Public URL: https://$NGROK_STATIC_URL"
    fi
fi

echo ""
echo "👤 Admin Access:"
echo "   Username: admin"
echo "   Password: admin123"
echo "   (Change password after first login)"
echo ""
echo "📁 Important Files:"
echo "   Service: /etc/systemd/system/$SERVICE_NAME.service"
echo "   Logs: $WORKSPACE_DIR/noctispro_production.log"
echo "   Config: $WORKSPACE_DIR/.env.production"
echo "   Ngrok: $WORKSPACE_DIR/.env.ngrok"
echo ""
echo "🔄 The service is configured to start automatically on boot!"
echo ""

# Ask if user wants to start the service now
read -p "Start NoctisPro service now? (y/N): " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Starting NoctisPro service..."
    $SUDO systemctl start "$SERVICE_NAME"
    
    echo ""
    echo "✅ Service started! Check status with:"
    echo "   sudo systemctl status $SERVICE_NAME"
    
    # Wait a moment and show the ngrok URL
    echo ""
    echo "⏳ Waiting for ngrok tunnel to establish..."
    sleep 10
    
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data.get('tunnels', []):
        if tunnel.get('proto') == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
" 2>/dev/null || true)
    
    if [ ! -z "$NGROK_URL" ]; then
        echo "🌍 Your NoctisPro is now accessible at: $NGROK_URL"
    else
        echo "Check ngrok logs for the tunnel URL: sudo journalctl -u $SERVICE_NAME -f"
    fi
fi

echo ""
echo "🎯 Next Steps:"
echo "   1. Access your application via the public URL"
echo "   2. Login with admin credentials"
echo "   3. Change default passwords"
echo "   4. Configure your specific settings"
echo "   5. Monitor logs: sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "✅ Setup complete! NoctisPro will automatically start on boot."