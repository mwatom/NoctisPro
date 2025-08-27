#!/bin/bash

# NoctisPro Startup Script for Auto-start
# This script will start NoctisPro services automatically

WORKSPACE_DIR="/workspace"
LOG_FILE="$WORKSPACE_DIR/noctispro_startup.log"

# Redirect output to log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "$(date): Starting NoctisPro startup script..."

# Function to check if a process is running
is_running() {
    pgrep -f "$1" > /dev/null
}

# Start PostgreSQL if not running
if ! is_running "postgres"; then
    echo "$(date): Starting PostgreSQL..."
    sudo service postgresql start
fi

# Start Redis if not running
if ! is_running "redis-server"; then
    echo "$(date): Starting Redis..."
    sudo service redis-server start
fi

# Wait for services to be ready
sleep 5

# Change to workspace directory
cd "$WORKSPACE_DIR"

# Check if Django is already running
if is_running "manage.py runserver"; then
    echo "$(date): Django is already running"
else
    echo "$(date): Starting Django application..."
    
    # Activate virtual environment and start Django
    source venv/bin/activate
    source .env.production
    
    # Run migrations
    python manage.py migrate
    
    # Collect static files
    python manage.py collectstatic --noinput
    
    # Start Django in background
    nohup python manage.py runserver 0.0.0.0:8000 >> "$LOG_FILE" 2>&1 &
    
    echo "$(date): Django started with PID $!"
fi

# Check if ngrok is already running
if is_running "ngrok"; then
    echo "$(date): Ngrok is already running"
else
    echo "$(date): Starting ngrok tunnel..."
    nohup ngrok http 8000 --log=stdout >> "$WORKSPACE_DIR/ngrok.log" 2>&1 &
    echo "$(date): Ngrok started with PID $!"
    
    # Wait for ngrok to start and get URL
    sleep 5
    
    # Try to get ngrok URL
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data['tunnels']:
        if tunnel['proto'] == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
" 2>/dev/null)
    
    if [ ! -z "$NGROK_URL" ]; then
        echo "$(date): Ngrok tunnel active: $NGROK_URL"
    else
        echo "$(date): Could not get ngrok URL immediately - check ngrok.log"
    fi
fi

echo "$(date): NoctisPro startup script completed"
echo "$(date): Django should be accessible at http://localhost:8000"
echo "$(date): Check ngrok.log for tunnel URL"