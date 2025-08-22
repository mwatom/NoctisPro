#!/bin/bash

# NoctisPro Internet Production Deployment Script
# Ubuntu Server 24.04 - Complete Setup for Internet Access
# This script fixes all deployment issues and gets the system online

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check if running as root or with sudo
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        log_info "Running as root"
        SUDO=""
    elif sudo -n true 2>/dev/null; then
        log_info "Running with sudo privileges"
        SUDO="sudo"
    else
        log_error "This script requires root privileges or sudo access"
        exit 1
    fi
}

# Install Docker if not present
install_docker() {
    log_info "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        $SUDO sh get-docker.sh
        $SUDO usermod -aG docker $USER
        rm get-docker.sh
        log_success "Docker installed successfully"
    else
        log_info "Docker already installed"
    fi
    
    # Install Docker Compose if not present
    if ! command -v docker-compose &> /dev/null; then
        log_info "Installing Docker Compose..."
        $SUDO apt-get update
        $SUDO apt-get install -y docker-compose-plugin
        log_success "Docker Compose installed"
    else
        log_info "Docker Compose already available"
    fi
}

# Start Docker daemon
start_docker() {
    log_info "Starting Docker daemon..."
    
    # Kill any existing Docker processes
    $SUDO pkill -f dockerd 2>/dev/null || true
    sleep 2
    
    # Start Docker daemon
    $SUDO dockerd > /tmp/docker.log 2>&1 &
    DOCKER_PID=$!
    
    # Wait for Docker to be ready
    log_info "Waiting for Docker to start..."
    for i in {1..30}; do
        if $SUDO docker info >/dev/null 2>&1; then
            log_success "Docker is running!"
            break
        fi
        sleep 1
        echo "   Attempt $i/30..."
    done
    
    # Check if Docker is running
    if ! $SUDO docker info >/dev/null 2>&1; then
        log_error "Failed to start Docker daemon"
        exit 1
    fi
}

# Create required directories
create_directories() {
    log_info "Creating required directories..."
    
    # Host directories for volume mounts
    $SUDO mkdir -p /opt/noctis/data/{postgres,redis}
    $SUDO mkdir -p /opt/noctis/{media,staticfiles,backups,dicom_storage}
    $SUDO chown -R $USER:$USER /opt/noctis
    
    # Local directories
    mkdir -p logs/nginx
    mkdir -p ssl
    mkdir -p backups
    
    log_success "All directories created"
}

# Update environment for internet access
update_environment() {
    log_info "Updating environment configuration for internet access..."
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    # Update .env.production for internet access
    if [ -f ".env.production" ]; then
        # Update ALLOWED_HOSTS to include server IP and wildcard
        sed -i "s/ALLOWED_HOSTS=.*/ALLOWED_HOSTS=localhost,127.0.0.1,noctis-server,$SERVER_IP,*/" .env.production
        
        # Update domain name to server IP if not already set
        if grep -q "noctis-server.local" .env.production; then
            sed -i "s/DOMAIN_NAME=noctis-server.local/DOMAIN_NAME=$SERVER_IP/" .env.production
        fi
        
        log_success "Environment updated for server IP: $SERVER_IP"
    else
        log_error ".env.production file not found"
        exit 1
    fi
}

# Configure firewall for internet access
configure_firewall() {
    log_info "Configuring firewall for internet access..."
    
    # Install ufw if not present
    if ! command -v ufw &> /dev/null; then
        $SUDO apt-get update
        $SUDO apt-get install -y ufw
    fi
    
    # Reset firewall to defaults
    $SUDO ufw --force reset
    
    # Set default policies
    $SUDO ufw default deny incoming
    $SUDO ufw default allow outgoing
    
    # Allow SSH
    $SUDO ufw allow ssh
    $SUDO ufw allow 22
    
    # Allow HTTP and HTTPS
    $SUDO ufw allow 80/tcp
    $SUDO ufw allow 443/tcp
    
    # Allow DICOM port
    $SUDO ufw allow 11112/tcp
    
    # Enable firewall
    $SUDO ufw --force enable
    
    log_success "Firewall configured for internet access"
}

# Deploy the application
deploy_application() {
    log_info "Deploying NoctisPro application..."
    
    # Stop any existing containers
    $SUDO docker compose -f docker-compose.production.yml down 2>/dev/null || true
    
    # Pull latest images
    log_info "Pulling Docker images..."
    $SUDO docker compose -f docker-compose.production.yml pull --ignore-pull-failures || true
    
    # Build and start containers
    log_info "Building and starting containers..."
    $SUDO docker compose -f docker-compose.production.yml --env-file .env.production up -d --build
    
    # Wait for services to be ready
    log_info "Waiting for services to start..."
    sleep 30
    
    # Check container status
    log_info "Container status:"
    $SUDO docker compose -f docker-compose.production.yml ps
}

# Run database migrations
run_migrations() {
    log_info "Running database migrations..."
    
    # Wait for database to be ready
    for i in {1..30}; do
        if $SUDO docker compose -f docker-compose.production.yml exec -T db pg_isready -U noctis_user -d noctis_pro >/dev/null 2>&1; then
            log_success "Database is ready!"
            break
        fi
        sleep 2
        echo "   Waiting for database... ($i/30)"
    done
    
    # Run migrations
    $SUDO docker compose -f docker-compose.production.yml exec -T web python manage.py migrate --noinput || true
    
    # Create superuser if it doesn't exist
    log_info "Creating admin user if needed..."
    $SUDO docker compose -f docker-compose.production.yml exec -T web python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctis.local', 'admin123')
    print('Admin user created: admin/admin123')
else:
    print('Admin user already exists')
" 2>/dev/null || true
    
    # Collect static files
    $SUDO docker compose -f docker-compose.production.yml exec -T web python manage.py collectstatic --noinput || true
    
    log_success "Database setup completed"
}

# Health check
health_check() {
    log_info "Performing health checks..."
    
    # Check if containers are running
    if ! $SUDO docker compose -f docker-compose.production.yml ps | grep -q "Up"; then
        log_error "Some containers are not running"
        return 1
    fi
    
    # Check if web service is responding
    for i in {1..10}; do
        if curl -f http://localhost >/dev/null 2>&1; then
            log_success "Web service is responding!"
            break
        fi
        sleep 3
        echo "   Checking web service... ($i/10)"
    done
    
    # Get server IP for display
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    log_success "Health check completed"
    log_success "NoctisPro is now accessible at:"
    log_success "  Local: http://localhost"
    log_success "  Network: http://$SERVER_IP"
    
    return 0
}

# Display final information
display_info() {
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "================================================================="
    echo -e "${GREEN}🎉 NOCTIS PRO DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉${NC}"
    echo "================================================================="
    echo ""
    echo "🌐 Your NoctisPro system is now accessible on the internet:"
    echo ""
    echo "   📱 Web Interface: http://$SERVER_IP"
    echo "   🔐 Admin Panel:   http://$SERVER_IP/admin"
    echo "   📊 API Docs:      http://$SERVER_IP/api/docs"
    echo ""
    echo "🔑 Default Admin Credentials:"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo "   ⚠️  CHANGE THESE CREDENTIALS IMMEDIATELY!"
    echo ""
    echo "🐳 Docker Management Commands:"
    echo "   View logs:    sudo docker compose -f docker-compose.production.yml logs -f"
    echo "   Stop system:  sudo docker compose -f docker-compose.production.yml down"
    echo "   Restart:      sudo docker compose -f docker-compose.production.yml restart"
    echo ""
    echo "🔥 Firewall Status:"
    $SUDO ufw status numbered
    echo ""
    echo "📁 Data Locations:"
    echo "   Database:     /opt/noctis/data/postgres"
    echo "   Media Files:  /opt/noctis/media"
    echo "   DICOM Files:  /opt/noctis/dicom_storage"
    echo "   Backups:      /opt/noctis/backups"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   Check containers: sudo docker ps"
    echo "   View all logs:    sudo docker compose -f docker-compose.production.yml logs"
    echo "   Restart service:  sudo docker compose -f docker-compose.production.yml restart [service]"
    echo ""
    echo "================================================================="
}

# Main deployment process
main() {
    echo "================================================================="
    echo -e "${BLUE}🚀 NOCTIS PRO INTERNET DEPLOYMENT SCRIPT 🚀${NC}"
    echo "================================================================="
    echo ""
    
    check_privileges
    install_docker
    start_docker
    create_directories
    update_environment
    configure_firewall
    deploy_application
    run_migrations
    
    if health_check; then
        display_info
    else
        log_error "Deployment completed but health check failed"
        log_info "Check logs with: sudo docker compose -f docker-compose.production.yml logs"
        exit 1
    fi
}

# Run main function
main "$@"