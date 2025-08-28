#!/bin/bash

# 🚀 NoctisPro Single-Line Production Deployment
# Complete setup, ngrok configuration, and auto-start in one command

curl -fsSL https://raw.githubusercontent.com/ngrok/install/main/install.sh | sudo bash && \
sudo apt-get update -qq && sudo apt-get install -y python3 python3-pip python3-venv postgresql redis-server nginx jq && \
cd /workspace && \
python3 -m venv venv && source venv/bin/activate && \
pip install --upgrade pip && pip install django pillow pydicom requests && \
cat > .env.production << 'PRODEOF'
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
PRODEOF
cat > .env.ngrok << 'NGROKEOF'
NGROK_USE_STATIC=true
NGROK_STATIC_URL=colt-charmed-lark.ngrok-free.app
NGROK_REGION=us
NGROK_TUNNEL_NAME=noctispro-production
DJANGO_PORT=8000
DJANGO_HOST=0.0.0.0
ALLOWED_HOSTS="*,colt-charmed-lark.ngrok-free.app,localhost,127.0.0.1"
DEBUG=False
SECURE_SSL_REDIRECT=False
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https
SERVE_MEDIA_FILES=True
HEALTH_CHECK_ENABLED=True
NGROKEOF
python manage.py collectstatic --noinput && \
python manage.py migrate --noinput && \
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@noctispro.local', 'admin123')" | python manage.py shell && \
sudo tee /etc/systemd/system/noctispro-production.service > /dev/null << 'SERVICEEOF'
[Unit]
Description=NoctisPro Production with Ngrok
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
SERVICEEOF
sudo systemctl daemon-reload && \
sudo systemctl enable noctispro-production.service && \
cat > start_production.sh << 'STARTEOF'
#!/bin/bash
echo "🚀 Starting NoctisPro Production..."
sudo systemctl start noctispro-production.service
sleep 15
echo "📊 Service Status:"
sudo systemctl status noctispro-production.service --no-pager -l
echo ""
echo "🌐 Getting ngrok URL..."
sleep 5
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "https://colt-charmed-lark.ngrok-free.app")
echo "✅ Access your application at: $NGROK_URL"
echo "🔧 Admin panel: $NGROK_URL/admin/"
echo "📱 Username: admin | Password: admin123"
STARTEOF
chmod +x start_production.sh && \
cat > stop_production.sh << 'STOPEOF'
#!/bin/bash
echo "🛑 Stopping NoctisPro Production..."
sudo systemctl stop noctispro-production.service
echo "✅ Services stopped"
STOPEOF
chmod +x stop_production.sh && \
echo "🎉 DEPLOYMENT COMPLETE! Run: ./start_production.sh"