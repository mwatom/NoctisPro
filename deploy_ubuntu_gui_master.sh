#!/bin/bash

# ============================================================================
# NoctisPro PACS - Complete Ubuntu Server 22.04 GUI Deployment Master Script
# ============================================================================
# This master script orchestrates the complete deployment of NoctisPro PACS
# on Ubuntu Server 22.04 with full GUI desktop environment, HTTPS access,
# and comprehensive system integration.
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/noctispro_master_deployment.log"
DEPLOYMENT_MODE="auto"  # Options: auto, minimal, full
INSTALL_SSL="auto"      # Options: auto, letsencrypt, cloudflare, selfsigned, none

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# Display banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║              NoctisPro PACS - GUI Deployment                  ║
    ║                Ubuntu Server 22.04 Edition                    ║
    ║                                                               ║
    ║  🏥 Medical Imaging System with Desktop GUI                   ║
    ║  🖥️  Auto-login with localhost browser                        ║
    ║  🔒 HTTPS public access configuration                         ║
    ║  🛠️  Terminal access for administration                       ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    header "Checking Prerequisites"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu" /etc/os-release; then
        warning "This script is optimized for Ubuntu. Continuing anyway..."
    fi
    
    local ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "unknown")
    info "Detected Ubuntu version: $ubuntu_version"
    
    # Check system resources
    local total_ram=$(free -m | awk 'NR==2{print $2}')
    local cpu_cores=$(nproc)
    local disk_space=$(df -h / | awk 'NR==2{print $4}' | sed 's/G.*//')
    
    log "System Resources:"
    log "  - RAM: ${total_ram}MB"
    log "  - CPU Cores: ${cpu_cores}"
    log "  - Available Disk: ${disk_space}GB"
    
    # Determine deployment mode based on resources
    if [[ $DEPLOYMENT_MODE == "auto" ]]; then
        if [[ $total_ram -ge 8192 && $cpu_cores -ge 4 ]]; then
            DEPLOYMENT_MODE="full"
            info "Auto-selected deployment mode: FULL (high-resource system)"
        elif [[ $total_ram -ge 4096 && $cpu_cores -ge 2 ]]; then
            DEPLOYMENT_MODE="standard"
            info "Auto-selected deployment mode: STANDARD (medium-resource system)"
        else
            DEPLOYMENT_MODE="minimal"
            info "Auto-selected deployment mode: MINIMAL (low-resource system)"
        fi
    fi
    
    # Check internet connectivity
    if ping -c 1 google.com &> /dev/null; then
        success "Internet connectivity: Available"
    else
        warning "Internet connectivity: Limited or unavailable"
    fi
    
    # Check required scripts
    local required_scripts=("ubuntu_gui_deployment.sh" "ssl_setup.sh" "desktop_integration.sh")
    for script in "${required_scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            success "Found: $script"
        else
            error "Missing required script: $script"
        fi
    done
}

# Get user configuration
get_user_configuration() {
    header "Configuration Setup"
    
    echo "NoctisPro PACS Deployment Configuration"
    echo "======================================"
    echo ""
    echo "Detected deployment mode: $DEPLOYMENT_MODE"
    echo ""
    echo "Configuration options:"
    echo "1. Desktop Environment:"
    echo "   - GNOME (recommended for 4GB+ RAM)"
    echo "   - XFCE (lightweight, good for 2GB+ RAM)"
    echo ""
    echo "2. SSL/HTTPS Setup:"
    echo "   - Let's Encrypt (requires domain name)"
    echo "   - Cloudflare Tunnel (free subdomain)"
    echo "   - Self-signed (localhost only)"
    echo "   - Skip SSL setup"
    echo ""
    
    # Desktop environment selection
    if [[ $DEPLOYMENT_MODE == "minimal" ]]; then
        DESKTOP_ENV="xfce"
        info "Using XFCE desktop for minimal deployment"
    else
        read -p "Choose desktop environment (gnome/xfce) [gnome]: " desktop_choice
        DESKTOP_ENV=${desktop_choice:-gnome}
    fi
    
    # SSL configuration
    echo ""
    echo "SSL/HTTPS Configuration:"
    echo "1) Let's Encrypt (free SSL, requires domain)"
    echo "2) Cloudflare Tunnel (free, includes domain)"
    echo "3) Self-signed certificate (localhost only)"
    echo "4) Skip SSL setup (HTTP only)"
    echo ""
    read -p "Choose SSL option (1-4) [3]: " ssl_choice
    
    case ${ssl_choice:-3} in
        1) INSTALL_SSL="letsencrypt" ;;
        2) INSTALL_SSL="cloudflare" ;;
        3) INSTALL_SSL="selfsigned" ;;
        4) INSTALL_SSL="none" ;;
        *) INSTALL_SSL="selfsigned" ;;
    esac
    
    # Confirmation
    echo ""
    echo "Deployment Configuration Summary:"
    echo "================================"
    echo "Mode: $DEPLOYMENT_MODE"
    echo "Desktop: $DESKTOP_ENV"
    echo "SSL: $INSTALL_SSL"
    echo ""
    read -p "Proceed with this configuration? (y/n) [y]: " confirm
    if [[ ${confirm:-y} != "y" ]]; then
        error "Deployment cancelled by user"
    fi
    
    # Export configuration for sub-scripts
    export DESKTOP_ENV
    export DEPLOYMENT_MODE
    export INSTALL_SSL
}

# Phase 1: Base system and GUI setup
deploy_base_system() {
    header "Phase 1: Base System & GUI Setup"
    
    log "Starting base system deployment..."
    
    # Make the GUI deployment script executable and run it
    chmod +x "$SCRIPT_DIR/ubuntu_gui_deployment.sh"
    
    # Run the GUI deployment script with our configuration
    if [[ -f "$SCRIPT_DIR/ubuntu_gui_deployment.sh" ]]; then
        bash "$SCRIPT_DIR/ubuntu_gui_deployment.sh"
        success "Base system and GUI deployment completed"
    else
        error "GUI deployment script not found"
    fi
}

# Phase 2: SSL/HTTPS configuration
deploy_ssl_configuration() {
    header "Phase 2: SSL/HTTPS Configuration"
    
    if [[ $INSTALL_SSL == "none" ]]; then
        info "Skipping SSL configuration as requested"
        return 0
    fi
    
    log "Starting SSL configuration..."
    
    # Make the SSL setup script executable
    chmod +x "$SCRIPT_DIR/ssl_setup.sh"
    
    case $INSTALL_SSL in
        "letsencrypt"|"cloudflare"|"selfsigned")
            if [[ -f "$SCRIPT_DIR/ssl_setup.sh" ]]; then
                # Run SSL setup in non-interactive mode for auto configurations
                if [[ $INSTALL_SSL == "selfsigned" ]]; then
                    # For self-signed, we can run automatically
                    echo "3" | bash "$SCRIPT_DIR/ssl_setup.sh"
                else
                    # For other SSL methods, run interactively
                    bash "$SCRIPT_DIR/ssl_setup.sh"
                fi
                success "SSL configuration completed"
            else
                error "SSL setup script not found"
            fi
            ;;
        *)
            warning "Unknown SSL configuration: $INSTALL_SSL"
            ;;
    esac
}

# Phase 3: Desktop integration
deploy_desktop_integration() {
    header "Phase 3: Desktop Integration"
    
    log "Starting desktop integration..."
    
    # Make the desktop integration script executable and run it
    chmod +x "$SCRIPT_DIR/desktop_integration.sh"
    
    if [[ -f "$SCRIPT_DIR/desktop_integration.sh" ]]; then
        bash "$SCRIPT_DIR/desktop_integration.sh"
        success "Desktop integration completed"
    else
        error "Desktop integration script not found"
    fi
}

# Phase 4: System optimization
optimize_system() {
    header "Phase 4: System Optimization"
    
    log "Optimizing system for $DEPLOYMENT_MODE mode..."
    
    case $DEPLOYMENT_MODE in
        "minimal")
            # Minimal optimizations for low-resource systems
            log "Applying minimal system optimizations..."
            
            # Reduce swap usage
            echo "vm.swappiness=10" >> /etc/sysctl.conf
            
            # Optimize systemd services
            systemctl disable snapd snapd.socket || true
            systemctl mask snapd.service || true
            
            # Clean up unnecessary packages
            apt autoremove -y
            apt autoclean
            ;;
            
        "standard")
            # Standard optimizations
            log "Applying standard system optimizations..."
            
            # Configure swap
            echo "vm.swappiness=20" >> /etc/sysctl.conf
            
            # Enable some performance features
            systemctl enable fstrim.timer || true
            ;;
            
        "full")
            # Full optimizations for high-resource systems
            log "Applying full system optimizations..."
            
            # Performance tuning
            echo "vm.swappiness=30" >> /etc/sysctl.conf
            echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf
            echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf
            
            # Enable all performance features
            systemctl enable fstrim.timer || true
            systemctl enable systemd-oomd || true
            ;;
    esac
    
    # Apply sysctl changes
    sysctl -p
    
    success "System optimization completed"
}

# Phase 5: Final configuration and testing
finalize_deployment() {
    header "Phase 5: Finalization & Testing"
    
    log "Finalizing deployment..."
    
    # Create deployment summary
    cat > /home/noctispro/Desktop/Deployment-Summary.txt << EOF
NoctisPro PACS Deployment Summary
===============================
$(date)

Deployment Configuration:
- Mode: $DEPLOYMENT_MODE
- Desktop Environment: $DESKTOP_ENV
- SSL Configuration: $INSTALL_SSL

System Information:
- OS: $(lsb_release -d | cut -f2)
- Kernel: $(uname -r)
- RAM: $(free -h | awk 'NR==2{print $2}')
- CPU: $(nproc) cores
- Disk: $(df -h / | awk 'NR==2{print $4}') available

Access Information:
- Local URL: http://localhost
$(if [[ $INSTALL_SSL != "none" ]]; then echo "- HTTPS URL: https://localhost"; fi)
- Admin Panel: http://localhost/admin/
- System User: noctispro / noctispro123
- Django Admin: admin / admin123

Services Status:
$(systemctl is-active noctispro && echo "✅ NoctisPro Service: Running" || echo "❌ NoctisPro Service: Not Running")
$(systemctl is-active nginx && echo "✅ Nginx: Running" || echo "❌ Nginx: Not Running")
$(systemctl is-active postgresql && echo "✅ PostgreSQL: Running" || echo "❌ PostgreSQL: Not Running")

Next Steps:
1. System will reboot and auto-login to desktop
2. Browser will automatically open to NoctisPro
3. Use desktop shortcuts for quick access
4. Run 'noctispro-admin status' for system status

Management Commands:
- noctispro-admin {start|stop|restart|status|logs|url}
- noctispro-ssl {renew|status|test}

For help, open NoctisPro-Help.html on the desktop.
EOF
    
    chown noctispro:noctispro /home/noctispro/Desktop/Deployment-Summary.txt
    
    # Test services
    log "Testing deployed services..."
    
    local services=("postgresql" "nginx" "noctispro")
    local all_services_ok=true
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            success "✅ $service is running"
        else
            warning "❌ $service is not running"
            all_services_ok=false
        fi
    done
    
    # Test web connectivity
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|302"; then
        success "✅ Web interface is accessible"
    else
        warning "❌ Web interface test failed"
        all_services_ok=false
    fi
    
    if $all_services_ok; then
        success "All service tests passed!"
    else
        warning "Some services may need attention. Check logs with: noctispro-admin logs"
    fi
}

# Display final instructions
show_completion_message() {
    clear
    header "Deployment Complete!"
    
    echo -e "${GREEN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║           🎉 NoctisPro PACS Deployment Complete! 🎉           ║
    ║                                                               ║
    ║  Your medical imaging system is ready with:                   ║
    ║                                                               ║
    ║  🖥️  Desktop GUI environment with auto-login                  ║
    ║  🏥 NoctisPro PACS medical imaging system                     ║
    ║  🔒 HTTPS/SSL configuration                                   ║
    ║  🚀 Auto-start services after reboot                         ║
    ║  📱 Desktop applications and shortcuts                        ║
    ║  🛠️  Admin tools and terminal access                          ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo ""
    echo -e "${CYAN}Access Information:${NC}"
    echo -e "  🌐 Local URL: ${GREEN}http://localhost${NC}"
    if [[ $INSTALL_SSL != "none" ]]; then
        echo -e "  🔒 HTTPS URL: ${GREEN}https://localhost${NC}"
    fi
    echo -e "  👤 System User: ${YELLOW}noctispro${NC} / ${YELLOW}noctispro123${NC}"
    echo -e "  🔑 Django Admin: ${YELLOW}admin${NC} / ${YELLOW}admin123${NC}"
    
    echo ""
    echo -e "${CYAN}What happens next:${NC}"
    echo "  1. System will reboot and auto-login to desktop"
    echo "  2. Browser will automatically open NoctisPro"
    echo "  3. Desktop shortcuts are ready for use"
    echo "  4. Check Desktop files for help and system info"
    
    echo ""
    echo -e "${CYAN}Management Commands:${NC}"
    echo "  📊 noctispro-admin status    - Check system status"
    echo "  🔄 noctispro-admin restart   - Restart services"
    echo "  📝 noctispro-admin logs      - View system logs"
    echo "  🌐 noctispro-admin url       - Show access URLs"
    
    if [[ $INSTALL_SSL != "none" ]]; then
        echo ""
        echo -e "${CYAN}SSL Management:${NC}"
        echo "  🔒 noctispro-ssl status     - Check SSL certificates"
        echo "  🔄 noctispro-ssl renew      - Renew certificates"
    fi
    
    echo ""
    echo -e "${YELLOW}⚠️  Important Notes:${NC}"
    echo "  • This is a medical imaging system - ensure HIPAA/GDPR compliance"
    echo "  • Backup your data regularly"
    echo "  • Keep the system updated for security"
    
    echo ""
    echo -e "${GREEN}Ready to reboot and start using NoctisPro PACS!${NC}"
    echo ""
    
    read -p "Reboot now to complete setup? (y/n) [y]: " reboot_choice
    if [[ ${reboot_choice:-y} == "y" ]]; then
        log "Rebooting system to complete deployment..."
        sleep 3
        reboot
    else
        log "Deployment complete. Manual reboot required to activate GUI."
    fi
}

# Main deployment orchestration
main() {
    # Initialize logging
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    log "Starting NoctisPro PACS Master Deployment"
    
    show_banner
    check_prerequisites
    get_user_configuration
    
    # Execute deployment phases
    deploy_base_system
    deploy_ssl_configuration
    deploy_desktop_integration
    optimize_system
    finalize_deployment
    
    # Show completion message
    show_completion_message
}

# Trap errors and provide cleanup
trap 'error "Deployment failed at line $LINENO. Check $LOG_FILE for details."' ERR

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "NoctisPro PACS Ubuntu GUI Deployment Script"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --minimal           Force minimal deployment mode"
        echo "  --standard          Force standard deployment mode"
        echo "  --full              Force full deployment mode"
        echo "  --no-ssl            Skip SSL configuration"
        echo "  --test-only         Test prerequisites only"
        echo ""
        echo "Examples:"
        echo "  $0                  # Interactive deployment"
        echo "  $0 --minimal        # Minimal resource deployment"
        echo "  $0 --no-ssl         # Deploy without SSL"
        exit 0
        ;;
    --minimal)
        DEPLOYMENT_MODE="minimal"
        ;;
    --standard)
        DEPLOYMENT_MODE="standard"
        ;;
    --full)
        DEPLOYMENT_MODE="full"
        ;;
    --no-ssl)
        INSTALL_SSL="none"
        ;;
    --test-only)
        show_banner
        check_prerequisites
        echo "Prerequisites check completed successfully!"
        exit 0
        ;;
esac

# Run main deployment
main "$@"