#!/bin/bash
# One-liner deployment for Noctis Pro DICOM System on Ubuntu 22.04
# Usage: curl -fsSL https://raw.githubusercontent.com/user/repo/main/one_liner_deploy.sh | bash
# Or: wget -qO- https://raw.githubusercontent.com/user/repo/main/one_liner_deploy.sh | bash
# Or: bash <(curl -s https://raw.githubusercontent.com/user/repo/main/one_liner_deploy.sh)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="noctis_pro"
APP_DIR="/opt/$APP_NAME"
VENV_DIR="$APP_DIR/venv"
HOST="0.0.0.0"
PORT="8000"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@noctis.local}"
ADMIN_PASS="${ADMIN_PASS:-admin123}"

echo -e "${BLUE}🚀 Starting Noctis Pro DICOM System Deployment${NC}"

# Check if running as root or with sudo access
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    if ! sudo -n true 2>/dev/null; then
        echo -e "${RED}❌ This script requires sudo access. Please run with sudo or ensure passwordless sudo is configured.${NC}"
        exit 1
    fi
    SUDO="sudo"
fi

# Update system packages
echo -e "${YELLOW}📦 Updating system packages...${NC}"
$SUDO apt-get update -y > /dev/null 2>&1

# Install system dependencies
echo -e "${YELLOW}🔧 Installing system dependencies...${NC}"
$SUDO apt-get install -y \
    python3 python3-venv python3-dev python3-pip \
    build-essential libpq-dev libjpeg-dev zlib1g-dev \
    libopenjp2-7 libssl-dev libffi-dev \
    git redis-server curl wget unzip \
    nginx supervisor htop > /dev/null 2>&1

# Enable and start Redis
echo -e "${YELLOW}🔴 Setting up Redis...${NC}"
$SUDO systemctl enable redis-server > /dev/null 2>&1
$SUDO systemctl start redis-server > /dev/null 2>&1

# Create application directory
echo -e "${YELLOW}📁 Setting up application directory...${NC}"
$SUDO mkdir -p $APP_DIR
$SUDO chown $USER:$USER $APP_DIR

# Clone/copy the application (assuming current directory has the code)
if [ -f "manage.py" ]; then
    echo -e "${YELLOW}📋 Copying application files...${NC}"
    cp -r . $APP_DIR/
else
    echo -e "${RED}❌ No Django application found in current directory. Please run this script from the project root.${NC}"
    exit 1
fi

cd $APP_DIR

# Create Python virtual environment
echo -e "${YELLOW}🐍 Setting up Python virtual environment...${NC}"
python3 -m venv $VENV_DIR
source $VENV_DIR/bin/activate

# Upgrade pip and install requirements
echo -e "${YELLOW}📦 Installing Python dependencies...${NC}"
pip install --upgrade pip wheel setuptools > /dev/null 2>&1
pip install -r requirements.txt > /dev/null 2>&1

# Set environment variables
export DJANGO_SETTINGS_MODULE=noctis_pro.settings
export REDIS_URL="redis://127.0.0.1:6379/0"

# Django setup
echo -e "${YELLOW}🗃️ Setting up Django database...${NC}"
python manage.py migrate --noinput > /dev/null 2>&1
python manage.py collectstatic --noinput > /dev/null 2>&1

# Create admin user
echo -e "${YELLOW}👤 Creating admin user...${NC}"
python - <<EOF > /dev/null 2>&1
import os
import django
django.setup()
from accounts.models import User
if not User.objects.filter(username='$ADMIN_USER').exists():
    User.objects.create_superuser(username='$ADMIN_USER', email='$ADMIN_EMAIL', password='$ADMIN_PASS', role='admin')
    print('Created admin user: $ADMIN_USER')
EOF

# Install and setup ngrok for secure tunneling
echo -e "${YELLOW}🌐 Setting up ngrok for secure external access...${NC}"
if ! command -v ngrok &> /dev/null; then
    cd /tmp
    wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    tar xzf ngrok-v3-stable-linux-amd64.tgz
    $SUDO mv ngrok /usr/local/bin/
    rm ngrok-v3-stable-linux-amd64.tgz
    cd $APP_DIR
fi

# Create systemd services
echo -e "${YELLOW}⚙️ Creating systemd services...${NC}"

# Django service
$SUDO tee /etc/systemd/system/noctis-django.service > /dev/null <<EOF
[Unit]
Description=Noctis Pro Django Application
After=network.target redis.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
Environment=REDIS_URL=redis://127.0.0.1:6379/0
ExecStart=$VENV_DIR/bin/daphne -b $HOST -p $PORT noctis_pro.asgi:application
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Celery service
$SUDO tee /etc/systemd/system/noctis-celery.service > /dev/null <<EOF
[Unit]
Description=Noctis Pro Celery Worker
After=network.target redis.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
Environment=REDIS_URL=redis://127.0.0.1:6379/0
ExecStart=$VENV_DIR/bin/celery -A noctis_pro worker -l info
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# DICOM receiver service
$SUDO tee /etc/systemd/system/noctis-dicom.service > /dev/null <<EOF
[Unit]
Description=Noctis Pro DICOM Receiver
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
ExecStart=$VENV_DIR/bin/python dicom_receiver.py --port 11112 --aet NOCTIS_SCP
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Ngrok service
$SUDO tee /etc/systemd/system/noctis-ngrok.service > /dev/null <<EOF
[Unit]
Description=Ngrok Tunnel for Noctis Pro
After=network.target noctis-django.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/local/bin/ngrok http $PORT --log stdout
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
echo -e "${YELLOW}🚀 Starting services...${NC}"
$SUDO systemctl daemon-reload
$SUDO systemctl enable noctis-django noctis-celery noctis-dicom noctis-ngrok > /dev/null 2>&1
$SUDO systemctl start noctis-django noctis-celery noctis-dicom > /dev/null 2>&1

# Wait for Django to start
sleep 5

# Start ngrok and get the public URL
$SUDO systemctl start noctis-ngrok > /dev/null 2>&1
sleep 10

# Get ngrok public URL
echo -e "${YELLOW}🔗 Getting public access URL...${NC}"
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tunnels = data.get('tunnels', [])
    if tunnels:
        print(tunnels[0]['public_url'])
    else:
        print('No tunnels found')
except:
    print('Error getting ngrok URL')
" 2>/dev/null)

# Get local IP for backup
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Create a status script
cat > $APP_DIR/status.sh <<EOF
#!/bin/bash
echo "=== Noctis Pro DICOM System Status ==="
echo
echo "Services:"
systemctl is-active --quiet noctis-django && echo "✅ Django: Running" || echo "❌ Django: Stopped"
systemctl is-active --quiet noctis-celery && echo "✅ Celery: Running" || echo "❌ Celery: Stopped"
systemctl is-active --quiet noctis-dicom && echo "✅ DICOM Receiver: Running" || echo "❌ DICOM Receiver: Stopped"
systemctl is-active --quiet noctis-ngrok && echo "✅ Ngrok Tunnel: Running" || echo "❌ Ngrok Tunnel: Stopped"
systemctl is-active --quiet redis && echo "✅ Redis: Running" || echo "❌ Redis: Stopped"
echo
echo "Access URLs:"
NGROK_URL=\$(curl -s http://localhost:4040/api/tunnels | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tunnels = data.get('tunnels', [])
    if tunnels:
        print(tunnels[0]['public_url'])
    else:
        print('No tunnels found')
except:
    print('Error getting ngrok URL')
" 2>/dev/null)
if [ "\$NGROK_URL" != "No tunnels found" ] && [ "\$NGROK_URL" != "Error getting ngrok URL" ]; then
    echo "🌐 Public URL (secure): \$NGROK_URL"
    echo "🌐 Admin Panel: \$NGROK_URL/admin-panel/"
    echo "🌐 Worklist: \$NGROK_URL/worklist/"
else
    echo "🌐 Local URL: http://$(hostname -I | awk '{print $1}'):$PORT"
    echo "🌐 Admin Panel: http://$(hostname -I | awk '{print $1}'):$PORT/admin-panel/"
    echo "🌐 Worklist: http://$(hostname -I | awk '{print $1}'):$PORT/worklist/"
fi
echo
echo "Admin Credentials:"
echo "Username: $ADMIN_USER"
echo "Password: $ADMIN_PASS"
echo
echo "To restart all services: sudo systemctl restart noctis-django noctis-celery noctis-dicom noctis-ngrok"
echo "To stop all services: sudo systemctl stop noctis-django noctis-celery noctis-dicom noctis-ngrok"
echo "To view logs: sudo journalctl -u noctis-django -f"
EOF

chmod +x $APP_DIR/status.sh

# Final output
echo
echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${BLUE}===========================================${NC}"
echo -e "${GREEN}🎉 Noctis Pro DICOM System is now running!${NC}"
echo
if [ "$NGROK_URL" != "No tunnels found" ] && [ "$NGROK_URL" != "Error getting ngrok URL" ]; then
    echo -e "${GREEN}🌐 Public Access URL (secure):${NC} $NGROK_URL"
    echo -e "${GREEN}🛠️ Admin Panel:${NC} $NGROK_URL/admin-panel/"
    echo -e "${GREEN}📋 Worklist:${NC} $NGROK_URL/worklist/"
else
    echo -e "${YELLOW}⚠️ Ngrok tunnel not ready yet. Local access:${NC}"
    echo -e "${GREEN}🌐 Local URL:${NC} http://$LOCAL_IP:$PORT"
    echo -e "${GREEN}🛠️ Admin Panel:${NC} http://$LOCAL_IP:$PORT/admin-panel/"
    echo -e "${GREEN}📋 Worklist:${NC} http://$LOCAL_IP:$PORT/worklist/"
    echo -e "${BLUE}💡 Run '$APP_DIR/status.sh' to get the public URL once ngrok is ready${NC}"
fi
echo
echo -e "${GREEN}👤 Admin Credentials:${NC}"
echo -e "   Username: $ADMIN_USER"
echo -e "   Password: $ADMIN_PASS"
echo
echo -e "${BLUE}📊 System Management:${NC}"
echo -e "   Status: $APP_DIR/status.sh"
echo -e "   Logs: sudo journalctl -u noctis-django -f"
echo -e "   Restart: sudo systemctl restart noctis-django noctis-celery noctis-dicom noctis-ngrok"
echo -e "${BLUE}===========================================${NC}"