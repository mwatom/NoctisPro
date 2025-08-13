#!/usr/bin/env bash
set -euo pipefail

# Config
# Allow overriding via env; default to the script directory
APP_DIR="${APP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
VENV_DIR="${VENV_DIR:-$APP_DIR/venv}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
REDIS_URL="${REDIS_URL:-redis://127.0.0.1:6379/0}"

# Detect IP for message
IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
IP_ADDR=${IP_ADDR:-"127.0.0.1"}

echo "==> Updating apt packages"
sudo apt-get update -y
sudo apt-get install -y python3 python3-venv python3-dev build-essential libpq-dev libjpeg-dev zlib1g-dev libopenjp2-7 libssl-dev libffi-dev git redis-server

# Ensure Redis is running
sudo systemctl enable --now redis-server || true

# Python venv
if [ ! -d "$VENV_DIR" ]; then
  echo "==> Creating virtualenv"
  python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

pip install --upgrade pip wheel setuptools

echo "==> Installing Python requirements"
pip install -r "$APP_DIR/requirements.txt"
# If AUTO_RELOAD is enabled, install watchdog for watchmedo
if [ "${AUTO_RELOAD:-}" = "1" ] || [ "${AUTO_RELOAD:-}" = "true" ] || [ "${AUTO_RELOAD:-}" = "True" ]; then
  echo "==> AUTO_RELOAD enabled: installing watchdog"
  pip install watchdog
fi

export DJANGO_SETTINGS_MODULE=noctis_pro.settings
export REDIS_URL

cd "$APP_DIR"

echo "==> Applying migrations"
python manage.py migrate --noinput

echo "==> Collecting static files"
python manage.py collectstatic --noinput

# Create superuser if env provided
if [ -n "${ADMIN_USER:-}" ] && [ -n "${ADMIN_EMAIL:-}" ] && [ -n "${ADMIN_PASS:-}" ]; then
  echo "==> Ensuring admin user ${ADMIN_USER} exists"
  python - <<'PY'
import os
import django
django.setup()
from accounts.models import User
u,p,e = os.environ['ADMIN_USER'], os.environ['ADMIN_PASS'], os.environ['ADMIN_EMAIL']
if not User.objects.filter(username=u).exists():
    User.objects.create_superuser(username=u, email=e, password=p, role='admin')
    print('Created admin user:', u)
else:
    print('Admin user already exists:', u)
PY
fi

# Stop previous processes if any
pkill -f "daphne .*noctis_pro.asgi" || true
pkill -f "celery .* worker" || true
pkill -f "dicom_receiver.py" || true

# Start server processes
if [ "${AUTO_RELOAD:-}" = "1" ] || [ "${AUTO_RELOAD:-}" = "true" ] || [ "${AUTO_RELOAD:-}" = "True" ]; then
  echo "==> Starting Django dev server with auto-reload on ${HOST}:${PORT}"
  nohup "$VENV_DIR/bin/python" manage.py runserver "$HOST:$PORT" > "$APP_DIR/django-dev.log" 2>&1 &

  # Start Celery with auto-restart on code changes if available
  if command -v celery >/dev/null 2>&1; then
    if command -v watchmedo >/dev/null 2>&1; then
      echo "==> Starting Celery worker with auto-restart"
      nohup watchmedo auto-restart -d "$APP_DIR" -p "*.py" -R -- celery -A noctis_pro worker -l info > "$APP_DIR/celery.log" 2>&1 &
    else
      echo "==> Starting Celery worker (no auto-restart)"
      nohup celery -A noctis_pro worker -l info > "$APP_DIR/celery.log" 2>&1 &
    fi
  fi

  # Start DICOM receiver with auto-restart on code changes
  if command -v watchmedo >/dev/null 2>&1; then
    echo "==> Starting DICOM receiver (auto-restart enabled)"
    nohup watchmedo auto-restart -d "$APP_DIR" -p "*.py" -R -- "$VENV_DIR/bin/python" "$APP_DIR/dicom_receiver.py" --port 11112 --aet NOCTIS_SCP > "$APP_DIR/dicom_receiver.log" 2>&1 &
  else
    echo "==> Starting DICOM receiver (no auto-restart)"
    nohup "$VENV_DIR/bin/python" "$APP_DIR/dicom_receiver.py" --port 11112 --aet NOCTIS_SCP > "$APP_DIR/dicom_receiver.log" 2>&1 &
  fi
else
  # Start Daphne (ASGI) for Django Channels
  echo "==> Starting Daphne on ${HOST}:${PORT}"
  nohup daphne -b "$HOST" -p "$PORT" noctis_pro.asgi:application > "$APP_DIR/daphne.log" 2>&1 &

  # Start Celery worker (optional but recommended for recon tasks)
  if command -v celery >/dev/null 2>&1; then
    echo "==> Starting Celery worker"
    nohup celery -A noctis_pro worker -l info > "$APP_DIR/celery.log" 2>&1 &
  fi

  # Start DICOM receiver (storescp)
  echo "==> Starting DICOM receiver (SCP)"
  nohup "$VENV_DIR/bin/python" "$APP_DIR/dicom_receiver.py" --port 11112 --aet NOCTIS_SCP > "$APP_DIR/dicom_receiver.log" 2>&1 &
fi

sleep 2

echo "\nDeployment completed. Access the system at: http://${IP_ADDR}:${PORT}/"
echo "Admin panel: http://${IP_ADDR}:${PORT}/admin-panel/"
echo "Worklist: http://${IP_ADDR}:${PORT}/worklist/"
