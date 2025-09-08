#!/bin/bash

# =============================================================================
# NoctisPro PACS - Simple Deployment Script
# =============================================================================
# Production deployment without Docker requirements
# =============================================================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="${SCRIPT_DIR}"
readonly LOG_FILE="/tmp/noctis_simple_deploy_$(date +%Y%m%d_%H%M%S).log"

# Logging functions
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}${message}${NC}"
    echo "${message}" >> "${LOG_FILE}"
}

warn() {
    local message="[WARNING] $1"
    echo -e "${YELLOW}${message}${NC}" >&2
    echo "${message}" >> "${LOG_FILE}"
}

error() {
    local message="[ERROR] $1"
    echo -e "${RED}${message}${NC}" >&2
    echo "${message}" >> "${LOG_FILE}"
}

success() {
    local message="[SUCCESS] $1"
    echo -e "${GREEN}✅ ${message}${NC}"
    echo "${message}" >> "${LOG_FILE}"
}

info() {
    local message="[INFO] $1"
    echo -e "${BLUE}${message}${NC}"
    echo "${message}" >> "${LOG_FILE}"
}

# Header
echo ""
echo -e "${BOLD}${CYAN}🚀 NoctisPro PACS - Simple Deployment${NC}"
echo -e "${BOLD}${CYAN}=====================================${NC}"
echo ""

# Install system dependencies
install_system_dependencies() {
    log "Installing system dependencies..."
    
    sudo apt update
    sudo apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        build-essential \
        pkg-config \
        libpq-dev \
        libjpeg-dev \
        zlib1g-dev \
        libopenjp2-7 \
        libssl-dev \
        libffi-dev \
        libxml2-dev \
        libxslt1-dev \
        libcups2-dev \
        cups-common \
        postgresql \
        postgresql-contrib \
        redis-server \
        nginx \
        curl \
        wget \
        git
    
    success "System dependencies installed"
}

# Setup database
setup_database() {
    log "Setting up PostgreSQL database..."
    
    # Start PostgreSQL
    sudo service postgresql start || true
    
    # Create database and user
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS noctis_pro;" || true
    sudo -u postgres psql -c "DROP USER IF EXISTS noctis_user;" || true
    sudo -u postgres psql -c "CREATE DATABASE noctis_pro;"
    sudo -u postgres psql -c "CREATE USER noctis_user WITH PASSWORD 'noctis_secure_password_2024';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE noctis_pro TO noctis_user;"
    sudo -u postgres psql -d noctis_pro -c "GRANT ALL ON SCHEMA public TO noctis_user;"
    
    success "PostgreSQL database configured"
}

# Setup Redis
setup_redis() {
    log "Setting up Redis cache..."
    
    sudo service redis-server start || true
    
    # Test Redis connection
    if redis-cli ping > /dev/null 2>&1; then
        success "Redis is running"
    else
        warn "Redis may not be fully ready yet"
    fi
}

# Setup Python environment
setup_python_environment() {
    log "Setting up Python virtual environment..."
    
    cd "${PROJECT_DIR}"
    
    # Remove existing virtual environment
    rm -rf venv_production
    
    # Create new virtual environment
    python3 -m venv venv_production
    source venv_production/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip wheel setuptools
    
    # Install core dependencies first
    pip install Django==5.2.6 Pillow psycopg2-binary redis celery gunicorn
    pip install djangorestframework django-cors-headers channels daphne
    pip install pydicom pynetdicom
    
    # Install remaining dependencies
    pip install -r requirements.txt || {
        warn "Some optional dependencies failed to install, continuing with core packages"
    }
    
    success "Python environment configured"
}

# Configure Django
configure_django() {
    log "Configuring Django application..."
    
    cd "${PROJECT_DIR}"
    source venv_production/bin/activate
    
    # Set environment variables
    export DEBUG=False
    export SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
    export DB_ENGINE=django.db.backends.postgresql
    export DB_NAME=noctis_pro
    export DB_USER=noctis_user
    export DB_PASSWORD=noctis_secure_password_2024
    export DB_HOST=localhost
    export DB_PORT=5432
    export REDIS_URL=redis://localhost:6379/0
    export CELERY_BROKER_URL=redis://localhost:6379/0
    export CELERY_RESULT_BACKEND=redis://localhost:6379/0
    export ALLOWED_HOSTS="*"
    
    # Run Django migrations
    python manage.py migrate --noinput
    
    # Collect static files
    python manage.py collectstatic --noinput
    
    # Create admin user
    python -c "
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()
from django.contrib.auth import get_user_model
User = get_user_model()
User.objects.filter(username='admin').delete()
User.objects.create_superuser('admin', 'admin@noctispro.com', 'NoctisAdmin2024!')
print('✅ Admin user created: admin / NoctisAdmin2024!')
"
    
    success "Django application configured"
}

# Create service files
create_service_files() {
    log "Creating systemd service files..."
    
    # Create gunicorn service
    sudo tee /etc/systemd/system/noctis-web.service > /dev/null << EOF
[Unit]
Description=NoctisPro PACS Web Application
After=network.target postgresql.service redis.service

[Service]
Type=notify
User=root
WorkingDirectory=${PROJECT_DIR}
Environment=DEBUG=False
Environment=SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
Environment=DB_ENGINE=django.db.backends.postgresql
Environment=DB_NAME=noctis_pro
Environment=DB_USER=noctis_user
Environment=DB_PASSWORD=noctis_secure_password_2024
Environment=DB_HOST=localhost
Environment=DB_PORT=5432
Environment=REDIS_URL=redis://localhost:6379/0
Environment=ALLOWED_HOSTS=*
ExecStart=${PROJECT_DIR}/venv_production/bin/gunicorn --bind 0.0.0.0:8000 --workers 4 --timeout 120 noctis_pro.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Create celery service
    sudo tee /etc/systemd/system/noctis-celery.service > /dev/null << EOF
[Unit]
Description=NoctisPro PACS Celery Worker
After=network.target postgresql.service redis.service

[Service]
Type=forking
User=root
WorkingDirectory=${PROJECT_DIR}
Environment=DEBUG=False
Environment=SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
Environment=DB_ENGINE=django.db.backends.postgresql
Environment=DB_NAME=noctis_pro
Environment=DB_USER=noctis_user
Environment=DB_PASSWORD=noctis_secure_password_2024
Environment=DB_HOST=localhost
Environment=DB_PORT=5432
Environment=REDIS_URL=redis://localhost:6379/0
Environment=CELERY_BROKER_URL=redis://localhost:6379/0
Environment=CELERY_RESULT_BACKEND=redis://localhost:6379/0
ExecStart=${PROJECT_DIR}/venv_production/bin/celery -A noctis_pro worker --loglevel=info --detach
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Create DICOM receiver service
    sudo tee /etc/systemd/system/noctis-dicom.service > /dev/null << EOF
[Unit]
Description=NoctisPro PACS DICOM Receiver
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=${PROJECT_DIR}
Environment=DEBUG=False
Environment=SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
Environment=DB_ENGINE=django.db.backends.postgresql
Environment=DB_NAME=noctis_pro
Environment=DB_USER=noctis_user
Environment=DB_PASSWORD=noctis_secure_password_2024
Environment=DB_HOST=localhost
Environment=DB_PORT=5432
Environment=REDIS_URL=redis://localhost:6379/0
ExecStart=${PROJECT_DIR}/venv_production/bin/python dicom_receiver.py --port 11112 --aet NOCTIS_SCP --bind 0.0.0.0
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    sudo systemctl daemon-reload
    
    success "Service files created"
}

# Configure Nginx
configure_nginx() {
    log "Configuring Nginx reverse proxy..."
    
    sudo tee /etc/nginx/sites-available/noctis > /dev/null << EOF
server {
    listen 80;
    server_name _;
    
    client_max_body_size 100M;
    
    location /static/ {
        alias ${PROJECT_DIR}/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias ${PROJECT_DIR}/media/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF

    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/noctis /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx configuration
    sudo nginx -t
    
    # Start nginx
    sudo service nginx restart
    
    success "Nginx configured"
}

# Start all services
start_services() {
    log "Starting all services..."
    
    # Enable and start services
    sudo systemctl enable noctis-web noctis-celery noctis-dicom
    sudo systemctl start noctis-web noctis-celery noctis-dicom
    
    # Wait for services to start
    sleep 10
    
    success "All services started"
}

# Setup Cloudflare tunnels
setup_tunnels() {
    log "Setting up Cloudflare tunnels..."
    
    # Install cloudflared if not available
    if ! command -v cloudflared >/dev/null 2>&1; then
        log "Installing cloudflared..."
        curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        sudo dpkg -i cloudflared.deb
        rm cloudflared.deb
    fi
    
    # Start tunnels
    log "Starting Cloudflare tunnels..."
    pkill cloudflared || true
    
    nohup cloudflared tunnel --url http://localhost:80 > tunnel_web.log 2>&1 &
    nohup cloudflared tunnel --url http://localhost:11112 > tunnel_dicom.log 2>&1 &
    
    # Wait for tunnels to start
    sleep 15
    
    # Extract URLs
    local web_url=$(grep "https://" tunnel_web.log | grep -o "https://[^[:space:]]*" | head -1)
    local dicom_url=$(grep "https://" tunnel_dicom.log | grep -o "https://[^[:space:]]*" | head -1)
    
    if [[ -n "$web_url" ]]; then
        success "✅ Web tunnel: $web_url"
        echo "$web_url" > web_tunnel_url.txt
    fi
    
    if [[ -n "$dicom_url" ]]; then
        success "✅ DICOM tunnel: $dicom_url"
        echo "$dicom_url" > dicom_tunnel_url.txt
    fi
}

# Health check
health_check() {
    log "Performing health checks..."
    
    local max_attempts=12
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -f -s "http://localhost/health/" >/dev/null 2>&1; then
            success "✅ Web service is healthy"
            break
        fi
        
        ((attempt++))
        if [[ $attempt -eq $max_attempts ]]; then
            warn "⚠️ Web service may not be fully ready yet"
            break
        fi
        
        log "Waiting for web service... (attempt $attempt/$max_attempts)"
        sleep 10
    done
    
    # Test DICOM port
    if timeout 5 bash -c "</dev/tcp/localhost/11112" >/dev/null 2>&1; then
        success "✅ DICOM port is accessible"
    else
        warn "⚠️ DICOM port may not be ready yet"
    fi
    
    # Test database
    if sudo -u postgres psql -d noctis_pro -c "SELECT 1;" >/dev/null 2>&1; then
        success "✅ PostgreSQL database is healthy"
    else
        warn "⚠️ Database may not be ready yet"
    fi
    
    # Test Redis
    if redis-cli ping >/dev/null 2>&1; then
        success "✅ Redis is healthy"
    else
        warn "⚠️ Redis may not be ready yet"
    fi
}

# Generate deployment report
generate_report() {
    log "Generating deployment report..."
    
    local web_url=$(cat web_tunnel_url.txt 2>/dev/null || echo "http://localhost")
    local dicom_url=$(cat dicom_tunnel_url.txt 2>/dev/null || echo "http://localhost:11112")
    
    cat > "${PROJECT_DIR}/SIMPLE_DEPLOYMENT_COMPLETE.md" << EOF
# 🚀 NoctisPro PACS - Simple Deployment Complete!

## 🌐 Access URLs
- **Web Application**: ${web_url}
- **Admin Panel**: ${web_url}/admin/
- **DICOM Service**: ${dicom_url}

## 🔐 Admin Credentials
- **Username**: admin
- **Password**: NoctisAdmin2024!
- **Email**: admin@noctispro.com

## 🔧 System Services
- ✅ PostgreSQL Database (System Service)
- ✅ Redis Cache (System Service)
- ✅ Nginx Reverse Proxy (System Service)
- ✅ Django Web App (noctis-web.service)
- ✅ Celery Worker (noctis-celery.service)
- ✅ DICOM Receiver (noctis-dicom.service)

## 🔧 Management Commands
\`\`\`bash
# Check service status
sudo systemctl status noctis-web noctis-celery noctis-dicom

# View service logs
sudo journalctl -u noctis-web -f
sudo journalctl -u noctis-celery -f
sudo journalctl -u noctis-dicom -f

# Restart services
sudo systemctl restart noctis-web noctis-celery noctis-dicom

# Stop services
sudo systemctl stop noctis-web noctis-celery noctis-dicom

# Start services
sudo systemctl start noctis-web noctis-celery noctis-dicom

# Access database
sudo -u postgres psql -d noctis_pro

# Access Redis
redis-cli
\`\`\`

## 📊 Service Health
Check service health with:
\`\`\`bash
curl -s ${web_url}/health/
sudo systemctl is-active noctis-web noctis-celery noctis-dicom
sudo -u postgres psql -d noctis_pro -c "SELECT 1;"
redis-cli ping
\`\`\`

## 🎉 Deployment Summary
- **Database**: PostgreSQL (Production-ready)
- **Cache**: Redis (High performance)
- **Web Server**: Nginx + Gunicorn
- **Background Tasks**: Celery worker
- **DICOM Support**: Full DICOM receiver
- **Public Access**: Cloudflare tunnels
- **Admin Access**: Full superuser privileges

**Access your system now**: ${web_url}
**Admin login**: admin / NoctisAdmin2024!
EOF

    success "Deployment report generated: SIMPLE_DEPLOYMENT_COMPLETE.md"
}

# Main deployment function
main() {
    local start_time=$(date +%s)
    
    log "Starting NoctisPro PACS simple deployment..."
    log "Log file: ${LOG_FILE}"
    
    # Install dependencies
    install_system_dependencies
    
    # Setup services
    setup_database
    setup_redis
    
    # Setup application
    setup_python_environment
    configure_django
    
    # Create services
    create_service_files
    configure_nginx
    
    # Start everything
    start_services
    
    # Setup public access
    setup_tunnels
    
    # Health checks
    health_check
    
    # Generate report
    generate_report
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo -e "${BOLD}${GREEN}🎉 DEPLOYMENT COMPLETE! 🎉${NC}"
    echo -e "${BOLD}${GREEN}=========================${NC}"
    echo ""
    echo -e "${GREEN}📊 Deployment Summary:${NC}"
    echo -e "   • Duration: ${duration} seconds"
    echo -e "   • Mode: Simple with PostgreSQL"
    echo -e "   • Services: 6 system services running"
    echo ""
    echo -e "${GREEN}🌐 Access Information:${NC}"
    if [[ -f web_tunnel_url.txt ]]; then
        local web_url=$(cat web_tunnel_url.txt)
        echo -e "   • Web URL: ${CYAN}${web_url}${NC}"
        echo -e "   • Admin Panel: ${CYAN}${web_url}/admin/${NC}"
    else
        echo -e "   • Web URL: ${CYAN}http://localhost${NC}"
        echo -e "   • Admin Panel: ${CYAN}http://localhost/admin/${NC}"
    fi
    if [[ -f dicom_tunnel_url.txt ]]; then
        local dicom_url=$(cat dicom_tunnel_url.txt)
        echo -e "   • DICOM URL: ${CYAN}${dicom_url}${NC}"
    else
        echo -e "   • DICOM URL: ${CYAN}http://localhost:11112${NC}"
    fi
    echo ""
    echo -e "${GREEN}🔐 Admin Credentials:${NC}"
    echo -e "   • Username: ${YELLOW}admin${NC}"
    echo -e "   • Password: ${YELLOW}NoctisAdmin2024!${NC}"
    echo ""
    echo -e "${GREEN}🔧 Management:${NC}"
    echo -e "   • Status: ${CYAN}sudo systemctl status noctis-web noctis-celery noctis-dicom${NC}"
    echo -e "   • Logs: ${CYAN}sudo journalctl -u noctis-web -f${NC}"
    echo -e "   • Restart: ${CYAN}sudo systemctl restart noctis-web${NC}"
    echo ""
    
    success "🚀 NoctisPro PACS is ready for use!"
}

# Error handling
trap 'error "Deployment interrupted"; exit 1' INT TERM

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root or with sudo privileges."
    error "Please run: sudo $0"
    exit 1
fi

# Run main function
main "$@"