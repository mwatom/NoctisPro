#!/bin/bash

# 🚀 NoctisPro Complete Production Deployment Script
# Single script for ngrok deployment and final production setup
# Configures static URL, production environment, and boot startup

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${PURPLE}
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║           🏥 NoctisPro Complete Production Deployment    ║
║                                                          ║
║   ⚡ Single script for complete production setup         ║
║   🌐 Static ngrok URL configuration                     ║
║   🔄 Auto-startup on boot                               ║
║   🛡️  Production security settings                       ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
${NC}"

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Configuration variables
WORKSPACE_DIR="/workspace"
SERVICE_NAME="noctispro-production"
NGROK_CONFIG_DIR="$HOME/.config/ngrok"
NGROK_CONFIG_FILE="$NGROK_CONFIG_DIR/ngrok.yml"

# Check if running as root for system configuration
check_root_permissions() {
    if [[ $EUID -eq 0 ]]; then
        warning "Running as root. This is required for system service installation."
        SUDO_CMD=""
    else
        info "Running as regular user. Will use sudo for system operations."
        SUDO_CMD="sudo"
        
        # Test sudo access
        if ! sudo -n true 2>/dev/null; then
            warning "This script requires sudo access for system configuration."
            echo "Please enter your password when prompted."
            sudo -v || error "Failed to obtain sudo access"
        fi
    fi
}

# Install system dependencies
install_dependencies() {
    log "📦 Installing system dependencies..."
    
    $SUDO_CMD apt-get update -qq
    $SUDO_CMD apt-get install -y \
        curl \
        wget \
        git \
        python3 \
        python3-pip \
        python3-venv \
        postgresql \
        postgresql-contrib \
        redis-server \
        nginx \
        supervisor \
        jq \
        sqlite3 \
        unzip \
        software-properties-common
    
    success "System dependencies installed"
}

# Install and configure ngrok
install_ngrok() {
    log "🌐 Installing and configuring ngrok..."
    
    # Check if ngrok is already installed
    if command -v ngrok &> /dev/null; then
        info "Ngrok already installed ($(ngrok version))"
    else
        info "Installing ngrok..."
        curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | $SUDO_CMD tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | $SUDO_CMD tee /etc/apt/sources.list.d/ngrok.list
        $SUDO_CMD apt-get update -qq
        $SUDO_CMD apt-get install -y ngrok
        success "Ngrok installed successfully"
    fi
}

# Configure ngrok authentication
configure_ngrok_auth() {
    log "🔑 Configuring ngrok authentication..."
    
    # Check if auth token is already configured
    if ngrok config check >/dev/null 2>&1; then
        info "Ngrok auth token already configured"
        return
    fi
    
    echo
    echo -e "${CYAN}📋 To get your ngrok auth token:${NC}"
    echo "   1. Visit: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "   2. Sign up or log in to your ngrok account"
    echo "   3. Copy your auth token from the dashboard"
    echo
    
    # Prompt for auth token
    while true; do
        read -p "Enter your ngrok auth token (or 'skip' to configure later): " -r AUTH_TOKEN
        
        if [[ $AUTH_TOKEN = "skip" ]]; then
            warning "Skipping auth token configuration. You'll need to configure it manually later."
            break
        fi
        
        if [[ -z $AUTH_TOKEN ]]; then
            warning "Please enter a valid auth token or 'skip'."
            continue
        fi
        
        # Try to configure the auth token
        if ngrok config add-authtoken "$AUTH_TOKEN" >/dev/null 2>&1; then
            success "Ngrok auth token configured successfully!"
            break
        else
            error "Failed to configure auth token. Please check the token and try again."
        fi
    done
}

# Set up ngrok configuration file
setup_ngrok_config() {
    log "⚙️ Setting up ngrok configuration..."
    
    # Create ngrok config directory
    mkdir -p "$NGROK_CONFIG_DIR"
    
    # Create ngrok configuration file
    cat > "$NGROK_CONFIG_FILE" << 'EOF'
version: "2"
console_ui: true
web_addr: localhost:4040
log_level: info
log_format: logfmt
log: /tmp/ngrok.log

tunnels:
  noctispro-static:
    proto: http
    addr: 8000
    subdomain: noctispro
    inspect: true
    bind_tls: true
  
  noctispro-domain:
    proto: http
    addr: 8000
    hostname: noctis.yourdomain.com
    inspect: true
    bind_tls: true
  
  noctispro-random:
    proto: http
    addr: 8000
    inspect: true
    bind_tls: true
EOF
    
    success "Ngrok configuration file created"
}

# Configure production environment
setup_production_environment() {
    log "🔧 Setting up production environment..."
    
    # Update .env.production with optimized settings
    cat > "$WORKSPACE_DIR/.env.production" << 'EOF'
# NoctisPro Production Environment Configuration
# Optimized for production deployment with ngrok

# Django Settings
DEBUG=False
SECRET_KEY=noctis-production-secret-key-change-this-in-production-2024
DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Security Settings for Production with Ngrok
ALLOWED_HOSTS=*,colt-charmed-lark.ngrok-free.app,localhost,127.0.0.1
SECURE_SSL_REDIRECT=False
SESSION_COOKIE_SECURE=False
CSRF_COOKIE_SECURE=False
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https

# Database Configuration (SQLite for simplicity)
USE_SQLITE=True
DATABASE_URL=sqlite:///workspace/db.sqlite3

# Static and Media Files
STATIC_URL=/static/
STATIC_ROOT=/workspace/staticfiles
MEDIA_URL=/media/
MEDIA_ROOT=/workspace/media
SERVE_MEDIA_FILES=True

# Logging Configuration
LOGGING_LEVEL=INFO
LOG_FILE=/workspace/noctis_pro.log
DJANGO_LOG_LEVEL=INFO

# Build Configuration
BUILD_TARGET=production
ENVIRONMENT=production

# Performance Settings
CONN_MAX_AGE=300
DATA_UPLOAD_MAX_MEMORY_SIZE=52428800
FILE_UPLOAD_MAX_MEMORY_SIZE=2621440

# Session Configuration
SESSION_TIMEOUT_MINUTES=60
SESSION_COOKIE_AGE=3600

# Health Check Configuration
HEALTH_CHECK_ENABLED=True
HEALTH_CHECK_URL=/health/
HEALTH_CHECK_INTERVAL=30

# Time Zone
TIME_ZONE=UTC
USE_TZ=True

# DICOM Configuration
DICOM_STORAGE_PATH=/workspace/media/dicom
DICOM_MAX_FILE_SIZE=104857600
DICOM_ALLOWED_EXTENSIONS=.dcm,.dicom
EOF

    # Update .env.ngrok with current static URL
    cat > "$WORKSPACE_DIR/.env.ngrok" << 'EOF'
# NoctisPro Ngrok Environment Configuration
# Production-ready configuration for static URL

# Static Domain Configuration - PRODUCTION READY
NGROK_USE_STATIC=true
NGROK_STATIC_URL=colt-charmed-lark.ngrok-free.app

# Ngrok Configuration
NGROK_REGION=us
NGROK_TUNNEL_NAME=noctispro-production
NGROK_WEB_ADDR=localhost:4040
NGROK_LOG_LEVEL=info

# Production Server Configuration
DJANGO_PORT=8000
DJANGO_HOST=0.0.0.0

# Django Production Settings
ALLOWED_HOSTS="*,colt-charmed-lark.ngrok-free.app,localhost,127.0.0.1"
DEBUG=False
USE_TZ=True
SECURE_SSL_REDIRECT=False
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https

# Performance Settings
SERVE_MEDIA_FILES=True
STATIC_ROOT=/workspace/staticfiles
MEDIA_ROOT=/workspace/media

# Logging Configuration
DJANGO_LOG_LEVEL=INFO
LOGGING_ENABLED=True

# Health Check Settings
HEALTH_CHECK_ENABLED=True
EOF

    success "Production environment configured"
}

# Set up Python virtual environment and dependencies
setup_python_environment() {
    log "🐍 Setting up Python environment..."
    
    cd "$WORKSPACE_DIR"
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        info "Virtual environment created"
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install requirements if file exists
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
        info "Requirements installed from requirements.txt"
    else
        # Install essential Django packages
        pip install django pillow pydicom
        info "Essential packages installed"
    fi
    
    success "Python environment ready"
}

# Set up Django application
setup_django() {
    log "🎯 Setting up Django application..."
    
    cd "$WORKSPACE_DIR"
    source venv/bin/activate
    
    # Load environment variables
    source .env.production
    source .env.ngrok
    
    # Run Django management commands
    python manage.py collectstatic --noinput --clear || warning "Static files collection failed"
    python manage.py migrate --noinput || warning "Database migration failed"
    
    # Create superuser if it doesn't exist
    echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@noctispro.local', 'admin123')" | python manage.py shell || warning "Superuser creation failed"
    
    success "Django application configured"
}

# Create systemd service
create_systemd_service() {
    log "🔄 Creating systemd service for boot startup..."
    
    # Create the systemd service file
    $SUDO_CMD tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null << EOF
[Unit]
Description=NoctisPro Production System with Ngrok
Documentation=file://$WORKSPACE_DIR/README.md
After=network-online.target
Wants=network-online.target
Requires=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=3

[Service]
Type=simple
User=$(whoami)
Group=$(whoami)
WorkingDirectory=$WORKSPACE_DIR
Environment=PATH=$WORKSPACE_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=HOME=$HOME
Environment=PYTHONPATH=$WORKSPACE_DIR
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
EnvironmentFile=-$WORKSPACE_DIR/.env.production
EnvironmentFile=-$WORKSPACE_DIR/.env.ngrok

# Pre-start checks
ExecStartPre=/bin/bash -c 'echo "🔍 Starting NoctisPro production system..."'
ExecStartPre=/bin/bash -c 'cd $WORKSPACE_DIR && source venv/bin/activate && python manage.py check --deploy --fail-level=ERROR'

# Start the application
ExecStart=/bin/bash -c 'cd $WORKSPACE_DIR && source venv/bin/activate && source .env.production && source .env.ngrok && python manage.py runserver 0.0.0.0:8000'

# Graceful shutdown
ExecStop=/bin/bash -c 'pkill -f "manage.py runserver" || true'
ExecStopPost=/bin/bash -c 'pkill -f "ngrok" || true'

# Process management
TimeoutStartSec=120
TimeoutStopSec=30
Restart=always
RestartSec=15
KillMode=mixed

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

# Security
NoNewPrivileges=true
PrivateTmp=true

# Resource limits
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    # Create ngrok service
    $SUDO_CMD tee /etc/systemd/system/${SERVICE_NAME}-ngrok.service > /dev/null << EOF
[Unit]
Description=NoctisPro Ngrok Tunnel
After=network-online.target ${SERVICE_NAME}.service
Wants=network-online.target
BindsTo=${SERVICE_NAME}.service

[Service]
Type=simple
User=$(whoami)
Group=$(whoami)
WorkingDirectory=$WORKSPACE_DIR
Environment=HOME=$HOME
EnvironmentFile=-$WORKSPACE_DIR/.env.ngrok

# Wait for Django to start
ExecStartPre=/bin/bash -c 'sleep 10'

# Start ngrok tunnel
ExecStart=/bin/bash -c 'source .env.ngrok 2>/dev/null || true; if [ "\$NGROK_USE_STATIC" = "true" ] && [ ! -z "\$NGROK_STATIC_URL" ]; then ngrok http 8000 --hostname=\$NGROK_STATIC_URL --log=stdout; else ngrok http 8000 --log=stdout; fi'

# Cleanup
ExecStop=/bin/bash -c 'pkill -f "ngrok" || true'

# Process management
TimeoutStartSec=60
TimeoutStopSec=15
Restart=always
RestartSec=10

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}-ngrok

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable services
    $SUDO_CMD systemctl daemon-reload
    $SUDO_CMD systemctl enable ${SERVICE_NAME}.service
    $SUDO_CMD systemctl enable ${SERVICE_NAME}-ngrok.service
    
    success "Systemd services created and enabled"
}

# Create management scripts
create_management_scripts() {
    log "📝 Creating management scripts..."
    
    # Start script
    cat > "$WORKSPACE_DIR/start_production_complete.sh" << 'EOF'
#!/bin/bash
echo "🚀 Starting NoctisPro Production System..."
sudo systemctl start noctispro-production.service
sudo systemctl start noctispro-production-ngrok.service
echo "✅ Services started"
echo "📊 Status: sudo systemctl status noctispro-production.service"
echo "🌐 Ngrok: sudo systemctl status noctispro-production-ngrok.service"
EOF

    # Stop script
    cat > "$WORKSPACE_DIR/stop_production_complete.sh" << 'EOF'
#!/bin/bash
echo "🛑 Stopping NoctisPro Production System..."
sudo systemctl stop noctispro-production-ngrok.service
sudo systemctl stop noctispro-production.service
echo "✅ Services stopped"
EOF

    # Status script
    cat > "$WORKSPACE_DIR/status_production.sh" << 'EOF'
#!/bin/bash
echo "📊 NoctisPro Production Status"
echo "============================="
echo
echo "🎯 Django Service:"
sudo systemctl status noctispro-production.service --no-pager -l
echo
echo "🌐 Ngrok Service:"
sudo systemctl status noctispro-production-ngrok.service --no-pager -l
echo
echo "🔗 Current ngrok URL:"
curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "Ngrok not running or no tunnels active"
echo
echo "📱 Quick Commands:"
echo "  Start:   ./start_production_complete.sh"
echo "  Stop:    ./stop_production_complete.sh"
echo "  Restart: sudo systemctl restart noctispro-production.service"
echo "  Logs:    sudo journalctl -u noctispro-production.service -f"
EOF

    # Make scripts executable
    chmod +x "$WORKSPACE_DIR/start_production_complete.sh"
    chmod +x "$WORKSPACE_DIR/stop_production_complete.sh"
    chmod +x "$WORKSPACE_DIR/status_production.sh"
    
    success "Management scripts created"
}

# Create health check script
create_health_check() {
    log "🏥 Creating health check script..."
    
    cat > "$WORKSPACE_DIR/health_check_production.py" << 'EOF'
#!/usr/bin/env python3
"""
NoctisPro Production Health Check
Monitors system health and ngrok tunnel status
"""

import os
import sys
import time
import json
import urllib.request
import subprocess
from datetime import datetime

def log(message, level="INFO"):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] [{level}] {message}")

def check_django_server():
    """Check if Django server is responding"""
    try:
        with urllib.request.urlopen("http://localhost:8000/health/", timeout=10) as response:
            if response.status == 200:
                log("✅ Django server is healthy")
                return True
            else:
                log(f"❌ Django server returned status {response.status}", "ERROR")
                return False
    except Exception as e:
        log(f"❌ Django server health check failed: {e}", "ERROR")
        return False

def check_ngrok_tunnel():
    """Check ngrok tunnel status"""
    try:
        with urllib.request.urlopen("http://localhost:4040/api/tunnels", timeout=10) as response:
            data = json.loads(response.read().decode())
            tunnels = data.get('tunnels', [])
            
            if tunnels:
                tunnel = tunnels[0]
                public_url = tunnel.get('public_url', 'Unknown')
                log(f"✅ Ngrok tunnel active: {public_url}")
                return True, public_url
            else:
                log("❌ No active ngrok tunnels found", "ERROR")
                return False, None
    except Exception as e:
        log(f"❌ Ngrok tunnel check failed: {e}", "ERROR")
        return False, None

def check_system_services():
    """Check systemd service status"""
    services = ["noctispro-production.service", "noctispro-production-ngrok.service"]
    all_running = True
    
    for service in services:
        try:
            result = subprocess.run(
                ["systemctl", "is-active", service],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0 and result.stdout.strip() == "active":
                log(f"✅ Service {service} is active")
            else:
                log(f"❌ Service {service} is not active", "ERROR")
                all_running = False
        except Exception as e:
            log(f"❌ Failed to check service {service}: {e}", "ERROR")
            all_running = False
    
    return all_running

def main():
    log("🔍 Starting NoctisPro production health check...")
    
    all_healthy = True
    
    # Check Django server
    if not check_django_server():
        all_healthy = False
    
    # Check ngrok tunnel
    tunnel_ok, public_url = check_ngrok_tunnel()
    if not tunnel_ok:
        all_healthy = False
    
    # Check system services
    if not check_system_services():
        all_healthy = False
    
    if all_healthy:
        log("🎉 All systems healthy!")
        if public_url:
            log(f"🌐 Access your application at: {public_url}")
        sys.exit(0)
    else:
        log("❌ Some systems are unhealthy", "ERROR")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

    chmod +x "$WORKSPACE_DIR/health_check_production.py"
    success "Health check script created"
}

# Test the deployment
test_deployment() {
    log "🧪 Testing deployment..."
    
    cd "$WORKSPACE_DIR"
    
    # Test Django
    source venv/bin/activate
    source .env.production
    
    python manage.py check --deploy --fail-level=WARNING || warning "Django deployment check has warnings"
    
    # Test ngrok config
    if ngrok config check >/dev/null 2>&1; then
        success "Ngrok configuration is valid"
    else
        warning "Ngrok configuration needs attention"
    fi
    
    success "Deployment tests completed"
}

# Main deployment function
main() {
    log "🚀 Starting complete NoctisPro production deployment..."
    
    # Pre-flight checks
    check_root_permissions
    
    # Installation and configuration
    install_dependencies
    install_ngrok
    configure_ngrok_auth
    setup_ngrok_config
    setup_production_environment
    setup_python_environment
    setup_django
    
    # System integration
    create_systemd_service
    create_management_scripts
    create_health_check
    
    # Testing
    test_deployment
    
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                          ║${NC}"
    echo -e "${GREEN}║          🎉 DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉        ║${NC}"
    echo -e "${GREEN}║                                                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
    success "NoctisPro production deployment completed!"
    echo
    info "📋 Next Steps:"
    echo "  1. Start services:  ./start_production_complete.sh"
    echo "  2. Check status:    ./status_production.sh"
    echo "  3. View logs:       sudo journalctl -u noctispro-production.service -f"
    echo "  4. Health check:    ./health_check_production.py"
    echo
    info "🌐 Your static URL: https://colt-charmed-lark.ngrok-free.app"
    echo
    info "📱 Quick Management:"
    echo "  • Start:   ./start_production_complete.sh"
    echo "  • Stop:    ./stop_production_complete.sh"
    echo "  • Status:  ./status_production.sh"
    echo "  • Health:  ./health_check_production.py"
    echo
    warning "⚠️  Important: Configure your ngrok auth token when prompted!"
    echo
}

# Run main function
main "$@"