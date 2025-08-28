#!/bin/bash

# 🏥 NoctisPro Production Deployment Script
# Ubuntu Server Auto-Startup Configuration

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root for system service configuration"
    fi
}

# Install required system packages
install_system_packages() {
    log "📦 Installing system packages..."
    
    apt-get update
    apt-get install -y \
        curl \
        wget \
        git \
        python3 \
        python3-pip \
        python3-venv \
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
        lsb-release
    
    info "System packages installed"
}

# Install Docker
install_docker() {
    log "🐳 Installing Docker..."
    
    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Install Docker Compose standalone
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    info "Docker installed and configured"
}

# Install ngrok
install_ngrok() {
    log "🌐 Installing ngrok..."
    
    # Download and install ngrok
    wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    tar xzf ngrok-v3-stable-linux-amd64.tgz
    mv ngrok /usr/local/bin/
    chmod +x /usr/local/bin/ngrok
    rm ngrok-v3-stable-linux-amd64.tgz
    
    info "ngrok installed"
}

# Setup application directory
setup_application() {
    log "📁 Setting up application directory..."
    
    INSTALL_DIR="/opt/noctispro"
    
    # Create application directory
    mkdir -p $INSTALL_DIR
    mkdir -p $INSTALL_DIR/logs
    mkdir -p $INSTALL_DIR/backups
    
    # Copy application files
    cp -r . $INSTALL_DIR/
    chmod +x $INSTALL_DIR/*.sh
    
    # Set proper ownership
    chown -R root:root $INSTALL_DIR
    
    info "Application copied to $INSTALL_DIR"
}

# Generate secure credentials
generate_credentials() {
    log "🔐 Generating secure credentials..."
    
    # Generate secret key
    SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(50))')
    
    # Generate database password
    DB_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')
    
    # Update environment file
    sed -i "s/SECRET_KEY=.*/SECRET_KEY=$SECRET_KEY/" /opt/noctispro/.env.production
    sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$DB_PASSWORD/" /opt/noctispro/.env.production
    
    info "Secure credentials generated"
}

# Configure admin user
configure_admin_user() {
    log "👤 Configuring admin user..."
    
    read -p "Enter admin email: " ADMIN_EMAIL
    read -s -p "Enter admin password: " ADMIN_PASSWORD
    echo
    
    # Update environment file
    sed -i "s/ADMIN_EMAIL=.*/ADMIN_EMAIL=$ADMIN_EMAIL/" /opt/noctispro/.env.production
    sed -i "s/ADMIN_PASSWORD=.*/ADMIN_PASSWORD=$ADMIN_PASSWORD/" /opt/noctispro/.env.production
    
    info "Admin user configured"
}

# Setup systemd services
setup_systemd_services() {
    log "⚙️  Setting up systemd services..."
    
    # Copy service files
    cp /opt/noctispro/noctispro-production.service /etc/systemd/system/
    cp /opt/noctispro/noctispro-ngrok.service /etc/systemd/system/
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable services
    systemctl enable noctispro-production.service
    systemctl enable noctispro-ngrok.service
    
    info "Systemd services configured"
}

# Deploy application
deploy_application() {
    log "🚀 Deploying application..."
    
    cd /opt/noctispro
    
    # Build and start services
    docker-compose -f docker-compose.production.yml build --no-cache
    docker-compose -f docker-compose.production.yml up -d
    
    # Wait for services to start
    sleep 30
    
    # Run migrations and setup
    docker-compose -f docker-compose.production.yml exec -T web python manage.py migrate --noinput
    docker-compose -f docker-compose.production.yml exec -T web python manage.py collectstatic --noinput
    
    # Create admin user if credentials were provided
    if [ ! -z "$ADMIN_PASSWORD" ]; then
        docker-compose -f docker-compose.production.yml exec -T web python manage.py shell << EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser(
        username='admin',
        email='$ADMIN_EMAIL',
        password='$ADMIN_PASSWORD'
    )
    print('Admin user created')
EOF
    fi
    
    info "Application deployed"
}

# Start services
start_services() {
    log "▶️  Starting services..."
    
    systemctl start noctispro-production.service
    systemctl start noctispro-ngrok.service
    
    info "Services started"
}

# Test deployment
test_deployment() {
    log "🧪 Testing deployment..."
    
    # Wait for services to be ready
    sleep 60
    
    # Test local access
    if curl -s http://localhost:8000/health/simple/ > /dev/null; then
        info "✅ Local access working"
    else
        warning "⚠️ Local access test failed"
    fi
    
    # Test ngrok tunnel
    if curl -s https://colt-charmed-lark.ngrok-free.app/health/simple/ > /dev/null; then
        info "✅ Ngrok tunnel working"
    else
        warning "⚠️ Ngrok tunnel test failed"
    fi
    
    info "Deployment testing completed"
}

# Display final information
display_final_info() {
    log "📋 Production Deployment Complete!"
    echo
    echo "🌐 Access URLs:"
    echo "  Local:     http://localhost:8000"
    echo "  Remote:    https://colt-charmed-lark.ngrok-free.app"
    echo
    echo "🔧 Service Management:"
    echo "  Start:     sudo systemctl start noctispro-production noctispro-ngrok"
    echo "  Stop:      sudo systemctl stop noctispro-production noctispro-ngrok"
    echo "  Status:    sudo systemctl status noctispro-production noctispro-ngrok"
    echo "  Restart:   sudo systemctl restart noctispro-production noctispro-ngrok"
    echo
    echo "📊 Monitoring:"
    echo "  Logs:      sudo journalctl -u noctispro-production -f"
    echo "  Ngrok:     sudo journalctl -u noctispro-ngrok -f"
    echo "  Docker:    cd /opt/noctispro && docker-compose -f docker-compose.production.yml logs -f"
    echo
    echo "🔒 Security:"
    echo "  - Change default passwords after first login"
    echo "  - Configure firewall rules as needed"
    echo "  - Set up SSL certificates for custom domains"
    echo
    echo "✅ NoctisPro is now running as a system service and will auto-start on boot!"
}

# Main deployment function
main() {
    echo
    echo "🏥 NoctisPro Production Deployment"
    echo "=================================="
    echo
    
    check_root
    install_system_packages
    install_docker
    install_ngrok
    setup_application
    generate_credentials
    configure_admin_user
    setup_systemd_services
    deploy_application
    start_services
    test_deployment
    display_final_info
    
    log "✅ Production deployment completed successfully!"
}

# Run main function
main "$@"