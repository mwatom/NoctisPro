#!/bin/bash

# ============================================================================
# SSL/HTTPS Setup Script for NoctisPro PACS
# ============================================================================
# This script sets up SSL certificates and HTTPS access for NoctisPro PACS
# Supports Let's Encrypt, Cloudflare Tunnel, and self-signed certificates
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN=""
EMAIL=""
SSL_METHOD="letsencrypt"  # Options: letsencrypt, cloudflare, selfsigned

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
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
        error "This script must be run as root (use sudo)"
    fi
}

# Get user input for SSL configuration
get_ssl_config() {
    echo "SSL/HTTPS Configuration for NoctisPro PACS"
    echo "=========================================="
    echo ""
    echo "Choose SSL method:"
    echo "1) Let's Encrypt (free SSL, requires domain)"
    echo "2) Cloudflare Tunnel (free, includes domain)"
    echo "3) Self-signed certificate (local/testing)"
    echo ""
    read -p "Enter choice (1-3): " choice
    
    case $choice in
        1)
            SSL_METHOD="letsencrypt"
            read -p "Enter your domain name: " DOMAIN
            read -p "Enter your email: " EMAIL
            ;;
        2)
            SSL_METHOD="cloudflare"
            ;;
        3)
            SSL_METHOD="selfsigned"
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
}

# Install certbot for Let's Encrypt
install_certbot() {
    log "Installing Certbot for Let's Encrypt..."
    apt update
    apt install -y certbot python3-certbot-nginx
}

# Setup Let's Encrypt SSL
setup_letsencrypt() {
    log "Setting up Let's Encrypt SSL for $DOMAIN..."
    
    # Update nginx configuration for domain
    cat > /etc/nginx/sites-available/noctispro << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    client_max_body_size 100M;
    
    location /static/ {
        alias /opt/noctispro/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias /opt/noctispro/media/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }
}
EOF
    
    # Test nginx configuration
    nginx -t
    systemctl reload nginx
    
    # Get SSL certificate
    certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive
    
    # Setup auto-renewal
    systemctl enable certbot.timer
    
    log "Let's Encrypt SSL configured for https://$DOMAIN"
}

# Install Cloudflare Tunnel
install_cloudflare_tunnel() {
    log "Installing Cloudflare Tunnel..."
    
    # Download and install cloudflared
    wget -O /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i /tmp/cloudflared.deb || apt-get install -f -y
    
    log "Cloudflare Tunnel installed. Please run the following commands:"
    echo ""
    echo "1. Login to Cloudflare:"
    echo "   cloudflared tunnel login"
    echo ""
    echo "2. Create a tunnel:"
    echo "   cloudflared tunnel create noctispro"
    echo ""
    echo "3. Create DNS record:"
    echo "   cloudflared tunnel route dns noctispro your-domain.com"
    echo ""
    echo "4. Run tunnel:"
    echo "   cloudflared tunnel run noctispro"
    echo ""
}

# Setup Cloudflare Tunnel
setup_cloudflare_tunnel() {
    log "Setting up Cloudflare Tunnel..."
    
    # Create tunnel configuration directory
    mkdir -p /etc/cloudflared
    
    # Create service configuration
    cat > /etc/systemd/system/cloudflared.service << 'EOF'
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel run noctispro
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable cloudflared
    
    warning "Complete Cloudflare Tunnel setup manually using the commands shown above"
}

# Generate self-signed certificate
setup_selfsigned() {
    log "Setting up self-signed SSL certificate..."
    
    # Create SSL directory
    mkdir -p /etc/ssl/noctispro
    
    # Generate private key
    openssl genrsa -out /etc/ssl/noctispro/server.key 2048
    
    # Generate certificate
    openssl req -new -x509 -key /etc/ssl/noctispro/server.key -out /etc/ssl/noctispro/server.crt -days 365 -subj "/C=US/ST=State/L=City/O=NoctisPro/OU=PACS/CN=localhost"
    
    # Update nginx configuration
    cat > /etc/nginx/sites-available/noctispro << 'EOF'
server {
    listen 80;
    server_name localhost;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name localhost;
    
    ssl_certificate /etc/ssl/noctispro/server.crt;
    ssl_certificate_key /etc/ssl/noctispro/server.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    client_max_body_size 100M;
    
    location /static/ {
        alias /opt/noctispro/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias /opt/noctispro/media/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }
}
EOF
    
    # Test and reload nginx
    nginx -t && systemctl reload nginx
    
    log "Self-signed SSL configured for https://localhost"
    warning "Self-signed certificates will show security warnings in browsers"
}

# Update firewall rules
update_firewall() {
    log "Updating firewall rules for HTTPS..."
    ufw allow 443/tcp
    ufw reload
}

# Create SSL management script
create_ssl_management() {
    log "Creating SSL management script..."
    
    cat > /usr/local/bin/noctispro-ssl << 'EOF'
#!/bin/bash

case "$1" in
    renew)
        if command -v certbot &> /dev/null; then
            certbot renew --quiet
            systemctl reload nginx
            echo "SSL certificates renewed"
        else
            echo "Certbot not installed"
        fi
        ;;
    status)
        if [[ -f "/etc/letsencrypt/live/*/fullchain.pem" ]]; then
            openssl x509 -in /etc/letsencrypt/live/*/fullchain.pem -text -noout | grep -A2 "Validity"
        elif [[ -f "/etc/ssl/noctispro/server.crt" ]]; then
            openssl x509 -in /etc/ssl/noctispro/server.crt -text -noout | grep -A2 "Validity"
        else
            echo "No SSL certificates found"
        fi
        ;;
    test)
        echo "Testing SSL configuration..."
        if command -v curl &> /dev/null; then
            curl -I https://localhost 2>/dev/null | head -1
        else
            echo "curl not available for testing"
        fi
        ;;
    *)
        echo "Usage: $0 {renew|status|test}"
        exit 1
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/noctispro-ssl
}

# Main function
main() {
    log "NoctisPro PACS SSL/HTTPS Setup"
    
    check_root
    get_ssl_config
    
    case $SSL_METHOD in
        "letsencrypt")
            install_certbot
            setup_letsencrypt
            ;;
        "cloudflare")
            install_cloudflare_tunnel
            setup_cloudflare_tunnel
            ;;
        "selfsigned")
            setup_selfsigned
            ;;
    esac
    
    update_firewall
    create_ssl_management
    
    log "SSL/HTTPS setup completed!"
    
    case $SSL_METHOD in
        "letsencrypt")
            echo "Access your system at: https://$DOMAIN"
            ;;
        "cloudflare")
            echo "Complete Cloudflare setup, then access via your Cloudflare domain"
            ;;
        "selfsigned")
            echo "Access your system at: https://localhost"
            echo "Note: You'll need to accept the security warning in your browser"
            ;;
    esac
}

# Run main function
main "$@"