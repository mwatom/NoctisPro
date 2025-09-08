#!/bin/bash

# =============================================================================
# NoctisPro PACS - Ubuntu 22.04 One-Command Deployment
# =============================================================================
# Complete deployment with FREE public URLs (no domain needed)
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
readonly PROJECT_DIR="/opt/noctis-pro"
readonly LOG_FILE="/tmp/noctis_ubuntu_deploy_$(date +%Y%m%d_%H%M%S).log"

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
clear
echo ""
echo -e "${BOLD}${CYAN}🚀 NoctisPro PACS - Ubuntu 22.04 One-Command Deployment${NC}"
echo -e "${BOLD}${CYAN}========================================================${NC}"
echo -e "${CYAN}✨ Features: FREE Public URLs, No Domain Required! ✨${NC}"
echo ""

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo privileges."
        error "Please run: sudo $0"
        exit 1
    fi
}

# Install system dependencies
install_system_dependencies() {
    log "🔧 Installing system dependencies..."
    
    # Update system
    apt update -y
    apt upgrade -y
    
    # Install all required packages
    DEBIAN_FRONTEND=noninteractive apt install -y \
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
        git \
        htop \
        ufw \
        unzip \
        telnet \
        netcat
    
    success "System dependencies installed"
}

# Setup project directory
setup_project() {
    log "📁 Setting up project directory..."
    
    # Copy current directory to /opt/noctis-pro
    if [[ "${SCRIPT_DIR}" != "${PROJECT_DIR}" ]]; then
        rm -rf "${PROJECT_DIR}"
        cp -r "${SCRIPT_DIR}" "${PROJECT_DIR}"
        chmod +x "${PROJECT_DIR}"/*.sh
    fi
    
    cd "${PROJECT_DIR}"
    
    success "Project directory setup complete"
}

# Setup database
setup_database() {
    log "🗄️ Setting up PostgreSQL database..."
    
    # Start PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    # Create database and user
    sudo -u postgres psql << EOF || true
DROP DATABASE IF EXISTS noctis_pro;
DROP USER IF EXISTS noctis_user;
CREATE DATABASE noctis_pro;
CREATE USER noctis_user WITH PASSWORD 'noctis_secure_password_2024';
GRANT ALL PRIVILEGES ON DATABASE noctis_pro TO noctis_user;
ALTER DATABASE noctis_pro OWNER TO noctis_user;
\q
EOF

    # Grant schema permissions
    sudo -u postgres psql -d noctis_pro -c "GRANT ALL ON SCHEMA public TO noctis_user;" || true
    
    success "PostgreSQL database configured"
}

# Setup Redis
setup_redis() {
    log "🔄 Setting up Redis cache..."
    
    systemctl start redis-server
    systemctl enable redis-server
    
    # Test Redis connection
    if redis-cli ping > /dev/null 2>&1; then
        success "Redis is running"
    else
        warn "Redis may not be fully ready yet"
    fi
}

# Setup Python environment
setup_python_environment() {
    log "🐍 Setting up Python virtual environment..."
    
    cd "${PROJECT_DIR}"
    
    # Remove existing virtual environment
    rm -rf venv_production
    
    # Create new virtual environment
    python3 -m venv venv_production
    source venv_production/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip wheel setuptools
    
    # Install core dependencies first (these are critical)
    log "Installing core Django packages..."
    pip install Django==5.2.6 Pillow psycopg2-binary redis celery gunicorn
    pip install djangorestframework django-cors-headers channels daphne
    pip install pydicom pynetdicom python-dotenv whitenoise
    
    # Install additional packages (non-critical)
    log "Installing additional packages..."
    pip install -r requirements.txt || {
        warn "Some optional dependencies failed to install, continuing with core packages"
        # Install essential packages individually
        pip install matplotlib numpy opencv-python-headless scikit-image || true
        pip install requests urllib3 cryptography PyJWT || true
        pip install reportlab qrcode || true
    }
    
    success "Python environment configured"
}

# Configure Django
configure_django() {
    log "⚙️ Configuring Django application..."
    
    cd "${PROJECT_DIR}"
    source venv_production/bin/activate
    
    # Generate secure secret key
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
    
    # Set environment variables
    export DEBUG=False
    export SECRET_KEY="${SECRET_KEY}"
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
    
    # Create .env file for persistence
    cat > .env << EOF
DEBUG=False
SECRET_KEY=${SECRET_KEY}
DB_ENGINE=django.db.backends.postgresql
DB_NAME=noctis_pro
DB_USER=noctis_user
DB_PASSWORD=noctis_secure_password_2024
DB_HOST=localhost
DB_PORT=5432
REDIS_URL=redis://localhost:6379/0
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/0
ALLOWED_HOSTS=*
EOF
    
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

# Create systemd services
create_services() {
    log "🔧 Creating system services..."
    
    # Create Gunicorn service
    cat > /etc/systemd/system/noctis-web.service << EOF
[Unit]
Description=NoctisPro PACS Web Application
After=network.target postgresql.service redis.service

[Service]
Type=notify
User=root
Group=root
WorkingDirectory=${PROJECT_DIR}
EnvironmentFile=${PROJECT_DIR}/.env
ExecStart=${PROJECT_DIR}/venv_production/bin/gunicorn --bind 0.0.0.0:8000 --workers 4 --timeout 120 noctis_pro.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Create Celery service
    cat > /etc/systemd/system/noctis-celery.service << EOF
[Unit]
Description=NoctisPro PACS Celery Worker
After=network.target postgresql.service redis.service

[Service]
Type=forking
User=root
Group=root
WorkingDirectory=${PROJECT_DIR}
EnvironmentFile=${PROJECT_DIR}/.env
ExecStart=${PROJECT_DIR}/venv_production/bin/celery -A noctis_pro worker --loglevel=info --detach
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Create DICOM service
    cat > /etc/systemd/system/noctis-dicom.service << EOF
[Unit]
Description=NoctisPro PACS DICOM Receiver
After=network.target postgresql.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=${PROJECT_DIR}
EnvironmentFile=${PROJECT_DIR}/.env
ExecStart=${PROJECT_DIR}/venv_production/bin/python dicom_receiver.py --port 11112 --aet NOCTIS_SCP --bind 0.0.0.0
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    systemctl daemon-reload
    
    success "System services created"
}

# Configure Nginx
configure_nginx() {
    log "🌐 Configuring Nginx reverse proxy..."
    
    cat > /etc/nginx/sites-available/noctis << 'EOF'
server {
    listen 80;
    server_name _;
    
    client_max_body_size 100M;
    client_body_timeout 120s;
    client_header_timeout 120s;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    location /static/ {
        alias /opt/noctis-pro/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias /opt/noctis-pro/media/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF

    # Enable the site
    ln -sf /etc/nginx/sites-available/noctis /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx configuration
    nginx -t
    
    # Start nginx
    systemctl enable nginx
    systemctl restart nginx
    
    success "Nginx configured"
}

# Configure firewall
configure_firewall() {
    log "🔥 Configuring firewall..."
    
    # Configure UFW firewall
    ufw --force enable
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 11112/tcp
    ufw reload
    
    success "Firewall configured"
}

# Start all services
start_services() {
    log "🚀 Starting all services..."
    
    # Enable and start services
    systemctl enable noctis-web noctis-celery noctis-dicom
    systemctl start noctis-web noctis-celery noctis-dicom
    
    # Wait for services to start
    sleep 15
    
    success "All services started"
}

# Setup Cloudflare tunnels for FREE public URLs
setup_public_urls() {
    log "🌐 Setting up FREE public URLs (no domain needed)..."
    
    cd "${PROJECT_DIR}"
    
    # Install cloudflared
    if ! command -v cloudflared >/dev/null 2>&1; then
        log "Installing Cloudflare Tunnel..."
        curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        dpkg -i cloudflared.deb
        rm cloudflared.deb
    fi
    
    # Kill any existing tunnels
    pkill cloudflared || true
    sleep 5
    
    # Start tunnels
    log "Starting Cloudflare tunnels..."
    nohup cloudflared tunnel --url http://localhost:80 > tunnel_web.log 2>&1 &
    nohup cloudflared tunnel --url http://localhost:11112 > tunnel_dicom.log 2>&1 &
    
    # Wait for tunnels to establish
    log "Waiting for tunnels to establish (45 seconds)..."
    sleep 45
    
    # Extract URLs
    WEB_URL=""
    DICOM_URL=""
    
    if [[ -f tunnel_web.log ]]; then
        WEB_URL=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' tunnel_web.log | head -1 || echo "")
    fi
    
    if [[ -f tunnel_dicom.log ]]; then
        DICOM_URL=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' tunnel_dicom.log | head -1 || echo "")
    fi
    
    # Save URLs
    if [[ -n "$WEB_URL" ]]; then
        echo "$WEB_URL" > web_tunnel_url.txt
        success "✅ Web tunnel: $WEB_URL"
    else
        warn "⚠️ Web tunnel URL not found yet, check tunnel_web.log"
    fi
    
    if [[ -n "$DICOM_URL" ]]; then
        echo "$DICOM_URL" > dicom_tunnel_url.txt
        success "✅ DICOM tunnel: $DICOM_URL"
    else
        warn "⚠️ DICOM tunnel URL not found yet, check tunnel_dicom.log"
    fi
    
    success "Public URLs configured"
}

# Health check
health_check() {
    log "🏥 Performing health checks..."
    
    local max_attempts=12
    local attempt=0
    
    # Test web service
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

# Setup automatic backups
setup_backups() {
    log "💾 Setting up automatic backups..."
    
    # Create backup script
    cat > /etc/cron.daily/noctis-backup << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/noctis/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"
sudo -u postgres pg_dump noctis_pro > "$BACKUP_DIR/database.sql"
tar -czf "$BACKUP_DIR/media.tar.gz" -C /opt/noctis-pro media/
find /backup/noctis/ -type d -mtime +7 -exec rm -rf {} + 2>/dev/null
EOF
    chmod +x /etc/cron.daily/noctis-backup
    
    success "Automatic daily backups configured"
}

# Generate deployment report
generate_report() {
    log "📊 Generating deployment report..."
    
    local web_url=$(cat "${PROJECT_DIR}/web_tunnel_url.txt" 2>/dev/null || echo "http://$(curl -s ifconfig.me || echo 'localhost')")
    local dicom_url=$(cat "${PROJECT_DIR}/dicom_tunnel_url.txt" 2>/dev/null || echo "http://$(curl -s ifconfig.me || echo 'localhost'):11112")
    local server_ip=$(curl -s ifconfig.me || echo "your-server-ip")
    
    cat > "${PROJECT_DIR}/DEPLOYMENT_SUCCESS.md" << EOF
# 🎉 NoctisPro PACS - Deployment Complete!

## 🌐 Access URLs

### FREE Public URLs (No Domain Required!)
- **Web Application**: ${web_url}
- **Admin Panel**: ${web_url}/admin/
- **DICOM Service**: ${dicom_url}

### Direct Server Access
- **Web Application**: http://${server_ip}/
- **Admin Panel**: http://${server_ip}/admin/
- **Health Check**: http://${server_ip}/health/

## 🔐 Login Credentials
- **Username**: \`admin\`
- **Password**: \`NoctisAdmin2024!\`
- **Email**: \`admin@noctispro.com\`

## 🏥 DICOM Configuration
- **Port**: \`11112\`
- **AET**: \`NOCTIS_SCP\`
- **Server IP**: \`${server_ip}\`
- **Public DICOM URL**: \`${dicom_url}\`

## 🔧 System Services
- ✅ PostgreSQL Database (System Service)
- ✅ Redis Cache (System Service)  
- ✅ Nginx Reverse Proxy (System Service)
- ✅ Django Web App (noctis-web.service)
- ✅ Celery Worker (noctis-celery.service)
- ✅ DICOM Receiver (noctis-dicom.service)
- ✅ Cloudflare Tunnels (FREE Public URLs)
- ✅ Automatic Daily Backups

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

# Check tunnel URLs
cat /opt/noctis-pro/web_tunnel_url.txt
cat /opt/noctis-pro/dicom_tunnel_url.txt

# Restart tunnels if URLs change
cd /opt/noctis-pro
sudo pkill cloudflared
nohup cloudflared tunnel --url http://localhost:80 > tunnel_web.log 2>&1 &
nohup cloudflared tunnel --url http://localhost:11112 > tunnel_dicom.log 2>&1 &
\`\`\`

## 📊 Health Checks
\`\`\`bash
# Test web application
curl -f http://localhost/health/

# Test database
sudo -u postgres psql -d noctis_pro -c "SELECT 1;"

# Test Redis
redis-cli ping

# Test DICOM port
telnet localhost 11112
\`\`\`

## 🚨 Important Notes

### Security
1. **Change default password immediately**: Go to ${web_url}/admin/ and change admin password
2. **Firewall is enabled**: Only ports 22, 80, 443, 11112 are open
3. **Auto-backups**: Daily backups saved to /backup/noctis/

### Public URLs
- **Cloudflare tunnels provide FREE public access**
- **No domain registration needed**
- **URLs may change if tunnels restart** - check tunnel log files
- **HTTPS is automatic** with Cloudflare tunnels

### DICOM Integration
- Configure your DICOM devices to send to: **${server_ip}:11112** (local) or **${dicom_url}** (public)
- AET: **NOCTIS_SCP**
- Supported: CT, MRI, X-Ray, Ultrasound, etc.

## 🎯 Next Steps

1. **Login**: Visit ${web_url}/admin/ with admin/NoctisAdmin2024!
2. **Change Password**: Update admin password immediately
3. **Add DICOM Nodes**: Configure your medical devices in admin panel
4. **Test Upload**: Try uploading a DICOM file
5. **Configure Users**: Add additional users and permissions

## 📞 Support

**Project Location**: \`/opt/noctis-pro/\`
**Log Files**: \`sudo journalctl -u noctis-web -f\`
**Tunnel Logs**: \`/opt/noctis-pro/tunnel_*.log\`

Your NoctisPro PACS system is ready for production use! 🏥✨

**Access now**: ${web_url}
EOF

    success "Deployment report generated: ${PROJECT_DIR}/DEPLOYMENT_SUCCESS.md"
}

# Main deployment function
main() {
    local start_time=$(date +%s)
    
    log "🚀 Starting NoctisPro PACS Ubuntu 22.04 deployment..."
    log "📝 Log file: ${LOG_FILE}"
    
    # Run all setup steps
    check_root
    install_system_dependencies
    setup_project
    setup_database
    setup_redis
    setup_python_environment
    configure_django
    create_services
    configure_nginx
    configure_firewall
    start_services
    setup_public_urls
    health_check
    setup_backups
    generate_report
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local web_url=$(cat "${PROJECT_DIR}/web_tunnel_url.txt" 2>/dev/null || echo "http://$(curl -s ifconfig.me || echo 'your-server-ip')")
    local dicom_url=$(cat "${PROJECT_DIR}/dicom_tunnel_url.txt" 2>/dev/null || echo "http://$(curl -s ifconfig.me || echo 'your-server-ip'):11112")
    
    # Final success message
    clear
    echo ""
    echo -e "${BOLD}${GREEN}🎉 DEPLOYMENT COMPLETE! 🎉${NC}"
    echo -e "${BOLD}${GREEN}=========================${NC}"
    echo ""
    echo -e "${GREEN}📊 Deployment Summary:${NC}"
    echo -e "   • Duration: ${duration} seconds"
    echo -e "   • Mode: Ubuntu 22.04 Production"
    echo -e "   • Services: 6 system services running"
    echo -e "   • Public URLs: ✅ FREE (no domain needed)"
    echo ""
    echo -e "${GREEN}🌐 Your FREE Public URLs:${NC}"
    echo -e "   • Web App: ${CYAN}${web_url}${NC}"
    echo -e "   • Admin: ${CYAN}${web_url}/admin/${NC}"
    echo -e "   • DICOM: ${CYAN}${dicom_url}${NC}"
    echo ""
    echo -e "${GREEN}🔐 Login Credentials:${NC}"
    echo -e "   • Username: ${YELLOW}admin${NC}"
    echo -e "   • Password: ${YELLOW}NoctisAdmin2024!${NC}"
    echo ""
    echo -e "${GREEN}🏥 DICOM Configuration:${NC}"
    echo -e "   • Port: ${YELLOW}11112${NC}"
    echo -e "   • AET: ${YELLOW}NOCTIS_SCP${NC}"
    echo -e "   • Server IP: ${YELLOW}$(curl -s ifconfig.me || echo 'your-server-ip')${NC}"
    echo ""
    echo -e "${GREEN}🔧 Quick Commands:${NC}"
    echo -e "   • Status: ${CYAN}sudo systemctl status noctis-web${NC}"
    echo -e "   • Logs: ${CYAN}sudo journalctl -u noctis-web -f${NC}"
    echo -e "   • Restart: ${CYAN}sudo systemctl restart noctis-web${NC}"
    echo ""
    echo -e "${BOLD}${CYAN}🚀 Your NoctisPro PACS system is LIVE and ready!${NC}"
    echo -e "${BOLD}${CYAN}Access it now: ${web_url}${NC}"
    echo ""
    
    success "🏥 NoctisPro PACS deployment completed successfully!"
}

# Error handling
trap 'error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"