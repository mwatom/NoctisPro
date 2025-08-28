#!/bin/bash

# SSL Setup Script for NoctisPro
# Run this after the main deployment script

set -e

DOMAIN_NAME="noctis-server.local"  # Change this to your actual domain
EMAIL="admin@noctis-server.local"  # Change this to your email

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

log_info "Setting up SSL certificate for $DOMAIN_NAME..."

# Get SSL certificate
certbot --nginx -d $DOMAIN_NAME --email $EMAIL --agree-tos --non-interactive

if [ $? -eq 0 ]; then
    log_success "SSL certificate obtained successfully"
    
    # Update environment to enable SSL
    sed -i 's/ENABLE_SSL=false/ENABLE_SSL=true/' /workspace/.env
    
    # Restart services
    systemctl restart noctis-django noctis-daphne
    
    log_success "HTTPS is now enabled!"
    log_info "Your site is available at: https://$DOMAIN_NAME"
else
    log_error "Failed to obtain SSL certificate"
    log_warning "You can still access the site via HTTP"
fi

# Setup automatic renewal
log_info "Setting up automatic SSL renewal..."
echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -

log_success "SSL setup completed!"