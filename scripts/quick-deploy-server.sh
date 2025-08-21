#!/bin/bash

# NOCTIS Pro - Quick Deploy to Ubuntu Server
# One-command deployment for production server

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NOCTIS_DIR="/opt/noctis"
COMPOSE_FILE="$NOCTIS_DIR/docker-compose.production.yml"
ENV_FILE="$NOCTIS_DIR/.env"

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Check if running on server
check_server_environment() {
    log "Checking server environment..."
    
    # Check if we're on Ubuntu
    if ! grep -q "Ubuntu" /etc/os-release; then
        error "This script is designed for Ubuntu servers"
        exit 1
    fi
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please run setup-ubuntu-server.sh first"
        exit 1
    fi
    
    # Check if NOCTIS directory exists
    if [ ! -d "$NOCTIS_DIR" ]; then
        error "NOCTIS directory not found. Please import data first or run setup script"
        exit 1
    fi
    
    log "Server environment verified"
}

# Check prerequisites
check_prerequisites() {
    log "Checking deployment prerequisites..."
    
    # Check if compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        error "Production compose file not found: $COMPOSE_FILE"
        error "Please import your application data first"
        exit 1
    fi
    
    # Check if environment file exists
    if [ ! -f "$ENV_FILE" ]; then
        error "Environment file not found: $ENV_FILE"
        error "Please create .env file from .env.server.example"
        exit 1
    fi
    
    # Check for required environment variables
    source "$ENV_FILE"
    
    if [ "$DEBUG" != "False" ]; then
        warn "DEBUG is not set to False in production environment"
    fi
    
    if [ -z "$SECRET_KEY" ] || [ "$SECRET_KEY" = "CHANGE-THIS-TO-A-STRONG-SECRET-KEY-FOR-PRODUCTION" ]; then
        error "SECRET_KEY is not properly configured in .env file"
        exit 1
    fi
    
    if [ -z "$DOMAIN_NAME" ] || [ "$DOMAIN_NAME" = "your-domain.com" ]; then
        error "DOMAIN_NAME is not configured in .env file"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Setup production directories
setup_production_directories() {
    log "Setting up production directories..."
    
    cd "$NOCTIS_DIR"
    
    # Create required directories with proper permissions
    sudo mkdir -p data/{postgres,redis,media,staticfiles,dicom_storage}
    sudo mkdir -p logs/{nginx,app}
    sudo mkdir -p backups
    sudo mkdir -p ssl
    
    # Set ownership
    sudo chown -R $USER:$USER "$NOCTIS_DIR"
    
    # Set proper permissions
    chmod 755 "$NOCTIS_DIR"/{data,logs,backups,ssl}
    chmod 755 "$NOCTIS_DIR"/data/*
    
    log "Production directories ready"
}

# Pull and build images
prepare_images() {
    log "Preparing Docker images..."
    
    cd "$NOCTIS_DIR"
    
    # Pull base images
    docker compose -f docker-compose.production.yml pull
    
    # Build application images
    docker compose -f docker-compose.production.yml build
    
    log "Docker images ready"
}

# Configure firewall
configure_production_firewall() {
    log "Configuring production firewall..."
    
    # Check if UFW is installed and active
    if command -v ufw &> /dev/null; then
        # Allow HTTP and HTTPS
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        
        # Allow DICOM port
        sudo ufw allow 11112/tcp
        
        # Reload firewall
        sudo ufw --force enable
        
        log "Firewall configured for production"
    else
        warn "UFW firewall not found. Please configure firewall manually"
    fi
}

# Start production services
start_production_services() {
    log "Starting production services..."
    
    cd "$NOCTIS_DIR"
    
    # Start core services first
    docker compose -f docker-compose.production.yml up -d db redis
    
    # Wait for database
    log "Waiting for database to be ready..."
    for i in {1..30}; do
        if docker compose -f docker-compose.production.yml exec db pg_isready -U noctis_user -d noctis_pro >/dev/null 2>&1; then
            log "Database is ready"
            break
        fi
        if [ $i -eq 30 ]; then
            error "Database failed to start"
            exit 1
        fi
        sleep 10
    done
    
    # Start application services
    docker compose -f docker-compose.production.yml up -d web celery dicom_receiver
    
    # Wait for web service
    log "Waiting for web application..."
    for i in {1..20}; do
        if docker compose -f docker-compose.production.yml exec web python manage.py check >/dev/null 2>&1; then
            log "Web application is ready"
            break
        fi
        if [ $i -eq 20 ]; then
            warn "Web application health check timeout"
            break
        fi
        sleep 15
    done
    
    # Start Nginx
    docker compose -f docker-compose.production.yml up -d nginx
    
    log "Production services started"
}

# Run production setup
run_production_setup() {
    log "Running production setup..."
    
    cd "$NOCTIS_DIR"
    
    # Run database migrations
    docker compose -f docker-compose.production.yml exec web python manage.py migrate --noinput
    
    # Collect static files
    docker compose -f docker-compose.production.yml exec web python manage.py collectstatic --noinput
    
    # Create cache table if using database cache
    docker compose -f docker-compose.production.yml exec web python manage.py createcachetable 2>/dev/null || true
    
    log "Production setup completed"
}

# Configure SSL certificates
setup_ssl() {
    log "Setting up SSL certificates..."
    
    source "$ENV_FILE"
    
    if [ -z "$LETSENCRYPT_EMAIL" ] || [ "$LETSENCRYPT_EMAIL" = "your-email@example.com" ]; then
        warn "LETSENCRYPT_EMAIL not configured. Skipping SSL setup."
        warn "Configure SSL manually with: sudo certbot --nginx"
        return
    fi
    
    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        warn "Certbot not installed. Installing..."
        sudo apt update
        sudo apt install -y certbot python3-certbot-nginx
    fi
    
    # Generate SSL certificates
    sudo certbot --nginx --non-interactive --agree-tos --email "$LETSENCRYPT_EMAIL" -d "$DOMAIN_NAME"
    
    # Setup auto-renewal
    if ! sudo crontab -l | grep -q certbot; then
        (sudo crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | sudo crontab -
        log "SSL auto-renewal configured"
    fi
    
    log "SSL certificates configured"
}

# Setup monitoring (optional)
setup_monitoring() {
    read -p "Enable monitoring (Prometheus + Grafana)? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Enabling monitoring services..."
        
        cd "$NOCTIS_DIR"
        ENABLE_MONITORING=true docker compose -f docker-compose.production.yml --profile monitoring up -d
        
        log "Monitoring services enabled"
        echo "📊 Prometheus: http://localhost:9090"
        echo "📈 Grafana:    http://localhost:3000 (admin/admin123)"
    fi
}

# Setup automated backups
setup_automated_backups() {
    log "Setting up automated backups..."
    
    # Create backup script if not exists
    if [ ! -f "$NOCTIS_DIR/scripts/backup-system.sh" ]; then
        warn "Backup script not found. Skipping backup automation."
        return
    fi
    
    # Setup cron job for daily backups
    if ! crontab -l 2>/dev/null | grep -q "backup-system.sh"; then
        (crontab -l 2>/dev/null; echo "0 2 * * * $NOCTIS_DIR/scripts/backup-system.sh >> $NOCTIS_DIR/logs/backup.log 2>&1") | crontab -
        log "Automated daily backups configured (2 AM)"
    else
        log "Backup cron job already exists"
    fi
}

# Display production status
show_production_status() {
    log "Checking production deployment status..."
    
    cd "$NOCTIS_DIR"
    
    echo ""
    echo "======================================="
    echo "NOCTIS Pro Production Deployment"
    echo "======================================="
    echo ""
    
    # Show container status
    docker compose -f docker-compose.production.yml ps
    
    echo ""
    echo "Access Information:"
    echo "==================="
    
    source "$ENV_FILE"
    
    echo "🌐 Web Application:    https://$DOMAIN_NAME"
    echo "🔧 Admin Panel:        https://$DOMAIN_NAME/admin"
    echo "🏥 DICOM Receiver:     $DOMAIN_NAME:11112"
    
    if docker compose -f docker-compose.production.yml ps | grep -q prometheus; then
        echo "📊 Prometheus:         http://$DOMAIN_NAME:9090"
        echo "📈 Grafana:            http://$DOMAIN_NAME:3000"
    fi
    
    echo ""
    echo "System Status:"
    echo "=============="
    echo "🔥 Firewall:          $(sudo ufw status | head -1)"
    echo "🔒 SSL Status:        $([ -d "/etc/letsencrypt/live/$DOMAIN_NAME" ] && echo "Configured" || echo "Not configured")"
    echo "💾 Backup Job:        $(crontab -l 2>/dev/null | grep -q backup-system.sh && echo "Configured" || echo "Not configured")"
    echo "📁 Data Directory:    $(du -sh $NOCTIS_DIR/data | cut -f1)"
    echo ""
    
    echo "Useful Commands:"
    echo "================"
    echo "View logs:           docker compose -f docker-compose.production.yml logs -f"
    echo "Restart services:    docker compose -f docker-compose.production.yml restart"
    echo "Update SSL:          sudo certbot --nginx"
    echo "Backup system:       $NOCTIS_DIR/scripts/backup-system.sh"
    echo "Check health:        curl -f https://$DOMAIN_NAME/health/"
    echo ""
}

# Perform health checks
run_health_checks() {
    log "Performing health checks..."
    
    cd "$NOCTIS_DIR"
    source "$ENV_FILE"
    
    # Check database connection
    if docker compose -f docker-compose.production.yml exec -T db pg_isready -U noctis_user -d noctis_pro >/dev/null 2>&1; then
        log "✅ Database: Healthy"
    else
        error "❌ Database: Unhealthy"
    fi
    
    # Check Redis connection
    if docker compose -f docker-compose.production.yml exec -T redis redis-cli ping >/dev/null 2>&1; then
        log "✅ Redis: Healthy"
    else
        error "❌ Redis: Unhealthy"
    fi
    
    # Check web application
    if curl -f "http://localhost:8000/health/" >/dev/null 2>&1; then
        log "✅ Web Application: Healthy"
    else
        warn "⚠️  Web Application: Health check failed"
    fi
    
    # Check HTTPS (if SSL is configured)
    if [ -d "/etc/letsencrypt/live/$DOMAIN_NAME" ]; then
        if curl -f "https://$DOMAIN_NAME/health/" >/dev/null 2>&1; then
            log "✅ HTTPS: Healthy"
        else
            warn "⚠️  HTTPS: Not accessible"
        fi
    fi
    
    log "Health checks completed"
}

# Main deployment function
main() {
    echo ""
    echo "🚀 NOCTIS Pro Quick Deploy to Ubuntu Server"
    echo "============================================"
    echo ""
    
    check_server_environment
    check_prerequisites
    setup_production_directories
    prepare_images
    configure_production_firewall
    start_production_services
    run_production_setup
    setup_ssl
    setup_monitoring
    setup_automated_backups
    show_production_status
    run_health_checks
    
    log ""
    log "🎉 NOCTIS Pro production deployment completed!"
    log ""
    log "Your medical imaging system is now running in production mode."
    log ""
    log "Important next steps:"
    log "1. Test the application thoroughly"
    log "2. Configure your DICOM devices to connect to port 11112"
    log "3. Set up monitoring and alerting"
    log "4. Review security settings"
    log "5. Test backup and restore procedures"
    log ""
    log "Support:"
    log "- Check logs: docker compose -f docker-compose.production.yml logs -f"
    log "- Monitor resources: htop, docker stats"
    log "- Backup system: $NOCTIS_DIR/scripts/backup-system.sh"
    log ""
}

# Handle script interruption
trap 'error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"