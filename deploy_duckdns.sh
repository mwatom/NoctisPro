#!/bin/bash

# =============================================================================
# NoctisPro PACS - DuckDNS Deployment Script
# =============================================================================
# This script deploys NoctisPro PACS with DuckDNS dynamic DNS support
# Features:
# - Free DuckDNS subdomain (no HTTP limits like ngrok)
# - Automatic SSL certificates with Let's Encrypt
# - Automatic IP updates every 5 minutes
# - Production-ready configuration
# =============================================================================

set -euo pipefail

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

# Global variables
DUCKDNS_SUBDOMAIN=""
DUCKDNS_TOKEN=""
DUCKDNS_DOMAIN=""
DEPLOYMENT_MODE=""

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

display_duckdns_intro() {
    echo ""
    echo -e "${BOLD}${CYAN}🦆 NoctisPro PACS - DuckDNS Deployment${NC}"
    echo -e "${BOLD}${CYAN}=====================================${NC}"
    echo ""
    echo -e "${GREEN}Why DuckDNS is Perfect for Medical Imaging:${NC}"
    echo "• 🆓 Completely FREE - No usage limits like ngrok"
    echo "• 🔒 SSL certificates with Let's Encrypt"
    echo "• 🌐 Global access with your own subdomain"
    echo "• 🔄 Automatic IP updates every 5 minutes"
    echo "• 🏥 Perfect for hospitals, clinics, and radiology practices"
    echo ""
    echo -e "${BLUE}Examples of what you'll get:${NC}"
    echo "• https://myclinic.duckdns.org"
    echo "• https://radiologylab.duckdns.org" 
    echo "• https://drsmith.duckdns.org"
    echo ""
}

setup_duckdns_credentials() {
    echo -e "${BOLD}${BLUE}📋 DuckDNS Setup Instructions:${NC}"
    echo ""
    echo "1. 🌐 Visit https://www.duckdns.org"
    echo "2. 🔑 Sign in with Google, GitHub, or Reddit (free)"
    echo "3. 📝 Create a subdomain (e.g., 'mynoctis' -> mynoctis.duckdns.org)"
    echo "4. 📋 Copy your token from the dashboard"
    echo ""
    
    while true; do
        read -p "Enter your DuckDNS subdomain (without .duckdns.org): " DUCKDNS_SUBDOMAIN
        if [[ -n "${DUCKDNS_SUBDOMAIN}" ]]; then
            break
        fi
        echo "Please enter a valid subdomain."
    done
    
    while true; do
        read -p "Enter your DuckDNS token: " DUCKDNS_TOKEN
        if [[ -n "${DUCKDNS_TOKEN}" ]]; then
            break
        fi
        echo "Please enter a valid token."
    done
    
    DUCKDNS_DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
    
    log "DuckDNS configuration:"
    log "  Subdomain: ${DUCKDNS_SUBDOMAIN}"
    log "  Domain: ${DUCKDNS_DOMAIN}"
}

test_duckdns_configuration() {
    log "Testing DuckDNS configuration..."
    
    local test_response
    test_response=$(curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}" || echo "FAIL")
    
    if [[ "${test_response}" == "OK" ]]; then
        success "✅ DuckDNS configuration verified!"
        
        # Wait a moment and test DNS resolution
        log "Testing DNS resolution..."
        sleep 5
        
        if nslookup "${DUCKDNS_DOMAIN}" >/dev/null 2>&1; then
            success "✅ DNS resolution working!"
        else
            warn "⚠️  DNS may still be propagating (this is normal)"
        fi
    else
        error "❌ DuckDNS configuration test failed: ${test_response}"
        error "Please check your subdomain and token"
        exit 1
    fi
}

choose_deployment_mode() {
    echo ""
    echo -e "${BOLD}${BLUE}🚀 Choose Deployment Mode:${NC}"
    echo ""
    echo "1. 🤖 Intelligent Auto-Detection (Recommended)"
    echo "   - Automatically detects your system capabilities"
    echo "   - Optimizes configuration for your hardware"
    echo "   - Best performance and reliability"
    echo ""
    echo "2. 📋 Master Orchestration"
    echo "   - Full-featured deployment with all bells and whistles"
    echo "   - Comprehensive validation and monitoring"
    echo "   - Professional deployment with detailed reporting"
    echo ""
    
    while true; do
        read -p "Select deployment mode (1-2): " choice
        case $choice in
            1)
                DEPLOYMENT_MODE="intelligent"
                info "Selected: Intelligent Auto-Detection"
                break
                ;;
            2)
                DEPLOYMENT_MODE="master"
                info "Selected: Master Orchestration"
                break
                ;;
            *)
                echo "Please enter 1 or 2."
                ;;
        esac
    done
}

run_deployment() {
    log "Starting deployment with DuckDNS configuration..."
    
    # Export DuckDNS configuration for the deployment script
    export DUCKDNS_SUBDOMAIN="${DUCKDNS_SUBDOMAIN}"
    export DUCKDNS_TOKEN="${DUCKDNS_TOKEN}"
    export DUCKDNS_ENABLED="true"
    export DUCKDNS_DOMAIN="${DUCKDNS_DOMAIN}"
    
    case "${DEPLOYMENT_MODE}" in
        "intelligent")
            if [[ -x "${PROJECT_DIR}/deploy_intelligent.sh" ]]; then
                log "Running intelligent deployment..."
                "${PROJECT_DIR}/deploy_intelligent.sh"
            else
                error "Intelligent deployment script not found"
                exit 1
            fi
            ;;
        "master")
            if [[ -x "${PROJECT_DIR}/deploy_master.sh" ]]; then
                log "Running master deployment..."
                "${PROJECT_DIR}/deploy_master.sh"
            else
                error "Master deployment script not found"
                exit 1
            fi
            ;;
        *)
            error "Unknown deployment mode: ${DEPLOYMENT_MODE}"
            exit 1
            ;;
    esac
}

display_success_summary() {
    echo ""
    echo "=============================================="
    echo -e "${BOLD}${GREEN}🎉 NoctisPro PACS - DuckDNS Deployment Complete!${NC}"
    echo "=============================================="
    echo ""
    echo -e "${BOLD}🌐 Your PACS System is Live:${NC}"
    echo -e "  ${GREEN}🔗 Web Interface: https://${DUCKDNS_DOMAIN}${NC}"
    echo -e "  ${GREEN}👑 Admin Panel: https://${DUCKDNS_DOMAIN}/admin/${NC}"
    echo -e "  ${GREEN}🏥 DICOM Port: ${DUCKDNS_DOMAIN}:11112${NC}"
    echo -e "  ${GREEN}🔑 Default Login: admin / admin123${NC}"
    echo ""
    echo -e "${BOLD}🦆 DuckDNS Features Active:${NC}"
    echo "  ✅ Free permanent domain (no HTTP limits)"
    echo "  ✅ Automatic IP updates every 5 minutes"
    echo "  ✅ SSL certificate with Let's Encrypt"
    echo "  ✅ Global accessibility"
    echo ""
    echo -e "${BOLD}📱 Share Your System:${NC}"
    echo -e "  ${CYAN}Send this link to your team: https://${DUCKDNS_DOMAIN}${NC}"
    echo ""
    echo -e "${BOLD}🔧 Management:${NC}"
    if [[ -f "${PROJECT_DIR}/manage_noctis_optimized.sh" ]]; then
        echo "  Start/Stop: ${PROJECT_DIR}/manage_noctis_optimized.sh {start|stop|restart}"
        echo "  Status: ${PROJECT_DIR}/manage_noctis_optimized.sh status"
        echo "  Logs: ${PROJECT_DIR}/manage_noctis_optimized.sh logs"
    elif [[ -f "${PROJECT_DIR}/manage_noctis.sh" ]]; then
        echo "  Start/Stop: ${PROJECT_DIR}/manage_noctis.sh {start|stop|restart}"
        echo "  Status: ${PROJECT_DIR}/manage_noctis.sh status"
        echo "  Logs: ${PROJECT_DIR}/manage_noctis.sh logs"
    fi
    echo ""
    echo -e "${BLUE}📋 Deployment Log: ${LOG_FILE}${NC}"
    echo ""
    success "🚀 Your medical imaging system is ready for production use!"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local start_time=$(date +%s)
    
    log "Starting NoctisPro PACS DuckDNS deployment..."
    log "Deployment log: ${LOG_FILE}"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root for security reasons."
        error "Please run as a regular user with sudo privileges."
        exit 1
    fi
    
    # Display introduction
    display_duckdns_intro
    
    # Setup DuckDNS credentials
    setup_duckdns_credentials
    
    # Test DuckDNS configuration
    test_duckdns_configuration
    
    # Choose deployment mode
    choose_deployment_mode
    
    # Run the actual deployment
    run_deployment
    
    # Display success summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    log "Total deployment time: ${duration} seconds"
    
    display_success_summary
    
    success "🎉 DuckDNS deployment completed successfully!"
}

# Handle interruption gracefully
trap 'error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"