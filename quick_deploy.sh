#!/bin/bash

# 🚀 NoctisPro Quick Deploy - Post Git Clone
# Single command for complete production deployment with ngrok static URL

echo "🚀 NoctisPro Quick Deploy Starting..."
echo "Using static URL from previous charts: colt-charmed-lark.ngrok-free.app"

# Install ngrok and dependencies
curl -fsSL https://raw.githubusercontent.com/ngrok/install/main/install.sh | sudo bash
sudo apt-get update -qq
sudo apt-get install -y python3 python3-pip python3-venv jq

# Setup Python environment
cd /workspace
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install django pillow pydicom requests

# Create production environment file
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

# Setup Django
python manage.py collectstatic --noinput
python manage.py migrate --noinput

# Create admin user
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@noctispro.local', 'admin123')" | python manage.py shell

# Create systemd service
sudo tee /etc/systemd/system/noctispro-production.service > /dev/null << 'EOF'
[Unit]
Description=NoctisPro Production with Ngrok Static URL
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=3

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/workspace
Environment=PATH=/workspace/venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=/workspace
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
EnvironmentFile=-/workspace/.env.production
EnvironmentFile=-/workspace/.env.ngrok

ExecStartPre=/bin/bash -c 'sleep 5'
ExecStart=/bin/bash -c 'cd /workspace && source venv/bin/activate && source .env.production && source .env.ngrok && python manage.py runserver 0.0.0.0:8000 & sleep 10 && if [ "$NGROK_USE_STATIC" = "true" ] && [ ! -z "$NGROK_STATIC_URL" ]; then ngrok http 8000 --hostname=$NGROK_STATIC_URL --log=stdout; else ngrok http 8000 --log=stdout; fi'

ExecStop=/bin/bash -c 'pkill -f "manage.py runserver" || true; pkill -f "ngrok" || true'

TimeoutStartSec=120
TimeoutStopSec=30
Restart=always
RestartSec=15

StandardOutput=journal
StandardError=journal
SyslogIdentifier=noctispro-production

[Install]
WantedBy=multi-user.target
EOF

# Enable service
sudo systemctl daemon-reload
sudo systemctl enable noctispro-production.service

# Create start script
cat > start_production.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting NoctisPro Production..."
sudo systemctl start noctispro-production.service
echo "⏳ Waiting for services to start..."
sleep 20

echo "📊 Service Status:"
sudo systemctl status noctispro-production.service --no-pager -l

echo ""
echo "🌐 Application URLs:"
echo "✅ Main App: https://colt-charmed-lark.ngrok-free.app"
echo "🔧 Admin Panel: https://colt-charmed-lark.ngrok-free.app/admin/"
echo "📱 DICOM Viewer: https://colt-charmed-lark.ngrok-free.app/dicom-viewer/"
echo "📋 Worklist: https://colt-charmed-lark.ngrok-free.app/worklist/"
echo ""
echo "🔑 Admin Credentials:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "📝 Management Commands:"
echo "   Stop:    ./stop_production.sh"
echo "   Status:  sudo systemctl status noctispro-production.service"
echo "   Logs:    sudo journalctl -u noctispro-production.service -f"
EOF

chmod +x start_production.sh

# Create stop script
cat > stop_production.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping NoctisPro Production..."
sudo systemctl stop noctispro-production.service
echo "✅ Services stopped"
EOF

chmod +x stop_production.sh

# Create status check script
cat > check_status.sh << 'EOF'
#!/bin/bash
echo "📊 NoctisPro Production Status"
echo "============================"
echo ""

echo "🎯 Service Status:"
sudo systemctl status noctispro-production.service --no-pager -l

echo ""
echo "🌐 Ngrok Tunnel:"
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "Not available")
echo "   Current URL: $NGROK_URL"

echo ""
echo "📱 Quick Access:"
echo "   Application: https://colt-charmed-lark.ngrok-free.app"
echo "   Admin Panel: https://colt-charmed-lark.ngrok-free.app/admin/"

echo ""
echo "🔧 Management:"
echo "   Start:   ./start_production.sh"
echo "   Stop:    ./stop_production.sh"
echo "   Restart: sudo systemctl restart noctispro-production.service"
echo "   Logs:    sudo journalctl -u noctispro-production.service -f"
EOF

chmod +x check_status.sh

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo ""
echo "📋 Next Steps:"
echo "1. Configure ngrok auth token: ngrok config add-authtoken YOUR_TOKEN"
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