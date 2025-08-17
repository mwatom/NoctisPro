#!/bin/bash
set -euo pipefail

# Noctis Pro DICOM System - Quick Production Deployment
# Enhanced with Advanced User & Facility Management
# Ubuntu 24.04 LTS Production Deployment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DOMAIN_NAME="${1:-}"
ADMIN_EMAIL="${2:-admin@localhost}"
DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-production}"

# Print banner
print_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║    ███╗   ██╗ ██████╗  ██████╗████████╗██╗███████╗               ║
║    ████╗  ██║██╔═══██╗██╔════╝╚══██╔══╝██║██╔════╝               ║
║    ██╔██╗ ██║██║   ██║██║        ██║   ██║███████╗               ║
║    ██║╚██╗██║██║   ██║██║        ██║   ██║╚════██║               ║
║    ██║ ╚████║╚██████╔╝╚██████╗   ██║   ██║███████║               ║
║    ╚═╝  ╚═══╝ ╚═════╝  ╚═════╝   ╚═╝   ╚═╝╚══════╝               ║
║                                                                  ║
║                PRODUCTION DEPLOYMENT v2.0                       ║
║            Enhanced User & Facility Management                   ║
║                DICOM Medical Imaging System                      ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        echo "Usage: sudo bash quick_production_deploy.sh [domain_name] [admin_email]"
        echo "Example: sudo bash quick_production_deploy.sh mydomain.com admin@mydomain.com"
        exit 1
    fi
}

# Check Ubuntu version
check_ubuntu_version() {
    if ! grep -q "Ubuntu 24.04" /etc/os-release; then
        print_warning "This script is optimized for Ubuntu 24.04. Current version:"
        cat /etc/os-release | grep PRETTY_NAME
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Main deployment function
main() {
    print_banner
    
    echo -e "${PURPLE}🚀 Starting Noctis Pro Production Deployment${NC}"
    echo -e "${CYAN}📋 Configuration:${NC}"
    echo -e "   Domain: ${DOMAIN_NAME:-'Local deployment (no SSL)'}"
    echo -e "   Admin Email: ${ADMIN_EMAIL}"
    echo -e "   Mode: ${DEPLOYMENT_MODE}"
    echo
    
    check_root
    check_ubuntu_version
    
    print_step "Checking for existing deployment script..."
    
    if [[ -f "deploy_ubuntu24.sh" ]]; then
        print_success "Found deploy_ubuntu24.sh - using existing deployment script"
        
        if [[ -n "$DOMAIN_NAME" ]]; then
            print_step "Deploying with domain name: $DOMAIN_NAME"
            bash deploy_ubuntu24.sh "$DOMAIN_NAME" "$ADMIN_EMAIL"
        else
            print_step "Deploying locally (no domain)"
            bash deploy_ubuntu24.sh
        fi
        
    else
        print_error "deploy_ubuntu24.sh not found!"
        echo
        echo -e "${YELLOW}Please ensure you're running this script from the Noctis Pro project directory.${NC}"
        echo -e "${CYAN}Expected file structure:${NC}"
        echo "  ├── deploy_ubuntu24.sh"
        echo "  ├── quick_production_deploy.sh (this script)"
        echo "  ├── manage.py"
        echo "  ├── requirements.txt"
        echo "  └── ..."
        echo
        exit 1
    fi
    
    # Post-deployment information
    echo
    echo -e "${GREEN}🎉 DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉${NC}"
    echo
    echo -e "${PURPLE}📊 Enhanced Features Deployed:${NC}"
    echo -e "${GREEN}✅ Advanced User Management${NC}"
    echo -e "   • Bulk operations (activate, deactivate, verify, delete)"
    echo -e "   • Advanced search and filtering"
    echo -e "   • Export to CSV/Excel/PDF"
    echo -e "   • Role-based access control"
    echo -e "   • Session tracking and security"
    echo
    echo -e "${GREEN}✅ Enhanced Facility Management${NC}"
    echo -e "   • Grid and list view modes"
    echo -e "   • Comprehensive facility analytics"
    echo -e "   • Bulk facility operations"
    echo -e "   • Advanced search capabilities"
    echo -e "   • DICOM AE Title management"
    echo
    echo -e "${GREEN}✅ Production-Ready Infrastructure${NC}"
    echo -e "   • SSL/TLS with Let's Encrypt (if domain provided)"
    echo -e "   • PostgreSQL 16 with optimizations"
    echo -e "   • Redis caching and message queuing"
    echo -e "   • Nginx reverse proxy with security headers"
    echo -e "   • UFW firewall configuration"
    echo -e "   • Fail2ban intrusion prevention"
    echo -e "   • Automated backups and log rotation"
    echo
    
    if [[ -n "$DOMAIN_NAME" ]]; then
        echo -e "${CYAN}🌐 Access Your System:${NC}"
        echo -e "   Web Interface: ${GREEN}https://$DOMAIN_NAME${NC}"
        echo -e "   Admin Panel: ${GREEN}https://$DOMAIN_NAME/admin-panel/${NC}"
        echo -e "   DICOM Port: ${GREEN}$DOMAIN_NAME:11112${NC}"
    else
        echo -e "${CYAN}🌐 Access Your System:${NC}"
        echo -e "   Web Interface: ${GREEN}http://$(hostname -I | awk '{print $1}')${NC}"
        echo -e "   Admin Panel: ${GREEN}http://$(hostname -I | awk '{print $1}')/admin-panel/${NC}"
        echo -e "   DICOM Port: ${GREEN}$(hostname -I | awk '{print $1}'):11112${NC}"
    fi
    
    echo
    echo -e "${CYAN}🔧 Management Commands:${NC}"
    echo -e "   Status: ${YELLOW}sudo /opt/noctis/status.sh${NC}"
    echo -e "   Restart: ${YELLOW}sudo /opt/noctis/restart.sh${NC}"
    echo -e "   Update: ${YELLOW}sudo /opt/noctis/update.sh${NC}"
    echo -e "   Backup: ${YELLOW}sudo /opt/noctis/backup.sh${NC}"
    echo
    echo -e "${CYAN}📚 Documentation:${NC}"
    echo -e "   Full Guide: ${YELLOW}production_deployment_guide.md${NC}"
    echo -e "   Ubuntu Guide: ${YELLOW}UBUNTU_24_DEPLOYMENT_GUIDE.md${NC}"
    echo
    echo -e "${PURPLE}🎯 Next Steps:${NC}"
    echo -e "1. Log in with the admin credentials shown above"
    echo -e "2. Configure your first facility and users"
    echo -e "3. Test DICOM connectivity"
    echo -e "4. Set up monitoring and alerts"
    echo -e "5. Configure regular backup verification"
    echo
    echo -e "${GREEN}Your medical imaging system is ready to serve healthcare facilities worldwide! 🏥🌍${NC}"
}

# Show usage if help requested
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Noctis Pro DICOM System - Quick Production Deployment"
    echo
    echo "Usage:"
    echo "  sudo bash quick_production_deploy.sh [domain_name] [admin_email]"
    echo
    echo "Examples:"
    echo "  # Deploy locally (no SSL)"
    echo "  sudo bash quick_production_deploy.sh"
    echo
    echo "  # Deploy with domain and SSL"
    echo "  sudo bash quick_production_deploy.sh mydomain.com admin@mydomain.com"
    echo
    echo "  # Deploy with subdomain"
    echo "  sudo bash quick_production_deploy.sh myapp.duckdns.org admin@example.com"
    echo
    echo "Requirements:"
    echo "  - Ubuntu 24.04 LTS"
    echo "  - Root/sudo access"
    echo "  - Internet connection"
    echo "  - Domain name (optional, for SSL)"
    echo
    echo "Features:"
    echo "  ✅ Enhanced User Management with bulk operations"
    echo "  ✅ Advanced Facility Management with analytics"
    echo "  ✅ Production-ready security and performance"
    echo "  ✅ Automated SSL with Let's Encrypt"
    echo "  ✅ PostgreSQL, Redis, Nginx stack"
    echo "  ✅ Automated backups and monitoring"
    echo
    exit 0
fi

# Run main deployment
main "$@"