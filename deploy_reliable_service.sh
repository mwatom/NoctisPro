#!/bin/bash

# 🚀 NoctisPro DICOM PACS - Reliable Service Deployment
# Ensures the system starts on boot without failure
# Compatible with systemd-based Linux systems

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="noctispro-pacs"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
DJANGO_PORT="8000"
NGROK_STATIC_URL="mallard-shining-curiously.ngrok-free.app"

print_header() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}🚀  NoctisPro PACS - Reliable Service Deployment${NC}"
    echo -e "${CYAN}   Auto-Start on Boot + Health Monitoring${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}🚨${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_dependencies() {
    print_info "Checking system dependencies..."
    
    # Check if systemd is available
    if ! command -v systemctl &> /dev/null; then
        print_error "systemd is required but not found"
        exit 1
    fi
    
    # Check if Python 3 is available
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not found"
        exit 1
    fi
    
    # Check if workspace directory exists
    if [[ ! -d "$WORKSPACE_DIR" ]]; then
        print_error "Workspace directory $WORKSPACE_DIR not found"
        exit 1
    fi
    
    # Check if manage.py exists
    if [[ ! -f "$WORKSPACE_DIR/manage.py" ]]; then
        print_error "Django manage.py not found in $WORKSPACE_DIR"
        exit 1
    fi
    
    print_success "All dependencies check passed"
}

install_python_dependencies() {
    print_info "Installing Python dependencies..."
    cd "$WORKSPACE_DIR"
    
    # Install system dependencies required for Python packages
    print_info "Installing system dependencies..."
    apt-get update -qq || print_warning "Package update failed, continuing with cached packages"
    
    # Install essential packages first
    apt-get install -y python3-pip python3-dev build-essential || print_warning "Some essential packages failed to install"
    
    # Install additional packages if available
    apt-get install -y libcups2-dev libssl-dev libffi-dev libjpeg-dev libpng-dev pkg-config python3-venv git 2>/dev/null || print_warning "Some optional packages failed to install"
    
    # Install requirements
    if [[ -f "requirements.txt" ]]; then
        print_info "Attempting to install full requirements..."
        if pip3 install -r requirements.txt --quiet --break-system-packages; then
            print_success "Full Python dependencies installed"
        elif [[ -f "requirements.minimal.txt" ]]; then
            print_warning "Full requirements failed, trying minimal requirements..."
            pip3 install -r requirements.minimal.txt --quiet --break-system-packages
            print_success "Minimal Python dependencies installed"
        else
            print_error "Failed to install Python dependencies"
            exit 1
        fi
    elif [[ -f "requirements.minimal.txt" ]]; then
        print_info "Installing minimal requirements..."
        pip3 install -r requirements.minimal.txt --quiet --break-system-packages
        print_success "Minimal Python dependencies installed"
    else
        print_warning "No requirements files found, skipping Python dependencies"
    fi
}

setup_django() {
    print_info "Setting up Django application..."
    cd "$WORKSPACE_DIR"
    
    # Collect static files
    print_info "Collecting static files..."
    python3 manage.py collectstatic --noinput --clear || {
        print_warning "Static files collection failed, continuing..."
    }
    
    # Run migrations
    print_info "Running database migrations..."
    python3 manage.py migrate --noinput || {
        print_warning "Database migrations failed, continuing..."
    }
    
    print_success "Django setup completed"
}

create_systemd_service() {
    print_info "Creating systemd service..."
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=NoctisPro DICOM PACS System
Documentation=https://github.com/noctispro/pacs
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=exec
User=root
Group=root
WorkingDirectory=$WORKSPACE_DIR
Environment=PYTHONPATH=$WORKSPACE_DIR
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
Environment=PYTHONUNBUFFERED=1

# Health check before starting
ExecStartPre=/bin/bash -c 'cd $WORKSPACE_DIR && python3 -c "import django; print(\\"Django OK\\")" || exit 1'

# Main service command with proper error handling
ExecStart=/bin/bash -c 'cd $WORKSPACE_DIR && exec python3 -m gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:$DJANGO_PORT --workers 3 --timeout 120 --max-requests 1000 --max-requests-jitter 50 --access-logfile $WORKSPACE_DIR/gunicorn_access.log --error-logfile $WORKSPACE_DIR/gunicorn_error.log'

# Restart policy for reliability
Restart=always
RestartSec=10
StartLimitBurst=5

# Resource limits
MemoryLimit=2G
CPUQuota=200%

# Security settings (relaxed for medical systems)
NoNewPrivileges=false
ProtectSystem=false
ReadWritePaths=$WORKSPACE_DIR /tmp /var/tmp /var/log

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=noctispro-pacs

# Graceful shutdown
TimeoutStartSec=60
TimeoutStopSec=30
KillMode=mixed
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

    print_success "Systemd service created at $SERVICE_FILE"
}

setup_ngrok_service() {
    print_info "Setting up ngrok tunnel service..."
    
    # Create ngrok service
    cat > "/etc/systemd/system/noctispro-ngrok.service" << EOF
[Unit]
Description=NoctisPro Ngrok Tunnel
After=noctispro-pacs.service
Requires=noctispro-pacs.service

[Service]
Type=exec
User=root
WorkingDirectory=$WORKSPACE_DIR
ExecStart=/bin/bash -c 'sleep 15 && ./ngrok http $DJANGO_PORT --domain=$NGROK_STATIC_URL --log=stdout'
Restart=always
RestartSec=15
StartLimitBurst=3

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=noctispro-ngrok

[Install]
WantedBy=multi-user.target
EOF

    print_success "Ngrok service created"
}

create_health_monitor() {
    print_info "Creating health monitoring script..."
    
    cat > "$WORKSPACE_DIR/health_monitor.sh" << 'EOF'
#!/bin/bash
# Health monitoring for NoctisPro PACS

SERVICE_NAME="noctispro-pacs"
DJANGO_URL="http://localhost:8000"
LOG_FILE="/var/log/noctispro-health.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_service() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        return 0
    else
        return 1
    fi
}

check_http() {
    if curl -s --connect-timeout 10 "$DJANGO_URL" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

main() {
    if ! check_service; then
        log_message "ERROR: Service $SERVICE_NAME is not running, attempting restart"
        systemctl restart "$SERVICE_NAME"
        sleep 10
    fi
    
    if ! check_http; then
        log_message "WARNING: HTTP check failed for $DJANGO_URL"
        systemctl restart "$SERVICE_NAME"
    else
        log_message "INFO: Health check passed"
    fi
}

main "$@"
EOF

    chmod +x "$WORKSPACE_DIR/health_monitor.sh"
    
    # Create cron job for health monitoring
    cat > "/etc/cron.d/noctispro-health" << EOF
# NoctisPro PACS Health Monitor - runs every 5 minutes
*/5 * * * * root $WORKSPACE_DIR/health_monitor.sh
EOF

    print_success "Health monitoring setup completed"
}

enable_services() {
    print_info "Enabling and starting services..."
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable services for auto-start on boot
    systemctl enable "$SERVICE_NAME"
    systemctl enable noctispro-ngrok
    
    # Stop any existing services
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl stop noctispro-ngrok 2>/dev/null || true
    
    # Start main service
    print_info "Starting NoctisPro PACS service..."
    systemctl start "$SERVICE_NAME"
    
    # Wait for main service to be ready
    sleep 10
    
    # Start ngrok service
    print_info "Starting ngrok tunnel service..."
    systemctl start noctispro-ngrok
    
    print_success "Services enabled and started"
}

verify_deployment() {
    print_info "Verifying deployment..."
    
    # Check service status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "NoctisPro PACS service is running"
    else
        print_error "NoctisPro PACS service failed to start"
        systemctl status "$SERVICE_NAME" --no-pager
        return 1
    fi
    
    # Check if port is listening
    if netstat -tuln | grep -q ":$DJANGO_PORT "; then
        print_success "Service is listening on port $DJANGO_PORT"
    else
        print_warning "Service may not be listening on port $DJANGO_PORT"
    fi
    
    # Check ngrok service
    if systemctl is-active --quiet noctispro-ngrok; then
        print_success "Ngrok tunnel service is running"
    else
        print_warning "Ngrok tunnel service is not running"
    fi
    
    print_success "Deployment verification completed"
}

show_status() {
    echo ""
    echo -e "${CYAN}🔍 Service Status:${NC}"
    echo "----------------------------------------"
    systemctl status "$SERVICE_NAME" --no-pager -l
    echo ""
    echo -e "${CYAN}🌐 Network Status:${NC}"
    echo "----------------------------------------"
    netstat -tuln | grep ":$DJANGO_PORT " || echo "Port $DJANGO_PORT not found"
    echo ""
    echo -e "${CYAN}🔗 Access URLs:${NC}"
    echo "----------------------------------------"
    echo "Local: http://localhost:$DJANGO_PORT"
    echo "Public: https://$NGROK_STATIC_URL"
    echo ""
    echo -e "${CYAN}📋 Service Management Commands:${NC}"
    echo "----------------------------------------"
    echo "Start:   sudo systemctl start $SERVICE_NAME"
    echo "Stop:    sudo systemctl stop $SERVICE_NAME"
    echo "Restart: sudo systemctl restart $SERVICE_NAME"
    echo "Status:  sudo systemctl status $SERVICE_NAME"
    echo "Logs:    sudo journalctl -u $SERVICE_NAME -f"
    echo ""
}

main() {
    print_header
    
    case "${1:-deploy}" in
        "deploy")
            check_root
            check_dependencies
            install_python_dependencies
            setup_django
            create_systemd_service
            setup_ngrok_service
            create_health_monitor
            enable_services
            verify_deployment
            show_status
            print_success "NoctisPro PACS deployed successfully! 🎉"
            ;;
        "start")
            systemctl start "$SERVICE_NAME"
            systemctl start noctispro-ngrok
            print_success "Services started"
            ;;
        "stop")
            systemctl stop noctispro-ngrok
            systemctl stop "$SERVICE_NAME"
            print_success "Services stopped"
            ;;
        "restart")
            systemctl restart "$SERVICE_NAME"
            systemctl restart noctispro-ngrok
            print_success "Services restarted"
            ;;
        "status")
            show_status
            ;;
        "logs")
            journalctl -u "$SERVICE_NAME" -f
            ;;
        *)
            echo "Usage: $0 {deploy|start|stop|restart|status|logs}"
            exit 1
            ;;
    esac
}

main "$@"