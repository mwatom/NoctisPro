#!/bin/bash

# System Status and SSL Domain Check Script for NoctisPro
# This script checks system status and identifies SSL domain naming issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
    echo -e "\n${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
}

# Global variables
ISSUES_FOUND=0
WARNINGS_FOUND=0

# Check system information
check_system_info() {
    log_header "SYSTEM INFORMATION"
    
    log_info "Hostname: $(hostname -f 2>/dev/null || hostname)"
    log_info "Operating System: $(uname -s) $(uname -r)"
    log_info "Architecture: $(uname -m)"
    log_info "Uptime: $(uptime | cut -d',' -f1)"
    
    # Check if running in container
    if [ -f /.dockerenv ]; then
        log_warning "Running inside Docker container"
        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    fi
    
    # Check init system
    if [ -d /run/systemd/system ]; then
        log_success "SystemD detected"
    else
        log_warning "SystemD not detected - some services may not be available"
        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    fi
}

# Check network connectivity
check_network() {
    log_header "NETWORK CONNECTIVITY"
    
    # Check internet connectivity
    if curl -s --max-time 5 https://httpbin.org/ip >/dev/null 2>&1; then
        log_success "Internet connectivity: OK"
        
        # Get public IP
        PUBLIC_IP=$(curl -s --max-time 5 https://httpbin.org/ip | grep -o '[0-9.]*' | head -1)
        log_info "Public IP: $PUBLIC_IP"
    else
        log_error "No internet connectivity"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
    
    # Check DNS resolution
    if nslookup google.com >/dev/null 2>&1; then
        log_success "DNS resolution: OK"
    else
        log_error "DNS resolution failed"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
}

# Check ports and services
check_ports_services() {
    log_header "PORTS AND SERVICES"
    
    # Common ports to check
    ports=("80:HTTP" "443:HTTPS" "8000:Django" "5432:PostgreSQL" "6379:Redis" "11112:DICOM")
    
    for port_info in "${ports[@]}"; do
        port=$(echo $port_info | cut -d':' -f1)
        service=$(echo $port_info | cut -d':' -f2)
        
        if command -v netstat >/dev/null 2>&1; then
            if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
                log_success "$service (port $port): LISTENING"
            else
                log_warning "$service (port $port): NOT LISTENING"
                WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
            fi
        elif command -v ss >/dev/null 2>&1; then
            if ss -tlnp 2>/dev/null | grep -q ":$port "; then
                log_success "$service (port $port): LISTENING"
            else
                log_warning "$service (port $port): NOT LISTENING"
                WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
            fi
        else
            log_warning "Cannot check port $port - no netstat/ss available"
            WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
        fi
    done
}

# Check Docker status
check_docker() {
    log_header "DOCKER STATUS"
    
    if command -v docker >/dev/null 2>&1; then
        log_success "Docker command available"
        
        if docker info >/dev/null 2>&1; then
            log_success "Docker daemon running"
            
            # Check running containers
            running_containers=$(docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null)
            if [ -n "$running_containers" ]; then
                log_success "Running containers:"
                echo "$running_containers"
            else
                log_warning "No running Docker containers"
                WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
            fi
        else
            log_error "Docker daemon not running"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    else
        log_warning "Docker not installed"
        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    fi
}

# Check SSL certificates and domain configuration
check_ssl_domain() {
    log_header "SSL CERTIFICATE AND DOMAIN CONFIGURATION"
    
    # Check for Let's Encrypt certificates
    if [ -d /etc/letsencrypt/live ]; then
        log_success "Let's Encrypt directory found"
        
        # List available certificates
        for cert_dir in /etc/letsencrypt/live/*/; do
            if [ -d "$cert_dir" ]; then
                domain=$(basename "$cert_dir")
                if [ "$domain" != "README" ]; then
                    log_info "Certificate found for domain: $domain"
                    
                    # Check certificate validity
                    cert_file="$cert_dir/fullchain.pem"
                    if [ -f "$cert_file" ]; then
                        if command -v openssl >/dev/null 2>&1; then
                            expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
                            if [ -n "$expiry" ]; then
                                log_info "Certificate expires: $expiry"
                                
                                # Check if certificate expires in next 30 days
                                expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
                                current_epoch=$(date +%s)
                                days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
                                
                                if [ $days_left -lt 30 ] && [ $days_left -gt 0 ]; then
                                    log_warning "Certificate expires in $days_left days"
                                    WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
                                elif [ $days_left -le 0 ]; then
                                    log_error "Certificate has expired"
                                    ISSUES_FOUND=$((ISSUES_FOUND + 1))
                                else
                                    log_success "Certificate valid for $days_left days"
                                fi
                            fi
                        fi
                    else
                        log_error "Certificate file not found: $cert_file"
                        ISSUES_FOUND=$((ISSUES_FOUND + 1))
                    fi
                fi
            fi
        done
    else
        log_warning "No Let's Encrypt certificates found"
        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    fi
    
    # Check for certbot
    if command -v certbot >/dev/null 2>&1; then
        log_success "Certbot available"
        
        # Check certbot auto-renewal
        if crontab -l 2>/dev/null | grep -q certbot; then
            log_success "Certbot auto-renewal configured"
        else
            log_warning "Certbot auto-renewal not configured"
            WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
        fi
    else
        log_warning "Certbot not installed"
        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    fi
}

# Check Nginx configuration
check_nginx() {
    log_header "NGINX CONFIGURATION"
    
    if command -v nginx >/dev/null 2>&1; then
        log_success "Nginx installed"
        
        # Test nginx configuration
        if nginx -t >/dev/null 2>&1; then
            log_success "Nginx configuration valid"
        else
            log_error "Nginx configuration invalid"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
            nginx -t 2>&1 | head -10
        fi
        
        # Check if nginx is running
        if pgrep nginx >/dev/null 2>&1; then
            log_success "Nginx is running"
        else
            log_warning "Nginx is not running"
            WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
        fi
        
        # Check for NoctisPro site configuration
        noctis_sites=("/etc/nginx/sites-available/noctis-pro" "/etc/nginx/sites-available/noctis" "/etc/nginx/sites-available/noctis-internet.conf")
        site_found=false
        
        for site in "${noctis_sites[@]}"; do
            if [ -f "$site" ]; then
                log_success "NoctisPro site config found: $site"
                site_found=true
                
                # Check if site is enabled
                site_name=$(basename "$site")
                if [ -L "/etc/nginx/sites-enabled/$site_name" ]; then
                    log_success "Site is enabled"
                else
                    log_warning "Site is not enabled"
                    WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
                fi
                break
            fi
        done
        
        if [ "$site_found" = false ]; then
            log_warning "No NoctisPro site configuration found"
            WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
        fi
    else
        log_warning "Nginx not installed"
        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    fi
}

# Check environment configuration
check_environment() {
    log_header "ENVIRONMENT CONFIGURATION"
    
    # Check for environment files
    env_files=(".env" ".env.production" "/etc/noctis/noctis.env")
    env_found=false
    
    for env_file in "${env_files[@]}"; do
        if [ -f "$env_file" ]; then
            log_success "Environment file found: $env_file"
            env_found=true
            
            # Check for important variables
            important_vars=("DOMAIN_NAME" "SECRET_KEY" "POSTGRES_PASSWORD" "ALLOWED_HOSTS")
            for var in "${important_vars[@]}"; do
                if grep -q "^$var=" "$env_file" 2>/dev/null; then
                    value=$(grep "^$var=" "$env_file" | cut -d= -f2 | tr -d '"' | tr -d "'")
                    if [ -n "$value" ] && [ "$value" != "your-domain.com" ] && [ "$value" != "change-me" ]; then
                        log_success "$var is configured"
                    else
                        log_warning "$var needs to be configured in $env_file"
                        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
                    fi
                else
                    log_warning "$var not found in $env_file"
                    WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
                fi
            done
        fi
    done
    
    if [ "$env_found" = false ]; then
        log_warning "No environment configuration files found"
        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    fi
}

# Check common SSL domain issues
check_ssl_domain_issues() {
    log_header "SSL DOMAIN NAMING ISSUES"
    
    # Common domain naming issues
    log_info "Checking for common SSL domain naming issues..."
    
    # Check hostname resolution
    hostname=$(hostname -f 2>/dev/null || hostname)
    log_info "System hostname: $hostname"
    
    if [ "$hostname" = "localhost" ] || [ "$hostname" = "cursor" ]; then
        log_warning "Hostname is set to default value: $hostname"
        log_warning "Consider setting a proper FQDN for SSL certificates"
        WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    fi
    
    # Check for wildcard certificates
    if [ -d /etc/letsencrypt/live ]; then
        for cert_dir in /etc/letsencrypt/live/*/; do
            if [ -d "$cert_dir" ]; then
                domain=$(basename "$cert_dir")
                if [[ "$domain" == *"*"* ]]; then
                    log_info "Wildcard certificate detected: $domain"
                fi
            fi
        done
    fi
    
    # Check for common domain misconfigurations
    common_issues=(
        "noctis-server.local:Local domain - won't work for public SSL"
        "localhost:Localhost - won't work for SSL certificates"
        "127.0.0.1:IP address - won't work for SSL certificates"
        "your-domain.com:Placeholder domain - needs to be changed"
    )
    
    for issue in "${common_issues[@]}"; do
        domain=$(echo "$issue" | cut -d':' -f1)
        description=$(echo "$issue" | cut -d':' -f2)
        
        # Check in environment files
        if grep -r "$domain" /etc/noctis/ 2>/dev/null | grep -v ".bak" | grep -q .; then
            log_warning "Found '$domain' in configuration: $description"
            WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
        fi
    done
}

# Provide solutions for common issues
provide_solutions() {
    log_header "SOLUTIONS FOR COMMON ISSUES"
    
    echo -e "\n${CYAN}SSL Domain Naming Solutions:${NC}"
    echo "1. For public SSL certificates:"
    echo "   - Use a real domain name (e.g., noctis.yourdomain.com)"
    echo "   - Point your domain's DNS A record to your server's public IP"
    echo "   - Run: sudo certbot --nginx -d yourdomain.com"
    
    echo -e "\n2. For local development:"
    echo "   - Use self-signed certificates"
    echo "   - Or use a service like ngrok for temporary public access"
    echo "   - Or use Let's Encrypt with DNS challenge"
    
    echo -e "\n3. For internal networks:"
    echo "   - Set up internal CA"
    echo "   - Use .local domains with mDNS"
    echo "   - Or use reverse proxy with valid SSL termination"
    
    echo -e "\n${CYAN}Quick Fixes:${NC}"
    if [ $WARNINGS_FOUND -gt 0 ] || [ $ISSUES_FOUND -gt 0 ]; then
        echo "1. Install missing components:"
        echo "   sudo apt update && sudo apt install -y docker.io nginx certbot python3-certbot-nginx"
        
        echo -e "\n2. Configure domain in environment:"
        echo "   Edit .env file and set DOMAIN_NAME to your actual domain"
        
        echo -e "\n3. Generate SSL certificate:"
        echo "   sudo certbot --nginx -d yourdomain.com"
        
        echo -e "\n4. Start services:"
        echo "   sudo systemctl enable --now nginx"
        echo "   sudo systemctl enable --now docker"
    fi
}

# Main execution
main() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║          NOCTIS PRO SYSTEM STATUS CHECK         ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_system_info
    check_network
    check_ports_services
    check_docker
    check_nginx
    check_ssl_domain
    check_environment
    check_ssl_domain_issues
    
    # Summary
    log_header "SUMMARY"
    
    if [ $ISSUES_FOUND -eq 0 ] && [ $WARNINGS_FOUND -eq 0 ]; then
        log_success "System appears to be healthy!"
    else
        if [ $ISSUES_FOUND -gt 0 ]; then
            log_error "Found $ISSUES_FOUND critical issues"
        fi
        if [ $WARNINGS_FOUND -gt 0 ]; then
            log_warning "Found $WARNINGS_FOUND warnings"
        fi
        
        provide_solutions
    fi
    
    echo -e "\n${CYAN}For detailed deployment guides, check:${NC}"
    echo "- README.md"
    echo "- DEPLOYMENT_SUMMARY.md"
    echo "- SUPER_SIMPLE_SETUP_GUIDE.md"
    
    # Exit with appropriate code
    if [ $ISSUES_FOUND -gt 0 ]; then
        exit 1
    elif [ $WARNINGS_FOUND -gt 0 ]; then
        exit 2
    else
        exit 0
    fi
}

# Run main function
main "$@"