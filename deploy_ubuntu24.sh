#!/bin/bash
set -euo pipefail

# Noctis Pro DICOM System - Ubuntu 24.04 Deployment Script
# Optimized for fresh Ubuntu 24.04 installations
# Usage: sudo bash deploy_ubuntu24.sh [domain_name] [admin_email]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration variables
APP_NAME="noctis"
APP_DIR="/opt/$APP_NAME"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/$APP_NAME"
BACKUP_DIR="/opt/backups/$APP_NAME"
DOMAIN_NAME="${1:-}"
ADMIN_EMAIL="${2:-admin@localhost}"
ADMIN_USER="admin"
DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-production}" # production, development, docker

# Generate secure passwords and keys
ADMIN_PASS="$(openssl rand -base64 32 | tr -d '=' | head -c 24)"
SECRET_KEY="$(openssl rand -base64 64 | tr -d '=' | head -c 50)"
POSTGRES_PASS="$(openssl rand -base64 32 | tr -d '=' | head -c 24)"

# Database configuration
USE_POSTGRES="${USE_POSTGRES:-true}"
POSTGRES_DB="noctis_pro"
POSTGRES_USER="noctis_user"

# Print banner
print_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    ███╗   ██╗ ██████╗  ██████╗████████╗██╗███████╗           ║
║    ████╗  ██║██╔═══██╗██╔════╝╚══██╔══╝██║██╔════╝           ║
║    ██╔██╗ ██║██║   ██║██║        ██║   ██║███████╗           ║
║    ██║╚██╗██║██║   ██║██║        ██║   ██║╚════██║           ║
║    ██║ ╚████║╚██████╔╝╚██████╗   ██║   ██║███████║           ║
║    ╚═╝  ╚═══╝ ╚═════╝  ╚═════╝   ╚═╝   ╚═╝╚══════╝           ║
║                                                               ║
║                   UBUNTU 24.04 DEPLOYMENT                    ║
║               DICOM Medical Imaging System                    ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Utility functions
print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check Ubuntu version
check_ubuntu_version() {
    if ! grep -q "Ubuntu 24.04" /etc/os-release; then
        print_warning "This script is optimized for Ubuntu 24.04. Current version:"
        cat /etc/os-release | grep PRETTY_NAME
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Update system packages
update_system() {
    print_step "Updating system packages..."
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common
}

# Install system dependencies
install_dependencies() {
    print_step "Installing system dependencies..."
    apt-get install -y \
        python3 python3-pip python3-venv python3-dev \
        build-essential pkg-config \
        libpq-dev postgresql postgresql-contrib \
        redis-server \
        nginx \
        supervisor \
        git curl wget unzip htop tree \
        libssl-dev libffi-dev \
        libjpeg-dev libpng-dev libwebp-dev \
        libopenjp2-7-dev libtiff5-dev \
        libgdcm-dev libgdcm-tools \
        libsqlite3-dev \
        fail2ban ufw \
        certbot python3-certbot-nginx \
        logrotate rsync \
        python3-pyqt5 \
        ffmpeg
}

# Configure firewall
configure_firewall() {
    print_step "Configuring UFW firewall..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 8000/tcp  # Django development
    ufw allow 11112/tcp # DICOM receiver
    ufw --force enable
}

# Setup PostgreSQL
setup_postgresql() {
    if [[ "$USE_POSTGRES" == "true" ]]; then
        print_step "Setting up PostgreSQL..."
        systemctl enable postgresql || echo "Warning: Could not enable PostgreSQL service"
        systemctl start postgresql || echo "Warning: Could not start PostgreSQL service"
        
        # Create database and user
        sudo -u postgres psql -c "CREATE DATABASE $POSTGRES_DB;" || true
        sudo -u postgres psql -c "CREATE USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASS';" || true
        sudo -u postgres psql -c "ALTER ROLE $POSTGRES_USER SET client_encoding TO 'utf8';"
        sudo -u postgres psql -c "ALTER ROLE $POSTGRES_USER SET default_transaction_isolation TO 'read committed';"
        sudo -u postgres psql -c "ALTER ROLE $POSTGRES_USER SET timezone TO 'UTC';"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_USER;"
        
        # Configure PostgreSQL for production
        # Find the correct PostgreSQL version and config directory
        PG_VERSION=$(sudo -u postgres psql -t -c "SHOW server_version;" | grep -oE '[0-9]+' | head -1)
        
        # Try multiple possible config directory locations
        PG_CONFIG_DIR=""
        
        # First try exact version match
        if [ -d "/etc/postgresql/$PG_VERSION/main" ] && [ -f "/etc/postgresql/$PG_VERSION/main/postgresql.conf" ]; then
            PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"
        else
            # Try version with patch number (e.g., 16.9)
            for possible_dir in /etc/postgresql/$PG_VERSION.*/main; do
                if [ -d "$possible_dir" ] && [ -f "$possible_dir/postgresql.conf" ]; then
                    PG_CONFIG_DIR="$possible_dir"
                    break
                fi
            done
            
            # If still not found, try any version
            if [ -z "$PG_CONFIG_DIR" ]; then
                for possible_dir in /etc/postgresql/*/main; do
                    if [ -d "$possible_dir" ] && [ -f "$possible_dir/postgresql.conf" ]; then
                        PG_CONFIG_DIR="$possible_dir"
                        break
                    fi
                done
            fi
        fi
        
        # If we still can't find it, try to locate it using find
        if [ -z "$PG_CONFIG_DIR" ]; then
            PG_CONFIG_DIR=$(find /etc/postgresql -name "postgresql.conf" -type f | head -1 | xargs dirname 2>/dev/null)
        fi
        
        # If we still can't find it, get it from PostgreSQL itself
        if [ -z "$PG_CONFIG_DIR" ] || [ ! -f "$PG_CONFIG_DIR/postgresql.conf" ]; then
            CONF_FILE=$(sudo -u postgres psql -t -c "SHOW config_file;" | tr -d ' ')
            PG_CONFIG_DIR=$(dirname "$CONF_FILE")
        fi
        
        echo "Using PostgreSQL config directory: $PG_CONFIG_DIR"
        
        # Backup original configs
        if [ -f "$PG_CONFIG_DIR/postgresql.conf" ]; then
            cp "$PG_CONFIG_DIR/postgresql.conf" "$PG_CONFIG_DIR/postgresql.conf.backup" || true
        fi
        if [ -f "$PG_CONFIG_DIR/pg_hba.conf" ]; then
            cp "$PG_CONFIG_DIR/pg_hba.conf" "$PG_CONFIG_DIR/pg_hba.conf.backup" || true
        fi
        
        # Optimize PostgreSQL configuration
        if [ -f "$PG_CONFIG_DIR/postgresql.conf" ]; then
            cat >> "$PG_CONFIG_DIR/postgresql.conf" << EOF

# Noctis Pro optimizations
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
EOF
        else
            echo "Warning: Could not find PostgreSQL configuration file to optimize"
        fi
        
        systemctl restart postgresql || echo "Warning: Could not restart PostgreSQL service"
    fi
}

# Setup Redis
setup_redis() {
    print_step "Setting up Redis..."
    systemctl enable redis-server || echo "Warning: Could not enable Redis service"
    systemctl start redis-server || echo "Warning: Could not start Redis service"
    
    # Configure Redis for production
    cp /etc/redis/redis.conf /etc/redis/redis.conf.backup || echo "Warning: Could not backup Redis config"
    
    # Basic Redis hardening
    sed -i 's/^# maxmemory <bytes>/maxmemory 512mb/' /etc/redis/redis.conf || echo "Warning: Could not set Redis maxmemory"
    sed -i 's/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf || echo "Warning: Could not set Redis maxmemory-policy"
    
    systemctl restart redis-server || echo "Warning: Could not restart Redis service"
}

# Create application user and directories
setup_application_structure() {
    print_step "Setting up application structure..."
    
    # Create application user
    useradd -r -s /bin/bash -d $APP_DIR -m $APP_NAME || true
    
    # Create directories
    mkdir -p $APP_DIR $LOG_DIR $BACKUP_DIR
    mkdir -p $APP_DIR/{media,staticfiles,uploads,exports}
    
    # Set permissions
    chown -R $APP_NAME:$APP_NAME $APP_DIR
    chown -R $APP_NAME:$APP_NAME $LOG_DIR
    chown -R $APP_NAME:$APP_NAME $BACKUP_DIR
    
    # Copy application files
    if [ -f "manage.py" ]; then
        print_step "Copying application files..."
        cp -r . $APP_DIR/source/
        chown -R $APP_NAME:$APP_NAME $APP_DIR/source/
    else
        print_error "No Django application found. Please run this script from the project root."
        exit 1
    fi
}

# Setup Python environment
setup_python_environment() {
    print_step "Setting up Python virtual environment..."
    
    # Create virtual environment as application user
    sudo -u $APP_NAME python3 -m venv $VENV_DIR
    
    # Install Python dependencies
    sudo -u $APP_NAME $VENV_DIR/bin/pip install --upgrade pip wheel setuptools
    sudo -u $APP_NAME $VENV_DIR/bin/pip install -r $APP_DIR/source/requirements.txt
    
    # Install additional production dependencies
    sudo -u $APP_NAME $VENV_DIR/bin/pip install gunicorn uvicorn[standard] setproctitle
}

# Create environment configuration
create_environment_config() {
    print_step "Creating environment configuration..."
    
    cat > $APP_DIR/.env << EOF
# Django settings
DEBUG=False
SECRET_KEY=$SECRET_KEY
DJANGO_SETTINGS_MODULE=noctis_pro.settings
ALLOWED_HOSTS=localhost,127.0.0.1,$DOMAIN_NAME

# Database settings
DATABASE_URL=postgresql://$POSTGRES_USER:$POSTGRES_PASS@localhost:5432/$POSTGRES_DB

# Redis settings
REDIS_URL=redis://localhost:6379/0
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/0

# Security settings
SECURE_SSL_REDIRECT=True
SECURE_HSTS_SECONDS=31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS=True
SECURE_HSTS_PRELOAD=True
SECURE_CONTENT_TYPE_NOSNIFF=True
SECURE_BROWSER_XSS_FILTER=True
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True

# Email settings (configure as needed)
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
DEFAULT_FROM_EMAIL=noctis@$DOMAIN_NAME
ADMIN_EMAIL=$ADMIN_EMAIL

# File storage
MEDIA_ROOT=$APP_DIR/media
STATIC_ROOT=$APP_DIR/staticfiles

# Logging
LOG_LEVEL=INFO
LOG_DIR=$LOG_DIR
EOF

    chown $APP_NAME:$APP_NAME $APP_DIR/.env
    chmod 600 $APP_DIR/.env
}

# Setup Django application
setup_django() {
    print_step "Setting up Django application..."
    
    cd $APP_DIR/source
    
    # Run Django setup commands as application user
    sudo -u $APP_NAME bash -c "
        source $VENV_DIR/bin/activate
        export \$(cat $APP_DIR/.env | grep -v '^#' | xargs)
        
        python manage.py migrate --noinput
        python manage.py collectstatic --noinput
        
        # Create superuser
        python manage.py shell << 'PYTHON_EOF'
import os
from accounts.models import User
if not User.objects.filter(username='$ADMIN_USER').exists():
    User.objects.create_superuser(
        username='$ADMIN_USER',
        email='$ADMIN_EMAIL',
        password='$ADMIN_PASS',
        role='admin'
    )
    print('Created admin user: $ADMIN_USER')
else:
    print('Admin user already exists')
PYTHON_EOF
    "
}

# Create systemd services
create_systemd_services() {
    print_step "Creating systemd services..."
    
    # Django/Gunicorn service
    cat > /etc/systemd/system/noctis-web.service << EOF
[Unit]
Description=Noctis Pro Django Web Application
After=network.target postgresql.service redis.service
Requires=postgresql.service redis.service

[Service]
Type=notify
User=$APP_NAME
Group=$APP_NAME
WorkingDirectory=$APP_DIR/source
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
EnvironmentFile=$APP_DIR/.env
ExecStart=$VENV_DIR/bin/gunicorn \\
    --bind 127.0.0.1:8000 \\
    --workers 4 \\
    --worker-class gthread \\
    --threads 2 \\
    --max-requests 1000 \\
    --max-requests-jitter 100 \\
    --timeout 30 \\
    --keep-alive 2 \\
    --access-logfile $LOG_DIR/gunicorn-access.log \\
    --error-logfile $LOG_DIR/gunicorn-error.log \\
    --log-level info \\
    --capture-output \\
    noctis_pro.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=3
KillMode=mixed
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Celery worker service
    cat > /etc/systemd/system/noctis-celery.service << EOF
[Unit]
Description=Noctis Pro Celery Worker
After=network.target postgresql.service redis.service
Requires=postgresql.service redis.service

[Service]
Type=simple
User=$APP_NAME
Group=$APP_NAME
WorkingDirectory=$APP_DIR/source
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
EnvironmentFile=$APP_DIR/.env
ExecStart=$VENV_DIR/bin/celery -A noctis_pro worker --loglevel=info --concurrency=2
Restart=always
RestartSec=3
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

    # DICOM receiver service
    cat > /etc/systemd/system/noctis-dicom.service << EOF
[Unit]
Description=Noctis Pro DICOM Receiver
After=network.target postgresql.service redis.service
Requires=postgresql.service redis.service

[Service]
Type=simple
User=$APP_NAME
Group=$APP_NAME
WorkingDirectory=$APP_DIR/source
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
EnvironmentFile=$APP_DIR/.env
ExecStart=$VENV_DIR/bin/python dicom_receiver.py --port 11112 --aet NOCTIS_SCP
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    systemctl daemon-reload
}

# Configure Nginx
configure_nginx() {
    print_step "Configuring Nginx..."
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Create Noctis site configuration
    cat > /etc/nginx/sites-available/noctis << 'EOF'
upstream noctis_backend {
    server 127.0.0.1:8000;
}

server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy strict-origin-when-cross-origin;
    
    # Increase client_max_body_size for DICOM uploads
    client_max_body_size 100M;
    client_body_timeout 60s;
    client_header_timeout 60s;
    
    # Static files
    location /static/ {
        alias /opt/noctis/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Media files
    location /media/ {
        alias /opt/noctis/media/;
        expires 1y;
        add_header Cache-Control "public";
    }
    
    # Main application
    location / {
        proxy_pass http://noctis_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint
    location /health/ {
        access_log off;
        proxy_pass http://noctis_backend;
        proxy_set_header Host $host;
    }
}
EOF

    # Enable the site
    ln -sf /etc/nginx/sites-available/noctis /etc/nginx/sites-enabled/
    
    # Test and restart Nginx
    nginx -t
    systemctl enable nginx || echo "Warning: Could not enable Nginx service"
    systemctl restart nginx || echo "Warning: Could not restart Nginx service"
}

# Setup SSL with Let's Encrypt (if domain provided)
setup_ssl() {
    if [[ -n "$DOMAIN_NAME" ]]; then
        print_step "Setting up SSL certificate for $DOMAIN_NAME..."
        
        # Update Nginx config with domain
        sed -i "s/server_name _;/server_name $DOMAIN_NAME;/" /etc/nginx/sites-available/noctis
        systemctl reload nginx || echo "Warning: Could not reload Nginx service"
        
        # Get SSL certificate
        certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email $ADMIN_EMAIL --redirect
        
        # Setup auto-renewal
        systemctl enable certbot.timer
        systemctl start certbot.timer
    fi
}

# Create backup scripts
create_backup_scripts() {
    print_step "Creating backup scripts..."
    
    cat > $APP_DIR/backup.sh << EOF
#!/bin/bash
# Noctis Pro Backup Script

BACKUP_DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/backup_\$BACKUP_DATE"

mkdir -p "\$BACKUP_PATH"

# Backup database
if [[ "$USE_POSTGRES" == "true" ]]; then
    sudo -u postgres pg_dump $POSTGRES_DB > "\$BACKUP_PATH/database.sql"
else
    cp $APP_DIR/source/db.sqlite3 "\$BACKUP_PATH/" 2>/dev/null || true
fi

# Backup media files
tar -czf "\$BACKUP_PATH/media.tar.gz" -C $APP_DIR media/ 2>/dev/null || true

# Backup configuration
cp $APP_DIR/.env "\$BACKUP_PATH/" 2>/dev/null || true

# Remove backups older than 7 days
find $BACKUP_DIR -type d -name "backup_*" -mtime +7 -exec rm -rf {} + 2>/dev/null || true

echo "Backup completed: \$BACKUP_PATH"
EOF

    chmod +x $APP_DIR/backup.sh
    chown $APP_NAME:$APP_NAME $APP_DIR/backup.sh
    
    # Add to crontab for daily backups
    (crontab -u $APP_NAME -l 2>/dev/null; echo "0 2 * * * $APP_DIR/backup.sh") | crontab -u $APP_NAME -
}

# Create management scripts
create_management_scripts() {
    print_step "Creating management scripts..."
    
    # Status script
    cat > $APP_DIR/status.sh << EOF
#!/bin/bash
echo "=== Noctis Pro System Status ==="
echo
echo "Services:"
systemctl is-active --quiet noctis-web && echo "✅ Web Server: Running" || echo "❌ Web Server: Stopped"
systemctl is-active --quiet noctis-celery && echo "✅ Celery Worker: Running" || echo "❌ Celery Worker: Stopped"
systemctl is-active --quiet noctis-dicom && echo "✅ DICOM Receiver: Running" || echo "❌ DICOM Receiver: Stopped"
systemctl is-active --quiet postgresql && echo "✅ PostgreSQL: Running" || echo "❌ PostgreSQL: Stopped"
systemctl is-active --quiet redis && echo "✅ Redis: Running" || echo "❌ Redis: Stopped"
systemctl is-active --quiet nginx && echo "✅ Nginx: Running" || echo "❌ Nginx: Stopped"
echo
echo "Access URLs:"
if [[ -n "$DOMAIN_NAME" ]]; then
    echo "🌐 Main URL: https://$DOMAIN_NAME"
    echo "🛠️ Admin Panel: https://$DOMAIN_NAME/admin-panel/"
    echo "📋 Worklist: https://$DOMAIN_NAME/worklist/"
else
    LOCAL_IP=\$(hostname -I | awk '{print \$1}')
    echo "🌐 Main URL: http://\$LOCAL_IP"
    echo "🛠️ Admin Panel: http://\$LOCAL_IP/admin-panel/"
    echo "📋 Worklist: http://\$LOCAL_IP/worklist/"
fi
echo
echo "Disk Usage:"
df -h $APP_DIR | tail -1
echo
echo "Recent Logs:"
journalctl -u noctis-web --no-pager -n 3 --since "1 hour ago" 2>/dev/null || echo "No recent logs"
EOF

    chmod +x $APP_DIR/status.sh
    
    # Restart script
    cat > $APP_DIR/restart.sh << EOF
#!/bin/bash
echo "Restarting Noctis Pro services..."
systemctl restart noctis-web noctis-celery noctis-dicom
echo "Services restarted"
EOF

    chmod +x $APP_DIR/restart.sh
    
    # Update script
    cat > $APP_DIR/update.sh << EOF
#!/bin/bash
echo "Updating Noctis Pro..."
cd $APP_DIR/source
sudo -u $APP_NAME git pull
sudo -u $APP_NAME $VENV_DIR/bin/pip install -r requirements.txt
sudo -u $APP_NAME bash -c "source $VENV_DIR/bin/activate && export \$(cat $APP_DIR/.env | grep -v '^#' | xargs) && python manage.py migrate && python manage.py collectstatic --noinput"
systemctl restart noctis-web noctis-celery noctis-dicom
echo "Update completed"
EOF

    chmod +x $APP_DIR/update.sh
    
    chown $APP_NAME:$APP_NAME $APP_DIR/*.sh
}

# Setup log rotation
setup_log_rotation() {
    print_step "Setting up log rotation..."
    
    cat > /etc/logrotate.d/noctis << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 $APP_NAME $APP_NAME
    postrotate
        systemctl reload noctis-web noctis-celery noctis-dicom
    endscript
}
EOF
}

# Start services
start_services() {
    print_step "Starting services..."
    
    # Enable and start services
    systemctl enable noctis-web noctis-celery noctis-dicom
    systemctl start noctis-web noctis-celery noctis-dicom
    
    # Wait for services to start
    sleep 10
    
    # Check service status
    if systemctl is-active --quiet noctis-web && systemctl is-active --quiet noctis-celery && systemctl is-active --quiet noctis-dicom; then
        print_success "All services started successfully"
    else
        print_warning "Some services may not have started correctly. Check with: systemctl status noctis-web"
    fi
}

# Setup fail2ban
setup_fail2ban() {
    print_step "Configuring Fail2ban..."
    
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true

[nginx-http-auth]
enabled = true

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban
}

# Print deployment summary
print_deployment_summary() {
    echo
    echo -e "${GREEN}🎉 Noctis Pro deployment completed successfully!${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo
    echo -e "${GREEN}📊 System Information:${NC}"
    echo -e "   Application Directory: $APP_DIR"
    echo -e "   Log Directory: $LOG_DIR"
    echo -e "   Backup Directory: $BACKUP_DIR"
    echo
    echo -e "${GREEN}🌐 Access Information:${NC}"
    if [[ -n "$DOMAIN_NAME" ]]; then
        echo -e "   Main URL: ${CYAN}https://$DOMAIN_NAME${NC}"
        echo -e "   Admin Panel: ${CYAN}https://$DOMAIN_NAME/admin-panel/${NC}"
        echo -e "   Worklist: ${CYAN}https://$DOMAIN_NAME/worklist/${NC}"
    else
        LOCAL_IP=$(hostname -I | awk '{print $1}')
        echo -e "   Main URL: ${CYAN}http://$LOCAL_IP${NC}"
        echo -e "   Admin Panel: ${CYAN}http://$LOCAL_IP/admin-panel/${NC}"
        echo -e "   Worklist: ${CYAN}http://$LOCAL_IP/worklist/${NC}"
    fi
    echo
    echo -e "${GREEN}👤 Admin Credentials:${NC}"
    echo -e "   Username: ${YELLOW}$ADMIN_USER${NC}"
    echo -e "   Password: ${YELLOW}$ADMIN_PASS${NC}"
    echo -e "   Email: ${YELLOW}$ADMIN_EMAIL${NC}"
    echo
    echo -e "${GREEN}🔧 Management Commands:${NC}"
    echo -e "   Status: ${CYAN}$APP_DIR/status.sh${NC}"
    echo -e "   Restart: ${CYAN}$APP_DIR/restart.sh${NC}"
    echo -e "   Update: ${CYAN}$APP_DIR/update.sh${NC}"
    echo -e "   Backup: ${CYAN}$APP_DIR/backup.sh${NC}"
    echo
    echo -e "${GREEN}📝 Important Files:${NC}"
    echo -e "   Environment: ${CYAN}$APP_DIR/.env${NC}"
    echo -e "   Nginx Config: ${CYAN}/etc/nginx/sites-available/noctis${NC}"
    echo -e "   Service Logs: ${CYAN}journalctl -u noctis-web -f${NC}"
    echo
    echo -e "${YELLOW}💡 Next Steps:${NC}"
    echo -e "   1. Save the admin credentials in a secure location"
    echo -e "   2. Configure email settings in $APP_DIR/.env if needed"
    echo -e "   3. Set up regular backups with $APP_DIR/backup.sh"
    echo -e "   4. Monitor logs with: journalctl -u noctis-web -f"
    echo -e "   5. Test DICOM functionality on port 11112"
    echo
    echo -e "${BLUE}================================================${NC}"
}

# Main execution
main() {
    print_banner
    
    check_root
    check_ubuntu_version
    
    print_step "Starting Noctis Pro deployment for Ubuntu 24.04..."
    
    update_system
    install_dependencies
    configure_firewall
    setup_postgresql
    setup_redis
    setup_application_structure
    setup_python_environment
    create_environment_config
    setup_django
    create_systemd_services
    configure_nginx
    setup_ssl
    create_backup_scripts
    create_management_scripts
    setup_log_rotation
    setup_fail2ban
    start_services
    
    print_deployment_summary
}

# Run main function
main "$@"