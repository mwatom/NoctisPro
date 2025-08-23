#!/bin/bash

# 🏥 NoctisPro Manual Deployment Script for Ubuntu 24.04
# Complete production deployment with HTTPS and domain setup
# Run with: sudo bash QUICK_MANUAL_DEPLOY_UBUNTU24.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration variables
PROJECT_NAME="noctis_pro"
PROJECT_USER="noctis"
PROJECT_DIR="/opt/noctis_pro"
GITHUB_REPO="https://github.com/mwatom/NoctisPro.git"

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
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN} $1 ${NC}"
    echo -e "${CYAN}========================================${NC}\n"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# Welcome message
clear
echo -e "${CYAN}"
echo "██╗  ██╗ ██████╗ ███╗   ██╗████████╗██╗███████╗██████╗ ██████╗  ██████╗ "
echo "██║  ██║██╔═══██╗██╔██╗ ██║╚══██╔══╝██║██╔════╝██╔══██╗██╔══██╗██╔═══██╗"
echo "███████║██║   ██║██║╚██╗██║   ██║   ██║███████╗██████╔╝██████╔╝██║   ██║"
echo "██╔══██║██║   ██║██║ ╚████║   ██║   ██║╚════██║██╔═══╝ ██╔══██╗██║   ██║"
echo "██║  ██║╚██████╔╝██║  ╚███║   ██║   ██║███████║██║     ██║  ██║╚██████╔╝"
echo "╚═╝  ╚═╝ ╚═════╝ ╚═╝   ╚══╝   ╚═╝   ╚═╝╚══════╝╚═╝     ╚═╝  ╚═╝ ╚═════╝ "
echo -e "${NC}"
echo -e "${GREEN}NoctisPro Medical Imaging Platform - Ubuntu 24.04 Manual Deployment${NC}"
echo -e "${BLUE}Complete production setup with HTTPS and domain configuration${NC}\n"

# Interactive configuration
log_header "🔧 DEPLOYMENT CONFIGURATION"

# Get domain name
read -p "Enter your domain name (e.g., medical.yourdomain.com or clinic.duckdns.org): " DOMAIN_NAME
if [[ -z "$DOMAIN_NAME" ]]; then
    log_error "Domain name is required!"
    exit 1
fi

# Get email for SSL certificate
read -p "Enter your email address for SSL certificate: " SSL_EMAIL
if [[ -z "$SSL_EMAIL" ]]; then
    log_error "Email address is required for SSL certificate!"
    exit 1
fi

# Confirm configuration
echo -e "\n${YELLOW}Deployment Configuration:${NC}"
echo -e "Domain: ${GREEN}$DOMAIN_NAME${NC}"
echo -e "Email: ${GREEN}$SSL_EMAIL${NC}"
echo -e "Installation Directory: ${GREEN}$PROJECT_DIR${NC}"
echo -e "Project User: ${GREEN}$PROJECT_USER${NC}"

read -p "Continue with deployment? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    log_info "Deployment cancelled by user"
    exit 0
fi

# Start deployment
log_header "🚀 STARTING UBUNTU 24.04 DEPLOYMENT"

# Step 1: System preparation
log_info "Step 1: Updating system packages..."
apt update && apt upgrade -y

log_info "Installing essential packages..."
apt install -y curl wget git unzip software-properties-common \
               lsb-release build-essential apt-transport-https \
               ca-certificates gnupg2

# Set hostname
hostnamectl set-hostname noctis-medical-server

# Configure timezone
timedatectl set-timezone UTC
log_success "System preparation completed"

# Step 2: Create system user
log_info "Step 2: Creating system user..."
if id "$PROJECT_USER" &>/dev/null; then
    log_warning "User $PROJECT_USER already exists"
else
    useradd -m -s /bin/bash "$PROJECT_USER"
    usermod -aG sudo "$PROJECT_USER"
    log_success "Created user: $PROJECT_USER"
fi

# Step 3: Install dependencies
log_info "Step 3: Installing dependencies..."

# Install Python
log_info "Installing Python 3.11+..."
apt install -y python3 python3-pip python3-venv python3-dev

# Install PostgreSQL
log_info "Installing PostgreSQL..."
apt install -y postgresql postgresql-contrib postgresql-client

# Install Redis
log_info "Installing Redis..."
apt install -y redis-server

# Install Nginx
log_info "Installing Nginx..."
apt install -y nginx

# Install medical imaging libraries
log_info "Installing medical imaging libraries..."
apt install -y libgdcm-dev libvtk9-dev libinsighttoolkit5-dev \
               libopencv-dev python3-opencv

# Install CUPS for printing
log_info "Installing CUPS for medical image printing..."
apt install -y cups cups-client cups-filters

# Install Docker
log_info "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker "$PROJECT_USER"

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Start services
systemctl enable docker postgresql redis nginx
systemctl start docker postgresql redis nginx

log_success "Dependencies installation completed"

# Step 4: Configure firewall
log_info "Step 4: Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow essential ports
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 8000/tcp  # Django dev

ufw --force enable
log_success "Firewall configured"

# Step 5: Download NoctisPro
log_info "Step 5: Downloading NoctisPro..."
mkdir -p "$PROJECT_DIR"
chown "$PROJECT_USER":"$PROJECT_USER" "$PROJECT_DIR"

# Clone as the project user
cd "$PROJECT_DIR"
sudo -u "$PROJECT_USER" git clone "$GITHUB_REPO" .

# Make scripts executable
chmod +x *.sh scripts/*.sh ops/*.sh 2>/dev/null || true

log_success "NoctisPro downloaded successfully"

# Step 6: Configure domain in deployment script
log_info "Step 6: Configuring deployment script..."
sed -i "s/DOMAIN_NAME=\"noctis-server.local\"/DOMAIN_NAME=\"$DOMAIN_NAME\"/" deploy_noctis_production.sh

# Update SSL email if the script supports it
if grep -q "SSL_EMAIL" deploy_noctis_production.sh; then
    sed -i "s/SSL_EMAIL=\".*\"/SSL_EMAIL=\"$SSL_EMAIL\"/" deploy_noctis_production.sh
fi

log_success "Deployment script configured"

# Step 7: Verify domain DNS
log_info "Step 7: Verifying domain DNS configuration..."
log_info "Checking DNS resolution for: $DOMAIN_NAME"

if nslookup "$DOMAIN_NAME" >/dev/null 2>&1; then
    RESOLVED_IP=$(dig +short "$DOMAIN_NAME" | head -n1)
    PUBLIC_IP=$(curl -s -4 ifconfig.me)
    
    log_info "Domain resolves to: $RESOLVED_IP"
    log_info "Server public IP: $PUBLIC_IP"
    
    if [[ "$RESOLVED_IP" == "$PUBLIC_IP" ]]; then
        log_success "✅ Domain DNS is correctly configured!"
    else
        log_warning "⚠️  Domain DNS may not be fully propagated yet"
        log_warning "Expected: $PUBLIC_IP, Got: $RESOLVED_IP"
        echo -e "\n${YELLOW}DNS propagation can take up to 48 hours.${NC}"
        echo -e "${YELLOW}You can continue with deployment, but SSL certificate generation may fail if DNS is not ready.${NC}"
        
        read -p "Continue with deployment anyway? (y/N): " dns_continue
        if [[ ! $dns_continue =~ ^[Yy]$ ]]; then
            log_info "Deployment paused. Please wait for DNS propagation and run the script again."
            exit 0
        fi
    fi
else
    log_warning "⚠️  Cannot resolve domain: $DOMAIN_NAME"
    log_warning "Please ensure your domain is properly configured before continuing"
    
    read -p "Continue with deployment anyway? (y/N): " dns_continue
    if [[ ! $dns_continue =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled. Please configure DNS and run again."
        exit 0
    fi
fi

# Step 8: Run main deployment
log_header "🏥 RUNNING MAIN NOCTISPRO DEPLOYMENT"
log_info "This may take 15-25 minutes..."

if [[ -f "deploy_noctis_production.sh" ]]; then
    ./deploy_noctis_production.sh
    DEPLOYMENT_EXIT_CODE=$?
    
    if [[ $DEPLOYMENT_EXIT_CODE -eq 0 ]]; then
        log_success "✅ Main deployment completed successfully!"
    else
        log_error "❌ Main deployment failed with exit code: $DEPLOYMENT_EXIT_CODE"
        log_info "Check the logs above for error details"
        exit $DEPLOYMENT_EXIT_CODE
    fi
else
    log_error "❌ deploy_noctis_production.sh not found!"
    exit 1
fi

# Step 9: Configure Auto-Start Services
log_header "⚙️ CONFIGURING AUTO-START SERVICES"

log_info "Enabling services for auto-start on boot..."

# Enable core system services for auto-start
systemctl enable postgresql
systemctl enable redis
systemctl enable nginx
systemctl enable docker

# Enable NoctisPro services for auto-start (if they exist)
if systemctl list-unit-files | grep -q "noctis-web"; then
    systemctl enable noctis-web
    log_success "✅ noctis-web enabled for auto-start"
fi

if systemctl list-unit-files | grep -q "noctis-worker"; then
    systemctl enable noctis-worker
    log_success "✅ noctis-worker enabled for auto-start"
fi

if systemctl list-unit-files | grep -q "noctis-scheduler"; then
    systemctl enable noctis-scheduler
    log_success "✅ noctis-scheduler enabled for auto-start"
fi

if systemctl list-unit-files | grep -q "noctis-startup"; then
    systemctl enable noctis-startup
    log_success "✅ noctis-startup enabled for auto-start"
fi

if systemctl list-unit-files | grep -q "noctis-dicom"; then
    systemctl enable noctis-dicom
    log_success "✅ noctis-dicom enabled for auto-start"
fi

log_success "Auto-start configuration completed!"

# Step 10: Post-deployment verification
log_header "✅ POST-DEPLOYMENT VERIFICATION"

log_info "Checking service status..."

# Check systemd services
services=("noctis-web" "noctis-worker" "noctis-scheduler" "postgresql" "redis" "nginx")
all_services_ok=true

for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        log_success "✅ $service is running"
    else
        log_error "❌ $service is not running"
        all_services_ok=false
    fi
done

# Check ports
log_info "Checking open ports..."
if netstat -tlnp | grep -q ":80 "; then
    log_success "✅ Port 80 (HTTP) is open"
else
    log_warning "⚠️  Port 80 (HTTP) is not listening"
fi

if netstat -tlnp | grep -q ":443 "; then
    log_success "✅ Port 443 (HTTPS) is open"
else
    log_warning "⚠️  Port 443 (HTTPS) is not listening"
fi

# Test web access
log_info "Testing web access..."
if curl -s -I "http://$DOMAIN_NAME" >/dev/null 2>&1; then
    log_success "✅ HTTP access working"
else
    log_warning "⚠️  HTTP access test failed"
fi

if curl -s -I "https://$DOMAIN_NAME" >/dev/null 2>&1; then
    log_success "✅ HTTPS access working"
else
    log_warning "⚠️  HTTPS access test failed (may be normal if SSL is still setting up)"
fi

# Final status
log_header "🎉 DEPLOYMENT SUMMARY"

if $all_services_ok; then
    echo -e "${GREEN}🎉 DEPLOYMENT SUCCESSFUL! 🎉${NC}\n"
    
    echo -e "${CYAN}Access your NoctisPro system:${NC}"
    echo -e "🌐 Web Interface: ${GREEN}https://$DOMAIN_NAME${NC}"
    echo -e "👨‍💼 Admin Panel: ${GREEN}https://$DOMAIN_NAME/admin/${NC}"
    echo -e "🔗 API Endpoint: ${GREEN}https://$DOMAIN_NAME/api/${NC}"
    
    echo -e "\n${CYAN}Default credentials:${NC}"
    echo -e "Username: ${GREEN}admin${NC}"
    echo -e "Password: ${YELLOW}Check deployment output above for generated password${NC}"
    
    echo -e "\n${CYAN}Important files:${NC}"
    echo -e "📁 Application: ${GREEN}$PROJECT_DIR${NC}"
    echo -e "📄 Nginx Config: ${GREEN}/etc/nginx/sites-available/noctis_pro${NC}"
    echo -e "🔐 SSL Certificates: ${GREEN}/etc/letsencrypt/live/$DOMAIN_NAME/${NC}"
    
    echo -e "\n${CYAN}Next steps:${NC}"
    echo -e "1. 📝 Create additional user accounts via admin panel"
    echo -e "2. 🏥 Configure DICOM settings for your medical devices"
    echo -e "3. 🖨️  Setup medical image printing if needed"
    echo -e "4. 📧 Configure email settings for notifications"
    echo -e "5. 🔒 Review security settings and user permissions"
    
else
    echo -e "${RED}⚠️  DEPLOYMENT COMPLETED WITH ISSUES ⚠️${NC}\n"
    echo -e "${YELLOW}Some services may not be running correctly.${NC}"
    echo -e "${YELLOW}Please check the logs and troubleshoot:${NC}"
    echo -e "📄 Check logs: ${CYAN}sudo journalctl -u noctis-web -f${NC}"
    echo -e "🔧 Restart services: ${CYAN}sudo systemctl restart noctis-web${NC}"
fi

# Generate troubleshooting info
log_info "Generating troubleshooting information..."
cat > "$PROJECT_DIR/deployment_info.txt" << EOF
NoctisPro Deployment Information
================================
Date: $(date)
Domain: $DOMAIN_NAME
Email: $SSL_EMAIL
Server IP: $(curl -s -4 ifconfig.me)
Ubuntu Version: $(lsb_release -d | cut -f2)

Service Status:
$(systemctl status noctis-web --no-pager -l 2>/dev/null || echo "noctis-web: Not found")

Network Status:
$(netstat -tlnp | grep -E ':80|:443|:8000')

Firewall Status:
$(ufw status)

Disk Usage:
$(df -h)

Memory Usage:
$(free -h)
EOF

echo -e "\n${CYAN}📋 Troubleshooting info saved to: ${GREEN}$PROJECT_DIR/deployment_info.txt${NC}"

# Display final commands
echo -e "\n${CYAN}Useful commands:${NC}"
echo -e "🔍 Check logs: ${GREEN}sudo journalctl -u noctis-web -f${NC}"
echo -e "🔄 Restart service: ${GREEN}sudo systemctl restart noctis-web${NC}"
echo -e "🧪 Test SSL: ${GREEN}curl -I https://$DOMAIN_NAME${NC}"
echo -e "📊 System status: ${GREEN}sudo systemctl status noctis-*${NC}"

echo -e "\n${GREEN}Deployment completed!${NC} 🏥✨"
log_info "Thank you for using NoctisPro Medical Imaging Platform!"