#!/bin/bash
set -euo pipefail

# Noctis Pro Docker Deployment Script for Ubuntu 24.04
# Usage: sudo bash deploy_docker_ubuntu24.sh [domain_name] [admin_email]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DOMAIN_NAME="${1:-}"
ADMIN_EMAIL="${2:-admin@localhost}"
DEPLOYMENT_DIR="/opt/noctis"
COMPOSE_FILE="docker-compose.production.yml"

# Generate secure passwords
POSTGRES_PASSWORD="$(openssl rand -base64 32 | tr -d '=' | head -c 24)"
SECRET_KEY="$(openssl rand -base64 64 | tr -d '=' | head -c 50)"
ADMIN_PASSWORD="$(openssl rand -base64 32 | tr -d '=' | head -c 24)"

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
║               DOCKER DEPLOYMENT - UBUNTU 24.04               ║
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

# Update system
update_system() {
    print_step "Updating system packages..."
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y curl wget gnupg lsb-release ca-certificates
}

# Install Docker
install_docker() {
    print_step "Installing Docker..."
    
    # Remove old Docker installations
    apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl enable docker
    systemctl start docker
    
    # Add current user to docker group if not root
    if [[ $SUDO_USER ]]; then
        usermod -aG docker $SUDO_USER
        print_success "Added $SUDO_USER to docker group"
    fi
}

# Configure firewall
configure_firewall() {
    print_step "Configuring UFW firewall..."
    apt-get install -y ufw
    
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 11112/tcp  # DICOM receiver
    ufw --force enable
}

# Setup deployment directory
setup_deployment_directory() {
    print_step "Setting up deployment directory..."
    
    mkdir -p $DEPLOYMENT_DIR
    cd $DEPLOYMENT_DIR
    
    # Copy application files
    if [ -f "/workspace/manage.py" ]; then
        cp -r /workspace/* . 2>/dev/null || true
        cp -r /workspace/.* . 2>/dev/null || true
    else
        print_error "No Django application found. Please ensure you're running from the project root."
        exit 1
    fi
    
    # Create required directories
    mkdir -p logs ssl backups
    mkdir -p data/{postgres,redis}
    mkdir -p media staticfiles dicom_storage
    mkdir -p deployment/{nginx,postgres,redis,backup,prometheus,grafana}
}

# Create environment file
create_environment_file() {
    print_step "Creating environment configuration..."
    
    # Determine allowed hosts
    ALLOWED_HOSTS="localhost,127.0.0.1"
    if [[ -n "$DOMAIN_NAME" ]]; then
        ALLOWED_HOSTS="$ALLOWED_HOSTS,$DOMAIN_NAME"
    fi
    
    cat > .env << EOF
# Django Configuration
SECRET_KEY=$SECRET_KEY
DEBUG=False
DJANGO_SETTINGS_MODULE=noctis_pro.settings
ALLOWED_HOSTS=$ALLOWED_HOSTS

# Database Configuration
POSTGRES_DB=noctis_pro
POSTGRES_USER=noctis_user
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Redis Configuration
REDIS_URL=redis://redis:6379/0
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# Admin Configuration
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASSWORD

# Security Configuration
SECURE_SSL_REDIRECT=${SECURE_SSL_REDIRECT:-False}
SECURE_HSTS_SECONDS=31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS=True
SECURE_HSTS_PRELOAD=True

# Email Configuration (configure as needed)
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
DEFAULT_FROM_EMAIL=noctis@${DOMAIN_NAME:-localhost}

# Monitoring (optional)
GRAFANA_PASSWORD=$ADMIN_PASSWORD
EOF

    chmod 600 .env
}

# Create Docker configurations
create_docker_configs() {
    print_step "Creating Docker configuration files..."
    
    # Nginx configuration
    mkdir -p deployment/nginx/sites-available
    cat > deployment/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;
    
    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Security
    server_tokens off;
    
    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # Include site configs
    include /etc/nginx/conf.d/*.conf;
}
EOF

    cat > deployment/nginx/sites-available/noctis.conf << 'EOF'
upstream noctis_backend {
    server web:8000;
}

server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy strict-origin-when-cross-origin;
    
    # File upload limits for DICOM
    client_max_body_size 500M;
    client_body_timeout 300s;
    client_header_timeout 60s;
    
    # Static files
    location /static/ {
        alias /var/www/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Media files
    location /media/ {
        alias /var/www/media/;
        expires 1d;
        add_header Cache-Control "public";
    }
    
    # Health check
    location /health/ {
        access_log off;
        proxy_pass http://noctis_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
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
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF

    # Redis configuration
    cat > deployment/redis/redis.conf << 'EOF'
# Redis production configuration
port 6379
bind 0.0.0.0

# Memory management
maxmemory 512mb
maxmemory-policy allkeys-lru

# Persistence
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /data

# Append only file
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# Logging
loglevel notice
logfile ""

# Security
# requirepass yourpassword  # Uncomment and set password if needed
EOF

    # PostgreSQL initialization
    cat > deployment/postgres/init.sql << 'EOF'
-- PostgreSQL initialization script
-- Create extensions if needed
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Set timezone
SET timezone = 'UTC';
EOF

    # Backup script
    cat > deployment/backup/backup.sh << 'EOF'
#!/bin/bash
# Docker backup script

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="/app/backups/backup_$BACKUP_DATE"

mkdir -p "$BACKUP_PATH"

# Backup database
echo "Backing up database..."
pg_dump -h db -U $POSTGRES_USER -d $POSTGRES_DB > "$BACKUP_PATH/database.sql"

# Backup media files
echo "Backing up media files..."
tar -czf "$BACKUP_PATH/media.tar.gz" -C /app media/ 2>/dev/null || true

# Remove old backups (keep 7 days)
find /app/backups -type d -name "backup_*" -mtime +7 -exec rm -rf {} + 2>/dev/null || true

echo "Backup completed: $BACKUP_PATH"
EOF

    chmod +x deployment/backup/backup.sh
}

# Install SSL certificate
setup_ssl() {
    if [[ -n "$DOMAIN_NAME" ]]; then
        print_step "Setting up SSL certificate for $DOMAIN_NAME..."
        
        # Install certbot
        apt-get install -y certbot
        
        # Update Nginx config with domain
        sed -i "s/server_name _;/server_name $DOMAIN_NAME;/" deployment/nginx/sites-available/noctis.conf
        
        # Start containers to get certificate
        docker compose -f $COMPOSE_FILE up -d nginx
        sleep 10
        
        # Get certificate
        certbot certonly --webroot -w deployment/nginx/ssl -d $DOMAIN_NAME \
            --non-interactive --agree-tos --email $ADMIN_EMAIL
        
        # Update Nginx config for SSL
        cat >> deployment/nginx/sites-available/noctis.conf << EOF

server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    
    # SSL Security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # Same location blocks as HTTP version
    client_max_body_size 500M;
    client_body_timeout 300s;
    client_header_timeout 60s;
    
    location /static/ {
        alias /var/www/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias /var/www/media/;
        expires 1d;
        add_header Cache-Control "public";
    }
    
    location /health/ {
        access_log off;
        proxy_pass http://noctis_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location / {
        proxy_pass http://noctis_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}
EOF
        
        # Update environment for SSL
        sed -i 's/SECURE_SSL_REDIRECT=False/SECURE_SSL_REDIRECT=True/' .env
        
        # Setup auto-renewal
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet && docker compose -f $DEPLOYMENT_DIR/$COMPOSE_FILE restart nginx") | crontab -
    fi
}

# Deploy with Docker Compose
deploy_containers() {
    print_step "Deploying containers with Docker Compose..."
    
    # Build and start containers
    docker compose -f $COMPOSE_FILE build
    docker compose -f $COMPOSE_FILE up -d
    
    # Wait for services to be ready
    print_step "Waiting for services to start..."
    sleep 30
    
    # Check container health
    for service in db redis web celery nginx; do
        if docker compose -f $COMPOSE_FILE ps $service | grep -q "Up"; then
            print_success "$service container is running"
        else
            print_warning "$service container may have issues"
        fi
    done
}

# Create management scripts
create_management_scripts() {
    print_step "Creating management scripts..."
    
    # Status script
    cat > status.sh << EOF
#!/bin/bash
echo "=== Noctis Pro Docker Status ==="
echo
docker compose -f $COMPOSE_FILE ps
echo
echo "=== Container Logs (last 10 lines) ==="
docker compose -f $COMPOSE_FILE logs --tail=10
echo
echo "=== System Resources ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
echo
echo "=== Access URLs ==="
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
EOF

    # Restart script
    cat > restart.sh << EOF
#!/bin/bash
echo "Restarting Noctis Pro containers..."
docker compose -f $COMPOSE_FILE restart
echo "Containers restarted"
EOF

    # Update script
    cat > update.sh << EOF
#!/bin/bash
echo "Updating Noctis Pro..."
git pull
docker compose -f $COMPOSE_FILE build
docker compose -f $COMPOSE_FILE up -d
echo "Update completed"
EOF

    # Backup script
    cat > backup.sh << EOF
#!/bin/bash
echo "Running backup..."
docker compose -f $COMPOSE_FILE exec -T backup /app/backup.sh
echo "Backup completed"
EOF

    # Logs script
    cat > logs.sh << EOF
#!/bin/bash
SERVICE=\${1:-web}
docker compose -f $COMPOSE_FILE logs -f \$SERVICE
EOF

    # Make scripts executable
    chmod +x *.sh
}

# Print deployment summary
print_deployment_summary() {
    echo
    echo -e "${GREEN}🎉 Noctis Pro Docker deployment completed successfully!${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo
    echo -e "${GREEN}📊 Deployment Information:${NC}"
    echo -e "   Deployment Directory: $DEPLOYMENT_DIR"
    echo -e "   Docker Compose File: $COMPOSE_FILE"
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
    echo -e "   Username: ${YELLOW}admin${NC}"
    echo -e "   Password: ${YELLOW}$ADMIN_PASSWORD${NC}"
    echo -e "   Email: ${YELLOW}$ADMIN_EMAIL${NC}"
    echo
    echo -e "${GREEN}🔧 Management Commands:${NC}"
    echo -e "   Status: ${CYAN}$DEPLOYMENT_DIR/status.sh${NC}"
    echo -e "   Restart: ${CYAN}$DEPLOYMENT_DIR/restart.sh${NC}"
    echo -e "   Update: ${CYAN}$DEPLOYMENT_DIR/update.sh${NC}"
    echo -e "   Backup: ${CYAN}$DEPLOYMENT_DIR/backup.sh${NC}"
    echo -e "   Logs: ${CYAN}$DEPLOYMENT_DIR/logs.sh [service]${NC}"
    echo
    echo -e "${GREEN}🐳 Docker Commands:${NC}"
    echo -e "   View containers: ${CYAN}docker compose -f $COMPOSE_FILE ps${NC}"
    echo -e "   View logs: ${CYAN}docker compose -f $COMPOSE_FILE logs -f${NC}"
    echo -e "   Restart services: ${CYAN}docker compose -f $COMPOSE_FILE restart${NC}"
    echo -e "   Stop all: ${CYAN}docker compose -f $COMPOSE_FILE down${NC}"
    echo
    echo -e "${YELLOW}💡 Next Steps:${NC}"
    echo -e "   1. Save the admin credentials in a secure location"
    echo -e "   2. Test the DICOM receiver on port 11112"
    echo -e "   3. Configure email settings in .env if needed"
    echo -e "   4. Set up monitoring (optional): docker compose --profile monitoring up -d"
    echo -e "   5. Monitor logs: $DEPLOYMENT_DIR/logs.sh"
    echo
    echo -e "${BLUE}================================================${NC}"
}

# Main execution
main() {
    print_banner
    
    check_root
    check_ubuntu_version
    
    print_step "Starting Noctis Pro Docker deployment for Ubuntu 24.04..."
    
    update_system
    install_docker
    configure_firewall
    setup_deployment_directory
    create_environment_file
    create_docker_configs
    deploy_containers
    setup_ssl
    create_management_scripts
    
    print_deployment_summary
}

# Run main function
main "$@"