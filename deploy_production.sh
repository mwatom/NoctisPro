#!/bin/bash
set -euo pipefail

# Noctis Pro Production Deployment Script for Ubuntu 22.04
# This script deploys the Noctis Pro DICOM system for production use
# Usage: sudo bash deploy_production.sh [domain_name] [admin_email]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="noctis"
APP_DIR="/opt/$APP_NAME"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/$APP_NAME"
DOMAIN_NAME="${1:-}"
ADMIN_EMAIL="${2:-admin@localhost}"
ADMIN_USER="admin"
ADMIN_PASS="$(openssl rand -base64 32)"
SECRET_KEY="$(openssl rand -base64 64)"

# Database configuration
USE_POSTGRES="${USE_POSTGRES:-true}"
POSTGRES_DB="noctis_pro"
POSTGRES_USER="noctis_user"
POSTGRES_PASS="$(openssl rand -base64 32)"

# Print banner
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
║                   PRODUCTION DEPLOYMENT                       ║
║               DICOM Medical Imaging System                    ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}🚀 Starting Noctis Pro Production Deployment for Ubuntu 22.04${NC}\n"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root. Please use sudo.${NC}"
    exit 1
fi

# Update system
echo -e "${YELLOW}📦 Updating system packages...${NC}"
apt-get update -q
apt-get upgrade -y -q

# Install system dependencies
echo -e "${YELLOW}🔧 Installing system dependencies...${NC}"
apt-get install -y -q \
    python3 python3-venv python3-dev python3-pip \
    build-essential pkg-config \
    libpq-dev libjpeg-dev zlib1g-dev libopenjp2-7 \
    libssl-dev libffi-dev libxml2-dev libxslt1-dev \
    git curl wget unzip htop tree \
    nginx redis-server \
    software-properties-common apt-transport-https \
    ca-certificates gnupg lsb-release \
    ufw fail2ban logrotate \
    certbot python3-certbot-nginx

# Install PostgreSQL if requested
if [[ "$USE_POSTGRES" == "true" ]]; then
    echo -e "${YELLOW}🐘 Installing PostgreSQL...${NC}"
    apt-get install -y -q postgresql postgresql-contrib
    
    # Configure PostgreSQL
    sudo -u postgres createuser --createdb "$POSTGRES_USER" || true
    sudo -u postgres psql -c "ALTER USER $POSTGRES_USER PASSWORD '$POSTGRES_PASS';" || true
    sudo -u postgres createdb "$POSTGRES_DB" --owner="$POSTGRES_USER" || true
fi

# Create noctis user
echo -e "${YELLOW}👤 Creating noctis user...${NC}"
if ! id "noctis" &>/dev/null; then
    useradd --system --create-home --shell /bin/bash noctis
fi

# Create directories
echo -e "${YELLOW}📁 Setting up directories...${NC}"
mkdir -p "$APP_DIR" "$LOG_DIR" /var/www/html
chown -R noctis:noctis "$APP_DIR" "$LOG_DIR"

# Copy application files
echo -e "${YELLOW}📋 Copying application files...${NC}"
if [ -f "manage.py" ]; then
    cp -r . "$APP_DIR/"
    chown -R noctis:noctis "$APP_DIR"
else
    echo -e "${RED}❌ No Django application found. Please run this script from the project root.${NC}"
    exit 1
fi

# Set up Python virtual environment
echo -e "${YELLOW}🐍 Setting up Python virtual environment...${NC}"
sudo -u noctis python3 -m venv "$VENV_DIR"
sudo -u noctis "$VENV_DIR/bin/pip" install --upgrade pip wheel setuptools

# Install Python requirements
echo -e "${YELLOW}📦 Installing Python dependencies...${NC}"
sudo -u noctis "$VENV_DIR/bin/pip" install -r "$APP_DIR/requirements.txt"

# Create environment file
echo -e "${YELLOW}⚙️ Creating environment configuration...${NC}"
cat > "$APP_DIR/.env" << EOF
# Django settings
SECRET_KEY=$SECRET_KEY
DEBUG=False
DJANGO_SETTINGS_MODULE=noctis_pro.settings_production

# Domain and network
DOMAIN_NAME=$DOMAIN_NAME
SERVER_IP=$(hostname -I | awk '{print $1}')
USE_SSL=false

# Database
EOF

if [[ "$USE_POSTGRES" == "true" ]]; then
    cat >> "$APP_DIR/.env" << EOF
POSTGRES_DB=$POSTGRES_DB
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASS
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
EOF
fi

cat >> "$APP_DIR/.env" << EOF

# Redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_DB=0
CELERY_BROKER_URL=redis://127.0.0.1:6379/0
CELERY_RESULT_BACKEND=redis://127.0.0.1:6379/0

# Admin
ADMIN_URL=admin-panel/

# Email (configure as needed)
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
DEFAULT_FROM_EMAIL=noctis@$DOMAIN_NAME
EOF

chown noctis:noctis "$APP_DIR/.env"
chmod 600 "$APP_DIR/.env"

# Django setup
echo -e "${YELLOW}🗃️ Setting up Django...${NC}"
cd "$APP_DIR"
sudo -u noctis -E "$VENV_DIR/bin/python" manage.py migrate --noinput
sudo -u noctis -E "$VENV_DIR/bin/python" manage.py collectstatic --noinput

# Create admin user
echo -e "${YELLOW}👤 Creating admin user...${NC}"
sudo -u noctis -E "$VENV_DIR/bin/python" -c "
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings_production')
django.setup()
from accounts.models import User
if not User.objects.filter(username='$ADMIN_USER').exists():
    User.objects.create_superuser(username='$ADMIN_USER', email='$ADMIN_EMAIL', password='$ADMIN_PASS', role='admin')
    print('Created admin user: $ADMIN_USER')
else:
    print('Admin user already exists')
"

# Install systemd services
echo -e "${YELLOW}⚙️ Installing systemd services...${NC}"
cp "$APP_DIR/deployment/systemd/"*.service /etc/systemd/system/
systemctl daemon-reload

# Enable services
systemctl enable redis-server
systemctl enable noctis-web.service
systemctl enable noctis-celery.service
systemctl enable noctis-dicom.service

# Configure Nginx
echo -e "${YELLOW}🌐 Configuring Nginx...${NC}"
cp "$APP_DIR/deployment/nginx/noctis-pro" /etc/nginx/sites-available/
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/noctis-pro /etc/nginx/sites-enabled/

# Update Nginx config with domain name if provided
if [[ -n "$DOMAIN_NAME" ]]; then
    sed -i "s/server_name _;/server_name $DOMAIN_NAME;/" /etc/nginx/sites-available/noctis-pro
    sed -i "s/DOMAIN_NAME/$DOMAIN_NAME/g" /etc/nginx/sites-available/noctis-pro
fi

# Test Nginx configuration
nginx -t

# Configure firewall
echo -e "${YELLOW}🔥 Configuring firewall...${NC}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw allow 11112/tcp  # DICOM port
ufw --force enable

# Configure fail2ban
echo -e "${YELLOW}🛡️ Configuring fail2ban...${NC}"
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true

[nginx-http-auth]
enabled = true

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
action = iptables-multiport[name=ReqLimit, port="http,https", protocol=tcp]
logpath = /var/log/nginx/*error.log
findtime = 600
bantime = 7200
maxretry = 10
EOF

# Configure log rotation
echo -e "${YELLOW}📋 Configuring log rotation...${NC}"
cat > /etc/logrotate.d/noctis << 'EOF'
/var/log/noctis/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 noctis noctis
    postrotate
        systemctl reload noctis-web noctis-celery noctis-dicom
    endscript
}
EOF

# Start services
echo -e "${YELLOW}🚀 Starting services...${NC}"
systemctl start redis-server
systemctl start noctis-web.service
systemctl start noctis-celery.service
systemctl start noctis-dicom.service
systemctl restart nginx
systemctl start fail2ban

# Wait for services to start
sleep 5

# Health check
echo -e "${YELLOW}🏥 Performing health check...${NC}"
check_service() {
    local service=$1
    if systemctl is-active --quiet "$service"; then
        echo -e "  ✅ $service: ${GREEN}Running${NC}"
    else
        echo -e "  ❌ $service: ${RED}Failed${NC}"
        return 1
    fi
}

echo "Service Status:"
check_service redis-server
check_service noctis-web.service
check_service noctis-celery.service
check_service noctis-dicom.service
check_service nginx
check_service fail2ban

# Test web service
if curl -s http://localhost/health > /dev/null; then
    echo -e "  ✅ Web service: ${GREEN}Responding${NC}"
else
    echo -e "  ❌ Web service: ${RED}Not responding${NC}"
fi

# SSL Setup if domain provided
if [[ -n "$DOMAIN_NAME" ]]; then
    echo -e "${YELLOW}🔒 Setting up SSL with Let's Encrypt...${NC}"
    
    # Update environment for SSL
    sed -i 's/USE_SSL=false/USE_SSL=true/' "$APP_DIR/.env"
    
    # Get SSL certificate
    if certbot --nginx --non-interactive --agree-tos --email "$ADMIN_EMAIL" -d "$DOMAIN_NAME"; then
        echo -e "  ✅ SSL certificate obtained successfully"
        
        # Enable SSL in Nginx config
        sed -i 's/# listen 443 ssl http2;/listen 443 ssl http2;/' /etc/nginx/sites-available/noctis-pro
        sed -i 's/# listen \[::\]:443 ssl http2;/listen [::]:443 ssl http2;/' /etc/nginx/sites-available/noctis-pro
        sed -i "s|# ssl_certificate /etc/letsencrypt/live/DOMAIN_NAME/|ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/|" /etc/nginx/sites-available/noctis-pro
        sed -i 's/# ssl_/ssl_/g' /etc/nginx/sites-available/noctis-pro
        sed -i 's/# add_header Strict-Transport-Security/add_header Strict-Transport-Security/' /etc/nginx/sites-available/noctis-pro
        
        # Test and reload Nginx
        nginx -t && systemctl reload nginx
        
        # Restart services to pick up SSL changes
        systemctl restart noctis-web.service
    else
        echo -e "  ⚠️ SSL certificate setup failed. Continuing with HTTP only."
    fi
fi

# Create management script
echo -e "${YELLOW}🛠️ Creating management scripts...${NC}"
cat > /usr/local/bin/noctis-ctl << 'EOF'
#!/bin/bash
# Noctis Pro Management Script

case "$1" in
    start)
        systemctl start noctis-web noctis-celery noctis-dicom
        echo "Noctis Pro services started"
        ;;
    stop)
        systemctl stop noctis-web noctis-celery noctis-dicom
        echo "Noctis Pro services stopped"
        ;;
    restart)
        systemctl restart noctis-web noctis-celery noctis-dicom
        echo "Noctis Pro services restarted"
        ;;
    status)
        systemctl status noctis-web noctis-celery noctis-dicom
        ;;
    logs)
        journalctl -f -u noctis-web -u noctis-celery -u noctis-dicom
        ;;
    update)
        cd /opt/noctis
        git pull
        sudo -u noctis /opt/noctis/venv/bin/pip install -r requirements.txt
        sudo -u noctis /opt/noctis/venv/bin/python manage.py migrate
        sudo -u noctis /opt/noctis/venv/bin/python manage.py collectstatic --noinput
        systemctl restart noctis-web noctis-celery noctis-dicom
        echo "Noctis Pro updated and restarted"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|update}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/noctis-ctl

# Save credentials
cat > "$APP_DIR/DEPLOYMENT_INFO.txt" << EOF
Noctis Pro Deployment Information
=====================================

Deployment Date: $(date)
Server IP: $(hostname -I | awk '{print $1}')
Domain: $DOMAIN_NAME

Admin Credentials:
------------------
Username: $ADMIN_USER
Password: $ADMIN_PASS
Email: $ADMIN_EMAIL

Database Credentials (PostgreSQL):
-----------------------------------
EOF

if [[ "$USE_POSTGRES" == "true" ]]; then
    cat >> "$APP_DIR/DEPLOYMENT_INFO.txt" << EOF
Database: $POSTGRES_DB
Username: $POSTGRES_USER
Password: $POSTGRES_PASS
EOF
else
    cat >> "$APP_DIR/DEPLOYMENT_INFO.txt" << EOF
Database: SQLite (db.sqlite3)
EOF
fi

cat >> "$APP_DIR/DEPLOYMENT_INFO.txt" << EOF

Secret Key: $SECRET_KEY

Access URLs:
------------
EOF

if [[ -n "$DOMAIN_NAME" ]]; then
    cat >> "$APP_DIR/DEPLOYMENT_INFO.txt" << EOF
Main Site: https://$DOMAIN_NAME/
Admin Panel: https://$DOMAIN_NAME/admin-panel/
Worklist: https://$DOMAIN_NAME/worklist/
EOF
else
    cat >> "$APP_DIR/DEPLOYMENT_INFO.txt" << EOF
Main Site: http://$(hostname -I | awk '{print $1}')/
Admin Panel: http://$(hostname -I | awk '{print $1}')/admin-panel/
Worklist: http://$(hostname -I | awk '{print $1}')/worklist/
EOF
fi

cat >> "$APP_DIR/DEPLOYMENT_INFO.txt" << EOF

DICOM Port: 11112

Management Commands:
--------------------
Start services: noctis-ctl start
Stop services: noctis-ctl stop
Restart services: noctis-ctl restart
Check status: noctis-ctl status
View logs: noctis-ctl logs
Update system: noctis-ctl update

Service Logs:
-------------
Application: /var/log/noctis/noctis_pro.log
Errors: /var/log/noctis/noctis_pro_errors.log
Nginx Access: /var/log/nginx/noctis_access.log
Nginx Errors: /var/log/nginx/noctis_error.log

Security:
---------
Firewall: UFW enabled
Fail2ban: Active
SSL: $([ -n "$DOMAIN_NAME" ] && echo "Enabled via Let's Encrypt" || echo "Disabled (no domain provided)")

NOTE: Save this file securely and delete it from the server after copying the credentials!
EOF

chmod 600 "$APP_DIR/DEPLOYMENT_INFO.txt"

# Final output
echo
echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${BLUE}===========================================${NC}"
echo -e "${GREEN}🎉 Noctis Pro DICOM System is now running!${NC}"
echo
echo -e "${PURPLE}📊 Access Information:${NC}"
if [[ -n "$DOMAIN_NAME" ]]; then
    echo -e "${GREEN}🌐 Main Site:${NC} https://$DOMAIN_NAME/"
    echo -e "${GREEN}🛠️ Admin Panel:${NC} https://$DOMAIN_NAME/admin-panel/"
    echo -e "${GREEN}📋 Worklist:${NC} https://$DOMAIN_NAME/worklist/"
else
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo -e "${GREEN}🌐 Main Site:${NC} http://$SERVER_IP/"
    echo -e "${GREEN}🛠️ Admin Panel:${NC} http://$SERVER_IP/admin-panel/"
    echo -e "${GREEN}📋 Worklist:${NC} http://$SERVER_IP/worklist/"
fi
echo
echo -e "${PURPLE}👤 Admin Credentials:${NC}"
echo -e "   Username: ${GREEN}$ADMIN_USER${NC}"
echo -e "   Password: ${GREEN}$ADMIN_PASS${NC}"
echo
echo -e "${PURPLE}🔧 Management Commands:${NC}"
echo -e "   Control services: ${BLUE}noctis-ctl {start|stop|restart|status|logs|update}${NC}"
echo -e "   View deployment info: ${BLUE}cat $APP_DIR/DEPLOYMENT_INFO.txt${NC}"
echo
echo -e "${YELLOW}⚠️ Important Security Notes:${NC}"
echo -e "   • Save the admin password from $APP_DIR/DEPLOYMENT_INFO.txt"
echo -e "   • Delete DEPLOYMENT_INFO.txt after saving credentials"
echo -e "   • Change default passwords for production use"
echo -e "   • Configure email settings in the Django admin"
if [[ -z "$DOMAIN_NAME" ]]; then
    echo -e "   • Set up SSL by re-running with a domain name"
fi
echo
echo -e "${BLUE}===========================================${NC}"
echo -e "${GREEN}🚀 Noctis Pro is ready for production use!${NC}"