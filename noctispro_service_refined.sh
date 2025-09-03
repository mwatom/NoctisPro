#!/bin/bash

# 🚀 NoctisPro Refined Service Manager
# Runs the new refined system with optimized settings

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
WORKSPACE_DIR="/workspace"
STATIC_URL="colt-charmed-lark.ngrok-free.app"
DJANGO_PORT="8000"
SERVICE_NAME="noctispro"
PID_FILE="$WORKSPACE_DIR/noctispro_service.pid"
LOG_FILE="$WORKSPACE_DIR/noctispro_service.log"

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}🚨${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

# Function to start the refined service
start_service() {
    print_info "Starting NoctisPro Refined Service..."
    
    # Kill any existing processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    pkill -f "gunicorn.*noctis" 2>/dev/null || true
    tmux kill-session -t $SERVICE_NAME 2>/dev/null || true
    sleep 2
    
    # Check if ngrok auth token is configured
    if ! $WORKSPACE_DIR/ngrok config check > /dev/null 2>&1; then
        print_error "Ngrok auth token is not configured!"
        echo "Please configure ngrok first:"
        echo "1. Get token from: https://dashboard.ngrok.com/get-started/your-authtoken"
        echo "2. Run: $WORKSPACE_DIR/ngrok config add-authtoken YOUR_TOKEN_HERE"
        exit 1
    fi
    
    # Ensure we're using the refined system
    cd $WORKSPACE_DIR
    
    # Activate virtual environment
    if [ ! -d "venv" ]; then
        print_info "Creating virtual environment..."
        python3 -m venv venv
    fi
    
    source venv/bin/activate
    
    # Install/update dependencies for refined system
    print_info "Installing refined system dependencies..."
    pip install -r requirements.txt > /dev/null 2>&1
    
    # Run migrations for refined system
    print_info "Running database migrations for refined system..."
    python manage.py migrate --run-syncdb > /dev/null 2>&1
    
    # Collect static files for refined system
    print_info "Collecting static files for refined system..."
    python manage.py collectstatic --noinput > /dev/null 2>&1
    
    # Create new tmux session for refined system
    tmux new-session -d -s $SERVICE_NAME -c $WORKSPACE_DIR
    
    # Start Django with refined settings in first window
    tmux send-keys -t $SERVICE_NAME "source venv/bin/activate" Enter
    tmux send-keys -t $SERVICE_NAME "export DJANGO_SETTINGS_MODULE=noctis_pro.settings" Enter
    tmux send-keys -t $SERVICE_NAME "python manage.py runserver 0.0.0.0:$DJANGO_PORT" Enter
    
    # Create second window for ngrok
    tmux new-window -t $SERVICE_NAME -n ngrok
    tmux send-keys -t $SERVICE_NAME:ngrok "sleep 10" Enter
    tmux send-keys -t $SERVICE_NAME:ngrok "$WORKSPACE_DIR/ngrok http --url=https://$STATIC_URL $DJANGO_PORT" Enter
    
    # Save service info
    echo "SERVICE_RUNNING=true" > $PID_FILE
    echo "SYSTEM_VERSION=refined" >> $PID_FILE
    echo "STARTED_AT=$(date)" >> $PID_FILE
    echo "TMUX_SESSION=$SERVICE_NAME" >> $PID_FILE
    echo "WORKSPACE_DIR=$WORKSPACE_DIR" >> $PID_FILE
    
    print_success "NoctisPro Refined Service started in tmux session '$SERVICE_NAME'"
    echo ""
    echo -e "${CYAN}🌐 Your refined system is now available at: https://$STATIC_URL/${NC}"
    echo -e "${GREEN}✨ Running optimized, production-ready configuration${NC}"
    echo ""
    echo -e "${YELLOW}📋 To check status: tmux attach -t $SERVICE_NAME${NC}"
    echo -e "${YELLOW}🛑 To stop service: $0 stop${NC}"
}

# Function to stop the service
stop_service() {
    print_info "Stopping NoctisPro service..."
    
    # Kill tmux session
    tmux kill-session -t $SERVICE_NAME 2>/dev/null || true
    
    # Kill any remaining processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    pkill -f "gunicorn.*noctis" 2>/dev/null || true
    
    # Remove PID file
    rm -f $PID_FILE
    
    print_success "NoctisPro service stopped"
}

# Function to check service status
status_service() {
    if [ -f "$PID_FILE" ] && tmux has-session -t $SERVICE_NAME 2>/dev/null; then
        print_success "NoctisPro Refined Service is running"
        echo ""
        echo -e "${CYAN}🌐 Available at: https://$STATIC_URL/${NC}"
        echo ""
        echo "Service details:"
        cat $PID_FILE
        echo ""
        echo "Tmux sessions:"
        tmux list-sessions | grep $SERVICE_NAME || true
        echo ""
        echo -e "${GREEN}✨ Running refined system with optimized configuration${NC}"
    else
        print_error "NoctisPro service is not running"
        return 1
    fi
}

# Function to restart the service
restart_service() {
    print_info "Restarting NoctisPro Refined Service..."
    stop_service
    sleep 3
    start_service
}

# Main command handling
case "${1:-start}" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    status)
        status_service
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start NoctisPro Refined Service"
        echo "  stop    - Stop NoctisPro service"
        echo "  restart - Restart NoctisPro service"
        echo "  status  - Check service status"
        exit 1
        ;;
esac
