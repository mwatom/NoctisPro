#!/bin/bash

# =============================================================================
# CloudFlare Tunnel Setup for NoctisPro PACS
# =============================================================================
# This script sets up CloudFlare tunnels to provide consistent public URLs
# that work alongside or replace ngrok for DICOM and web access
# =============================================================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="${SCRIPT_DIR}"
readonly CONFIG_DIR="${PROJECT_DIR}/config/cloudflare"
readonly LOG_FILE="${PROJECT_DIR}/logs/cloudflare_tunnel.log"

# Create necessary directories
mkdir -p "${CONFIG_DIR}" "${PROJECT_DIR}/logs"

log() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${GREEN}[${timestamp}] ${message}${NC}"
    echo "[${timestamp}] ${message}" >> "${LOG_FILE}"
}

warn() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${YELLOW}[${timestamp}] WARNING: ${message}${NC}" >&2
    echo "[${timestamp}] WARNING: ${message}" >> "${LOG_FILE}"
}

error() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${RED}[${timestamp}] ERROR: ${message}${NC}" >&2
    echo "[${timestamp}] ERROR: ${message}" >> "${LOG_FILE}"
}

success() {
    local message="$1"
    echo -e "${GREEN}✅ ${message}${NC}"
}

# Check if CloudFlare tunnel is installed
check_cloudflared() {
    if ! command -v cloudflared >/dev/null 2>&1; then
        error "cloudflared not found. Installing..."
        
        # Download and install cloudflared
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        sudo dpkg -i cloudflared-linux-amd64.deb
        rm cloudflared-linux-amd64.deb
        
        success "CloudFlare tunnel installed"
    else
        log "CloudFlare tunnel already installed"
    fi
}

# Setup CloudFlare tunnel authentication
setup_tunnel_auth() {
    echo ""
    echo -e "${BOLD}${BLUE}=== CloudFlare Tunnel Authentication ===${NC}"
    echo ""
    echo "To set up CloudFlare tunnel, you need to:"
    echo "1. Go to https://dash.cloudflare.com/"
    echo "2. Select your domain (or create a free one)"
    echo "3. Go to Zero Trust > Access > Tunnels"
    echo "4. Create a new tunnel"
    echo ""
    
    read -p "Do you want to authenticate now? (y/N): " -r auth_choice
    
    if [[ "$auth_choice" =~ ^[Yy]$ ]]; then
        log "Starting CloudFlare authentication..."
        
        # Authenticate with CloudFlare
        if cloudflared tunnel login; then
            success "CloudFlare authentication successful"
            return 0
        else
            error "CloudFlare authentication failed"
            return 1
        fi
    else
        warn "Skipping CloudFlare authentication. You can run this later with: cloudflared tunnel login"
        return 1
    fi
}

# Create tunnel if it doesn't exist
create_tunnel() {
    local tunnel_name="noctis-pacs-tunnel"
    
    log "Checking for existing tunnel..."
    
    # Check if tunnel already exists
    if cloudflared tunnel list | grep -q "$tunnel_name"; then
        log "Tunnel '$tunnel_name' already exists"
        TUNNEL_ID=$(cloudflared tunnel list | grep "$tunnel_name" | awk '{print $1}')
    else
        log "Creating new tunnel: $tunnel_name"
        
        if cloudflared tunnel create "$tunnel_name"; then
            TUNNEL_ID=$(cloudflared tunnel list | grep "$tunnel_name" | awk '{print $1}')
            success "Tunnel created with ID: $TUNNEL_ID"
        else
            error "Failed to create tunnel"
            return 1
        fi
    fi
    
    # Save tunnel ID for later use
    echo "$TUNNEL_ID" > "${CONFIG_DIR}/tunnel_id.txt"
    echo "$tunnel_name" > "${CONFIG_DIR}/tunnel_name.txt"
}

# Generate tunnel configuration
generate_tunnel_config() {
    local tunnel_id="$1"
    local config_file="${CONFIG_DIR}/config.yml"
    
    log "Generating tunnel configuration..."
    
    # Get domain from user or use default
    echo ""
    echo "Enter your CloudFlare domain (e.g., yourdomain.com):"
    read -r cf_domain
    
    if [[ -z "$cf_domain" ]]; then
        error "Domain is required"
        return 1
    fi
    
    # Create tunnel configuration
    cat > "$config_file" << EOF
tunnel: ${tunnel_id}
credentials-file: /etc/cloudflared/${tunnel_id}.json

ingress:
  # Main web interface
  - hostname: noctis.${cf_domain}
    service: http://localhost:8000
    originRequest:
      httpHostHeader: localhost:8000
      noTLSVerify: true

  # Admin interface
  - hostname: admin.${cf_domain}
    service: http://localhost:8000/admin/
    originRequest:
      httpHostHeader: localhost:8000
      noTLSVerify: true

  # DICOM receiver (TCP over HTTP tunnel)
  - hostname: dicom.${cf_domain}
    service: tcp://localhost:11112
    originRequest:
      noTLSVerify: true

  # API endpoints
  - hostname: api.${cf_domain}
    service: http://localhost:8000/api/
    originRequest:
      httpHostHeader: localhost:8000
      noTLSVerify: true

  # Static files
  - hostname: static.${cf_domain}
    service: http://localhost:8000/static/
    originRequest:
      httpHostHeader: localhost:8000
      noTLSVerify: true

  # Media files
  - hostname: media.${cf_domain}
    service: http://localhost:8000/media/
    originRequest:
      httpHostHeader: localhost:8000
      noTLSVerify: true

  # Catch-all rule - must be last
  - service: http_status:404
EOF

    success "Tunnel configuration created: $config_file"
    
    # Save domain for later use
    echo "$cf_domain" > "${CONFIG_DIR}/domain.txt"
}

# Create DNS records
setup_dns_records() {
    local cf_domain="$1"
    local tunnel_id="$2"
    
    log "Setting up DNS records for CloudFlare tunnel..."
    
    # List of subdomains to create
    local subdomains=("noctis" "admin" "dicom" "api" "static" "media")
    
    for subdomain in "${subdomains[@]}"; do
        local hostname="${subdomain}.${cf_domain}"
        
        log "Creating DNS record for $hostname..."
        
        if cloudflared tunnel route dns "$tunnel_id" "$hostname"; then
            success "DNS record created: $hostname"
        else
            warn "Failed to create DNS record for $hostname (may already exist)"
        fi
    done
}

# Create systemd service for tunnel
create_tunnel_service() {
    local config_file="${CONFIG_DIR}/config.yml"
    
    log "Creating systemd service for CloudFlare tunnel..."
    
    # Create systemd service file
    sudo tee /etc/systemd/system/cloudflared-tunnel.service > /dev/null << EOF
[Unit]
Description=CloudFlare Tunnel for NoctisPro PACS
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel --config ${config_file} run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable cloudflared-tunnel.service
    
    success "CloudFlare tunnel systemd service created"
}

# Update Docker configuration for CloudFlare integration
update_docker_config() {
    local docker_compose_file="${PROJECT_DIR}/docker-compose.cloudflare.yml"
    
    log "Creating CloudFlare-integrated Docker Compose configuration..."
    
    # Read the tunnel ID and domain
    local tunnel_id=$(cat "${CONFIG_DIR}/tunnel_id.txt" 2>/dev/null || echo "")
    local cf_domain=$(cat "${CONFIG_DIR}/domain.txt" 2>/dev/null || echo "")
    
    if [[ -z "$tunnel_id" || -z "$cf_domain" ]]; then
        warn "Tunnel ID or domain not found. Creating basic configuration."
        tunnel_id="YOUR_TUNNEL_ID"
        cf_domain="yourdomain.com"
    fi
    
    cat > "$docker_compose_file" << EOF
version: '3.8'

services:
  # PostgreSQL Database
  db:
    image: postgres:15-alpine
    container_name: noctis_db
    environment:
      POSTGRES_DB: noctis_pro
      POSTGRES_USER: noctis_user
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:-noctis_secure_password}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U noctis_user -d noctis_pro"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    networks:
      - noctis_network

  # Redis for caching and message broker
  redis:
    image: redis:7-alpine
    container_name: noctis_redis
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    networks:
      - noctis_network

  # Django Web Application
  web:
    build:
      context: .
      dockerfile: Dockerfile
      target: \${BUILD_TARGET:-production}
    container_name: noctis_web
    environment:
      - DEBUG=\${DEBUG:-False}
      - SECRET_KEY=\${SECRET_KEY:-your-secret-key-change-in-production}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - DB_ENGINE=django.db.backends.postgresql
      - DB_NAME=noctis_pro
      - DB_USER=noctis_user
      - DB_PASSWORD=\${POSTGRES_PASSWORD:-noctis_secure_password}
      - DB_HOST=db
      - DB_PORT=5432
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
      - ALLOWED_HOSTS=*,noctis.${cf_domain},admin.${cf_domain},api.${cf_domain},static.${cf_domain},media.${cf_domain}
      - CLOUDFLARE_DOMAIN=${cf_domain}
    volumes:
      - .:/app
      - media_files:/app/media
      - static_files:/app/staticfiles
    ports:
      - "8000:8000"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    restart: unless-stopped
    networks:
      - noctis_network
    command: >
      sh -c "python manage.py migrate --noinput &&
             python manage.py collectstatic --noinput &&
             python -c \"from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').delete(); User.objects.create_superuser('admin', 'admin@noctispro.com', 'NoctisAdmin2024!'); print('✅ Admin user created')\" &&
             gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:8000 --workers 4 --timeout 120"

  # DICOM Receiver Service
  dicom_receiver:
    build:
      context: .
      dockerfile: Dockerfile
      target: \${BUILD_TARGET:-production}
    container_name: noctis_dicom
    environment:
      - DEBUG=\${DEBUG:-False}
      - SECRET_KEY=\${SECRET_KEY:-your-secret-key-change-in-production}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - DB_ENGINE=django.db.backends.postgresql
      - DB_NAME=noctis_pro
      - DB_USER=noctis_user
      - DB_PASSWORD=\${POSTGRES_PASSWORD:-noctis_secure_password}
      - DB_HOST=db
      - DB_PORT=5432
      - REDIS_URL=redis://redis:6379/0
      - CLOUDFLARE_DOMAIN=${cf_domain}
    volumes:
      - .:/app
      - media_files:/app/media
    ports:
      - "11112:11112"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - noctis_network
    command: python dicom_receiver.py --port 11112 --aet NOCTIS_SCP

  # Celery Worker for background tasks
  celery:
    build:
      context: .
      dockerfile: Dockerfile
      target: \${BUILD_TARGET:-production}
    container_name: noctis_celery
    environment:
      - DEBUG=\${DEBUG:-False}
      - SECRET_KEY=\${SECRET_KEY:-your-secret-key-change-in-production}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - DB_ENGINE=django.db.backends.postgresql
      - DB_NAME=noctis_pro
      - DB_USER=noctis_user
      - DB_PASSWORD=\${POSTGRES_PASSWORD:-noctis_secure_password}
      - DB_HOST=db
      - DB_PORT=5432
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
    volumes:
      - .:/app
      - media_files:/app/media
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - noctis_network
    command: celery -A noctis_pro worker --loglevel=info

  # CloudFlare Tunnel Service
  cloudflare_tunnel:
    image: cloudflare/cloudflared:latest
    container_name: noctis_cloudflare_tunnel
    environment:
      - TUNNEL_TOKEN=\${CLOUDFLARE_TUNNEL_TOKEN}
    volumes:
      - ./config/cloudflare:/etc/cloudflared
    restart: unless-stopped
    networks:
      - noctis_network
    command: tunnel --config /etc/cloudflared/config.yml run
    depends_on:
      - web
      - dicom_receiver

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  media_files:
    driver: local
  static_files:
    driver: local

networks:
  noctis_network:
    name: noctis_network
    driver: bridge
EOF

    success "CloudFlare-integrated Docker Compose configuration created: $docker_compose_file"
}

# Create environment file with CloudFlare settings
create_cloudflare_env() {
    local env_file="${PROJECT_DIR}/.env.cloudflare"
    local cf_domain=$(cat "${CONFIG_DIR}/domain.txt" 2>/dev/null || echo "yourdomain.com")
    
    log "Creating CloudFlare environment configuration..."
    
    cat > "$env_file" << EOF
# NoctisPro PACS - CloudFlare Configuration
# Generated by CloudFlare tunnel setup script

# Django Configuration
DEBUG=False
SECRET_KEY=$(openssl rand -base64 32)
DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Database Configuration
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# CloudFlare Configuration
CLOUDFLARE_DOMAIN=${cf_domain}
CLOUDFLARE_TUNNEL_TOKEN=YOUR_TUNNEL_TOKEN_HERE

# Public URLs
PUBLIC_WEB_URL=https://noctis.${cf_domain}
PUBLIC_ADMIN_URL=https://admin.${cf_domain}
PUBLIC_API_URL=https://api.${cf_domain}
PUBLIC_DICOM_URL=dicom.${cf_domain}:11112

# System Configuration
WORKERS=4
BUILD_TARGET=production

# Deployment Metadata
DEPLOYMENT_MODE=docker_cloudflare
DEPLOYED_AT=$(date -Iseconds)
EOF

    success "CloudFlare environment configuration created: $env_file"
    
    echo ""
    echo -e "${YELLOW}Important: Update the CLOUDFLARE_TUNNEL_TOKEN in $env_file${NC}"
    echo "You can get this token from the CloudFlare dashboard after creating your tunnel."
}

# Create startup script for CloudFlare integration
create_startup_script() {
    local startup_script="${PROJECT_DIR}/start_noctis_cloudflare.sh"
    
    log "Creating CloudFlare-integrated startup script..."
    
    cat > "$startup_script" << 'EOF'
#!/bin/bash

# NoctisPro PACS with CloudFlare Tunnel - Startup Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
cd "$PROJECT_DIR"

echo "🚀 Starting NoctisPro PACS with CloudFlare Tunnel..."
echo "=================================================="

# Load CloudFlare environment
if [ -f ".env.cloudflare" ]; then
    set -a
    . .env.cloudflare
    set +a
    echo "✅ CloudFlare configuration loaded"
else
    echo "⚠️  CloudFlare configuration not found, using defaults"
fi

# Check if CloudFlare tunnel is configured
if [ -f "config/cloudflare/config.yml" ]; then
    echo "✅ CloudFlare tunnel configuration found"
else
    echo "❌ CloudFlare tunnel not configured. Run ./cloudflare-tunnel-setup.sh first"
    exit 1
fi

# Start services with Docker Compose
echo "Starting services with Docker Compose..."

# Use CloudFlare-integrated compose file if available
if [ -f "docker-compose.cloudflare.yml" ]; then
    COMPOSE_FILE="docker-compose.cloudflare.yml"
    echo "Using CloudFlare-integrated configuration"
else
    COMPOSE_FILE="docker-compose.yml"
    echo "Using standard configuration"
fi

# Start services
docker-compose -f "$COMPOSE_FILE" up -d

# Wait for services to start
echo "Waiting for services to initialize..."
sleep 15

# Health checks
echo ""
echo "🔍 Performing health checks..."
echo "==============================="

# Check web service
if curl -f -s --max-time 10 "http://localhost:8000/" >/dev/null 2>&1; then
    echo "✅ Web service is responding"
    WEB_STATUS="✅ Healthy"
else
    echo "❌ Web service is not responding"
    WEB_STATUS="❌ Not responding"
fi

# Check DICOM port
if timeout 5 bash -c "</dev/tcp/localhost/11112" >/dev/null 2>&1; then
    echo "✅ DICOM port is accessible"
    DICOM_STATUS="✅ Accessible"
else
    echo "❌ DICOM port is not accessible"
    DICOM_STATUS="❌ Not accessible"
fi

# Check CloudFlare tunnel status
if systemctl is-active --quiet cloudflared-tunnel; then
    echo "✅ CloudFlare tunnel is running"
    TUNNEL_STATUS="✅ Active"
else
    echo "⚠️  CloudFlare tunnel service not active"
    TUNNEL_STATUS="⚠️  Inactive"
fi

# Display summary
echo ""
echo "🎉 NoctisPro PACS with CloudFlare - Deployment Summary"
echo "====================================================="
echo "Web Service:      $WEB_STATUS"
echo "DICOM Service:    $DICOM_STATUS"
echo "CloudFlare Tunnel: $TUNNEL_STATUS"
echo ""
echo "🌐 Access Information:"
if [ -n "${CLOUDFLARE_DOMAIN:-}" ]; then
    echo "   Public Web:     https://noctis.${CLOUDFLARE_DOMAIN}"
    echo "   Public Admin:   https://admin.${CLOUDFLARE_DOMAIN}"
    echo "   Public API:     https://api.${CLOUDFLARE_DOMAIN}"
    echo "   DICOM Endpoint: dicom.${CLOUDFLARE_DOMAIN}:11112"
else
    echo "   Local Web:      http://localhost:8000"
    echo "   Local Admin:    http://localhost:8000/admin/"
    echo "   Local DICOM:    localhost:11112"
fi
echo "   Default Login:  admin / NoctisAdmin2024!"
echo ""
echo "📁 Management Commands:"
echo "   View Logs:      docker-compose -f $COMPOSE_FILE logs -f"
echo "   Stop Services:  docker-compose -f $COMPOSE_FILE down"
echo "   Restart:        docker-compose -f $COMPOSE_FILE restart"
echo ""
echo "🚀 NoctisPro PACS with CloudFlare is ready!"
EOF

    chmod +x "$startup_script"
    success "CloudFlare-integrated startup script created: $startup_script"
}

# Main execution
main() {
    echo ""
    echo -e "${BOLD}${BLUE}🚀 NoctisPro PACS - CloudFlare Tunnel Setup${NC}"
    echo -e "${BOLD}${BLUE}==============================================${NC}"
    echo ""
    
    log "Starting CloudFlare tunnel setup..."
    
    # Step 1: Check CloudFlare installation
    check_cloudflared
    
    # Step 2: Setup authentication
    if setup_tunnel_auth; then
        # Step 3: Create tunnel
        create_tunnel
        
        # Step 4: Generate configuration
        generate_tunnel_config "$TUNNEL_ID"
        
        # Step 5: Setup DNS records
        setup_dns_records "$(cat ${CONFIG_DIR}/domain.txt)" "$TUNNEL_ID"
        
        # Step 6: Create systemd service
        create_tunnel_service
        
        success "CloudFlare tunnel setup completed successfully!"
    else
        warn "CloudFlare authentication skipped. Manual setup required."
    fi
    
    # Step 7: Update Docker configuration
    update_docker_config
    
    # Step 8: Create environment file
    create_cloudflare_env
    
    # Step 9: Create startup script
    create_startup_script
    
    echo ""
    echo -e "${BOLD}${GREEN}🎉 CloudFlare Tunnel Setup Complete!${NC}"
    echo "==========================================="
    echo ""
    echo "Next steps:"
    echo "1. Update the CLOUDFLARE_TUNNEL_TOKEN in .env.cloudflare"
    echo "2. Start the tunnel: sudo systemctl start cloudflared-tunnel"
    echo "3. Start NoctisPro with CloudFlare: ./start_noctis_cloudflare.sh"
    echo ""
    echo "Your consistent public URLs will be:"
    if [ -f "${CONFIG_DIR}/domain.txt" ]; then
        local cf_domain=$(cat "${CONFIG_DIR}/domain.txt")
        echo "  - Web Interface: https://noctis.${cf_domain}"
        echo "  - Admin Panel: https://admin.${cf_domain}"
        echo "  - DICOM Endpoint: dicom.${cf_domain}:11112"
    fi
    echo ""
    success "Setup complete! CloudFlare tunnel provides consistent URLs regardless of your local setup."
}

# Run main function
main "$@"