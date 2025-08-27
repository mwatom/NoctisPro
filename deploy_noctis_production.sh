#!/bin/bash

# NoctisPro Production Deployment Script for Ubuntu Server
# Server: noctis-server (192.168.100.15)
# This script sets up a complete production environment with HTTPS

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="noctis_pro"
PROJECT_USER="noctis"
PROJECT_DIR="/opt/noctis_pro"
DOMAIN_NAME="noctis-server.local"  # Change this to your actual domain
SERVER_IP="192.168.100.15"
GITHUB_REPO="https://github.com/mwatom/NoctisPro.git"

# Database configuration
DB_NAME="noctis_pro"
DB_USER="noctis_user"
DB_PASSWORD=$(openssl rand -base64 32)
DJANGO_SECRET_KEY=$(openssl rand -base64 50)
REDIS_PASSWORD=$(openssl rand -base64 32)

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

log_info "Starting NoctisPro Production Deployment..."

# Detect Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
UBUNTU_MAJOR=$(echo $UBUNTU_VERSION | cut -d. -f1)

log_info "Detected Ubuntu version: $UBUNTU_VERSION"

# Handle Ubuntu 24.04 specific requirements
if [[ "$UBUNTU_MAJOR" == "24" ]]; then
    log_info "Applying Ubuntu 24.04 compatibility fixes..."
    
    # Install iptables-legacy for Docker compatibility
    apt update
    apt install -y iptables-persistent
    
    # Switch to iptables-legacy
    update-alternatives --set iptables /usr/sbin/iptables-legacy
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
    
    # Install additional packages for Ubuntu 24.04
    apt install -y fuse-overlayfs
    
    log_success "Ubuntu 24.04 compatibility fixes applied"
fi

# Update system
log_info "Updating system packages..."
apt update && apt upgrade -y

# Install Docker
install_docker() {
    log_info "Installing Docker..."
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        log_warning "Docker is already installed"
        docker --version
        return 0
    fi
    
    # Remove old Docker versions
    log_info "Removing old Docker versions..."
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install prerequisites
    log_info "Installing Docker prerequisites..."
    apt install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        apt-transport-https \
        software-properties-common
    
    # Add Docker's official GPG key
    log_info "Adding Docker GPG key..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    log_info "Adding Docker repository..."
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index
    apt update
    
    # Install Docker Engine
    log_info "Installing Docker Engine..."
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Configure Docker for Ubuntu 24.04 if needed
    if [[ "$UBUNTU_MAJOR" == "24" ]]; then
        log_info "Configuring Docker for Ubuntu 24.04..."
        mkdir -p /etc/docker
        cat > /etc/docker/daemon.json << EOF
{
    "storage-driver": "overlay2",
    "iptables": true,
    "ip-forward": true,
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF
    fi
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add project user to docker group
    usermod -aG docker $PROJECT_USER
    
    # Test Docker installation
    log_info "Testing Docker installation..."
    if docker --version && docker compose version; then
        log_success "Docker installed successfully"
        docker --version
        docker compose version
    else
        log_error "Docker installation failed"
        exit 1
    fi
}

# Install Docker
install_docker

# Install required packages
log_info "Installing required packages..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    postgresql \
    postgresql-contrib \
    redis-server \
    nginx \
    certbot \
    python3-certbot-nginx \
    git \
    curl \
    supervisor \
    ufw \
    fail2ban \
    htop \
    tree \
    unzip \
    build-essential \
    python3-dev \
    libpq-dev \
    libjpeg-dev \
    libpng-dev \
    libgdcm-dev \
    cups \
    cups-client \
    cups-filters \
    printer-driver-all \
    printer-driver-canon \
    printer-driver-epson \
    printer-driver-hplip \
    printer-driver-brlaser

# Create project user
log_info "Creating project user..."
if ! id "$PROJECT_USER" &>/dev/null; then
    useradd -m -s /bin/bash $PROJECT_USER
    usermod -aG sudo $PROJECT_USER
    log_success "User $PROJECT_USER created"
else
    log_warning "User $PROJECT_USER already exists"
fi

# Create project directory
log_info "Creating project directory..."
mkdir -p $PROJECT_DIR
mkdir -p $PROJECT_DIR/logs
mkdir -p $PROJECT_DIR/staticfiles
mkdir -p $PROJECT_DIR/media
chown -R $PROJECT_USER:$PROJECT_USER $PROJECT_DIR

# Setup PostgreSQL
log_info "Configuring PostgreSQL..."
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;" || log_warning "Database might already exist"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" || log_warning "User might already exist"
sudo -u postgres psql -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
sudo -u postgres psql -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
sudo -u postgres psql -c "ALTER ROLE $DB_USER SET timezone TO 'UTC';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# Configure PostgreSQL for production
log_info "Configuring PostgreSQL for production..."

# Get PostgreSQL major version only (e.g., "16" instead of "16.6")
PG_VERSION=$(sudo -u postgres psql -c "SELECT version();" | grep -oE '[0-9]+' | head -1)
log_info "Detected PostgreSQL version: $PG_VERSION"

# Find the actual config directory (handles different version formats)
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"
if [ ! -d "$PG_CONFIG_DIR" ]; then
    # Fallback: find any PostgreSQL config directory
    PG_CONFIG_DIR=$(find /etc/postgresql -type d -name "main" | head -1)
    if [ -z "$PG_CONFIG_DIR" ]; then
        log_error "Could not find PostgreSQL configuration directory"
        exit 1
    fi
    log_warning "Using config directory: $PG_CONFIG_DIR"
fi

PG_CONFIG="$PG_CONFIG_DIR/postgresql.conf"
PG_HBA="$PG_CONFIG_DIR/pg_hba.conf"

# Verify config files exist before backing up
if [ ! -f "$PG_CONFIG" ]; then
    log_error "PostgreSQL config file not found: $PG_CONFIG"
    log_info "Available PostgreSQL directories:"
    ls -la /etc/postgresql/ 2>/dev/null || echo "No PostgreSQL config directory found"
    exit 1
fi

# Backup original configs
log_info "Backing up PostgreSQL configuration files..."
cp "$PG_CONFIG" "$PG_CONFIG.backup"
cp "$PG_HBA" "$PG_HBA.backup"

# Configure PostgreSQL settings
cat >> $PG_CONFIG << EOF

# NoctisPro Production Settings
shared_preload_libraries = 'pg_stat_statements'
max_connections = 200
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 4MB
min_wal_size = 1GB
max_wal_size = 4GB
EOF

# Enable PostgreSQL and restart
systemctl enable postgresql
systemctl restart postgresql

# Configure Redis
log_info "Configuring Redis..."
sed -i "s|# requirepass foobared|requirepass $REDIS_PASSWORD|" /etc/redis/redis.conf
sed -i "s/bind 127.0.0.1 ::1/bind 127.0.0.1/" /etc/redis/redis.conf
systemctl enable redis-server
systemctl restart redis-server

# Configure CUPS printing system
log_info "Configuring CUPS printing system..."
systemctl enable cups
systemctl start cups

# Add project user to lpadmin group for printer management
usermod -a -G lpadmin $PROJECT_USER

# Configure CUPS for local network access
cupsctl --remote-any

# Create CUPS configuration backup
cp /etc/cups/cupsd.conf /etc/cups/cupsd.conf.backup

# Optimize CUPS for medical imaging printing
cat >> /etc/cups/cupsd.conf << EOF

# NoctisPro Medical Imaging Optimizations
MaxJobs 100
MaxJobsPerPrinter 10
MaxJobsPerUser 10
PreserveJobHistory On
PreserveJobFiles On
AutoPurgeJobs Yes
EOF

systemctl restart cups

# Clone or update project
log_info "Setting up project code..."
if [ -d "$PROJECT_DIR/.git" ]; then
    log_info "Updating existing repository..."
    cd $PROJECT_DIR
    sudo -u $PROJECT_USER git pull origin main
else
    log_info "Cloning repository..."
    sudo -u $PROJECT_USER git clone $GITHUB_REPO $PROJECT_DIR
fi

cd $PROJECT_DIR

# Create virtual environment
log_info "Creating Python virtual environment..."
sudo -u $PROJECT_USER python3 -m venv venv
sudo -u $PROJECT_USER ./venv/bin/pip install --upgrade pip

# Install Python dependencies
log_info "Installing Python dependencies..."
sudo -u $PROJECT_USER ./venv/bin/pip install -r requirements.txt

# Create environment file
log_info "Creating environment configuration..."
cat > $PROJECT_DIR/.env << EOF
# Django Configuration
SECRET_KEY=$DJANGO_SECRET_KEY
DEBUG=False
ALLOWED_HOSTS=noctis-server,192.168.100.15,localhost,127.0.0.1,$DOMAIN_NAME

# Database Configuration
DB_ENGINE=django.db.backends.postgresql
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_HOST=localhost
DB_PORT=5432

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=$REDIS_PASSWORD

# Domain Configuration
DOMAIN_NAME=$DOMAIN_NAME
ENABLE_SSL=false

# Email Configuration (configure as needed)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=
DEFAULT_FROM_EMAIL=noreply@noctis-server.local
EOF

chown $PROJECT_USER:$PROJECT_USER $PROJECT_DIR/.env
chmod 600 $PROJECT_DIR/.env

# Run Django setup
log_info "Setting up Django application..."
cd $PROJECT_DIR
sudo -u $PROJECT_USER ./venv/bin/python manage.py collectstatic --noinput --settings=noctis_pro.settings_production
sudo -u $PROJECT_USER ./venv/bin/python manage.py migrate --settings=noctis_pro.settings_production

# Create Django superuser
log_info "Creating Django superuser..."
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@noctis-server.local', 'admin123') if not User.objects.filter(username='admin').exists() else None" | sudo -u $PROJECT_USER ./venv/bin/python manage.py shell --settings=noctis_pro.settings_production

# Configure Gunicorn
log_info "Configuring Gunicorn..."
cat > $PROJECT_DIR/gunicorn.conf.py << EOF
import multiprocessing

bind = "127.0.0.1:8000"
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
max_requests = 1000
max_requests_jitter = 100
timeout = 30
keepalive = 2
preload_app = True
user = "$PROJECT_USER"
group = "$PROJECT_USER"
tmp_upload_dir = None
errorlog = "$PROJECT_DIR/logs/gunicorn_error.log"
accesslog = "$PROJECT_DIR/logs/gunicorn_access.log"
loglevel = "info"
EOF

chown $PROJECT_USER:$PROJECT_USER $PROJECT_DIR/gunicorn.conf.py

# Create systemd service for Django
log_info "Creating systemd service for Django..."
cat > /etc/systemd/system/noctis-django.service << EOF
[Unit]
Description=NoctisPro Django Application
After=network.target postgresql.service redis-server.service

[Service]
Type=notify
User=$PROJECT_USER
Group=$PROJECT_USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
ExecStart=$PROJECT_DIR/venv/bin/gunicorn noctis_pro.wsgi:application -c $PROJECT_DIR/gunicorn.conf.py
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for Daphne (WebSocket support)
log_info "Creating systemd service for Daphne..."
cat > /etc/systemd/system/noctis-daphne.service << EOF
[Unit]
Description=NoctisPro Daphne WebSocket Server
After=network.target postgresql.service redis-server.service

[Service]
Type=simple
User=$PROJECT_USER
Group=$PROJECT_USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
ExecStart=$PROJECT_DIR/venv/bin/daphne -b 127.0.0.1 -p 8001 noctis_pro.asgi:application
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for Celery
log_info "Creating systemd service for Celery..."
cat > /etc/systemd/system/noctis-celery.service << EOF
[Unit]
Description=NoctisPro Celery Worker
After=network.target postgresql.service redis-server.service

[Service]
Type=simple
User=$PROJECT_USER
Group=$PROJECT_USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
ExecStart=$PROJECT_DIR/venv/bin/celery -A noctis_pro worker -l info
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx
log_info "Configuring Nginx..."
cat > /etc/nginx/sites-available/noctis-pro << EOF
upstream django_app {
    server 127.0.0.1:8000;
}

upstream daphne_app {
    server 127.0.0.1:8001;
}

server {
    listen 80;
    server_name $DOMAIN_NAME $SERVER_IP noctis-server;
    
    client_max_body_size 100M;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Static files
    location /static/ {
        alias $PROJECT_DIR/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Media files
    location /media/ {
        alias $PROJECT_DIR/media/;
        expires 1y;
        add_header Cache-Control "public";
    }
    
    # WebSocket connections
    location /ws/ {
        proxy_pass http://daphne_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
    
    # Django application
    location / {
        proxy_pass http://django_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/noctis-pro /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

# Configure firewall
log_info "Configuring firewall..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'
ufw allow 2222/tcp
ufw allow from 192.168.100.0/24

# Configure fail2ban
log_info "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true

[nginx-http-auth]
enabled = true

[nginx-limit-req]
enabled = true
EOF

# Enable and start services
log_info "Starting services..."
systemctl daemon-reload
systemctl enable noctis-django noctis-daphne noctis-celery nginx fail2ban cups
systemctl start noctis-django noctis-daphne noctis-celery nginx fail2ban cups

# Create GitHub webhook handler
log_info "Setting up GitHub webhook handler..."
cat > $PROJECT_DIR/webhook_handler.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import json
import hmac
import hashlib
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/webhook':
            self.send_response(404)
            self.end_headers()
            return
        
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        # Verify webhook signature (optional)
        # signature = self.headers.get('X-Hub-Signature-256')
        
        try:
            payload = json.loads(post_data.decode('utf-8'))
            if payload.get('ref') == 'refs/heads/main':
                self.deploy()
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'Deployment triggered')
            else:
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'Not main branch, ignoring')
        except Exception as e:
            print(f"Error: {e}")
            self.send_response(500)
            self.end_headers()
    
    def deploy(self):
        try:
            os.chdir('/opt/noctis_pro')
            subprocess.run(['git', 'pull', 'origin', 'main'], check=True)
            subprocess.run(['./venv/bin/pip', 'install', '-r', 'requirements.txt'], check=True)
            subprocess.run(['./venv/bin/python', 'manage.py', 'migrate', '--settings=noctis_pro.settings_production'], check=True)
            subprocess.run(['./venv/bin/python', 'manage.py', 'collectstatic', '--noinput', '--settings=noctis_pro.settings_production'], check=True)
            subprocess.run(['systemctl', 'restart', 'noctis-django', 'noctis-daphne'], check=True)
            print("Deployment completed successfully")
        except subprocess.CalledProcessError as e:
            print(f"Deployment failed: {e}")

if __name__ == '__main__':
    server = HTTPServer(('127.0.0.1', 8080), WebhookHandler)
    print("Webhook server running on port 8080")
    server.serve_forever()
EOF

chmod +x $PROJECT_DIR/webhook_handler.py
chown $PROJECT_USER:$PROJECT_USER $PROJECT_DIR/webhook_handler.py

# Create systemd service for webhook
cat > /etc/systemd/system/noctis-webhook.service << EOF
[Unit]
Description=NoctisPro GitHub Webhook Handler
After=network.target

[Service]
Type=simple
User=$PROJECT_USER
Group=$PROJECT_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/python3 $PROJECT_DIR/webhook_handler.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl enable noctis-webhook
systemctl start noctis-webhook

# Add webhook location to Nginx
log_info "Adding webhook endpoint to Nginx..."
sed -i '/location \/ {/i \    # GitHub webhook\n    location /webhook {\n        proxy_pass http://127.0.0.1:8080/webhook;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto $scheme;\n    }\n' /etc/nginx/sites-available/noctis-pro

systemctl reload nginx

# Create backup script
log_info "Creating backup script..."
cat > /usr/local/bin/noctis-backup.sh << EOF
#!/bin/bash
BACKUP_DIR="/opt/backups/noctis_pro"
DATE=\$(date +%Y%m%d_%H%M%S)

mkdir -p \$BACKUP_DIR

# Database backup
sudo -u postgres pg_dump $DB_NAME > \$BACKUP_DIR/database_\$DATE.sql

# Media files backup
tar -czf \$BACKUP_DIR/media_\$DATE.tar.gz -C $PROJECT_DIR media/

# Remove backups older than 30 days
find \$BACKUP_DIR -type f -mtime +30 -delete

echo "Backup completed: \$DATE"
EOF

chmod +x /usr/local/bin/noctis-backup.sh

# Add backup to cron
echo "0 2 * * * root /usr/local/bin/noctis-backup.sh" >> /etc/crontab

# Create status check script
log_info "Creating status check script..."
cat > /usr/local/bin/noctis-status.sh << EOF
#!/bin/bash
echo "=== NoctisPro System Status ==="
echo
echo "Services:"
systemctl is-active noctis-django noctis-daphne noctis-celery noctis-webhook nginx postgresql redis-server cups
echo
echo "Disk Usage:"
df -h $PROJECT_DIR
echo
echo "Memory Usage:"
free -h
echo
echo "Printer Status:"
lpstat -p -d 2>/dev/null || echo "No printers configured"
echo
echo "Recent Logs:"
journalctl -u noctis-django --since "1 hour ago" --no-pager -n 10
EOF

chmod +x /usr/local/bin/noctis-status.sh

# Final status check
log_info "Checking service status..."
sleep 5
systemctl status noctis-django noctis-daphne noctis-celery --no-pager

# Display final information
log_success "NoctisPro deployment completed successfully!"
echo
echo "=== Deployment Information ==="
echo "Server IP: $SERVER_IP"
echo "Domain: $DOMAIN_NAME"
echo "HTTP URL: http://$SERVER_IP"
echo "HTTP URL (Port 2222): http://$SERVER_IP:2222"
echo "Admin URL: http://$SERVER_IP/admin"
echo "Admin URL (Port 2222): http://$SERVER_IP:2222/admin"
echo "Admin Username: admin"
echo "Admin Password: admin123"
echo
echo "=== Database Information ==="
echo "Database: $DB_NAME"
echo "Username: $DB_USER"
echo "Password: $DB_PASSWORD"
echo
echo "=== Important Files ==="
echo "Project Directory: $PROJECT_DIR"
echo "Environment File: $PROJECT_DIR/.env"
echo "Logs Directory: $PROJECT_DIR/logs"
echo "Nginx Config: /etc/nginx/sites-available/noctis-pro"
echo
echo "=== Useful Commands ==="
echo "Check status: /usr/local/bin/noctis-status.sh"
echo "Create backup: /usr/local/bin/noctis-backup.sh"
echo "Setup printer: ./setup_printer.sh"
echo "Validate deployment: python3 validate_deployment_with_printing.py"
echo "View logs: journalctl -u noctis-django -f"
echo "Restart services: systemctl restart noctis-django noctis-daphne noctis-celery"
echo
echo "=== ACCESS INFORMATION ==="
echo "🌐 Local Access: http://$SERVER_IP (port 80)"
echo "🌐 Local Access: http://$SERVER_IP:2222 (port 2222)"
echo "🔧 Admin Panel: http://$SERVER_IP/admin (port 80)"
echo "🔧 Admin Panel: http://$SERVER_IP:2222/admin (port 2222)"
echo "🔗 Local Webhook: http://$SERVER_IP/webhook"
echo
echo "=== INTERNET ACCESS SETUP ==="
echo "To enable internet access, run: sudo ./setup_secure_access.sh"
echo "Available options:"
echo "  1) Domain with HTTPS (https://your-domain.com)"
echo "  2) Cloudflare Tunnel (secure, no open ports)"
echo "  3) VPN Access (private network)"
echo "  4) Reverse Proxy (custom domain)"
echo
echo "=== Next Steps ==="
echo "1. Configure internet access: sudo ./setup_secure_access.sh"
echo "2. Change default admin password"
echo "3. Configure your facility's printer (optional): sudo ./setup_printer.sh"
echo "4. Set up GitHub webhook for auto-updates"
echo
log_warning "Please save the database password and Django secret key in a secure location!"
echo "Database Password: $DB_PASSWORD"
echo "Django Secret Key: $DJANGO_SECRET_KEY"
echo "Redis Password: $REDIS_PASSWORD"