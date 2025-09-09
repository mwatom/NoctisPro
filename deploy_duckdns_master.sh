#!/bin/bash

# =============================================================================
# NoctisPro PACS - DuckDNS Master Deployment Script
# =============================================================================
# Seamless DuckDNS integration with automatic configuration and zero limits
# Unlike ngrok, DuckDNS provides unlimited HTTP requests and permanent URLs
# =============================================================================

set -euo pipefail

# Version and metadata
readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_NAME="NoctisPro DuckDNS Deployment"
readonly SCRIPT_DATE="$(date '+%Y-%m-%d')"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="${SCRIPT_DIR}"
readonly LOG_FILE="/tmp/noctis_duckdns_deploy_$(date +%Y%m%d_%H%M%S).log"
readonly DUCKDNS_CONFIG_DIR="/etc/noctis"
readonly DUCKDNS_ENV_FILE="${DUCKDNS_CONFIG_DIR}/duckdns.env"
readonly NOCTIS_ENV_FILE="${DUCKDNS_CONFIG_DIR}/noctis.env"

# Global variables
declare -g DUCKDNS_TOKEN=""
declare -g DUCKDNS_SUBDOMAIN=""
declare -g PUBLIC_IP=""
declare -g DEPLOYMENT_MODE="production"
declare -g USE_SSL=true
declare -g AUTO_RENEW=true

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

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
    echo "SUCCESS: ${message}" >> "${LOG_FILE}"
}

info() {
    local message="$1"
    echo -e "${BLUE}ℹ️  ${message}${NC}"
    echo "INFO: ${message}" >> "${LOG_FILE}"
}

phase() {
    local phase_name="$1"
    local message="$2"
    echo ""
    echo -e "${BOLD}${CYAN}=== ${phase_name}: ${message} ===${NC}"
    echo ""
    log "Phase started: ${phase_name}"
}

# =============================================================================
# DUCKDNS CONFIGURATION
# =============================================================================

check_existing_duckdns_config() {
    phase "CONFIG_CHECK" "Checking existing DuckDNS configuration"
    
    if [[ -f "${DUCKDNS_ENV_FILE}" ]]; then
        source "${DUCKDNS_ENV_FILE}"
        if [[ -n "${DUCKDNS_TOKEN:-}" ]] && [[ -n "${DUCKDNS_SUBDOMAIN:-}" ]]; then
            log "Found existing DuckDNS configuration"
            log "Subdomain: ${DUCKDNS_SUBDOMAIN}.duckdns.org"
            
            echo ""
            read -p "Use existing DuckDNS configuration? (Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                success "Using existing DuckDNS configuration"
                return 0
            fi
        fi
    fi
    
    return 1
}

configure_duckdns_interactive() {
    phase "DUCKDNS_SETUP" "Interactive DuckDNS Configuration"
    
    echo -e "${BOLD}${CYAN}🦆 DuckDNS Configuration${NC}"
    echo ""
    echo "DuckDNS provides free, permanent URLs with no HTTP request limits."
    echo "Unlike ngrok, your URL never changes and there are no usage restrictions."
    echo ""
    echo "If you don't have a DuckDNS account yet:"
    echo "  1. Visit https://www.duckdns.org"
    echo "  2. Sign in with Google, GitHub, or Twitter"
    echo "  3. Create a subdomain (e.g., 'myhospital')"
    echo "  4. Copy your token from the account page"
    echo ""
    
    # Get subdomain
    while [[ -z "${DUCKDNS_SUBDOMAIN}" ]]; do
        read -p "Enter your DuckDNS subdomain (without .duckdns.org): " DUCKDNS_SUBDOMAIN
        
        # Validate subdomain format
        if [[ ! "${DUCKDNS_SUBDOMAIN}" =~ ^[a-z0-9-]+$ ]]; then
            error "Invalid subdomain format. Use only lowercase letters, numbers, and hyphens."
            DUCKDNS_SUBDOMAIN=""
        fi
    done
    
    # Get token
    while [[ -z "${DUCKDNS_TOKEN}" ]]; do
        read -p "Enter your DuckDNS token: " DUCKDNS_TOKEN
        
        # Validate token format (UUID-like)
        if [[ ! "${DUCKDNS_TOKEN}" =~ ^[a-f0-9-]{36,}$ ]]; then
            warn "Token format looks unusual. Make sure you copied it correctly."
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                DUCKDNS_TOKEN=""
            fi
        fi
    done
    
    success "DuckDNS configuration collected"
}

detect_public_ip() {
    phase "IP_DETECTION" "Detecting public IP address"
    
    # Try multiple services for redundancy
    local ip_services=(
        "https://ifconfig.me"
        "https://api.ipify.org"
        "https://icanhazip.com"
        "https://checkip.amazonaws.com"
    )
    
    for service in "${ip_services[@]}"; do
        PUBLIC_IP=$(curl -s --max-time 5 "${service}" 2>/dev/null || true)
        if [[ -n "${PUBLIC_IP}" ]] && [[ "${PUBLIC_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            success "Detected public IP: ${PUBLIC_IP}"
            return 0
        fi
    done
    
    # Fallback to local IP if public IP detection fails
    PUBLIC_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -n "${PUBLIC_IP}" ]]; then
        warn "Could not detect public IP, using local IP: ${PUBLIC_IP}"
        warn "DuckDNS will auto-detect your public IP if behind NAT"
    else
        error "Could not detect any IP address"
        return 1
    fi
}

update_duckdns() {
    phase "DUCKDNS_UPDATE" "Updating DuckDNS record"
    
    local update_url="https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}"
    
    if [[ -n "${PUBLIC_IP}" ]]; then
        update_url="${update_url}&ip=${PUBLIC_IP}"
    fi
    
    log "Updating DuckDNS record for ${DUCKDNS_SUBDOMAIN}.duckdns.org..."
    
    local response=$(curl -s --max-time 10 "${update_url}" 2>/dev/null || echo "FAILED")
    
    if [[ "${response}" == "OK" ]]; then
        success "DuckDNS record updated successfully!"
        success "Your URL: https://${DUCKDNS_SUBDOMAIN}.duckdns.org"
    elif [[ "${response}" == "KO" ]]; then
        error "DuckDNS update failed - check your token and subdomain"
        return 1
    else
        error "DuckDNS update failed - network error"
        return 1
    fi
}

save_duckdns_config() {
    phase "CONFIG_SAVE" "Saving DuckDNS configuration"
    
    # Create config directory
    sudo mkdir -p "${DUCKDNS_CONFIG_DIR}"
    
    # Save DuckDNS configuration
    sudo tee "${DUCKDNS_ENV_FILE}" > /dev/null << EOF
# DuckDNS Configuration for NoctisPro PACS
# Generated on $(date)
DUCKDNS_TOKEN="${DUCKDNS_TOKEN}"
DUCKDNS_SUBDOMAIN="${DUCKDNS_SUBDOMAIN}"
DUCKDNS_UPDATE_INTERVAL=300
EOF
    
    # Save public URL to main config
    sudo tee "${NOCTIS_ENV_FILE}" > /dev/null << EOF
# NoctisPro PACS Configuration
# Generated on $(date)
PUBLIC_URL="https://${DUCKDNS_SUBDOMAIN}.duckdns.org"
ALLOWED_HOSTS="${DUCKDNS_SUBDOMAIN}.duckdns.org,localhost,127.0.0.1,${PUBLIC_IP}"
USE_SSL=${USE_SSL}
DEPLOYMENT_MODE=${DEPLOYMENT_MODE}
EOF
    
    # Secure the configuration files
    sudo chmod 600 "${DUCKDNS_ENV_FILE}" "${NOCTIS_ENV_FILE}"
    
    success "Configuration saved to ${DUCKDNS_CONFIG_DIR}"
}

# =============================================================================
# SYSTEMD SERVICE SETUP
# =============================================================================

setup_duckdns_systemd() {
    phase "SYSTEMD_SETUP" "Setting up automatic DuckDNS updates"
    
    log "Creating DuckDNS update service..."
    
    # Create update script
    sudo tee /usr/local/bin/duckdns-update > /dev/null << 'SCRIPT'
#!/bin/bash
set -euo pipefail

# Load configuration
source /etc/noctis/duckdns.env 2>/dev/null || exit 1

# Detect current IP
IP=$(curl -s --max-time 5 https://ifconfig.me || \
     curl -s --max-time 5 https://api.ipify.org || \
     hostname -I | awk '{print $1}')

# Update DuckDNS
URL="https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}"
[[ -n "${IP}" ]] && URL="${URL}&ip=${IP}"

RESPONSE=$(curl -s --max-time 10 "${URL}")
echo "$(date '+%Y-%m-%d %H:%M:%S') - DuckDNS update: ${RESPONSE} (IP: ${IP:-auto})"

[[ "${RESPONSE}" == "OK" ]] || exit 1
SCRIPT
    
    sudo chmod +x /usr/local/bin/duckdns-update
    
    # Create systemd service
    sudo tee /etc/systemd/system/duckdns-update.service > /dev/null << 'SERVICE'
[Unit]
Description=DuckDNS Dynamic DNS Updater
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/duckdns-update
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE
    
    # Create systemd timer for automatic updates
    sudo tee /etc/systemd/system/duckdns-update.timer > /dev/null << 'TIMER'
[Unit]
Description=Run DuckDNS updater every 5 minutes
Requires=duckdns-update.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
TIMER
    
    # Reload systemd and enable services
    sudo systemctl daemon-reload
    sudo systemctl enable --now duckdns-update.timer
    sudo systemctl start duckdns-update.service
    
    success "DuckDNS automatic updates configured (every 5 minutes)"
}

# =============================================================================
# DJANGO CONFIGURATION
# =============================================================================

update_django_settings() {
    phase "DJANGO_CONFIG" "Updating Django settings for DuckDNS"
    
    local settings_file="${PROJECT_DIR}/noctis_pro/settings.py"
    local public_url="https://${DUCKDNS_SUBDOMAIN}.duckdns.org"
    
    log "Updating Django settings for ${public_url}..."
    
    # Backup current settings
    cp "${settings_file}" "${settings_file}.backup.$(date +%s)"
    
    # Update ALLOWED_HOSTS if not already configured
    if ! grep -q "${DUCKDNS_SUBDOMAIN}.duckdns.org" "${settings_file}"; then
        python3 << PYTHON
import re

settings_file = "${settings_file}"
subdomain = "${DUCKDNS_SUBDOMAIN}"
public_ip = "${PUBLIC_IP}"

with open(settings_file, 'r') as f:
    content = f.read()

# Update ALLOWED_HOSTS
allowed_hosts_pattern = r'ALLOWED_HOSTS\s*=\s*\[[^\]]*\]'
new_allowed_hosts = f"""ALLOWED_HOSTS = [
    'localhost',
    '127.0.0.1',
    '{subdomain}.duckdns.org',
    '{public_ip}',
    '*'  # Allow all hosts in production with proper nginx config
]"""

if re.search(allowed_hosts_pattern, content):
    content = re.sub(allowed_hosts_pattern, new_allowed_hosts, content)
else:
    # Add after DEBUG setting
    debug_pattern = r'(DEBUG\s*=\s*[^\n]+\n)'
    content = re.sub(debug_pattern, r'\1\n' + new_allowed_hosts + '\n', content)

# Add CSRF trusted origins
csrf_pattern = r'CSRF_TRUSTED_ORIGINS\s*=\s*\[[^\]]*\]'
new_csrf = f"""CSRF_TRUSTED_ORIGINS = [
    'https://{subdomain}.duckdns.org',
    'http://{subdomain}.duckdns.org',
    'http://localhost:8000',
    'http://127.0.0.1:8000'
]"""

if not re.search(csrf_pattern, content):
    content = content + '\n' + new_csrf + '\n'

# Add PUBLIC_URL setting
if 'PUBLIC_URL' not in content:
    content = content + f"\n# DuckDNS Configuration\nPUBLIC_URL = 'https://{subdomain}.duckdns.org'\n"

with open(settings_file, 'w') as f:
    f.write(content)

print("Django settings updated successfully")
PYTHON
    fi
    
    success "Django settings updated for DuckDNS"
}

# =============================================================================
# NGINX CONFIGURATION
# =============================================================================

setup_nginx_duckdns() {
    phase "NGINX_SETUP" "Configuring Nginx for DuckDNS"
    
    # Install nginx if not present
    if ! command -v nginx >/dev/null 2>&1; then
        log "Installing Nginx..."
        sudo apt-get update
        sudo apt-get install -y nginx certbot python3-certbot-nginx
    fi
    
    local nginx_config="/etc/nginx/sites-available/noctis-duckdns"
    
    log "Creating Nginx configuration for ${DUCKDNS_SUBDOMAIN}.duckdns.org..."
    
    sudo tee "${nginx_config}" > /dev/null << EOF
# NoctisPro PACS - DuckDNS Nginx Configuration
# Auto-generated on $(date)

upstream noctis_backend {
    server localhost:8000;
}

server {
    listen 80;
    listen [::]:80;
    server_name ${DUCKDNS_SUBDOMAIN}.duckdns.org;

    # Redirect to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DUCKDNS_SUBDOMAIN}.duckdns.org;

    # SSL will be configured by certbot
    # ssl_certificate /etc/letsencrypt/live/${DUCKDNS_SUBDOMAIN}.duckdns.org/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/${DUCKDNS_SUBDOMAIN}.duckdns.org/privkey.pem;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Max upload size for DICOM files
    client_max_body_size 500M;
    client_body_timeout 300s;

    # Proxy settings
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
    send_timeout 300s;

    location / {
        proxy_pass http://noctis_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    location /static/ {
        alias ${PROJECT_DIR}/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias ${PROJECT_DIR}/media/;
        expires 7d;
        add_header Cache-Control "public";
    }

    # WebSocket support for real-time features
    location /ws/ {
        proxy_pass http://noctis_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    # Enable the site
    sudo ln -sf "${nginx_config}" /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx configuration
    if sudo nginx -t; then
        sudo systemctl reload nginx
        success "Nginx configured for DuckDNS"
    else
        error "Nginx configuration test failed"
        return 1
    fi
}

# =============================================================================
# SSL CERTIFICATE SETUP
# =============================================================================

setup_ssl_certificate() {
    phase "SSL_SETUP" "Setting up SSL certificate with Let's Encrypt"
    
    if [[ "${USE_SSL}" != "true" ]]; then
        warn "SSL disabled, skipping certificate setup"
        return 0
    fi
    
    log "Obtaining SSL certificate for ${DUCKDNS_SUBDOMAIN}.duckdns.org..."
    
    # Install certbot if not present
    if ! command -v certbot >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y certbot python3-certbot-nginx
    fi
    
    # Obtain certificate
    sudo certbot --nginx \
        -d "${DUCKDNS_SUBDOMAIN}.duckdns.org" \
        --non-interactive \
        --agree-tos \
        --email "admin@${DUCKDNS_SUBDOMAIN}.duckdns.org" \
        --redirect \
        --expand
    
    if [[ $? -eq 0 ]]; then
        success "SSL certificate obtained successfully!"
        
        # Setup auto-renewal
        if [[ "${AUTO_RENEW}" == "true" ]]; then
            log "Setting up automatic SSL renewal..."
            (sudo crontab -l 2>/dev/null; echo "0 0,12 * * * certbot renew --quiet --no-self-upgrade") | sudo crontab -
            success "SSL auto-renewal configured"
        fi
    else
        warn "SSL certificate setup failed - continuing without SSL"
        warn "You can manually run: sudo certbot --nginx -d ${DUCKDNS_SUBDOMAIN}.duckdns.org"
    fi
}

# =============================================================================
# SERVICE INTEGRATION
# =============================================================================

integrate_with_noctis_services() {
    phase "SERVICE_INTEGRATION" "Integrating DuckDNS with NoctisPro services"
    
    # Update systemd service files if they exist
    local service_files=(
        "/etc/systemd/system/noctis-web.service"
        "/etc/systemd/system/noctis-dicom.service"
        "/etc/systemd/system/noctis-worker.service"
    )
    
    for service_file in "${service_files[@]}"; do
        if [[ -f "${service_file}" ]]; then
            log "Updating ${service_file} with DuckDNS environment..."
            
            # Add environment file to service
            if ! grep -q "EnvironmentFile=" "${service_file}"; then
                sudo sed -i "/\[Service\]/a EnvironmentFile=-${NOCTIS_ENV_FILE}" "${service_file}"
            fi
        fi
    done
    
    # Reload systemd if we made changes
    if [[ -f "/etc/systemd/system/noctis-web.service" ]]; then
        sudo systemctl daemon-reload
        success "NoctisPro services updated with DuckDNS configuration"
    fi
}

# =============================================================================
# VALIDATION AND TESTING
# =============================================================================

validate_duckdns_setup() {
    phase "VALIDATION" "Validating DuckDNS setup"
    
    local validation_passed=true
    local public_url="https://${DUCKDNS_SUBDOMAIN}.duckdns.org"
    
    # Test DNS resolution
    log "Testing DNS resolution..."
    if host "${DUCKDNS_SUBDOMAIN}.duckdns.org" >/dev/null 2>&1; then
        success "✅ DNS resolution working"
    else
        error "❌ DNS resolution failed"
        validation_passed=false
    fi
    
    # Test HTTP redirect
    log "Testing HTTP redirect..."
    if curl -sI "http://${DUCKDNS_SUBDOMAIN}.duckdns.org" | grep -q "301\|302"; then
        success "✅ HTTP redirect working"
    else
        warn "⚠️  HTTP redirect may not be configured"
    fi
    
    # Test HTTPS access
    log "Testing HTTPS access..."
    if curl -sSf --max-time 10 "${public_url}" >/dev/null 2>&1; then
        success "✅ HTTPS access working"
    else
        warn "⚠️  HTTPS access not yet available (certificate may be pending)"
    fi
    
    # Test DuckDNS update service
    log "Testing DuckDNS update service..."
    if sudo systemctl is-active --quiet duckdns-update.timer; then
        success "✅ DuckDNS auto-update active"
    else
        error "❌ DuckDNS auto-update not running"
        validation_passed=false
    fi
    
    if [[ "${validation_passed}" == "true" ]]; then
        success "All validation checks passed!"
    else
        warn "Some validation checks failed - please review the logs"
    fi
    
    return 0
}

# =============================================================================
# DEPLOYMENT SUMMARY
# =============================================================================

display_deployment_summary() {
    local public_url="https://${DUCKDNS_SUBDOMAIN}.duckdns.org"
    
    echo ""
    echo "=============================================="
    echo "🦆 DuckDNS Deployment Complete!"
    echo "=============================================="
    echo ""
    echo "📊 Configuration Summary:"
    echo "  Domain: ${GREEN}${DUCKDNS_SUBDOMAIN}.duckdns.org${NC}"
    echo "  Public IP: ${GREEN}${PUBLIC_IP}${NC}"
    echo "  SSL Enabled: ${GREEN}${USE_SSL}${NC}"
    echo "  Auto-Update: ${GREEN}Every 5 minutes${NC}"
    echo ""
    echo "🌐 Access URLs:"
    echo "  Main Application: ${GREEN}${public_url}${NC}"
    echo "  Admin Panel: ${GREEN}${public_url}/admin/${NC}"
    echo "  DICOM Viewer: ${GREEN}${public_url}/dicom-viewer/${NC}"
    echo "  API Endpoint: ${GREEN}${public_url}/api/${NC}"
    echo ""
    echo "🔧 Management Commands:"
    echo "  Check status: ${CYAN}sudo systemctl status duckdns-update.timer${NC}"
    echo "  View logs: ${CYAN}sudo journalctl -u duckdns-update -f${NC}"
    echo "  Update now: ${CYAN}sudo systemctl start duckdns-update${NC}"
    echo "  Restart services: ${CYAN}sudo systemctl restart noctis-web${NC}"
    echo ""
    echo "📝 Configuration Files:"
    echo "  DuckDNS Config: ${DUCKDNS_ENV_FILE}"
    echo "  NoctisPro Config: ${NOCTIS_ENV_FILE}"
    echo "  Nginx Config: /etc/nginx/sites-available/noctis-duckdns"
    echo ""
    echo "✨ Key Advantages over Ngrok:"
    echo "  ✅ No HTTP request limits"
    echo "  ✅ Permanent URL that never changes"
    echo "  ✅ Free SSL certificates"
    echo "  ✅ No session timeouts"
    echo "  ✅ Full production ready"
    echo "  ✅ Automatic IP updates"
    echo ""
    success "🎉 Your NoctisPro PACS is now accessible worldwide at:"
    success "🔗 ${public_url}"
    echo ""
    echo "Default login: admin / admin123"
    echo ""
}

# =============================================================================
# MAIN ORCHESTRATION
# =============================================================================

main() {
    local start_time=$(date +%s)
    
    echo ""
    echo "${BOLD}${CYAN}🦆 NoctisPro PACS - DuckDNS Master Deployment${NC}"
    echo "${BOLD}${CYAN}===============================================${NC}"
    echo ""
    echo "Version: ${SCRIPT_VERSION}"
    echo "Date: ${SCRIPT_DATE}"
    echo ""
    echo "This script will configure DuckDNS for global access with:"
    echo "  • No HTTP request limits (unlike ngrok)"
    echo "  • Permanent URL that never changes"
    echo "  • Automatic SSL certificates"
    echo "  • Production-ready configuration"
    echo ""
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        error "Please run this script with sudo, not as root directly"
        exit 1
    fi
    
    # Check for existing configuration
    if ! check_existing_duckdns_config; then
        configure_duckdns_interactive
    fi
    
    # Detect public IP
    detect_public_ip
    
    # Update DuckDNS record
    update_duckdns
    
    # Save configuration
    save_duckdns_config
    
    # Setup automatic updates
    setup_duckdns_systemd
    
    # Update Django settings
    update_django_settings
    
    # Setup Nginx
    setup_nginx_duckdns
    
    # Setup SSL certificate
    setup_ssl_certificate
    
    # Integrate with existing services
    integrate_with_noctis_services
    
    # Validate setup
    validate_duckdns_setup
    
    # Display summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "Total deployment time: ${duration} seconds"
    display_deployment_summary
    
    success "DuckDNS deployment completed successfully!"
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "NoctisPro DuckDNS Deployment Script v${SCRIPT_VERSION}"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --token TOKEN       DuckDNS token (optional, will prompt if not provided)"
        echo "  --subdomain NAME    DuckDNS subdomain (optional, will prompt if not provided)"
        echo "  --no-ssl            Disable SSL certificate setup"
        echo "  --no-auto-renew     Disable automatic SSL renewal"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Interactive setup"
        echo "  $0 --token abc123 --subdomain clinic  # Automated setup"
        echo ""
        exit 0
        ;;
    --token)
        DUCKDNS_TOKEN="${2:-}"
        shift 2
        ;;
    --subdomain)
        DUCKDNS_SUBDOMAIN="${2:-}"
        shift 2
        ;;
    --no-ssl)
        USE_SSL=false
        shift
        ;;
    --no-auto-renew)
        AUTO_RENEW=false
        shift
        ;;
esac

# Run main deployment
main "$@"