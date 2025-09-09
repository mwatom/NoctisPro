#!/bin/bash

# =============================================================================
# NoctisPro PACS - Quick HTTPS Deployment Script
# One-command setup for static HTTPS URL
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}" >&2; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

# Configuration
DOMAIN="${DOMAIN:-}"
EMAIL="${EMAIL:-}"
DEPLOYMENT_TYPE="${DEPLOYMENT_TYPE:-auto}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_usage() {
    echo "NoctisPro PACS - Quick HTTPS Deployment"
    echo "======================================"
    echo
    echo "Usage: DOMAIN=your-domain.com EMAIL=your-email@domain.com $0"
    echo
    echo "Examples:"
    echo "  DOMAIN=noctispro.hospital.com EMAIL=admin@hospital.com $0"
    echo "  DOMAIN=pacs.clinic.org EMAIL=it@clinic.org $0"
    echo
    echo "Environment Variables:"
    echo "  DOMAIN          - Your domain name (required)"
    echo "  EMAIL           - Your email for SSL certificates (required)"
    echo "  DEPLOYMENT_TYPE - auto, kubernetes, docker, native (default: auto)"
    echo
    echo "Prerequisites:"
    echo "  - Domain DNS pointing to this server"
    echo "  - Ports 80, 443, and 11112 open"
    echo "  - Docker/Kubernetes/Systemd available"
    echo
}

detect_deployment() {
    if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
        echo "kubernetes"
    elif command -v docker-compose >/dev/null 2>&1 && [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
        echo "docker"
    elif command -v systemctl >/dev/null 2>&1; then
        echo "native"
    else
        echo "unknown"
    fi
}

setup_kubernetes() {
    log "Deploying NoctisPro on Kubernetes with HTTPS..."
    
    # Install cert-manager if not present
    if ! kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
        log "Installing cert-manager..."
        kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
        kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
    fi
    
    # Update configurations with user values
    sed -i "s/your-email@example.com/$EMAIL/g" "$PROJECT_DIR/deployment/kubernetes/cert-manager.yaml"
    sed -i "s/your-domain.com/$DOMAIN/g" "$PROJECT_DIR/deployment/kubernetes/ingress.yaml"
    
    # Deploy everything
    kubectl apply -f "$PROJECT_DIR/deployment/kubernetes/"
    
    log "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/noctispro-web -n noctispro
    
    info "Kubernetes deployment complete!"
    info "Access: https://$DOMAIN"
    info "Certificate will be automatically provisioned"
}

setup_docker() {
    log "Deploying NoctisPro with Docker and HTTPS..."
    
    # Create SSL nginx config
    mkdir -p "$PROJECT_DIR/deployment/nginx/ssl"
    
    cat > "$PROJECT_DIR/docker-compose.https.yml" << EOF
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./deployment/nginx/nginx-https.conf:/etc/nginx/conf.d/default.conf:ro
      - ./staticfiles:/app/staticfiles:ro
      - ./media:/app/media:ro
      - certbot-etc:/etc/letsencrypt
      - certbot-var:/var/lib/letsencrypt
      - ./deployment/nginx/ssl:/var/www/certbot
    depends_on:
      - web
      - certbot
    restart: unless-stopped

  certbot:
    image: certbot/certbot
    volumes:
      - certbot-etc:/etc/letsencrypt
      - certbot-var:/var/lib/letsencrypt
      - ./deployment/nginx/ssl:/var/www/certbot
    command: certonly --webroot --webroot-path=/var/www/certbot --email $EMAIL --agree-tos --no-eff-email --force-renewal -d $DOMAIN
    restart: "no"

  web:
    environment:
      - ALLOWED_HOSTS=$DOMAIN,localhost,127.0.0.1
      - SECURE_SSL_REDIRECT=True
      - SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https

volumes:
  certbot-etc:
  certbot-var:
EOF

    # Create HTTPS nginx configuration
    cat > "$PROJECT_DIR/deployment/nginx/nginx-https.conf" << EOF
upstream django {
    server web:8000;
}

server {
    listen 80;
    server_name $DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    client_max_body_size 100M;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
    
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    location /static/ {
        alias /app/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias /app/media/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location / {
        proxy_pass http://django;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

    # Start services
    docker-compose -f docker-compose.yml -f docker-compose.https.yml up -d
    
    log "Waiting for services to start..."
    sleep 30
    
    # Get SSL certificate
    docker-compose -f docker-compose.yml -f docker-compose.https.yml run --rm certbot
    
    # Reload nginx
    docker-compose -f docker-compose.yml -f docker-compose.https.yml restart nginx
    
    info "Docker deployment complete!"
    info "Access: https://$DOMAIN"
}

setup_native() {
    log "Deploying NoctisPro natively with HTTPS..."
    
    # Install dependencies
    if command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y nginx certbot python3-certbot-nginx
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y nginx certbot python3-certbot-nginx
    fi
    
    # Deploy NoctisPro first
    ./deploy_noctispro.sh
    
    # Create nginx config
    sudo tee /etc/nginx/sites-available/noctispro << EOF
upstream django {
    server 127.0.0.1:8080;
}

server {
    listen 80;
    server_name $DOMAIN;
    client_max_body_size 100M;
    
    location /static/ {
        alias $PROJECT_DIR/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias $PROJECT_DIR/media/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location / {
        proxy_pass http://django;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # Enable site
    sudo ln -sf /etc/nginx/sites-available/noctispro /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo nginx -t
    sudo systemctl restart nginx
    
    # Get SSL certificate
    sudo certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive
    
    # Enable services
    sudo systemctl enable nginx
    
    info "Native deployment complete!"
    info "Access: https://$DOMAIN"
}

main() {
    if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
        show_usage
        exit 1
    fi
    
    log "🚀 Starting NoctisPro HTTPS deployment..."
    info "Domain: $DOMAIN"
    info "Email: $EMAIL"
    
    if [ "$DEPLOYMENT_TYPE" = "auto" ]; then
        DEPLOYMENT_TYPE=$(detect_deployment)
        info "Auto-detected: $DEPLOYMENT_TYPE"
    fi
    
    case "$DEPLOYMENT_TYPE" in
        kubernetes) setup_kubernetes ;;
        docker) setup_docker ;;
        native) setup_native ;;
        *) 
            error "Unsupported deployment type: $DEPLOYMENT_TYPE"
            exit 1
            ;;
    esac
    
    log "🎉 NoctisPro HTTPS deployment complete!"
    echo
    info "🌐 Access your PACS system:"
    echo "   Web Interface: https://$DOMAIN"
    echo "   Admin Panel:   https://$DOMAIN/admin/"
    echo "   Default Login: admin / admin123"
    echo
    info "🏥 DICOM Configuration:"
    echo "   AE Title: NOCTIS_SCP"
    echo "   Hostname: $DOMAIN"
    echo "   Port:     11112"
    echo
    warn "Make sure your DNS records point to this server!"
}

main "$@"