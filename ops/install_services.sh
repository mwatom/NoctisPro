#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/workspace"
VENV_DIR="$APP_DIR/venv"
HOST="127.0.0.1"
PORT="8000"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
	echo "This script must be run with sudo or as root."
	exit 1
fi

apt-get update -y
apt-get install -y python3 python3-venv python3-dev build-essential libpq-dev libjpeg-dev zlib1g-dev libopenjp2-7 libssl-dev libffi-dev git redis-server nginx

systemctl enable --now redis-server || true

if [ ! -d "$VENV_DIR" ]; then
	python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

pip install --upgrade pip wheel setuptools
pip install -r "$APP_DIR/requirements.txt"

cd "$APP_DIR"
"$VENV_DIR/bin/python" manage.py migrate --noinput
"$VENV_DIR/bin/python" manage.py collectstatic --noinput

cp "$APP_DIR/ops/noctis-web.service" /etc/systemd/system/noctis-web.service
cp "$APP_DIR/ops/noctis-celery.service" /etc/systemd/system/noctis-celery.service
cp "$APP_DIR/ops/noctis-dicom.service" /etc/systemd/system/noctis-dicom.service

systemctl daemon-reload
systemctl enable --now noctis-web.service noctis-celery.service noctis-dicom.service

cp "$APP_DIR/ops/nginx-noctis.conf" /etc/nginx/sites-available/noctis
ln -sf /etc/nginx/sites-available/noctis /etc/nginx/sites-enabled/noctis
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl restart nginx

# Open firewall (ignore if ufw is not installed)
ufw allow "Nginx Full" || true
ufw allow 11112/tcp || true

IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
IP_ADDR=${IP_ADDR:-"<server-ip>"}

echo
echo "Setup complete. Access the system at: http://$IP_ADDR/"
echo "Admin panel: http://$IP_ADDR/admin-panel/"
echo "Worklist: http://$IP_ADDR/worklist/"