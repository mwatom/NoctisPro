#!/bin/bash
# 🚀 Ultimate NoctisPro Production Deployment - Single Command
curl -fsSL https://raw.githubusercontent.com/ngrok/install/main/install.sh | sudo bash && sudo apt-get update -qq && sudo apt-get install -y python3 python3-pip python3-venv jq && cd /workspace && python3 -m venv venv && source venv/bin/activate && pip install --upgrade pip && pip install django pillow pydicom requests && printf 'DEBUG=False\nSECRET_KEY=noctis-production-secret-2024\nDJANGO_SETTINGS_MODULE=noctis_pro.settings\nALLOWED_HOSTS=*,colt-charmed-lark.ngrok-free.app,localhost\nUSE_SQLITE=True\nSTATIC_ROOT=/workspace/staticfiles\nMEDIA_ROOT=/workspace/media\nSERVE_MEDIA_FILES=True\nBUILD_TARGET=production\nENVIRONMENT=production\nHEALTH_CHECK_ENABLED=True\nTIME_ZONE=UTC\nUSE_TZ=True\nDICOM_STORAGE_PATH=/workspace/media/dicom\n' > .env.production && printf 'NGROK_USE_STATIC=true\nNGROK_STATIC_URL=colt-charmed-lark.ngrok-free.app\nNGROK_REGION=us\nDJANGO_PORT=8000\nDJANGO_HOST=0.0.0.0\nALLOWED_HOSTS="*,colt-charmed-lark.ngrok-free.app,localhost"\nDEBUG=False\nSECURE_SSL_REDIRECT=False\nSECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https\nSERVE_MEDIA_FILES=True\nHEALTH_CHECK_ENABLED=True\n' > .env.ngrok && python manage.py collectstatic --noinput && python manage.py migrate --noinput && echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@noctispro.local', 'admin123')" | python manage.py shell && sudo bash -c 'cat > /etc/systemd/system/noctispro-production.service << '\''EOF'\''
[Unit]
Description=NoctisPro Production with Ngrok
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/workspace
Environment=PATH=/workspace/venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=/workspace
EnvironmentFile=-/workspace/.env.production
EnvironmentFile=-/workspace/.env.ngrok
ExecStart=/bin/bash -c "cd /workspace && source venv/bin/activate && source .env.production && source .env.ngrok && python manage.py runserver 0.0.0.0:8000 & sleep 10 && ngrok http 8000 --hostname=colt-charmed-lark.ngrok-free.app --log=stdout"
ExecStop=/bin/bash -c "pkill -f '\''manage.py runserver'\'' || true; pkill -f '\''ngrok'\'' || true"
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF' && sudo systemctl daemon-reload && sudo systemctl enable noctispro-production.service && printf '#!/bin/bash\necho "🚀 Starting NoctisPro..."\nsudo systemctl start noctispro-production.service\nsleep 15\necho "✅ Access: https://colt-charmed-lark.ngrok-free.app"\necho "🔧 Admin: https://colt-charmed-lark.ngrok-free.app/admin/"\necho "📱 Login: admin / admin123"\n' > start_production.sh && chmod +x start_production.sh && printf '#!/bin/bash\necho "🛑 Stopping NoctisPro..."\nsudo systemctl stop noctispro-production.service\necho "✅ Stopped"\n' > stop_production.sh && chmod +x stop_production.sh && echo "🎉 DEPLOYMENT COMPLETE! Run: ./start_production.sh"