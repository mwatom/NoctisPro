#!/bin/bash

set -euo pipefail

# Minimal, non-interactive deployment for Ubuntu 22.04
# - Sets up Python venv, installs requirements
# - Applies migrations, collects static
# - Creates Django superuser (admin/admin123 unless overridden)
# - Runs Gunicorn via systemd on port 8000
# - Installs and runs ngrok via systemd, exposes port 8000
# Env overrides: NGROK_AUTHTOKEN, NGROK_DOMAIN (reserved), ADMIN_EMAIL, ADMIN_USERNAME, ADMIN_PASSWORD

PROJECT_DIR="/workspace"
VENV_DIR="$PROJECT_DIR/venv"
DJANGO_PORT="8000"
SERVICE_NAME="noctispro"
NGROK_SERVICE_NAME="noctispro-ngrok"

# Inputs via env with defaults
NGROK_AUTHTOKEN="${NGROK_AUTHTOKEN:-}"
NGROK_DOMAIN="${NGROK_DOMAIN:-}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@noctispro.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"

echo "[+] Updating apt and installing base packages"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  python3 python3-venv python3-pip python3-dev build-essential \
  libpq-dev curl wget unzip git \
  systemd || true

echo "[+] Ensuring project directory exists: $PROJECT_DIR"
sudo mkdir -p "$PROJECT_DIR"
sudo chown -R "$USER":"$USER" "$PROJECT_DIR"

cd "$PROJECT_DIR"

echo "[+] Setting up Python virtual environment"
if [ -d "$VENV_DIR" ]; then
  rm -rf "$VENV_DIR"
fi
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip wheel setuptools

if [ -f requirements.txt ]; then
  echo "[+] Installing Python requirements"
  pip install -r requirements.txt
else
  echo "[!] requirements.txt not found, installing Django and Gunicorn minimal set"
  pip install Django gunicorn psycopg2-binary redis gevent
fi

echo "[+] Exporting Django environment"
export DJANGO_SETTINGS_MODULE=noctis_pro.settings
export DEBUG=False
export ALLOWED_HOSTS="*"

echo "[+] Running Django migrations and collectstatic"
python manage.py migrate --noinput
python manage.py collectstatic --noinput || true

echo "[+] Creating superuser if missing: $ADMIN_USERNAME"
python manage.py shell <<PY
from django.contrib.auth import get_user_model
User = get_user_model()
username = "${ADMIN_USERNAME}"
email = "${ADMIN_EMAIL}"
password = "${ADMIN_PASSWORD}"
u = User.objects.filter(username=username).first()
if not u:
    User.objects.create_superuser(username, email, password)
    print("created")
else:
    print("exists")
PY

echo "[+] Creating systemd unit for Gunicorn: $SERVICE_NAME.service"
sudo tee /etc/systemd/system/${SERVICE_NAME}.service >/dev/null <<EOF
[Unit]
Description=NoctisPro Django (Gunicorn)
After=network.target

[Service]
Type=simple
User=${USER}
Group=${USER}
WorkingDirectory=${PROJECT_DIR}
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
Environment=DEBUG=False
Environment=ALLOWED_HOSTS=*
Environment=PATH=${VENV_DIR}/bin
ExecStart=${VENV_DIR}/bin/gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:${DJANGO_PORT} --workers 3 --worker-class gevent --timeout 120
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Reloading systemd and starting ${SERVICE_NAME}"
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl restart ${SERVICE_NAME}

echo "[+] Installing ngrok"
if ! command -v ngrok >/dev/null 2>&1; then
  curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list >/dev/null
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ngrok
fi

if [ -n "$NGROK_AUTHTOKEN" ]; then
  echo "[+] Configuring ngrok authtoken"
  ngrok config add-authtoken "$NGROK_AUTHTOKEN"
else
  echo "[!] NGROK_AUTHTOKEN not provided; ngrok will run unauthenticated (ephemeral)."
fi

echo "[+] Creating systemd unit for ngrok: ${NGROK_SERVICE_NAME}.service"
if [ -n "$NGROK_DOMAIN" ]; then
  NGROK_CMD="/usr/bin/ngrok http --domain=${NGROK_DOMAIN} ${DJANGO_PORT}"
else
  NGROK_CMD="/usr/bin/ngrok http ${DJANGO_PORT}"
fi

sudo tee /etc/systemd/system/${NGROK_SERVICE_NAME}.service >/dev/null <<EOF
[Unit]
Description=ngrok tunnel for NoctisPro
After=network.target ${SERVICE_NAME}.service

[Service]
Type=simple
User=${USER}
ExecStart=${NGROK_CMD}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Starting ngrok tunnel"
sudo systemctl daemon-reload
sudo systemctl enable ${NGROK_SERVICE_NAME}
sudo systemctl restart ${NGROK_SERVICE_NAME}

echo "[+] Waiting for ngrok API to report tunnels..."
sleep 5 || true

if command -v curl >/dev/null 2>&1; then
  URL=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -oE 'https://[a-zA-Z0-9.-]+\.ngrok[^" ]*' | head -n1 || true)
  if [ -n "$URL" ]; then
    echo "[OK] Public URL: $URL"
  else
    echo "[!] Could not auto-detect ngrok URL. Check: sudo journalctl -u ${NGROK_SERVICE_NAME} -f"
  fi
fi

echo "[DONE] App should be available via ngrok."
echo "Admin: ${ADMIN_USERNAME} / ${ADMIN_PASSWORD}"
