#!/bin/bash

# =============================================================================
# NoctisPro PACS - Production Deployment with HTTPS
# =============================================================================
# This script runs the master deployment with production HTTPS configuration
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║        🏥 NoctisPro PACS - Production HTTPS Deployment        ║
    ║                                                               ║
    ║  🔒 Automatic HTTPS with SSL certificates                     ║
    ║  🌍 Public internet access via secure tunnels                ║
    ║  🚀 Production-ready deployment with monitoring               ║
    ║  🛡️  Enterprise security and performance optimization         ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_requirements() {
    echo -e "${BLUE}🔍 Checking deployment requirements...${NC}"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}❌ This script should not be run as root${NC}"
        echo -e "${YELLOW}Please run as a regular user with sudo privileges${NC}"
        exit 1
    fi
    
    # Check sudo access
    if ! sudo -v >/dev/null 2>&1; then
        echo -e "${RED}❌ This script requires sudo privileges${NC}"
        echo -e "${YELLOW}Please ensure your user has sudo access${NC}"
        exit 1
    fi
    
    # Check if master deployment script exists
    if [[ ! -f "${SCRIPT_DIR}/deploy_master.sh" ]]; then
        echo -e "${RED}❌ Master deployment script not found${NC}"
        echo -e "${YELLOW}Please ensure deploy_master.sh is in the same directory${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Requirements check passed${NC}"
}

show_deployment_info() {
    echo ""
    echo -e "${CYAN}${BOLD}📋 Deployment Information${NC}"
    echo "=========================="
    echo ""
    echo -e "${GREEN}What will be installed:${NC}"
    echo "• 🏥 NoctisPro PACS medical imaging system"
    echo "• 🔒 Nginx reverse proxy with HTTPS/SSL"
    echo "• 🌍 Ngrok tunnel for public internet access"
    echo "• 🛡️  SSL certificate management (self-signed + Let's Encrypt)"
    echo "• 📊 System monitoring and health checks"
    echo "• 🔧 Management scripts for easy administration"
    echo ""
    echo -e "${GREEN}After deployment you'll have:${NC}"
    echo "• 🔒 Local HTTPS access: https://localhost"
    echo "• 🌍 Public HTTPS access: (requires ngrok token)"
    echo "• 👤 Admin panel: https://localhost/admin/"
    echo "• 🏥 DICOM receiver on port 11112"
    echo "• 📋 Management commands via ./manage_noctis.sh"
    echo ""
    echo -e "${YELLOW}⚠️  Note: Public access requires a free ngrok account${NC}"
    echo "   Get your token from: https://ngrok.com/signup"
    echo ""
}

confirm_deployment() {
    echo -e "${BOLD}🚀 Ready to deploy NoctisPro PACS with production HTTPS?${NC}"
    echo ""
    read -p "Continue with deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deployment cancelled by user${NC}"
        exit 0
    fi
}

run_deployment() {
    echo ""
    echo -e "${CYAN}${BOLD}🚀 Starting Production Deployment...${NC}"
    echo ""
    
    # Set environment variables for production deployment
    export FORCE_HTTPS_SETUP=true
    export PRODUCTION_MODE=true
    export ENABLE_MONITORING=true
    
    # Run the master deployment script
    if bash "${SCRIPT_DIR}/deploy_master.sh" "$@"; then
        echo ""
        echo -e "${GREEN}${BOLD}🎉 Production deployment completed successfully!${NC}"
        show_post_deployment_info
    else
        echo ""
        echo -e "${RED}${BOLD}❌ Deployment failed${NC}"
        echo -e "${YELLOW}Check the deployment logs for details${NC}"
        exit 1
    fi
}

show_post_deployment_info() {
    echo ""
    echo -e "${CYAN}${BOLD}📋 Post-Deployment Information${NC}"
    echo "==============================="
    echo ""
    echo -e "${GREEN}🌐 Access URLs:${NC}"
    echo "• 🔒 Local HTTPS: https://localhost"
    echo "• 🌍 Local HTTP:  http://localhost (redirects to HTTPS)"
    echo "• 👤 Admin Panel: https://localhost/admin/"
    echo ""
    echo -e "${GREEN}🔐 Default Credentials:${NC}"
    echo "• Username: admin"
    echo "• Password: admin123"
    echo ""
    echo -e "${GREEN}🔧 Management Commands:${NC}"
    echo "• Check status:    ./manage_noctis.sh status"
    echo "• View HTTPS info: ./manage_noctis.sh https"
    echo "• Health check:    ./manage_noctis.sh health"
    echo "• View logs:       ./manage_noctis.sh logs"
    echo "• Restart system:  ./manage_noctis.sh restart"
    echo ""
    echo -e "${GREEN}🌍 For Public Internet Access:${NC}"
    echo "1. Get free ngrok token: https://ngrok.com/signup"
    echo "2. Configure token: ./manage_noctis.sh https"
    echo "3. Start public tunnel: sudo systemctl start noctispro-ngrok"
    echo ""
    echo -e "${GREEN}📊 System Monitoring:${NC}"
    echo "• HTTPS status: /usr/local/bin/noctispro-https-monitor"
    echo "• SSL certificates auto-renew every 90 days"
    echo "• Health checks run every 30 minutes"
    echo ""
    echo -e "${CYAN}${BOLD}🎉 Your NoctisPro PACS is ready for production use!${NC}"
}

# Main execution
main() {
    show_banner
    check_requirements
    show_deployment_info
    confirm_deployment
    run_deployment "$@"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "NoctisPro PACS Production Deployment Script"
        echo ""
        echo "This script deploys NoctisPro PACS with production-ready HTTPS configuration"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --force             Skip confirmation prompts"
        echo "  --no-https          Skip HTTPS setup (not recommended for production)"
        echo ""
        echo "Features:"
        echo "  • Automatic HTTPS with SSL certificates"
        echo "  • Public internet access via ngrok tunnels"
        echo "  • Production security hardening"
        echo "  • System monitoring and health checks"
        echo "  • Easy management commands"
        echo ""
        exit 0
        ;;
    --force)
        export SKIP_CONFIRMATION=true
        show_banner
        check_requirements
        run_deployment "${@:2}"
        ;;
    --no-https)
        export SKIP_HTTPS_SETUP=true
        echo -e "${YELLOW}⚠️  HTTPS setup will be skipped - not recommended for production${NC}"
        main "${@:2}"
        ;;
    *)
        main "$@"
        ;;
esac