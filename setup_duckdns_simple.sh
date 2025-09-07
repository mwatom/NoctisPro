#!/bin/bash

# =============================================================================
# Simple DuckDNS Setup Script for NoctisPro PACS
# =============================================================================
# This script sets up DuckDNS for your NoctisPro deployment
# Unlike ngrok, DuckDNS has no HTTP request limits and is completely free
# =============================================================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration
readonly PROJECT_DIR="/workspace"
readonly LOG_FILE="/tmp/duckdns_setup_$(date +%Y%m%d_%H%M%S).log"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}${message}${NC}"
    echo "${message}" >> "${LOG_FILE}"
}

warn() {
    local message="[WARNING] $1"
    echo -e "${YELLOW}${message}${NC}" >&2
    echo "${message}" >> "${LOG_FILE}"
}

error() {
    local message="[ERROR] $1"
    echo -e "${RED}${message}${NC}" >&2
    echo "${message}" >> "${LOG_FILE}"
}

info() {
    local message="[INFO] $1"
    echo -e "${BLUE}${message}${NC}"
    echo "${message}" >> "${LOG_FILE}"
}

success() {
    local message="[SUCCESS] $1"
    echo -e "${GREEN}✅ ${message}${NC}"
    echo "${message}" >> "${LOG_FILE}"
}

# =============================================================================
# DUCKDNS SETUP FUNCTIONS
# =============================================================================

display_intro() {
    echo ""
    echo -e "${BOLD}${CYAN}🦆 DuckDNS Setup for NoctisPro PACS${NC}"
    echo -e "${BOLD}${CYAN}====================================${NC}"
    echo ""
    echo -e "${BLUE}DuckDNS provides free dynamic DNS with NO HTTP limits!${NC}"
    echo -e "${BLUE}Perfect alternative to ngrok for your PACS deployment.${NC}"
    echo ""
    echo -e "${YELLOW}What you'll need:${NC}"
    echo "1. A DuckDNS account (free at https://www.duckdns.org)"
    echo "2. Your DuckDNS token"
    echo "3. A subdomain name (e.g., 'mynoctispro')"
    echo ""
}

get_duckdns_credentials() {
    local token=""
    local subdomain=""
    
    # Check if already configured
    if [[ -f "${PROJECT_DIR}/.duckdns_config" ]]; then
        source "${PROJECT_DIR}/.duckdns_config"
        if [[ -n "${DUCKDNS_TOKEN:-}" ]] && [[ -n "${DUCKDNS_SUBDOMAIN:-}" ]]; then
            info "Found existing DuckDNS configuration:"
            info "  Subdomain: ${DUCKDNS_SUBDOMAIN}.duckdns.org"
            echo ""
            read -p "Do you want to use this configuration? (Y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                log "Setting up new DuckDNS configuration..."
            else
                log "Using existing DuckDNS configuration"
                return 0
            fi
        fi
    fi
    
    # Get DuckDNS token
    echo -e "${YELLOW}Step 1: Get your DuckDNS token${NC}"
    echo "1. Go to https://www.duckdns.org"
    echo "2. Sign in with Google/GitHub/Reddit/Twitter"
    echo "3. Copy your token from the top of the page"
    echo ""
    
    while [[ -z "$token" ]]; do
        read -p "Enter your DuckDNS token: " token
        if [[ -z "$token" ]]; then
            warn "Token cannot be empty. Please try again."
        fi
    done
    
    # Get subdomain
    echo ""
    echo -e "${YELLOW}Step 2: Choose your subdomain${NC}"
    echo "This will be your domain: [subdomain].duckdns.org"
    echo ""
    
    while [[ -z "$subdomain" ]]; do
        read -p "Enter your subdomain (e.g., 'mynoctispro'): " subdomain
        if [[ -z "$subdomain" ]]; then
            warn "Subdomain cannot be empty. Please try again."
        elif [[ ! "$subdomain" =~ ^[a-zA-Z0-9-]+$ ]]; then
            warn "Subdomain can only contain letters, numbers, and hyphens."
            subdomain=""
        fi
    done
    
    # Save configuration
    DUCKDNS_TOKEN="$token"
    DUCKDNS_SUBDOMAIN="$subdomain"
    DUCKDNS_DOMAIN="${subdomain}.duckdns.org"
    
    log "DuckDNS credentials configured"
    log "Domain: ${DUCKDNS_DOMAIN}"
}

detect_public_ip() {
    log "Detecting public IP address..."
    
    local ip_services=(
        "https://ifconfig.me"
        "https://api.ipify.org"
        "https://ipinfo.io/ip"
        "https://checkip.amazonaws.com"
        "https://icanhazip.com"
    )
    
    PUBLIC_IP=""
    for service in "${ip_services[@]}"; do
        log "Trying IP detection service: $service"
        PUBLIC_IP=$(curl -s --connect-timeout 10 --max-time 15 "$service" 2>/dev/null | tr -d '\n\r' | grep -oE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' || true)
        
        if [[ -n "$PUBLIC_IP" ]] && [[ "$PUBLIC_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            success "Public IP detected: $PUBLIC_IP"
            return 0
        fi
    done
    
    warn "Could not detect public IP - DuckDNS will use auto-detection"
    PUBLIC_IP=""
}

test_duckdns_update() {
    log "Testing DuckDNS update..."
    
    local update_url="https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}"
    if [[ -n "$PUBLIC_IP" ]]; then
        update_url+="&ip=${PUBLIC_IP}"
    fi
    
    local response=$(curl -s --connect-timeout 30 --max-time 45 "$update_url" 2>/dev/null || echo "ERROR")
    
    if [[ "$response" == "OK" ]]; then
        success "DuckDNS update successful!"
        log "Domain ${DUCKDNS_DOMAIN} is now pointing to your server"
    else
        error "DuckDNS update failed: $response"
        error "Please check your token and subdomain"
        return 1
    fi
}

create_update_script() {
    log "Creating DuckDNS update script..."
    
    local update_script="${PROJECT_DIR}/update_duckdns.sh"
    
    cat > "$update_script" << EOF
#!/bin/bash
# DuckDNS IP Update Script for NoctisPro PACS
# Auto-generated by DuckDNS setup script

set -euo pipefail

# Configuration
DUCKDNS_TOKEN="${DUCKDNS_TOKEN}"
DUCKDNS_SUBDOMAIN="${DUCKDNS_SUBDOMAIN}"
LOG_FILE="${PROJECT_DIR}/duckdns.log"

# Get current public IP with fallback methods
PUBLIC_IP=""
for service in "https://ifconfig.me" "https://api.ipify.org" "https://ipinfo.io/ip" "https://checkip.amazonaws.com"; do
    PUBLIC_IP=\$(curl -s --connect-timeout 10 --max-time 15 "\$service" 2>/dev/null | tr -d '\n\r' | grep -oE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\$' || true)
    if [[ -n "\$PUBLIC_IP" ]] && [[ "\$PUBLIC_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\$ ]]; then
        break
    fi
    PUBLIC_IP=""
done

# Update DuckDNS
UPDATE_URL="https://www.duckdns.org/update?domains=\${DUCKDNS_SUBDOMAIN}&token=\${DUCKDNS_TOKEN}"
if [[ -n "\$PUBLIC_IP" ]]; then
    UPDATE_URL+="&ip=\${PUBLIC_IP}"
fi

RESPONSE=\$(curl -s --connect-timeout 30 --max-time 45 "\$UPDATE_URL" 2>/dev/null || echo "ERROR")

if [[ "\$RESPONSE" == "OK" ]]; then
    if [[ -n "\$PUBLIC_IP" ]]; then
        echo "\$(date): SUCCESS: Updated \${DUCKDNS_SUBDOMAIN}.duckdns.org to \$PUBLIC_IP" >> "\$LOG_FILE"
    else
        echo "\$(date): SUCCESS: Updated \${DUCKDNS_SUBDOMAIN}.duckdns.org (auto-detected IP)" >> "\$LOG_FILE"
    fi
else
    echo "\$(date): ERROR: Failed to update DNS. Response: \$RESPONSE" >> "\$LOG_FILE"
fi
EOF

    chmod +x "$update_script"
    success "Update script created: $update_script"
}

setup_cron_job() {
    log "Setting up automatic updates (cron job)..."
    
    local update_script="${PROJECT_DIR}/update_duckdns.sh"
    local cron_entry="*/5 * * * * $update_script >/dev/null 2>&1"
    
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "$update_script"; then
        info "Cron job already exists, updating..."
        (crontab -l 2>/dev/null | grep -v "$update_script"; echo "$cron_entry") | crontab -
    else
        info "Adding new cron job..."
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    fi
    
    success "Cron job configured - DuckDNS will update every 5 minutes"
}

save_configuration() {
    log "Saving DuckDNS configuration..."
    
    # Save to project directory
    cat > "${PROJECT_DIR}/.duckdns_config" << EOF
# DuckDNS Configuration for NoctisPro PACS
# Generated on $(date)

DUCKDNS_TOKEN="${DUCKDNS_TOKEN}"
DUCKDNS_SUBDOMAIN="${DUCKDNS_SUBDOMAIN}"
DUCKDNS_DOMAIN="${DUCKDNS_DOMAIN}"
PUBLIC_IP="${PUBLIC_IP}"
DUCKDNS_ENABLED=true
EOF

    chmod 600 "${PROJECT_DIR}/.duckdns_config"
    
    # Also save to environment file
    if [[ -f "${PROJECT_DIR}/.env" ]]; then
        # Update existing .env file
        grep -v "DUCKDNS_" "${PROJECT_DIR}/.env" > "${PROJECT_DIR}/.env.tmp" || true
        cat >> "${PROJECT_DIR}/.env.tmp" << EOF

# DuckDNS Configuration
DUCKDNS_TOKEN=${DUCKDNS_TOKEN}
DUCKDNS_SUBDOMAIN=${DUCKDNS_SUBDOMAIN}
DUCKDNS_DOMAIN=${DUCKDNS_DOMAIN}
DUCKDNS_ENABLED=true
EOF
        mv "${PROJECT_DIR}/.env.tmp" "${PROJECT_DIR}/.env"
    else
        # Create new .env file
        cat > "${PROJECT_DIR}/.env" << EOF
# DuckDNS Configuration
DUCKDNS_TOKEN=${DUCKDNS_TOKEN}
DUCKDNS_SUBDOMAIN=${DUCKDNS_SUBDOMAIN}
DUCKDNS_DOMAIN=${DUCKDNS_DOMAIN}
DUCKDNS_ENABLED=true
EOF
    fi
    
    success "Configuration saved"
}

test_dns_resolution() {
    log "Testing DNS resolution..."
    
    # Wait a moment for DNS to propagate
    sleep 5
    
    local resolved_ip=$(nslookup "${DUCKDNS_DOMAIN}" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}' || true)
    
    if [[ -n "$resolved_ip" ]]; then
        info "DNS resolution: ${DUCKDNS_DOMAIN} -> ${resolved_ip}"
        if [[ "$resolved_ip" == "$PUBLIC_IP" ]]; then
            success "DNS resolution matches your public IP!"
        else
            warn "DNS may still be propagating (can take a few minutes)"
        fi
    else
        warn "DNS resolution test inconclusive - may need time to propagate"
    fi
}

display_summary() {
    echo ""
    echo -e "${BOLD}${GREEN}🎉 DuckDNS Setup Complete!${NC}"
    echo "================================"
    echo ""
    echo -e "${CYAN}Your DuckDNS Domain:${NC} ${BOLD}${DUCKDNS_DOMAIN}${NC}"
    echo -e "${CYAN}Public IP:${NC} ${PUBLIC_IP:-auto-detected}"
    echo ""
    echo -e "${YELLOW}Access URLs:${NC}"
    echo "  • Web Interface: http://${DUCKDNS_DOMAIN}:8000"
    echo "  • Admin Panel: http://${DUCKDNS_DOMAIN}:8000/admin/"
    echo "  • DICOM Port: ${DUCKDNS_DOMAIN}:11112"
    echo ""
    echo -e "${YELLOW}Files Created:${NC}"
    echo "  • Configuration: ${PROJECT_DIR}/.duckdns_config"
    echo "  • Update Script: ${PROJECT_DIR}/update_duckdns.sh"
    echo "  • Environment: ${PROJECT_DIR}/.env"
    echo "  • Log File: ${LOG_FILE}"
    echo ""
    echo -e "${YELLOW}Automatic Updates:${NC}"
    echo "  • Cron job runs every 5 minutes"
    echo "  • Updates log to: ${PROJECT_DIR}/duckdns.log"
    echo ""
    echo -e "${GREEN}✅ No HTTP limits like ngrok!${NC}"
    echo -e "${GREEN}✅ Completely free service${NC}"
    echo -e "${GREEN}✅ Automatic IP updates${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "1. Run your main deployment script: ./deploy_master.sh"
    echo "2. Access your PACS at: http://${DUCKDNS_DOMAIN}:8000"
    echo "3. Check logs: tail -f ${PROJECT_DIR}/duckdns.log"
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local start_time=$(date +%s)
    
    display_intro
    
    # Step 1: Get credentials
    get_duckdns_credentials
    
    # Step 2: Detect public IP
    detect_public_ip
    
    # Step 3: Test DuckDNS update
    if ! test_duckdns_update; then
        error "DuckDNS setup failed. Please check your credentials."
        exit 1
    fi
    
    # Step 4: Create update script
    create_update_script
    
    # Step 5: Setup automatic updates
    setup_cron_job
    
    # Step 6: Save configuration
    save_configuration
    
    # Step 7: Test DNS resolution
    test_dns_resolution
    
    # Step 8: Display summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log "Setup completed in ${duration} seconds"
    
    display_summary
}

# Error handling
trap 'error "Setup interrupted"; exit 1' INT TERM

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root for security reasons."
    error "Please run as a regular user."
    exit 1
fi

# Run main function
main "$@"