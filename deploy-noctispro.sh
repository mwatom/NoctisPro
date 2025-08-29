#!/bin/bash

# NoctisPro One-Line Deployment Script
curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list && sudo apt-get update -qq && sudo apt-get install -y python3 python3-pip python3-venv redis-server nginx jq ngrok fail2ban ufw && cd /opt && sudo git clone https://github.com/your-repo/noctispro.git && sudo chown -R $(whoami):$(whoami) /opt/noctispro && cd /opt/noctispro && python3 -m venv venv && source venv/bin/activate && pip install --upgrade pip && pip install django pillow pydicom requests daphne channels channels-redis gunicorn whitenoise django-extensions djangorestframework opencv-python-headless SimpleITK reportlab celery django-widget-tweaks python-dotenv django-cors-headers psycopg2-binary django-redis && echo "DEBUG=False" > .env.production && echo "SECRET_KEY=noctis-enterprise-production-2024" >> .env.production && echo "USE_SQLITE=True" >> .env.production && echo "ALLOWED_HOSTS=*,colt-charmed-lark.ngrok-free.app,localhost" >> .env.production && sudo systemctl enable redis-server && sudo systemctl start redis-server && python manage.py collectstatic --noinput && python manage.py migrate --noinput && echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').delete(); User.objects.create_superuser('admin', 'admin@noctispro.com', 'NoctisPro2024')" | python manage.py shell && ngrok config add-authtoken 31Ru57qNtsoaFXnGZDyosoqQBKi_2RV15cXnsTifpKjae1N36 && sudo bash -c 'cat > /etc/systemd/system/noctispro-production.service << "EOF"
[Unit]
Description=NoctisPro Production
After=network.target redis-server.service
Requires=redis-server.service

[Service]
Type=forking
User='$(whoami)'
WorkingDirectory=/opt/noctispro
Environment=PATH=/opt/noctispro/venv/bin:/usr/bin:/bin
ExecStart=/bin/bash -c "cd /opt/noctispro && source venv/bin/activate && python manage.py runserver 0.0.0.0:8000 & sleep 10 && ngrok http 8000 --hostname=colt-charmed-lark.ngrok-free.app --log=stdout &"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF' && sudo systemctl daemon-reload && sudo systemctl enable noctispro-production.service && sudo systemctl start noctispro-production.service && sleep 20 && echo "🎉 DEPLOYED! Access: https://colt-charmed-lark.ngrok-free.app | Admin: admin/NoctisPro2024"