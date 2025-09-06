#!/bin/bash

# One-Command Internet Deployment
# Usage: ./internet_now.sh

echo "🌍 DEPLOYING TO INTERNET NOW! 🌍"
echo "Domain: noctispro2.duckdns.org:8000"

# Quick setup
cd /home/noctispro/NoctisPro 2>/dev/null || cd /workspace
source venv/bin/activate 2>/dev/null || { python3 -m venv venv && source venv/bin/activate; }

# Kill existing processes
sudo lsof -ti:8000 | xargs -r sudo kill -9 2>/dev/null || true

# Update DuckDNS
/workspace/update_duckdns.sh 2>/dev/null || true

# Quick migration and admin setup
python manage.py migrate --noinput
echo "from django.contrib.auth import get_user_model; User=get_user_model(); User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin','admin@noctispro.com','admin123')" | python manage.py shell

# Start server
export DEBUG=False
export ALLOWED_HOSTS="*,noctispro2.duckdns.org,*.duckdns.org,localhost"

echo ""
echo "🚀 LIVE AT: http://noctispro2.duckdns.org:8000"
echo "🔑 Admin: admin / admin123"
echo ""

python manage.py runserver 0.0.0.0:8000