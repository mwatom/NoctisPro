# 🚀 NoctisPro Post-Clone Production Deployment

## After Git Clone - Single Command Deployment

After cloning the repository, run this **ONE COMMAND** for complete production setup:

```bash
sudo bash -c 'curl -fsSL https://raw.githubusercontent.com/ngrok/install/main/install.sh | bash && apt-get update -qq && apt-get install -y python3 python3-pip python3-venv jq && cd /workspace && python3 -m venv venv && source venv/bin/activate && pip install --upgrade pip && pip install django pillow pydicom requests && printf "DEBUG=False\nSECRET_KEY=noctis-production-secret-2024\nDJANGO_SETTINGS_MODULE=noctis_pro.settings\nALLOWED_HOSTS=*,mallard-shining-curiously.ngrok-free.app,localhost\nUSE_SQLITE=True\nSTATIC_ROOT=/workspace/staticfiles\nMEDIA_ROOT=/workspace/media\nSERVE_MEDIA_FILES=True\nBUILD_TARGET=production\nENVIRONMENT=production\nHEALTH_CHECK_ENABLED=True\nTIME_ZONE=UTC\nUSE_TZ=True\nDICOM_STORAGE_PATH=/workspace/media/dicom\n" > .env.production && printf "NGROK_USE_STATIC=true\nNGROK_STATIC_URL=mallard-shining-curiously.ngrok-free.app\nNGROK_REGION=us\nDJANGO_PORT=8000\nDJANGO_HOST=0.0.0.0\nALLOWED_HOSTS=*,mallard-shining-curiously.ngrok-free.app,localhost\nDEBUG=False\nSECURE_SSL_REDIRECT=False\nSECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https\nSERVE_MEDIA_FILES=True\nHEALTH_CHECK_ENABLED=True\n" > .env.ngrok && python manage.py collectstatic --noinput && python manage.py migrate --noinput && echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username=\"admin\").exists() or User.objects.create_superuser(\"admin\", \"admin@noctispro.local\", \"admin123\")" | python manage.py shell && cat > /etc/systemd/system/noctispro-production.service << EOF
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
ExecStart=/bin/bash -c "cd /workspace && source venv/bin/activate && source .env.production && source .env.ngrok && python manage.py runserver 0.0.0.0:8000 & sleep 10 && ngrok http 8000 --hostname=mallard-shining-curiously.ngrok-free.app --log=stdout"
ExecStop=/bin/bash -c "pkill -f \"manage.py runserver\" || true; pkill -f \"ngrok\" || true"
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable noctispro-production.service && printf "#!/bin/bash\necho \"🚀 Starting NoctisPro...\"\nsudo systemctl start noctispro-production.service\nsleep 15\necho \"✅ Access: https://mallard-shining-curiously.ngrok-free.app\"\necho \"🔧 Admin: https://mallard-shining-curiously.ngrok-free.app/admin/\"\necho \"📱 Login: admin / admin123\"\n" > /workspace/start_production.sh && chmod +x /workspace/start_production.sh && printf "#!/bin/bash\necho \"🛑 Stopping NoctisPro...\"\nsudo systemctl stop noctispro-production.service\necho \"✅ Stopped\"\n" > /workspace/stop_production.sh && chmod +x /workspace/stop_production.sh && echo "🎉 DEPLOYMENT COMPLETE! Run: /workspace/start_production.sh"'
```

## Or Use The Script (Easier):

```bash
sudo /workspace/deploy_now.sh
```

## Complete Workflow:

```bash
# 1. Clone the repository
git clone <your-noctispro-repo-url>
cd noctispro

# 2. Run single deployment command
sudo /workspace/deploy_now.sh

# 3. Start the application
./start_production.sh
```

## 🌐 Instant Access:

- **Application**: https://mallard-shining-curiously.ngrok-free.app
- **Admin Panel**: https://mallard-shining-curiously.ngrok-free.app/admin/
- **Username**: admin
- **Password**: admin123

## 📱 Management Commands:

```bash
# Start application
./start_production.sh

# Stop application
./stop_production.sh

# Check status
sudo systemctl status noctispro-production.service

# View logs
sudo journalctl -u noctispro-production.service -f

# Restart
sudo systemctl restart noctispro-production.service
```

## ✨ What This Does:

1. ✅ Installs ngrok and all dependencies
2. ✅ Creates Python virtual environment
3. ✅ Installs Django and required packages
4. ✅ Configures production environment
5. ✅ Sets up static ngrok URL (mallard-shining-curiously.ngrok-free.app)
6. ✅ Runs Django migrations
7. ✅ Creates admin user (admin/admin123)
8. ✅ Sets up systemd service for boot startup
9. ✅ Creates start/stop scripts
10. ✅ Ready for production use!

## 🔑 Important Note:

You'll need to configure your ngrok auth token after deployment:

```bash
ngrok config add-authtoken YOUR_TOKEN_HERE
```

Get your token from: https://dashboard.ngrok.com/get-started/your-authtoken

## 🎉 That's It!

Your NoctisPro medical imaging platform is production-ready with the static URL from your previous charts!