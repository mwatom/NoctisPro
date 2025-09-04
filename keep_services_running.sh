#!/bin/bash
# Auto-restart services if they go down

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}"

# Check and restart Nginx
if ! pgrep -f nginx > /dev/null; then
    sudo nginx
fi

# Check and restart Gunicorn
if ! pgrep -f "gunicorn.*noctis_pro" > /dev/null; then
    cd "${WORK_DIR}"
    source venv/bin/activate
    nohup gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:8000 --workers 3 --timeout 1800 --daemon > /dev/null 2>&1
fi

# Check and restart Ngrok
if ! pgrep -f ngrok > /dev/null; then
    nohup ngrok http --url=mallard-shining-curiously.ngrok-free.app 80 > "${WORK_DIR}/ngrok.log" 2>&1 &
fi
