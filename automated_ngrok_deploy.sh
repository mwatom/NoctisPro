#!/bin/bash

# 🚀 Automated NoctisPro Deployment with Ngrok Authentication
# This script automatically sets up the environment and deploys with ngrok

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
PROJECT_DIR="/workspace/noctis_pro_deployment"
NGROK_BINARY="/workspace/ngrok"
VENV_PATH="$PROJECT_DIR/venv"
SERVICE_NAME="noctispro-django"
NGROK_SERVICE_NAME="noctispro-ngrok"
STATIC_HOSTNAME="mallard-shining-curiously.ngrok-free.app"
PORT=8000

echo -e "${CYAN}🚀 NoctisPro Automated Deployment with Ngrok${NC}"
echo -e "${CYAN}==============================================${NC}"
echo ""

# Function to log with timestamp
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Function to check if service exists
service_exists() {
    systemctl list-unit-files | grep -q "^$1.service" 2>/dev/null
}

# Function to kill processes on port
kill_port_processes() {
    local port=$1
    log "Checking for processes on port $port..."
    
    local pids=$(lsof -ti:$port 2>/dev/null || true)
    if [ -n "$pids" ]; then
        log "Killing processes on port $port: $pids"
        echo $pids | xargs -r kill -9 2>/dev/null || true
        sleep 2
    fi
}

# Function to setup environment
setup_environment() {
    log "Setting up environment variables..."
    
    # Create environment file
    cat > /workspace/.env << EOF
# Django Environment
DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1,$STATIC_HOSTNAME

# Ngrok Configuration
NGROK_AUTHTOKEN=\${NGROK_AUTHTOKEN:-}
NGROK_HOSTNAME=$STATIC_HOSTNAME
NGROK_PORT=$PORT

# Database
DATABASE_URL=sqlite:///workspace/noctis_pro_deployment/db.sqlite3

# Static files
STATIC_URL=/static/
STATIC_ROOT=/workspace/noctis_pro_deployment/staticfiles/

# Security
SECRET_KEY=\${SECRET_KEY:-django-insecure-change-this-in-production}
EOF

    # Source environment
    export $(cat /workspace/.env | grep -v '^#' | xargs) 2>/dev/null || true
    
    log "Environment variables configured"
}

# Function to check and configure ngrok authentication
setup_ngrok_auth() {
    log "Setting up ngrok authentication..."
    
    # Check if ngrok is authenticated
    if $NGROK_BINARY config check > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Ngrok is already authenticated${NC}"
        return 0
    fi
    
    # Check for auth token in environment
    if [ -n "${NGROK_AUTHTOKEN:-}" ]; then
        log "Using auth token from environment variable"
        $NGROK_BINARY config add-authtoken "$NGROK_AUTHTOKEN"
        echo -e "${GREEN}✅ Ngrok authentication configured from environment${NC}"
        return 0
    fi
    
    # Check for auth token in .env file
    if [ -f "/workspace/.env" ]; then
        local env_token=$(grep "^NGROK_AUTHTOKEN=" /workspace/.env | cut -d'=' -f2 | tr -d '"' || true)
        if [ -n "$env_token" ] && [ "$env_token" != "\${NGROK_AUTHTOKEN:-}" ]; then
            log "Using auth token from .env file"
            $NGROK_BINARY config add-authtoken "$env_token"
            echo -e "${GREEN}✅ Ngrok authentication configured from .env file${NC}"
            return 0
        fi
    fi
    
    # Create ngrok config directory and file
    local ngrok_config_dir="$HOME/.config/ngrok"
    local ngrok_config_file="$ngrok_config_dir/ngrok.yml"
    
    mkdir -p "$ngrok_config_dir"
    
    # Check if config file exists and has authtoken
    if [ -f "$ngrok_config_file" ]; then
        if grep -q "authtoken:" "$ngrok_config_file"; then
            log "Found existing ngrok configuration"
            if $NGROK_BINARY config check > /dev/null 2>&1; then
                echo -e "${GREEN}✅ Existing ngrok authentication is valid${NC}"
                return 0
            else
                log "Existing ngrok configuration is invalid, will prompt for new token"
            fi
        fi
    fi
    
    # Prompt for auth token
    echo -e "${YELLOW}⚠️  Ngrok authentication required${NC}"
    echo ""
    echo "To get your free ngrok auth token:"
    echo -e "1. Visit: ${CYAN}https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
    echo -e "2. Copy your auth token"
    echo ""
    
    read -p "Enter your ngrok auth token (or press Enter to skip): " user_token
    
    if [ -n "$user_token" ]; then
        $NGROK_BINARY config add-authtoken "$user_token"
        echo -e "${GREEN}✅ Ngrok authentication configured${NC}"
        
        # Save to .env for future use
        sed -i "s/NGROK_AUTHTOKEN=.*/NGROK_AUTHTOKEN=$user_token/" /workspace/.env 2>/dev/null || true
        
        return 0
    else
        echo -e "${RED}❌ Ngrok authentication skipped - tunnel will not work${NC}"
        return 1
    fi
}

# Function to setup Django
setup_django() {
    log "Setting up Django application..."
    
    cd "$PROJECT_DIR"
    
    # Activate virtual environment
    if [ -d "$VENV_PATH" ]; then
        source "$VENV_PATH/bin/activate"
        log "Virtual environment activated"
    else
        echo -e "${YELLOW}⚠️  Virtual environment not found, creating new one...${NC}"
        python3 -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
    fi
    
    # Run Django setup
    log "Running Django migrations and setup..."
    python manage.py migrate --noinput
    python manage.py collectstatic --noinput
    
    # Create superuser if it doesn't exist
    python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'admin123')
    print('Superuser created: admin/admin123')
else:
    print('Superuser already exists')
" 2>/dev/null || log "Superuser setup completed"
    
    log "Django setup completed"
}

# Function to create systemd service for Django
create_django_service() {
    log "Creating Django systemd service..."
    
    local service_file="/etc/systemd/system/$SERVICE_NAME.service"
    
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=NoctisPro Django Application
After=network.target

[Service]
Type=simple
User=noctispro
Group=noctispro
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$VENV_PATH/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
EnvironmentFile=/workspace/.env
ExecStart=$VENV_PATH/bin/daphne -b 0.0.0.0 -p $PORT noctis_pro.asgi:application
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    
    log "Django service created and enabled"
}

# Function to create systemd service for Ngrok
create_ngrok_service() {
    log "Creating Ngrok systemd service..."
    
    local service_file="/etc/systemd/system/$NGROK_SERVICE_NAME.service"
    
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=NoctisPro Ngrok Tunnel
After=network.target $SERVICE_NAME.service
Requires=$SERVICE_NAME.service

[Service]
Type=simple
User=noctispro
Group=noctispro
WorkingDirectory=/workspace
EnvironmentFile=/workspace/.env
ExecStart=$NGROK_BINARY http $PORT --hostname=$STATIC_HOSTNAME --log=stdout
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable "$NGROK_SERVICE_NAME"
    
    log "Ngrok service created and enabled"
}

# Function to start services
start_services() {
    log "Starting services..."
    
    # Kill any existing processes on port
    kill_port_processes $PORT
    
    # Start Django service
    sudo systemctl restart "$SERVICE_NAME"
    sleep 3
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}✅ Django service started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start Django service${NC}"
        sudo journalctl -u "$SERVICE_NAME" --no-pager -n 20
        return 1
    fi
    
    # Start Ngrok service (only if authenticated)
    if $NGROK_BINARY config check > /dev/null 2>&1; then
        sudo systemctl restart "$NGROK_SERVICE_NAME"
        sleep 5
        
        if systemctl is-active --quiet "$NGROK_SERVICE_NAME"; then
            echo -e "${GREEN}✅ Ngrok service started successfully${NC}"
        else
            echo -e "${YELLOW}⚠️  Ngrok service failed to start${NC}"
            sudo journalctl -u "$NGROK_SERVICE_NAME" --no-pager -n 10
        fi
    else
        echo -e "${YELLOW}⚠️  Skipping Ngrok service - not authenticated${NC}"
    fi
}

# Function to show status
show_status() {
    echo ""
    echo -e "${PURPLE}📊 Deployment Status${NC}"
    echo "===================="
    
    # Django service status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}✅ Django Service: Running${NC}"
        echo -e "   Local URL: ${CYAN}http://localhost:$PORT${NC}"
    else
        echo -e "${RED}❌ Django Service: Not running${NC}"
    fi
    
    # Ngrok service status
    if systemctl is-active --quiet "$NGROK_SERVICE_NAME"; then
        echo -e "${GREEN}✅ Ngrok Service: Running${NC}"
        echo -e "   Public URL: ${CYAN}https://$STATIC_HOSTNAME${NC}"
        echo -e "   Admin URL: ${CYAN}https://$STATIC_HOSTNAME/admin/${NC}"
        echo -e "   Username: admin"
        echo -e "   Password: admin123"
    else
        echo -e "${YELLOW}⚠️  Ngrok Service: Not running${NC}"
    fi
    
    # Test connectivity
    echo ""
    log "Testing local connectivity..."
    if curl -s http://localhost:$PORT > /dev/null; then
        echo -e "${GREEN}✅ Local server is responding${NC}"
    else
        echo -e "${RED}❌ Local server is not responding${NC}"
    fi
    
    if systemctl is-active --quiet "$NGROK_SERVICE_NAME"; then
        log "Testing public URL..."
        if curl -s -H "ngrok-skip-browser-warning: 1" "https://$STATIC_HOSTNAME" > /dev/null; then
            echo -e "${GREEN}✅ Public URL is accessible${NC}"
        else
            echo -e "${YELLOW}⚠️  Public URL test inconclusive${NC}"
        fi
    fi
}

# Function to show logs
show_logs() {
    echo ""
    echo -e "${BLUE}📋 Service Logs${NC}"
    echo "==============="
    
    echo -e "${CYAN}Django Service Logs (last 10 lines):${NC}"
    sudo journalctl -u "$SERVICE_NAME" --no-pager -n 10 || true
    
    echo ""
    echo -e "${CYAN}Ngrok Service Logs (last 10 lines):${NC}"
    sudo journalctl -u "$NGROK_SERVICE_NAME" --no-pager -n 10 || true
}

# Main deployment function
main() {
    case "${1:-deploy}" in
        "deploy")
            setup_environment
            setup_ngrok_auth || echo -e "${YELLOW}⚠️  Continuing without ngrok authentication${NC}"
            setup_django
            create_django_service
            create_ngrok_service
            start_services
            show_status
            ;;
        "start")
            start_services
            show_status
            ;;
        "stop")
            log "Stopping services..."
            sudo systemctl stop "$NGROK_SERVICE_NAME" 2>/dev/null || true
            sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
            echo -e "${GREEN}✅ Services stopped${NC}"
            ;;
        "restart")
            sudo systemctl stop "$NGROK_SERVICE_NAME" 2>/dev/null || true
            sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
            sleep 2
            start_services
            show_status
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "setup-auth")
            setup_ngrok_auth
            ;;
        *)
            echo -e "${CYAN}Usage: $0 {deploy|start|stop|restart|status|logs|setup-auth}${NC}"
            echo ""
            echo "Commands:"
            echo "  deploy     - Full deployment with environment setup"
            echo "  start      - Start services"
            echo "  stop       - Stop services"
            echo "  restart    - Restart services"
            echo "  status     - Show current status"
            echo "  logs       - Show service logs"
            echo "  setup-auth - Setup ngrok authentication only"
            exit 1
            ;;
    esac
}

# Check if running as root for systemd operations
if [ "$EUID" -ne 0 ] && [[ "${1:-deploy}" =~ ^(deploy|start|stop|restart)$ ]]; then
    echo -e "${YELLOW}⚠️  This script needs sudo access for systemd operations${NC}"
    echo "Re-running with sudo..."
    exec sudo -E "$0" "$@"
fi

# Run main function
main "$@"