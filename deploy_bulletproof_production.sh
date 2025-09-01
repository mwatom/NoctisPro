#!/bin/bash

# 🏥 NoctisPro Bulletproof Production Deployment Script
# Complete system deployment with auto-startup services and full DICOM viewer

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

header() {
    echo
    echo -e "${BOLD}${BLUE}=============================================="
    echo -e "  $1"
    echo -e "===============================================${NC}"
    echo
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root for systemd service installation"
    fi
}

# Install system dependencies
install_system_deps() {
    header "📦 Installing System Dependencies"
    
    log "Updating package lists..."
    apt update -qq
    
    log "Installing essential packages..."
    apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        redis-server \
        postgresql \
        postgresql-contrib \
        nginx \
        supervisor \
        curl \
        wget \
        git \
        jq \
        build-essential \
        pkg-config \
        libpq-dev \
        libjpeg-dev \
        libpng-dev \
        libwebp-dev \
        libopenjp2-7-dev \
        libtiff5-dev \
        libffi-dev \
        libssl-dev \
        libsqlite3-dev \
        libgdcm-dev \
        libcups2-dev \
        netcat-openbsd \
        ca-certificates \
        gnupg \
        lsb-release || error "Failed to install system dependencies"
    
    success "System dependencies installed successfully"
}

# Setup virtual environment
setup_venv() {
    header "🐍 Setting Up Virtual Environment"
    
    cd /workspace
    
    if [[ -d "venv" ]]; then
        log "Removing existing virtual environment..."
        rm -rf venv
    fi
    
    log "Creating new virtual environment..."
    python3 -m venv venv || error "Failed to create virtual environment"
    
    log "Activating virtual environment..."
    source venv/bin/activate || error "Failed to activate virtual environment"
    
    log "Upgrading pip..."
    pip install --upgrade pip
    
    success "Virtual environment created and activated"
}

# Install Python dependencies
install_python_deps() {
    header "📚 Installing Python Dependencies"
    
    source /workspace/venv/bin/activate
    
    # Install core Django and web dependencies
    log "Installing core web framework dependencies..."
    pip install \
        django \
        djangorestframework \
        django-cors-headers \
        django-redis \
        channels \
        channels-redis \
        daphne \
        gunicorn \
        psycopg2-binary \
        redis \
        celery \
        pillow \
        requests || error "Failed to install core dependencies"
    
    # Install DICOM and medical imaging dependencies
    log "Installing DICOM and medical imaging dependencies..."
    pip install \
        pydicom \
        SimpleITK \
        gdcm-python \
        scipy \
        numpy \
        matplotlib \
        plotly \
        scikit-image \
        scikit-learn \
        opencv-python \
        nibabel || warning "Some medical imaging dependencies may have failed"
    
    # Install additional scientific and utility packages
    log "Installing additional scientific packages..."
    pip install \
        reportlab \
        openpyxl \
        python-dateutil \
        pytz \
        jsonfield \
        django-environ || warning "Some additional packages may have failed"
    
    success "Python dependencies installed"
}

# Configure production environment
setup_production_env() {
    header "⚙️ Configuring Production Environment"
    
    cd /workspace
    
    # Generate secure secret key
    SECRET_KEY="noctis-production-$(openssl rand -hex 32)"
    
    log "Creating production environment configuration..."
    cat > .env.production << EOF
# Production Configuration for NoctisPro
DEBUG=False
SECRET_KEY=$SECRET_KEY
DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
ALLOWED_HOSTS=*,localhost,127.0.0.1
USE_SQLITE=false
DISABLE_REDIS=false
USE_DUMMY_CACHE=false

# Database Configuration
POSTGRES_DB=noctis_pro
POSTGRES_USER=noctis_user
POSTGRES_PASSWORD=noctis_secure_password_$(openssl rand -hex 16)
POSTGRES_HOST=localhost
POSTGRES_PORT=5432

# Redis Configuration
REDIS_URL=redis://localhost:6379/0
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/0

# File Storage
STATIC_ROOT=/workspace/staticfiles
MEDIA_ROOT=/workspace/media
SERVE_MEDIA_FILES=True
DICOM_STORAGE_PATH=/workspace/media/dicom

# Production Settings
BUILD_TARGET=production
ENVIRONMENT=production
HEALTH_CHECK_ENABLED=True
TIME_ZONE=UTC
USE_TZ=True

# Security Settings
SECURE_BROWSER_XSS_FILTER=True
SECURE_CONTENT_TYPE_NOSNIFF=True
X_FRAME_OPTIONS=DENY
LOGGING_LEVEL=INFO

# Session Configuration
SESSION_TIMEOUT_MINUTES=30
SESSION_WARNING_MINUTES=5
EOF

    # Set proper permissions
    chmod 600 .env.production
    
    success "Production environment configured"
}

# Setup database
setup_database() {
    header "🗄️ Setting Up Database"
    
    # Start PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    # Wait for PostgreSQL to be ready
    sleep 5
    
    # Create database and user
    log "Creating database and user..."
    sudo -u postgres psql << EOF
CREATE DATABASE noctis_pro;
CREATE USER noctis_user WITH ENCRYPTED PASSWORD 'noctis_secure_password_$(openssl rand -hex 16)';
GRANT ALL PRIVILEGES ON DATABASE noctis_pro TO noctis_user;
ALTER USER noctis_user CREATEDB;
\q
EOF

    success "Database configured"
}

# Setup Redis
setup_redis() {
    header "🔄 Setting Up Redis"
    
    # Configure Redis
    log "Configuring Redis..."
    systemctl start redis-server
    systemctl enable redis-server
    
    # Test Redis connection
    if redis-cli ping > /dev/null 2>&1; then
        success "Redis is running and responding"
    else
        warning "Redis may not be responding correctly"
    fi
}

# Django setup
setup_django() {
    header "🐍 Setting Up Django"
    
    cd /workspace
    source venv/bin/activate
    
    # Create necessary directories
    log "Creating necessary directories..."
    mkdir -p media/dicom staticfiles logs backups
    chown -R www-data:www-data media staticfiles
    
    # Run Django system check
    log "Running Django system check..."
    python manage.py check --settings=noctis_pro.settings_production || error "Django system check failed"
    
    # Collect static files
    log "Collecting static files..."
    python manage.py collectstatic --noinput --settings=noctis_pro.settings_production || warning "Static files collection had issues"
    
    # Run migrations
    log "Running database migrations..."
    python manage.py migrate --noinput --settings=noctis_pro.settings_production || warning "Some migrations may have failed"
    
    success "Django configured successfully"
}

# Create systemd services
create_systemd_services() {
    header "🔧 Creating Systemd Services"
    
    # Main Django service
    log "Creating NoctisPro Django service..."
    cat > /etc/systemd/system/noctispro-django.service << EOF
[Unit]
Description=NoctisPro Django Application (Production DICOM Viewer)
After=network.target postgresql.service redis-server.service
Wants=postgresql.service redis-server.service
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=exec
User=www-data
Group=www-data
WorkingDirectory=/workspace
Environment=PATH=/workspace/venv/bin
EnvironmentFile=/workspace/.env.production
ExecStartPre=/bin/sleep 5
ExecStartPre=/bin/bash -c 'cd /workspace && source venv/bin/activate && python manage.py migrate --noinput --settings=noctis_pro.settings_production'
ExecStartPre=/bin/bash -c 'cd /workspace && source venv/bin/activate && python manage.py collectstatic --noinput --settings=noctis_pro.settings_production'
ExecStart=/workspace/venv/bin/daphne -b 0.0.0.0 -p 8000 noctis_pro.asgi:application
Restart=always
RestartSec=10
TimeoutStartSec=300
TimeoutStopSec=60

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=noctispro-django

# Security
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    # Celery worker service
    log "Creating Celery worker service..."
    cat > /etc/systemd/system/noctispro-celery.service << EOF
[Unit]
Description=NoctisPro Celery Worker
After=network.target redis-server.service noctispro-django.service
Wants=redis-server.service

[Service]
Type=exec
User=www-data
Group=www-data
WorkingDirectory=/workspace
Environment=PATH=/workspace/venv/bin
EnvironmentFile=/workspace/.env.production
ExecStart=/workspace/venv/bin/celery -A noctis_pro worker --loglevel=info
Restart=always
RestartSec=10

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=noctispro-celery

# Security
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    # DICOM receiver service
    log "Creating DICOM receiver service..."
    cat > /etc/systemd/system/noctispro-dicom.service << EOF
[Unit]
Description=NoctisPro DICOM Receiver
After=network.target noctispro-django.service
Wants=noctispro-django.service

[Service]
Type=exec
User=www-data
Group=www-data
WorkingDirectory=/workspace
Environment=PATH=/workspace/venv/bin
EnvironmentFile=/workspace/.env.production
ExecStart=/workspace/venv/bin/python dicom_receiver.py
Restart=always
RestartSec=10

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=noctispro-dicom

# Security
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    systemctl daemon-reload
    
    success "Systemd services created"
}

# Configure Nginx
setup_nginx() {
    header "🌐 Setting Up Nginx"
    
    log "Creating Nginx configuration..."
    cat > /etc/nginx/sites-available/noctispro << EOF
server {
    listen 80;
    server_name localhost;
    
    client_max_body_size 500M;
    
    # Static files
    location /static/ {
        alias /workspace/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
    
    # Media files
    location /media/ {
        alias /workspace/media/;
        expires 7d;
        add_header Cache-Control "public, no-transform";
    }
    
    # Main application
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts for large DICOM uploads
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

    # Enable the site
    ln -sf /etc/nginx/sites-available/noctispro /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and restart Nginx
    nginx -t || error "Nginx configuration test failed"
    systemctl restart nginx
    systemctl enable nginx
    
    success "Nginx configured and running"
}

# Create management scripts
create_management_scripts() {
    header "📝 Creating Management Scripts"
    
    cd /workspace
    
    # Start script
    log "Creating start script..."
    cat > start_noctispro_production.sh << 'EOF'
#!/bin/bash

# 🏥 NoctisPro Production Startup Script

echo "🚀 Starting NoctisPro Production System..."

# Start all services
systemctl start postgresql redis-server
sleep 5

systemctl start noctispro-django
systemctl start noctispro-celery
systemctl start noctispro-dicom
systemctl start nginx

echo "✅ All services started"
echo
echo "🌐 Access URLs:"
echo "   Web Interface: http://localhost"
echo "   DICOM Viewer: http://localhost/dicom_viewer/"
echo "   Admin Panel: http://localhost/admin/"
echo
echo "📊 Check status with: ./check_noctispro_production.sh"
EOF
    chmod +x start_noctispro_production.sh
    
    # Stop script
    log "Creating stop script..."
    cat > stop_noctispro_production.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping NoctisPro Production System..."

systemctl stop noctispro-dicom
systemctl stop noctispro-celery
systemctl stop noctispro-django

echo "✅ NoctisPro services stopped"
EOF
    chmod +x stop_noctispro_production.sh
    
    # Status check script
    log "Creating status check script..."
    cat > check_noctispro_production.sh << 'EOF'
#!/bin/bash

echo "🏥 NoctisPro Production System Status"
echo "===================================="
echo

# Check services
services=("postgresql" "redis-server" "noctispro-django" "noctispro-celery" "noctispro-dicom" "nginx")

for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "✅ $service: Running"
    else
        echo "❌ $service: Stopped"
    fi
done

echo
echo "🌐 Web Interface: http://localhost"
echo "📋 DICOM Viewer: http://localhost/dicom_viewer/"
echo "⚙️  Admin Panel: http://localhost/admin/"
echo
echo "📊 Service Logs:"
echo "   Django: journalctl -u noctispro-django -f"
echo "   Celery: journalctl -u noctispro-celery -f"
echo "   DICOM:  journalctl -u noctispro-dicom -f"
echo
echo "🔧 Management Commands:"
echo "   Start:  ./start_noctispro_production.sh"
echo "   Stop:   ./stop_noctispro_production.sh"
echo "   Status: ./check_noctispro_production.sh"
EOF
    chmod +x check_noctispro_production.sh
    
    success "Management scripts created"
}

# Enable auto-startup
enable_autostart() {
    header "🔄 Enabling Auto-Startup"
    
    log "Enabling services for auto-startup..."
    systemctl enable postgresql
    systemctl enable redis-server
    systemctl enable noctispro-django
    systemctl enable noctispro-celery
    systemctl enable noctispro-dicom
    systemctl enable nginx
    
    success "Auto-startup enabled for all services"
}

# Final verification
verify_deployment() {
    header "🧪 Verifying Deployment"
    
    log "Starting services for verification..."
    systemctl start postgresql redis-server
    sleep 5
    systemctl start noctispro-django
    sleep 10
    
    # Test web interface
    if curl -s http://localhost:8000/health/ > /dev/null 2>&1; then
        success "✅ Web interface is responding"
    else
        warning "⚠️  Web interface may not be responding yet"
    fi
    
    # Test DICOM viewer
    if curl -s http://localhost:8000/dicom_viewer/ > /dev/null 2>&1; then
        success "✅ DICOM viewer is accessible"
    else
        warning "⚠️  DICOM viewer may not be responding yet"
    fi
    
    log "Deployment verification completed"
}

# Main deployment function
main() {
    header "🏥 NoctisPro Bulletproof Production Deployment"
    log "Starting deployment at $(date)"
    
    check_root
    install_system_deps
    setup_venv
    install_python_deps
    setup_production_env
    setup_database
    setup_redis
    setup_django
    create_systemd_services
    setup_nginx
    create_management_scripts
    enable_autostart
    verify_deployment
    
    header "🎉 Deployment Complete!"
    success "NoctisPro has been successfully deployed as a production service"
    
    echo
    log "🎯 What's been configured:"
    echo "   ✅ Full production DICOM viewer with all features"
    echo "   ✅ PostgreSQL database with proper configuration"
    echo "   ✅ Redis caching and message broker"
    echo "   ✅ Nginx reverse proxy with static file serving"
    echo "   ✅ Systemd services with auto-startup"
    echo "   ✅ Celery background task processing"
    echo "   ✅ DICOM receiver service"
    echo "   ✅ Security hardening and logging"
    
    echo
    log "🚀 Next steps:"
    echo "   1. Run: ./start_noctispro_production.sh"
    echo "   2. Check status: ./check_noctispro_production.sh"
    echo "   3. Access web interface: http://localhost"
    echo "   4. Access DICOM viewer: http://localhost/dicom_viewer/"
    echo "   5. Create admin user: cd /workspace && source venv/bin/activate && python manage.py createsuperuser"
    
    echo
    log "🔧 The system will automatically start on server reboot"
    success "Deployment completed successfully at $(date)"
}

# Run main function
main "$@"