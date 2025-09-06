#!/bin/bash
# NOCTIS PRO PACS - Service Monitor and Auto-Restart

check_and_restart_service() {
    local service_name=$1
    local check_command=$2
    local restart_command=$3
    
    if ! eval $check_command > /dev/null 2>&1; then
        echo "$(date): $service_name is down, restarting..."
        eval $restart_command
        sleep 5
        if eval $check_command > /dev/null 2>&1; then
            echo "$(date): $service_name restarted successfully"
        else
            echo "$(date): Failed to restart $service_name"
        fi
    fi
}

# Check Nginx
check_and_restart_service "Nginx" \
    "pgrep -f nginx" \
    "sudo nginx"

# Check Gunicorn
check_and_restart_service "Gunicorn" \
    "pgrep -f 'gunicorn.*noctis_pro'" \
    "cd /workspace && source venv/bin/activate && nohup gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:8000 --workers 3 --timeout 1800 --daemon > /dev/null 2>&1"

# Check Ngrok (always ensure it's running)
check_and_restart_service "Ngrok" \
    "pgrep -f ngrok" \
    "nohup ngrok http --url=mallard-shining-curiously.ngrok-free.app 80 > /workspace/ngrok.log 2>&1 &"
