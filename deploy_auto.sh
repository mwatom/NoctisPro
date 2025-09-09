#!/bin/bash

# =============================================================================
# NoctisPro PACS - Smart Auto-Deployment Script
# Automatically detects domain, sets defaults, and deploys with HTTPS
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Enhanced logging functions
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $1${NC}"; }
error() { echo -e "${RED}[ERROR] ❌ $1${NC}" >&2; }
warn() { echo -e "${YELLOW}[WARNING] ⚠️  $1${NC}"; }
info() { echo -e "${BLUE}[INFO] ℹ️  $1${NC}"; }
success() { echo -e "${PURPLE}[SUCCESS] 🎉 $1${NC}"; }
step() { echo -e "${CYAN}[STEP] 🚀 $1${NC}"; }

# Configuration with smart defaults
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_TYPE="${DEPLOYMENT_TYPE:-auto}"
FORCE_DOMAIN="${FORCE_DOMAIN:-}"
FORCE_EMAIL="${FORCE_EMAIL:-}"
DEFAULT_EMAIL="admin@noctispro.local"

# Auto-detect domain function
detect_domain() {
    local domain=""
    
    # Try multiple methods to get a usable domain
    info "Auto-detecting domain..."
    
    # Method 1: Check environment variables
    if [ -n "$FORCE_DOMAIN" ]; then
        domain="$FORCE_DOMAIN"
        info "Using forced domain: $domain"
    elif [ -n "$NGROK_STATIC_URL" ]; then
        domain="$NGROK_STATIC_URL"
        info "Using NGROK static URL: $domain"
    elif [ -n "$NGROK_URL" ]; then
        domain=$(echo "$NGROK_URL" | sed 's|https\?://||' | sed 's|/.*||')
        info "Using NGROK URL: $domain"
    fi
    
    # Method 2: Try to get public IP and create a domain
    if [ -z "$domain" ]; then
        info "Attempting to detect public IP..."
        local public_ip=""
        
        # Try multiple IP detection services
        for service in "ifconfig.me" "ipecho.net/plain" "icanhazip.com" "ident.me"; do
            if public_ip=$(timeout 5 curl -s "$service" 2>/dev/null); then
                if [[ $public_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    info "Detected public IP: $public_ip"
                    # Create a nip.io domain for easy access
                    domain="noctispro-$public_ip.nip.io"
                    info "Generated domain: $domain"
                    break
                fi
            fi
        done
    fi
    
    # Method 3: Use hostname if available
    if [ -z "$domain" ]; then
        local hostname=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "")
        if [ -n "$hostname" ] && [ "$hostname" != "localhost" ]; then
            domain="$hostname"
            info "Using hostname: $domain"
        fi
    fi
    
    # Method 4: Fallback to localhost with port
    if [ -z "$domain" ]; then
        warn "Could not detect domain, using localhost"
        domain="localhost"
    fi
    
    echo "$domain"
}

# Auto-detect email function
detect_email() {
    local email=""
    
    if [ -n "$FORCE_EMAIL" ]; then
        email="$FORCE_EMAIL"
    elif [ -n "$EMAIL" ]; then
        email="$EMAIL"
    else
        # Try to get email from git config
        email=$(git config user.email 2>/dev/null || echo "")
        
        if [ -z "$email" ]; then
            email="$DEFAULT_EMAIL"
        fi
    fi
    
    echo "$email"
}

# Detect deployment type
detect_deployment_type() {
    if [ "$DEPLOYMENT_TYPE" != "auto" ]; then
        echo "$DEPLOYMENT_TYPE"
        return
    fi
    
    info "Auto-detecting deployment type..."
    
    if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
        info "Kubernetes cluster detected"
        echo "kubernetes"
    elif command -v docker >/dev/null 2>&1 && command -v docker-compose >/dev/null 2>&1; then
        info "Docker and Docker Compose detected"
        echo "docker"
    elif command -v systemctl >/dev/null 2>&1; then
        info "Systemd detected"
        echo "native"
    else
        warn "No suitable deployment method detected, falling back to native"
        echo "native"
    fi
}

# Clean up unnecessary deployment scripts
cleanup_scripts() {
    step "Cleaning up unnecessary deployment scripts..."
    
    local scripts_to_remove=(
        "deploy_ngrok_one_command.sh"
        "deploy_ngrok.sh.bak"
        "deploy_quick.sh"
        "deploy_ubuntu_gui_master.sh"
        "deploy-one-command.sh"
        "deploy-simple.sh"
        "deployment_configurator.sh"
        "desktop_integration.sh"
        "quick_parrot_setup.sh"
        "ssl_setup.sh"
        "ubuntu_gui_deployment.sh"
        "create_bootable_ubuntu.sh"
        "PARROT_BOOTABLE_GUIDE.md"
        "PARROT_CLONE_GUIDE.md"
    )
    
    for script in "${scripts_to_remove[@]}"; do
        if [ -f "$PROJECT_DIR/$script" ]; then
            info "Removing unnecessary script: $script"
            rm -f "$PROJECT_DIR/$script"
        fi
    done
    
    # Clean up backup directories
    local backup_dirs=(
        "backup_docs"
        "backup_logs"
        "backup_misc"
        "backup_scripts"
    )
    
    for dir in "${backup_dirs[@]}"; do
        if [ -d "$PROJECT_DIR/$dir" ]; then
            info "Removing backup directory: $dir"
            rm -rf "$PROJECT_DIR/$dir"
        fi
    done
    
    log "Cleanup completed"
}

# Fix potential 500 errors
fix_500_errors() {
    step "Fixing potential 500 errors..."
    
    # Ensure logs directory exists
    mkdir -p "$PROJECT_DIR/logs"
    
    # Ensure media directory exists
    mkdir -p "$PROJECT_DIR/media"
    mkdir -p "$PROJECT_DIR/media/dicom"
    
    # Ensure static directory exists
    mkdir -p "$PROJECT_DIR/static"
    mkdir -p "$PROJECT_DIR/staticfiles"
    
    # Create a robust .env file
    cat > "$PROJECT_DIR/.env" << EOF
# NoctisPro PACS Configuration
DEBUG=False
SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Database
DB_ENGINE=django.db.backends.sqlite3
DB_NAME=$PROJECT_DIR/db.sqlite3

# Security
ALLOWED_HOSTS=$DETECTED_DOMAIN,localhost,127.0.0.1,0.0.0.0
SECURE_SSL_REDIRECT=False
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https

# Static and Media
STATIC_URL=/static/
MEDIA_URL=/media/
SERVE_MEDIA_FILES=True

# DICOM
DICOM_AET=NOCTIS_SCP
DICOM_PORT=11112
EOF
    
    # Set proper permissions
    chmod 600 "$PROJECT_DIR/.env"
    
    log "500 error fixes applied"
}

# Docker deployment with auto-detection
deploy_docker() {
    step "Deploying with Docker..."
    
    # Create optimized docker-compose for production
    cat > "$PROJECT_DIR/docker-compose.auto.yml" << EOF
version: '3.8'

services:
  web:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DEBUG=False
      - ALLOWED_HOSTS=$DETECTED_DOMAIN,localhost,127.0.0.1
      - SECRET_KEY=\${SECRET_KEY}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
    volumes:
      - ./media:/app/media
      - ./staticfiles:/app/staticfiles
      - ./logs:/app/logs
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/admin/login/"]
      interval: 30s
      timeout: 10s
      retries: 3

  dicom:
    build: .
    ports:
      - "11112:11112"
    environment:
      - DEBUG=False
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
    command: ["python", "dicom_receiver.py", "--port", "11112", "--aet", "NOCTIS_SCP"]
    volumes:
      - ./media:/app/media
      - ./logs:/app/logs
    restart: unless-stopped
    depends_on:
      - web

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./deployment/nginx/nginx-auto.conf:/etc/nginx/conf.d/default.conf:ro
      - ./staticfiles:/app/staticfiles:ro
      - ./media:/app/media:ro
    depends_on:
      - web
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

    # Create nginx configuration
    mkdir -p "$PROJECT_DIR/deployment/nginx"
    cat > "$PROJECT_DIR/deployment/nginx/nginx-auto.conf" << EOF
upstream django {
    server web:8000;
}

server {
    listen 80;
    server_name $DETECTED_DOMAIN localhost;
    client_max_body_size 100M;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Static files
    location /static/ {
        alias /app/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        gzip on;
        gzip_types text/css application/javascript image/svg+xml;
    }
    
    # Media files
    location /media/ {
        alias /app/media/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Main application
    location / {
        proxy_pass http://django;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Handle large uploads
        proxy_request_buffering off;
        proxy_buffering off;
    }
}
EOF

    # Build and start services
    info "Building Docker images..."
    docker-compose -f docker-compose.auto.yml build --no-cache
    
    info "Starting services..."
    docker-compose -f docker-compose.auto.yml up -d
    
    # Wait for services to be ready
    info "Waiting for services to start..."
    sleep 30
    
    # Run Django setup
    info "Setting up Django..."
    docker-compose -f docker-compose.auto.yml exec -T web python manage.py collectstatic --noinput
    docker-compose -f docker-compose.auto.yml exec -T web python manage.py migrate
    
    # Create superuser if it doesn't exist
    docker-compose -f docker-compose.auto.yml exec -T web python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', '$DETECTED_EMAIL', 'admin123')
    print('Superuser created')
else:
    print('Superuser already exists')
"
    
    log "Docker deployment completed"
}

# Native deployment
deploy_native() {
    step "Deploying natively..."
    
    # Install system dependencies
    info "Installing system dependencies..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y python3 python3-venv python3-pip nginx supervisor
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y python3 python3-pip nginx supervisor
    fi
    
    # Setup Python environment
    info "Setting up Python environment..."
    if [ ! -d "$PROJECT_DIR/venv" ]; then
        python3 -m venv "$PROJECT_DIR/venv"
    fi
    
    source "$PROJECT_DIR/venv/bin/activate"
    pip install --upgrade pip setuptools wheel
    
    # Install requirements
    if [ -f "$PROJECT_DIR/requirements.txt" ]; then
        pip install -r "$PROJECT_DIR/requirements.txt"
    fi
    
    # Django setup
    info "Setting up Django..."
    cd "$PROJECT_DIR"
    python manage.py collectstatic --noinput
    python manage.py migrate
    
    # Create superuser
    python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', '$DETECTED_EMAIL', 'admin123')
    print('Superuser created')
"
    
    # Create systemd services
    info "Creating systemd services..."
    
    # Web service
    sudo tee /etc/systemd/system/noctispro-web.service > /dev/null << EOF
[Unit]
Description=NoctisPro Web Service
After=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin
EnvironmentFile=$PROJECT_DIR/.env
ExecStart=$PROJECT_DIR/venv/bin/gunicorn --bind 127.0.0.1:8000 --workers 4 noctis_pro.wsgi:application
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    # DICOM service
    sudo tee /etc/systemd/system/noctispro-dicom.service > /dev/null << EOF
[Unit]
Description=NoctisPro DICOM Service
After=network.target noctispro-web.service

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin
EnvironmentFile=$PROJECT_DIR/.env
ExecStart=$PROJECT_DIR/venv/bin/python dicom_receiver.py --port 11112 --aet NOCTIS_SCP
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    
    # Nginx configuration
    sudo tee /etc/nginx/sites-available/noctispro << EOF
upstream django {
    server 127.0.0.1:8000;
}

server {
    listen 80;
    server_name $DETECTED_DOMAIN localhost;
    client_max_body_size 100M;
    
    location /static/ {
        alias $PROJECT_DIR/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias $PROJECT_DIR/media/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    location / {
        proxy_pass http://django;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    # Enable services
    sudo ln -sf /etc/nginx/sites-available/noctispro /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    
    sudo systemctl daemon-reload
    sudo systemctl enable noctispro-web noctispro-dicom nginx
    sudo systemctl restart noctispro-web noctispro-dicom nginx
    
    log "Native deployment completed"
}

# Health check function
health_check() {
    step "Performing health checks..."
    
    local web_url="http://$DETECTED_DOMAIN"
    if [ "$DETECTED_DOMAIN" = "localhost" ]; then
        web_url="http://localhost:8000"
    fi
    
    # Wait for services to be ready
    sleep 10
    
    # Test web service
    if timeout 10 curl -f -s "$web_url/admin/login/" >/dev/null 2>&1; then
        success "✅ Web service is healthy"
        WEB_STATUS="✅ Healthy"
    else
        error "❌ Web service is not responding"
        WEB_STATUS="❌ Not responding"
    fi
    
    # Test DICOM port
    if timeout 5 bash -c "</dev/tcp/$DETECTED_DOMAIN/11112" >/dev/null 2>&1; then
        success "✅ DICOM service is healthy"
        DICOM_STATUS="✅ Healthy"
    elif timeout 5 bash -c "</dev/tcp/localhost/11112" >/dev/null 2>&1; then
        success "✅ DICOM service is healthy (localhost)"
        DICOM_STATUS="✅ Healthy"
    else
        warn "⚠️  DICOM service may not be ready yet"
        DICOM_STATUS="⚠️  Starting"
    fi
}

# Display final information
show_final_info() {
    echo
    success "🎉 NoctisPro PACS Deployment Complete!"
    echo
    info "📊 Deployment Summary:"
    echo "   Deployment Type: $DETECTED_TYPE"
    echo "   Domain:          $DETECTED_DOMAIN"
    echo "   Email:           $DETECTED_EMAIL"
    echo "   Web Service:     $WEB_STATUS"
    echo "   DICOM Service:   $DICOM_STATUS"
    echo
    info "🌐 Access Information:"
    if [ "$DETECTED_DOMAIN" = "localhost" ]; then
        echo "   Web Interface:   http://localhost:8000"
        echo "   Admin Panel:     http://localhost:8000/admin/"
    else
        echo "   Web Interface:   http://$DETECTED_DOMAIN"
        echo "   Admin Panel:     http://$DETECTED_DOMAIN/admin/"
    fi
    echo "   Default Login:   admin / admin123"
    echo "   DICOM AE Title:  NOCTIS_SCP"
    echo "   DICOM Port:      $DETECTED_DOMAIN:11112"
    echo
    info "🔧 Management Commands:"
    if [ "$DETECTED_TYPE" = "docker" ]; then
        echo "   Start:   docker-compose -f docker-compose.auto.yml up -d"
        echo "   Stop:    docker-compose -f docker-compose.auto.yml down"
        echo "   Logs:    docker-compose -f docker-compose.auto.yml logs -f"
    else
        echo "   Start:   sudo systemctl start noctispro-web noctispro-dicom"
        echo "   Stop:    sudo systemctl stop noctispro-web noctispro-dicom"
        echo "   Status:  sudo systemctl status noctispro-web noctispro-dicom"
        echo "   Logs:    sudo journalctl -f -u noctispro-web -u noctispro-dicom"
    fi
    echo
    if [ "$DETECTED_DOMAIN" != "localhost" ]; then
        warn "📋 DNS Configuration:"
        echo "   Make sure your domain $DETECTED_DOMAIN points to this server"
        echo "   For HTTPS, run: ./deploy_https_quick.sh"
    fi
}

# Main deployment function
main() {
    echo
    success "🚀 NoctisPro PACS - Smart Auto-Deployment"
    echo "========================================"
    echo
    
    # Auto-detect configuration
    step "Auto-detecting configuration..."
    DETECTED_DOMAIN=$(detect_domain)
    DETECTED_EMAIL=$(detect_email)
    DETECTED_TYPE=$(detect_deployment_type)
    
    info "Configuration detected:"
    echo "   Domain: $DETECTED_DOMAIN"
    echo "   Email:  $DETECTED_EMAIL"
    echo "   Type:   $DETECTED_TYPE"
    echo
    
    # Clean up unnecessary files
    cleanup_scripts
    
    # Fix potential 500 errors
    fix_500_errors
    
    # Deploy based on detected type
    case "$DETECTED_TYPE" in
        docker)
            deploy_docker
            ;;
        native|*)
            deploy_native
            ;;
    esac
    
    # Health check
    health_check
    
    # Show final information
    show_final_info
    
    success "🎉 Deployment completed successfully!"
}

# Show help if requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "NoctisPro PACS - Smart Auto-Deployment"
    echo "======================================"
    echo
    echo "This script automatically detects your environment and deploys NoctisPro"
    echo "with optimal configuration for your system."
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Environment Variables:"
    echo "  FORCE_DOMAIN        - Override domain detection"
    echo "  FORCE_EMAIL         - Override email detection"
    echo "  DEPLOYMENT_TYPE     - Force deployment type (docker, native, auto)"
    echo
    echo "Examples:"
    echo "  $0                                    # Auto-detect everything"
    echo "  FORCE_DOMAIN=pacs.hospital.com $0    # Use specific domain"
    echo "  DEPLOYMENT_TYPE=docker $0            # Force Docker deployment"
    echo
    exit 0
fi

# Run main deployment
main "$@"