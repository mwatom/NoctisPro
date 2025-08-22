#!/bin/bash

# SSL Domain Issues Fix Script for NoctisPro
# This script helps resolve common SSL domain naming issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
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

log_header() {
    echo -e "\n${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
}

# Global variables
DOMAIN_NAME=""
EMAIL=""
SETUP_TYPE=""
PUBLIC_IP=""

# Get public IP address
get_public_ip() {
    if command -v curl >/dev/null 2>&1; then
        PUBLIC_IP=$(curl -s --max-time 10 https://httpbin.org/ip 2>/dev/null | grep -o '[0-9.]*' | head -1 || echo "")
        if [ -z "$PUBLIC_IP" ]; then
            PUBLIC_IP=$(curl -s --max-time 10 http://ifconfig.me 2>/dev/null || echo "")
        fi
    fi
    
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP="Unable to determine"
    fi
}

# Interactive domain configuration
configure_domain_interactive() {
    log_header "SSL DOMAIN CONFIGURATION"
    
    echo "Select your SSL setup type:"
    echo "1) Public domain with Let's Encrypt SSL (Recommended for production)"
    echo "2) Self-signed certificate for development/testing"
    echo "3) Use ngrok for temporary public access"
    echo "4) Internal network with custom CA"
    echo "5) Skip SSL configuration"
    
    while true; do
        read -p "Enter your choice (1-5): " choice
        case $choice in
            1)
                SETUP_TYPE="public"
                configure_public_domain
                break
                ;;
            2)
                SETUP_TYPE="selfsigned"
                configure_selfsigned
                break
                ;;
            3)
                SETUP_TYPE="ngrok"
                configure_ngrok
                break
                ;;
            4)
                SETUP_TYPE="internal"
                configure_internal_ca
                break
                ;;
            5)
                SETUP_TYPE="skip"
                log_warning "Skipping SSL configuration"
                break
                ;;
            *)
                echo "Invalid choice. Please enter 1-5."
                ;;
        esac
    done
}

# Configure public domain with Let's Encrypt
configure_public_domain() {
    log_info "Setting up public domain with Let's Encrypt SSL"
    
    get_public_ip
    log_info "Your public IP address is: $PUBLIC_IP"
    
    echo ""
    echo "To use Let's Encrypt SSL, you need:"
    echo "1. A registered domain name"
    echo "2. DNS A record pointing to your server's public IP ($PUBLIC_IP)"
    echo "3. Port 80 and 443 open in your firewall"
    echo ""
    
    while true; do
        read -p "Enter your domain name (e.g., noctis.yourdomain.com): " DOMAIN_NAME
        if [ -n "$DOMAIN_NAME" ] && [[ "$DOMAIN_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
            break
        else
            echo "Please enter a valid domain name."
        fi
    done
    
    while true; do
        read -p "Enter your email address for Let's Encrypt: " EMAIL
        if [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo "Please enter a valid email address."
        fi
    done
    
    # Check if domain resolves to current IP
    log_info "Checking DNS resolution for $DOMAIN_NAME..."
    if command -v nslookup >/dev/null 2>&1; then
        RESOLVED_IP=$(nslookup $DOMAIN_NAME 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}' || echo "")
        if [ "$RESOLVED_IP" = "$PUBLIC_IP" ]; then
            log_success "Domain resolves correctly to $PUBLIC_IP"
        else
            log_warning "Domain resolves to $RESOLVED_IP, but your public IP is $PUBLIC_IP"
            log_warning "Please update your DNS A record to point to $PUBLIC_IP"
        fi
    fi
    
    setup_letsencrypt
}

# Configure self-signed certificate
configure_selfsigned() {
    log_info "Setting up self-signed certificate"
    
    while true; do
        read -p "Enter hostname for certificate (or press Enter for 'localhost'): " DOMAIN_NAME
        if [ -z "$DOMAIN_NAME" ]; then
            DOMAIN_NAME="localhost"
        fi
        break
    done
    
    setup_selfsigned_cert
}

# Configure ngrok
configure_ngrok() {
    log_info "Setting up ngrok for temporary public access"
    
    if ! command -v ngrok >/dev/null 2>&1; then
        log_info "Installing ngrok..."
        install_ngrok
    fi
    
    setup_ngrok
}

# Configure internal CA
configure_internal_ca() {
    log_info "Setting up internal CA"
    
    while true; do
        read -p "Enter internal domain name (e.g., noctis.internal): " DOMAIN_NAME
        if [ -n "$DOMAIN_NAME" ]; then
            break
        fi
    done
    
    setup_internal_ca
}

# Install required packages
install_packages() {
    log_header "INSTALLING REQUIRED PACKAGES"
    
    if command -v apt >/dev/null 2>&1; then
        log_info "Updating package lists..."
        sudo apt update
        
        log_info "Installing required packages..."
        sudo apt install -y nginx certbot python3-certbot-nginx openssl curl
        
        log_success "Packages installed successfully"
    elif command -v yum >/dev/null 2>&1; then
        log_info "Installing required packages (CentOS/RHEL)..."
        sudo yum install -y nginx certbot python3-certbot-nginx openssl curl
    else
        log_error "Package manager not found. Please install nginx, certbot, and openssl manually."
        exit 1
    fi
}

# Setup Let's Encrypt SSL
setup_letsencrypt() {
    log_header "SETTING UP LET'S ENCRYPT SSL"
    
    # Install required packages
    install_packages
    
    # Create basic nginx configuration
    create_basic_nginx_config
    
    # Start nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx
    
    # Get SSL certificate
    log_info "Obtaining SSL certificate for $DOMAIN_NAME..."
    sudo certbot --nginx -d "$DOMAIN_NAME" --email "$EMAIL" --agree-tos --non-interactive
    
    if [ $? -eq 0 ]; then
        log_success "SSL certificate obtained successfully!"
        
        # Update environment files
        update_environment_files
        
        # Setup auto-renewal
        setup_certbot_renewal
        
        log_success "HTTPS is now configured for https://$DOMAIN_NAME"
    else
        log_error "Failed to obtain SSL certificate"
        log_info "Common issues:"
        log_info "1. Domain doesn't resolve to this server"
        log_info "2. Port 80/443 not accessible from internet"
        log_info "3. Nginx not properly configured"
    fi
}

# Setup self-signed certificate
setup_selfsigned_cert() {
    log_header "SETTING UP SELF-SIGNED CERTIFICATE"
    
    # Create SSL directory
    sudo mkdir -p /etc/ssl/noctis
    
    # Generate private key
    log_info "Generating private key..."
    sudo openssl genrsa -out /etc/ssl/noctis/noctis.key 2048
    
    # Generate certificate
    log_info "Generating self-signed certificate..."
    sudo openssl req -new -x509 -key /etc/ssl/noctis/noctis.key -out /etc/ssl/noctis/noctis.crt -days 365 \
        -subj "/C=US/ST=State/L=City/O=NoctisPro/CN=$DOMAIN_NAME"
    
    # Set proper permissions
    sudo chmod 600 /etc/ssl/noctis/noctis.key
    sudo chmod 644 /etc/ssl/noctis/noctis.crt
    
    log_success "Self-signed certificate created"
    
    # Create nginx configuration for self-signed cert
    create_selfsigned_nginx_config
    
    # Update environment files
    update_environment_files
    
    log_success "Self-signed SSL configured for https://$DOMAIN_NAME"
    log_warning "Browsers will show security warnings for self-signed certificates"
}

# Install and setup ngrok
install_ngrok() {
    if command -v snap >/dev/null 2>&1; then
        sudo snap install ngrok
    else
        # Download and install ngrok manually
        curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
        sudo apt update && sudo apt install ngrok
    fi
}

# Setup ngrok
setup_ngrok() {
    log_info "Setting up ngrok tunnel..."
    
    echo "To use ngrok, you need to:"
    echo "1. Sign up at https://ngrok.com/"
    echo "2. Get your auth token from the dashboard"
    echo "3. Run: ngrok authtoken YOUR_AUTH_TOKEN"
    echo "4. Start tunnel: ngrok http 80"
    echo ""
    echo "After starting ngrok, it will provide a public URL like:"
    echo "https://abc123.ngrok.io -> http://localhost:80"
    echo ""
    echo "Use the ngrok URL as your domain name in the application configuration."
    
    log_success "Ngrok setup instructions provided"
}

# Setup internal CA
setup_internal_ca() {
    log_header "SETTING UP INTERNAL CA"
    
    # Create CA directory
    sudo mkdir -p /etc/ssl/noctis-ca
    cd /etc/ssl/noctis-ca
    
    # Generate CA private key
    log_info "Generating CA private key..."
    sudo openssl genrsa -out ca.key 4096
    
    # Generate CA certificate
    log_info "Generating CA certificate..."
    sudo openssl req -new -x509 -key ca.key -sha256 -subj "/C=US/ST=State/L=City/O=NoctisPro-CA/CN=NoctisPro-CA" -days 3650 -out ca.crt
    
    # Generate server private key
    log_info "Generating server private key..."
    sudo openssl genrsa -out server.key 4096
    
    # Generate server certificate request
    log_info "Generating server certificate..."
    sudo openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=NoctisPro/CN=$DOMAIN_NAME"
    
    # Generate server certificate
    sudo openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256
    
    # Set permissions
    sudo chmod 600 /etc/ssl/noctis-ca/*.key
    sudo chmod 644 /etc/ssl/noctis-ca/*.crt
    
    log_success "Internal CA and server certificate created"
    log_info "To trust the certificate, add /etc/ssl/noctis-ca/ca.crt to your browser's trusted certificates"
    
    # Create nginx configuration for internal CA
    create_internal_ca_nginx_config
    
    # Update environment files
    update_environment_files
}

# Create basic nginx configuration
create_basic_nginx_config() {
    log_info "Creating nginx configuration..."
    
    sudo tee /etc/nginx/sites-available/noctis >/dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/noctis /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
}

# Create nginx configuration for self-signed certificate
create_selfsigned_nginx_config() {
    sudo tee /etc/nginx/sites-available/noctis >/dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;
    
    ssl_certificate /etc/ssl/noctis/noctis.crt;
    ssl_certificate_key /etc/ssl/noctis/noctis.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    sudo ln -sf /etc/nginx/sites-available/noctis /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
}

# Create nginx configuration for internal CA
create_internal_ca_nginx_config() {
    sudo tee /etc/nginx/sites-available/noctis >/dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;
    
    ssl_certificate /etc/ssl/noctis-ca/server.crt;
    ssl_certificate_key /etc/ssl/noctis-ca/server.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    sudo ln -sf /etc/nginx/sites-available/noctis /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
}

# Update environment files
update_environment_files() {
    log_info "Updating environment configuration..."
    
    # Update .env file
    if [ -f ".env" ]; then
        if grep -q "DOMAIN_NAME=" .env; then
            sed -i "s/DOMAIN_NAME=.*/DOMAIN_NAME=$DOMAIN_NAME/" .env
        else
            echo "DOMAIN_NAME=$DOMAIN_NAME" >> .env
        fi
        
        # Enable SSL
        if grep -q "ENABLE_SSL=" .env; then
            sed -i "s/ENABLE_SSL=.*/ENABLE_SSL=true/" .env
        else
            echo "ENABLE_SSL=true" >> .env
        fi
    fi
    
    # Update .env.production file
    if [ -f ".env.production" ]; then
        if grep -q "DOMAIN_NAME=" .env.production; then
            sed -i "s/DOMAIN_NAME=.*/DOMAIN_NAME=$DOMAIN_NAME/" .env.production
        else
            echo "DOMAIN_NAME=$DOMAIN_NAME" >> .env.production
        fi
        
        # Enable SSL
        if grep -q "ENABLE_SSL=" .env.production; then
            sed -i "s/ENABLE_SSL=.*/ENABLE_SSL=true/" .env.production
        else
            echo "ENABLE_SSL=true" >> .env.production
        fi
    fi
    
    log_success "Environment files updated"
}

# Setup certbot auto-renewal
setup_certbot_renewal() {
    log_info "Setting up SSL certificate auto-renewal..."
    
    # Add cron job for renewal
    if ! crontab -l 2>/dev/null | grep -q certbot; then
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        log_success "Auto-renewal configured"
    else
        log_info "Auto-renewal already configured"
    fi
}

# Test SSL configuration
test_ssl_config() {
    log_header "TESTING SSL CONFIGURATION"
    
    if [ "$SETUP_TYPE" = "skip" ]; then
        log_info "SSL configuration was skipped"
        return
    fi
    
    # Test HTTP redirect
    if command -v curl >/dev/null 2>&1; then
        log_info "Testing HTTP to HTTPS redirect..."
        if curl -s -I "http://$DOMAIN_NAME" | grep -q "301\|302"; then
            log_success "HTTP to HTTPS redirect working"
        else
            log_warning "HTTP to HTTPS redirect not working"
        fi
        
        # Test HTTPS
        log_info "Testing HTTPS connection..."
        if curl -s -k "https://$DOMAIN_NAME/health" >/dev/null 2>&1; then
            log_success "HTTPS connection working"
        else
            log_warning "HTTPS connection failed"
        fi
    fi
    
    # Test certificate
    if [ "$SETUP_TYPE" = "public" ] && command -v openssl >/dev/null 2>&1; then
        log_info "Testing SSL certificate..."
        if echo | openssl s_client -connect "$DOMAIN_NAME:443" -servername "$DOMAIN_NAME" 2>/dev/null | openssl x509 -noout -dates >/dev/null 2>&1; then
            log_success "SSL certificate is valid"
        else
            log_warning "SSL certificate test failed"
        fi
    fi
}

# Show final configuration
show_final_config() {
    log_header "FINAL CONFIGURATION"
    
    case $SETUP_TYPE in
        "public")
            log_success "Public SSL configuration completed!"
            echo "Your application is available at:"
            echo "  HTTPS: https://$DOMAIN_NAME"
            echo "  HTTP:  http://$DOMAIN_NAME (redirects to HTTPS)"
            echo ""
            echo "SSL Certificate: Let's Encrypt"
            echo "Auto-renewal: Enabled"
            ;;
        "selfsigned")
            log_success "Self-signed SSL configuration completed!"
            echo "Your application is available at:"
            echo "  HTTPS: https://$DOMAIN_NAME"
            echo ""
            echo "SSL Certificate: Self-signed"
            echo "Note: Browsers will show security warnings"
            ;;
        "ngrok")
            log_success "Ngrok setup completed!"
            echo "To start your tunnel:"
            echo "  ngrok http 80"
            echo ""
            echo "Then use the provided ngrok URL in your application"
            ;;
        "internal")
            log_success "Internal CA SSL configuration completed!"
            echo "Your application is available at:"
            echo "  HTTPS: https://$DOMAIN_NAME"
            echo ""
            echo "SSL Certificate: Internal CA"
            echo "CA Certificate: /etc/ssl/noctis-ca/ca.crt"
            echo "Import the CA certificate to your browser to avoid warnings"
            ;;
        "skip")
            log_info "SSL configuration was skipped"
            echo "Your application will run on HTTP only"
            ;;
    esac
}

# Main execution
main() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║          NOCTIS PRO SSL DOMAIN FIX TOOL         ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Check if running as root for some operations
    if [[ $EUID -ne 0 ]] && [[ "$1" != "--help" ]]; then
        log_warning "Some operations require root privileges"
        log_info "You may be prompted for sudo password"
    fi
    
    if [[ "$1" == "--help" ]]; then
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help          Show this help message"
        echo "  --auto-public   Automatically setup public SSL (requires DOMAIN_NAME and EMAIL env vars)"
        echo "  --auto-self     Automatically setup self-signed SSL"
        echo ""
        echo "Interactive mode (default): Prompts for configuration options"
        exit 0
    elif [[ "$1" == "--auto-public" ]]; then
        if [ -z "$DOMAIN_NAME" ] || [ -z "$EMAIL" ]; then
            log_error "DOMAIN_NAME and EMAIL environment variables required for auto-public mode"
            exit 1
        fi
        SETUP_TYPE="public"
        setup_letsencrypt
    elif [[ "$1" == "--auto-self" ]]; then
        SETUP_TYPE="selfsigned"
        DOMAIN_NAME="localhost"
        setup_selfsigned_cert
    else
        configure_domain_interactive
    fi
    
    test_ssl_config
    show_final_config
    
    log_success "SSL domain configuration completed!"
}

# Run main function
main "$@"