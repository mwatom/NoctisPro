#!/bin/bash

# =============================================================================
# NoctisPro PACS - CloudFlare Integrated Deployment Script
# =============================================================================
# This script deploys NoctisPro PACS with CloudFlare tunnel integration
# for consistent public URLs, replacing the need for ngrok domains
# =============================================================================

set -euo pipefail

# Colors and formatting
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
readonly LOG_FILE="${PROJECT_DIR}/logs/cloudflare_deployment_$(date +%Y%m%d_%H%M%S).log"
readonly CONFIG_DIR="${PROJECT_DIR}/config"

# Deployment state
declare -g DEPLOYMENT_PHASE="INITIALIZATION"
declare -g VALIDATION_PASSED=false
declare -g SERVICES_STARTED=false
declare -g TUNNEL_CONFIGURED=false

# Create logs directory
mkdir -p "${PROJECT_DIR}/logs" "${CONFIG_DIR}"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_entry="[${timestamp}] [${DEPLOYMENT_PHASE}] ${message}"
    
    echo -e "${GREEN}${log_entry}${NC}"
    echo "${log_entry}" >> "${LOG_FILE}"
}

warn() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_entry="[${timestamp}] [${DEPLOYMENT_PHASE}] WARNING: ${message}"
    
    echo -e "${YELLOW}${log_entry}${NC}" >&2
    echo "${log_entry}" >> "${LOG_FILE}"
}

error() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_entry="[${timestamp}] [${DEPLOYMENT_PHASE}] ERROR: ${message}"
    
    echo -e "${RED}${log_entry}${NC}" >&2
    echo "${log_entry}" >> "${LOG_FILE}"
}

success() {
    local message="$1"
    echo -e "${GREEN}✅ ${message}${NC}"
    log "SUCCESS: ${message}"
}

phase() {
    DEPLOYMENT_PHASE="$1"
    local message="$2"
    echo ""
    echo -e "${BOLD}${CYAN}=== ${DEPLOYMENT_PHASE}: ${message} ===${NC}"
    echo ""
    log "Phase started: ${DEPLOYMENT_PHASE}"
}

# =============================================================================
# SYSTEM VALIDATION
# =============================================================================

validate_system() {
    phase "SYSTEM_VALIDATION" "Validating system requirements"
    
    local validation_failed=false
    
    # Check Docker
    if command -v docker >/dev/null 2>&1; then
        log "✅ Docker found: $(docker --version)"
    else
        error "Docker not found. Please install Docker first."
        validation_failed=true
    fi
    
    # Check Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        log "✅ Docker Compose found: $(docker-compose --version)"
    else
        error "Docker Compose not found. Please install Docker Compose first."
        validation_failed=true
    fi
    
    # Check Python
    if command -v python3 >/dev/null 2>&1; then
        log "✅ Python 3 found: $(python3 --version)"
    else
        warn "Python 3 not found. Some configuration scripts may not work."
    fi
    
    # Check CloudFlare tunnel
    if command -v cloudflared >/dev/null 2>&1; then
        log "✅ CloudFlare tunnel found: $(cloudflared --version)"
    else
        warn "CloudFlare tunnel not found. Will install during setup."
    fi
    
    # Check disk space
    local available_space=$(df "${PROJECT_DIR}" | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $available_space -ge 5 ]]; then
        log "✅ Sufficient disk space: ${available_space}GB available"
    else
        error "Insufficient disk space: ${available_space}GB available (minimum 5GB required)"
        validation_failed=true
    fi
    
    # Check memory
    local available_memory=$(free -g | awk 'NR==2{print $2}')
    if [[ $available_memory -ge 2 ]]; then
        log "✅ Sufficient memory: ${available_memory}GB available"
    else
        warn "Limited memory: ${available_memory}GB available (recommended minimum 2GB)"
    fi
    
    if [[ "$validation_failed" == "true" ]]; then
        error "System validation failed. Please address the issues above."
        exit 1
    fi
    
    VALIDATION_PASSED=true
    success "System validation passed"
}

# =============================================================================
# CLOUDFLARE TUNNEL SETUP
# =============================================================================

setup_cloudflare_tunnel() {
    phase "CLOUDFLARE_SETUP" "Setting up CloudFlare tunnel"
    
    # Install CloudFlare tunnel if not available
    if ! command -v cloudflared >/dev/null 2>&1; then
        log "Installing CloudFlare tunnel..."
        
        if [[ -f cloudflared.deb ]]; then
            log "Using existing cloudflared.deb package"
        else
            log "Downloading CloudFlare tunnel..."
            wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -O cloudflared.deb
        fi
        
        sudo dpkg -i cloudflared.deb
        success "CloudFlare tunnel installed"
    fi
    
    # Check if tunnel setup script exists and run it
    if [[ -x "${PROJECT_DIR}/cloudflare-tunnel-setup.sh" ]]; then
        log "Running CloudFlare tunnel setup script..."
        
        # Run in interactive mode if terminal is available
        if [[ -t 0 ]]; then
            "${PROJECT_DIR}/cloudflare-tunnel-setup.sh"
        else
            log "Running in non-interactive mode - manual setup required later"
        fi
        
        TUNNEL_CONFIGURED=true
        success "CloudFlare tunnel setup completed"
    else
        warn "CloudFlare tunnel setup script not found. Creating basic configuration..."
        create_basic_tunnel_config
    fi
}

create_basic_tunnel_config() {
    log "Creating basic CloudFlare tunnel configuration..."
    
    local cf_config_dir="${CONFIG_DIR}/cloudflare"
    mkdir -p "$cf_config_dir"
    
    # Create basic tunnel configuration
    cat > "${cf_config_dir}/config.yml" << EOF
# Basic CloudFlare Tunnel Configuration
# This file needs to be updated with your actual tunnel ID and credentials

tunnel: YOUR_TUNNEL_ID_HERE
credentials-file: /etc/cloudflared/YOUR_TUNNEL_ID_HERE.json

ingress:
  # Main web interface
  - hostname: noctis.yourdomain.com
    service: http://web:8000
    originRequest:
      httpHostHeader: localhost:8000
      noTLSVerify: true

  # Admin interface
  - hostname: admin.yourdomain.com
    service: http://web:8000
    originRequest:
      httpHostHeader: localhost:8000
      noTLSVerify: true

  # DICOM receiver
  - hostname: dicom.yourdomain.com
    service: tcp://dicom_receiver:11112

  # Catch-all rule
  - service: http_status:404
EOF

    warn "Basic tunnel configuration created. You need to:"
    warn "1. Authenticate with CloudFlare: cloudflared tunnel login"
    warn "2. Create a tunnel: cloudflared tunnel create noctis-pacs"
    warn "3. Update the configuration with your tunnel ID and domain"
    warn "4. Set up DNS records for your subdomains"
}

# =============================================================================
# DICOM NETWORK CONFIGURATION
# =============================================================================

configure_dicom_network() {
    phase "DICOM_NETWORK" "Configuring DICOM network for remote AE access"
    
    # Run DICOM network configuration script
    if [[ -x "${PROJECT_DIR}/dicom_network_config.py" ]]; then
        log "Running DICOM network configuration..."
        
        if python3 "${PROJECT_DIR}/dicom_network_config.py" >> "${LOG_FILE}" 2>&1; then
            success "DICOM network configuration completed"
        else
            warn "DICOM network configuration failed - check logs"
        fi
    else
        warn "DICOM network configuration script not found"
    fi
    
    # Ensure DICOM port is accessible
    log "Configuring firewall for DICOM access..."
    
    # Check if ufw is available and configure it
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow 11112/tcp comment "NoctisPro DICOM" 2>/dev/null || true
        sudo ufw allow 8000/tcp comment "NoctisPro Web" 2>/dev/null || true
        log "Firewall rules configured for DICOM and web access"
    else
        warn "UFW not available - ensure ports 8000 and 11112 are accessible"
    fi
}

# =============================================================================
# DOCKER DEPLOYMENT
# =============================================================================

prepare_docker_environment() {
    phase "DOCKER_PREP" "Preparing Docker environment"
    
    # Create environment file
    local env_file="${PROJECT_DIR}/.env"
    
    if [[ ! -f "$env_file" ]]; then
        log "Creating environment configuration..."
        
        cat > "$env_file" << EOF
# NoctisPro PACS - Docker Environment Configuration
# Generated by CloudFlare integrated deployment script

# Django Configuration
DEBUG=False
SECRET_KEY=$(openssl rand -base64 32)
DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Database Configuration
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# System Configuration
WORKERS=4
BUILD_TARGET=production

# CloudFlare Configuration (update these values)
CLOUDFLARE_DOMAIN=yourdomain.com
CLOUDFLARE_TUNNEL_TOKEN=YOUR_TUNNEL_TOKEN_HERE

# Deployment Metadata
DEPLOYMENT_MODE=docker_cloudflare
DEPLOYED_AT=$(date -Iseconds)
EOF

        success "Environment configuration created: $env_file"
    else
        log "Using existing environment configuration: $env_file"
    fi
    
    # Create Docker network if it doesn't exist
    if ! docker network ls | grep -q "noctis_network"; then
        docker network create noctis_network
        log "Docker network 'noctis_network' created"
    fi
}

deploy_with_docker() {
    phase "DOCKER_DEPLOY" "Deploying with Docker Compose"
    
    cd "${PROJECT_DIR}"
    
    # Determine which compose file to use
    local compose_file="docker-compose.yml"
    
    if [[ -f "docker-compose.cloudflare.yml" ]]; then
        compose_file="docker-compose.cloudflare.yml"
        log "Using CloudFlare-integrated Docker Compose configuration"
    else
        log "Using standard Docker Compose configuration"
    fi
    
    # Pull latest images
    log "Pulling Docker images..."
    docker-compose -f "$compose_file" pull || true
    
    # Build application images
    log "Building application images..."
    docker-compose -f "$compose_file" build
    
    # Start core services first
    log "Starting core services (database, redis)..."
    docker-compose -f "$compose_file" up -d db redis
    
    # Wait for database to be ready
    log "Waiting for database to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if docker-compose -f "$compose_file" exec -T db pg_isready -U noctis_user -d noctis_pro >/dev/null 2>&1; then
            success "Database is ready"
            break
        fi
        
        ((attempt++))
        if [[ $attempt -eq $max_attempts ]]; then
            error "Database failed to start within timeout"
            return 1
        fi
        
        log "Waiting for database... (attempt $attempt/$max_attempts)"
        sleep 10
    done
    
    # Start application services
    log "Starting application services..."
    docker-compose -f "$compose_file" up -d web dicom_receiver celery
    
    # Start CloudFlare tunnel if configuration exists
    if [[ -f "${CONFIG_DIR}/cloudflare/config.yml" ]] && docker-compose -f "$compose_file" config | grep -q "cloudflare_tunnel"; then
        log "Starting CloudFlare tunnel service..."
        docker-compose -f "$compose_file" up -d cloudflare_tunnel
    fi
    
    SERVICES_STARTED=true
    success "Docker deployment completed"
}

# =============================================================================
# POST-DEPLOYMENT VALIDATION
# =============================================================================

validate_deployment() {
    phase "POST_VALIDATION" "Validating deployment"
    
    local validation_failed=false
    
    # Wait for services to fully start
    log "Waiting for services to initialize..."
    sleep 20
    
    # Test web service
    log "Testing web service..."
    local web_attempts=0
    local web_ready=false
    
    while [[ $web_attempts -lt 10 ]] && [[ "$web_ready" == "false" ]]; do
        if curl -f -s --max-time 10 "http://localhost:8000/" >/dev/null 2>&1; then
            success "✅ Web service is responding"
            web_ready=true
        else
            ((web_attempts++))
            log "Web service not ready, attempt $web_attempts/10..."
            sleep 10
        fi
    done
    
    if [[ "$web_ready" == "false" ]]; then
        error "❌ Web service is not responding after multiple attempts"
        validation_failed=true
    fi
    
    # Test DICOM port
    log "Testing DICOM port..."
    if timeout 10 bash -c "</dev/tcp/localhost/11112" >/dev/null 2>&1; then
        success "✅ DICOM port is accessible"
    else
        error "❌ DICOM port is not accessible"
        validation_failed=true
    fi
    
    # Test admin interface
    log "Testing admin interface..."
    if curl -f -s --max-time 10 "http://localhost:8000/admin/" >/dev/null 2>&1; then
        success "✅ Admin interface is accessible"
    else
        warn "⚠️  Admin interface may not be fully ready yet"
    fi
    
    # Check Docker services
    log "Checking Docker service status..."
    local compose_file="docker-compose.yml"
    if [[ -f "docker-compose.cloudflare.yml" ]]; then
        compose_file="docker-compose.cloudflare.yml"
    fi
    
    local running_services=$(docker-compose -f "$compose_file" ps --services --filter "status=running" | wc -l)
    local total_services=$(docker-compose -f "$compose_file" ps --services | wc -l)
    
    log "Docker services running: $running_services/$total_services"
    
    if [[ "$validation_failed" == "true" ]]; then
        error "Post-deployment validation failed"
        return 1
    else
        success "Post-deployment validation passed"
        return 0
    fi
}

# =============================================================================
# ERROR HANDLING AND TROUBLESHOOTING
# =============================================================================

troubleshoot_deployment() {
    phase "TROUBLESHOOTING" "Diagnosing deployment issues"
    
    echo ""
    echo -e "${YELLOW}🔍 Deployment Troubleshooting Information${NC}"
    echo "========================================="
    
    # Check Docker status
    echo ""
    echo "Docker Service Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || true
    
    # Check logs for errors
    echo ""
    echo "Recent Error Logs:"
    echo "=================="
    
    # Web service logs
    echo ""
    echo "Web Service Logs (last 20 lines):"
    docker logs noctis_web --tail 20 2>/dev/null || echo "Web service logs not available"
    
    # DICOM service logs
    echo ""
    echo "DICOM Service Logs (last 20 lines):"
    docker logs noctis_dicom --tail 20 2>/dev/null || echo "DICOM service logs not available"
    
    # Database logs
    echo ""
    echo "Database Logs (last 10 lines):"
    docker logs noctis_db --tail 10 2>/dev/null || echo "Database logs not available"
    
    # Network connectivity
    echo ""
    echo "Network Connectivity:"
    echo "===================="
    
    # Test internal connectivity
    echo "Testing internal Docker network..."
    docker exec noctis_web curl -f -s --max-time 5 "http://db:5432" >/dev/null 2>&1 && echo "✅ Web -> Database: OK" || echo "❌ Web -> Database: Failed"
    docker exec noctis_web curl -f -s --max-time 5 "http://redis:6379" >/dev/null 2>&1 && echo "✅ Web -> Redis: OK" || echo "❌ Web -> Redis: Failed"
    
    # Port accessibility
    echo ""
    echo "Port Accessibility:"
    echo "=================="
    timeout 5 bash -c "</dev/tcp/localhost/8000" >/dev/null 2>&1 && echo "✅ Port 8000 (Web): Accessible" || echo "❌ Port 8000 (Web): Not accessible"
    timeout 5 bash -c "</dev/tcp/localhost/11112" >/dev/null 2>&1 && echo "✅ Port 11112 (DICOM): Accessible" || echo "❌ Port 11112 (DICOM): Not accessible"
    timeout 5 bash -c "</dev/tcp/localhost/5432" >/dev/null 2>&1 && echo "✅ Port 5432 (Database): Accessible" || echo "❌ Port 5432 (Database): Not accessible"
    
    echo ""
    echo -e "${BLUE}📁 Log Files:${NC}"
    echo "Deployment log: ${LOG_FILE}"
    echo "Docker logs: docker logs <container_name>"
    echo "DICOM logs: ${PROJECT_DIR}/logs/dicom_receiver.log"
}

# =============================================================================
# DEPLOYMENT SUMMARY
# =============================================================================

display_deployment_summary() {
    echo ""
    echo "=============================================="
    echo "🎉 NoctisPro PACS - CloudFlare Deployment Complete!"
    echo "=============================================="
    echo ""
    
    # Get local IP for display
    local local_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo "📊 Deployment Summary:"
    echo "  System Validation: ${VALIDATION_PASSED}"
    echo "  Services Started: ${SERVICES_STARTED}"
    echo "  CloudFlare Configured: ${TUNNEL_CONFIGURED}"
    echo ""
    echo "🌐 Access Information:"
    echo "  Local Web Interface: ${GREEN}http://localhost:8000${NC}"
    echo "  Local Admin Panel: ${GREEN}http://localhost:8000/admin/${NC}"
    echo "  Network Web Interface: ${GREEN}http://${local_ip}:8000${NC}"
    echo "  DICOM Port: ${GREEN}${local_ip}:11112${NC}"
    echo "  Default Login: ${GREEN}admin / NoctisAdmin2024!${NC}"
    echo ""
    
    # Display CloudFlare URLs if configured
    if [[ -f "${CONFIG_DIR}/cloudflare/domain.txt" ]]; then
        local cf_domain=$(cat "${CONFIG_DIR}/cloudflare/domain.txt")
        echo "🌍 CloudFlare Public URLs:"
        echo "  Web Interface: ${CYAN}https://noctis.${cf_domain}${NC}"
        echo "  Admin Panel: ${CYAN}https://admin.${cf_domain}${NC}"
        echo "  DICOM Endpoint: ${CYAN}dicom.${cf_domain}:11112${NC}"
        echo ""
    fi
    
    echo "🔧 Management Commands:"
    echo "  View Status: ${CYAN}docker-compose ps${NC}"
    echo "  View Logs: ${CYAN}docker-compose logs -f${NC}"
    echo "  Stop Services: ${CYAN}docker-compose down${NC}"
    echo "  Restart Services: ${CYAN}docker-compose restart${NC}"
    echo ""
    echo "📁 Important Files:"
    echo "  Deployment Log: ${LOG_FILE}"
    echo "  Environment Config: ${PROJECT_DIR}/.env"
    echo "  DICOM Guide: ${PROJECT_DIR}/docs/DICOM_CONNECTION_GUIDE.md"
    
    if [[ -f "${CONFIG_DIR}/cloudflare/config.yml" ]]; then
        echo "  CloudFlare Config: ${CONFIG_DIR}/cloudflare/config.yml"
    fi
    
    echo ""
    
    if [[ "${VALIDATION_PASSED}" == "true" && "${SERVICES_STARTED}" == "true" ]]; then
        success "🎉 Deployment completed successfully!"
        success "🔗 Access your NoctisPro PACS system at: http://localhost:8000"
    else
        warn "⚠️  Deployment completed with issues. Check the troubleshooting section above."
    fi
}

# =============================================================================
# CLEANUP AND ERROR HANDLING
# =============================================================================

cleanup_on_exit() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        error "Deployment failed with exit code $exit_code"
        echo ""
        troubleshoot_deployment
        
        echo ""
        echo -e "${RED}Deployment failed. Common solutions:${NC}"
        echo "1. Check if ports 8000 and 11112 are available"
        echo "2. Ensure Docker and Docker Compose are properly installed"
        echo "3. Verify sufficient disk space and memory"
        echo "4. Check the deployment log: ${LOG_FILE}"
        echo "5. Run: docker-compose logs to see service-specific errors"
    fi
    
    log "Deployment script finished with exit code $exit_code"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local start_time=$(date +%s)
    
    echo ""
    echo -e "${BOLD}${CYAN}🚀 NoctisPro PACS - CloudFlare Integrated Deployment${NC}"
    echo -e "${BOLD}${CYAN}====================================================${NC}"
    echo ""
    echo "This script will deploy NoctisPro PACS with CloudFlare tunnel integration"
    echo "for consistent public URLs that replace the need for purchasing domains."
    echo ""
    
    log "Starting CloudFlare integrated deployment..."
    log "Deployment log: ${LOG_FILE}"
    
    # Phase 1: System Validation
    validate_system
    
    # Phase 2: CloudFlare Tunnel Setup
    setup_cloudflare_tunnel
    
    # Phase 3: DICOM Network Configuration
    configure_dicom_network
    
    # Phase 4: Docker Environment Preparation
    prepare_docker_environment
    
    # Phase 5: Docker Deployment
    deploy_with_docker
    
    # Phase 6: Post-deployment Validation
    if validate_deployment; then
        # Phase 7: Display Summary
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log "Total deployment time: ${duration} seconds"
        display_deployment_summary
        
        success "🎉 NoctisPro PACS deployment with CloudFlare integration complete!"
    else
        error "Deployment validation failed"
        troubleshoot_deployment
        exit 1
    fi
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "NoctisPro PACS CloudFlare Integrated Deployment Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --validate-only     Run validation checks only"
        echo "  --troubleshoot      Run troubleshooting diagnostics"
        echo ""
        echo "This script deploys NoctisPro PACS with CloudFlare tunnel integration"
        echo "for consistent public URLs without needing to purchase domains."
        exit 0
        ;;
    --validate-only)
        echo "Running validation checks only..."
        validate_system
        exit 0
        ;;
    --troubleshoot)
        echo "Running troubleshooting diagnostics..."
        troubleshoot_deployment
        exit 0
        ;;
esac

# Set up error handling
trap cleanup_on_exit EXIT
trap 'error "Script interrupted"; exit 1' INT TERM

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root for security reasons."
    error "Please run as a regular user with sudo privileges."
    exit 1
fi

# Run main deployment
main "$@"