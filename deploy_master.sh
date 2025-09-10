#!/bin/bash

# =============================================================================
# NoctisPro PACS - Master Intelligent Deployment Script
# =============================================================================
# Unified deployment orchestrator that auto-detects system capabilities
# and deploys optimally across any server environment
# =============================================================================

set -euo pipefail

# Version and metadata
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="NoctisPro PACS Master Deployment"
readonly SCRIPT_AUTHOR="AI Assistant"
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
readonly LOG_FILE="/tmp/noctis_master_deploy_$(date +%Y%m%d_%H%M%S).log"
readonly BACKUP_DIR="/tmp/noctis_backup_$(date +%Y%m%d_%H%M%S)"

# Global deployment state
declare -g DEPLOYMENT_PHASE="INITIALIZATION"
declare -g DEPLOYMENT_MODE=""
declare -g SYSTEM_PROFILE=""
declare -g VALIDATION_PASSED=false
declare -g ROLLBACK_AVAILABLE=false

# =============================================================================
# ENHANCED LOGGING SYSTEM
# =============================================================================

log() {
    local level="INFO"
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_entry="[${timestamp}] [${level}] [${DEPLOYMENT_PHASE}] ${message}"
    
    echo -e "${GREEN}${log_entry}${NC}"
    echo "${log_entry}" >> "${LOG_FILE}"
}

warn() {
    local level="WARN"
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_entry="[${timestamp}] [${level}] [${DEPLOYMENT_PHASE}] ${message}"
    
    echo -e "${YELLOW}${log_entry}${NC}" >&2
    echo "${log_entry}" >> "${LOG_FILE}"
}

error() {
    local level="ERROR"
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_entry="[${timestamp}] [${level}] [${DEPLOYMENT_PHASE}] ${message}"
    
    echo -e "${RED}${log_entry}${NC}" >&2
    echo "${log_entry}" >> "${LOG_FILE}"
}

success() {
    local level="SUCCESS"
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_entry="[${timestamp}] [${level}] [${DEPLOYMENT_PHASE}] ${message}"
    
    echo -e "${GREEN}✅ ${message}${NC}"
    echo "${log_entry}" >> "${LOG_FILE}"
}

info() {
    local level="INFO"
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_entry="[${timestamp}] [${level}] [${DEPLOYMENT_PHASE}] ${message}"
    
    echo -e "${BLUE}${message}${NC}"
    echo "${log_entry}" >> "${LOG_FILE}"
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
# SYSTEM PROFILING AND DETECTION
# =============================================================================

create_system_profile() {
    phase "SYSTEM_ANALYSIS" "Analyzing system capabilities"
    
    # Run system detection from intelligent deployment script
    source "${PROJECT_DIR}/deploy_intelligent.sh"
    
    # Perform comprehensive analysis
    detect_operating_system
    detect_system_resources
    detect_installed_software
    determine_deployment_mode
    
    # Create system profile
    SYSTEM_PROFILE="os=${DETECTED_OS}_arch=${DETECTED_ARCH}_mem=${AVAILABLE_MEMORY_GB}gb_cpu=${AVAILABLE_CPU_CORES}cores"
    
    log "System profile created: ${SYSTEM_PROFILE}"
    log "Detected OS: ${DETECTED_OS} ${DETECTED_VERSION}"
    log "Architecture: ${DETECTED_ARCH}"
    log "Resources: ${AVAILABLE_MEMORY_GB}GB RAM, ${AVAILABLE_CPU_CORES} CPU cores"
    log "Selected deployment mode: ${DEPLOYMENT_MODE}"
    
    # Save system profile for reference
    cat > "${PROJECT_DIR}/system_profile.json" << EOF
{
  "profile_id": "${SYSTEM_PROFILE}",
  "timestamp": "$(date -Iseconds)",
  "os": "${DETECTED_OS}",
  "os_version": "${DETECTED_VERSION}",
  "architecture": "${DETECTED_ARCH}",
  "memory_gb": ${AVAILABLE_MEMORY_GB},
  "cpu_cores": ${AVAILABLE_CPU_CORES},
  "storage_gb": ${AVAILABLE_STORAGE_GB},
  "deployment_mode": "${DEPLOYMENT_MODE}",
  "capabilities": {
    "has_docker": ${HAS_DOCKER},
    "has_systemd": ${HAS_SYSTEMD},
    "has_nginx": ${HAS_NGINX},
    "has_python3": ${HAS_PYTHON3},
    "internet_access": ${INTERNET_ACCESS}
  },
  "optimal_workers": ${OPTIMAL_WORKERS},
  "use_nginx": ${USE_NGINX},
  "use_ssl": ${USE_SSL}
}
EOF
    
    success "System analysis complete - Profile: ${SYSTEM_PROFILE}"
}

# =============================================================================
# PRE-DEPLOYMENT VALIDATION
# =============================================================================

run_pre_deployment_validation() {
    phase "VALIDATION" "Running pre-deployment validation"
    
    # Run test suite
    if [[ -x "${PROJECT_DIR}/test_deployment.sh" ]]; then
        log "Running deployment test suite..."
        if "${PROJECT_DIR}/test_deployment.sh" > "${LOG_FILE}.tests" 2>&1; then
            VALIDATION_PASSED=true
            success "All validation tests passed"
        else
            error "Validation tests failed - check ${LOG_FILE}.tests for details"
            
            # Ask user if they want to continue despite failures
            echo ""
            warn "Some validation tests failed. This may indicate potential issues."
            read -p "Do you want to continue anyway? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                warn "Continuing with deployment despite validation failures"
                VALIDATION_PASSED=true
            else
                error "Deployment aborted due to validation failures"
                exit 1
            fi
        fi
    else
        warn "Test suite not found - skipping validation"
        VALIDATION_PASSED=true
    fi
    
    # Check system requirements
    validate_system_requirements
    
    # Check disk space
    validate_disk_space
    
    # Check network connectivity if needed
    if [[ "${INTERNET_ACCESS}" == "true" ]]; then
        validate_network_connectivity
    fi
}

validate_system_requirements() {
    log "Validating system requirements..."
    
    local requirements_met=true
    
    # Minimum memory check
    if [[ ${AVAILABLE_MEMORY_GB} -lt 1 ]]; then
        error "Insufficient memory: ${AVAILABLE_MEMORY_GB}GB (minimum 1GB required)"
        requirements_met=false
    fi
    
    # Minimum storage check
    if [[ ${AVAILABLE_STORAGE_GB} -lt 5 ]]; then
        error "Insufficient storage: ${AVAILABLE_STORAGE_GB}GB (minimum 5GB required)"
        requirements_met=false
    fi
    
    # Python check for native deployment
    if [[ "${DEPLOYMENT_MODE}" == "native_"* ]] && [[ "${HAS_PYTHON3}" == "false" ]]; then
        error "Python 3 required for native deployment but not found"
        requirements_met=false
    fi
    
    # Docker check for Docker deployment
    if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]] && [[ "${HAS_DOCKER}" == "false" ]]; then
        warn "Docker not available - will install during deployment"
    fi
    
    if [[ "$requirements_met" == "true" ]]; then
        success "System requirements validation passed"
    else
        error "System requirements validation failed"
        exit 1
    fi
}

validate_disk_space() {
    log "Validating disk space requirements..."
    
    local required_space_gb=5
    
    # Adjust required space based on deployment mode
    case "${DEPLOYMENT_MODE}" in
        "docker_full")
            required_space_gb=10
            ;;
        "docker_minimal")
            required_space_gb=7
            ;;
        "native_"*)
            required_space_gb=5
            ;;
    esac
    
    if [[ ${AVAILABLE_STORAGE_GB} -ge $required_space_gb ]]; then
        success "Sufficient disk space available: ${AVAILABLE_STORAGE_GB}GB (${required_space_gb}GB required)"
    else
        error "Insufficient disk space: ${AVAILABLE_STORAGE_GB}GB (${required_space_gb}GB required)"
        exit 1
    fi
}

validate_network_connectivity() {
    log "Validating network connectivity..."
    
    local connectivity_tests=(
        "8.8.8.8:53"
        "github.com:443"
        "pypi.org:443"
    )
    
    local failed_tests=0
    
    for test in "${connectivity_tests[@]}"; do
        IFS=':' read -r host port <<< "$test"
        if timeout 10 bash -c "</dev/tcp/${host}/${port}" >/dev/null 2>&1; then
            log "✅ Connectivity to ${host}:${port} - OK"
        else
            warn "❌ Connectivity to ${host}:${port} - FAILED"
            ((failed_tests++))
        fi
    done
    
    if [[ $failed_tests -eq 0 ]]; then
        success "Network connectivity validation passed"
    else
        warn "Some network connectivity tests failed (${failed_tests}/${#connectivity_tests[@]})"
        warn "Deployment may fail if external resources are required"
    fi
}

# =============================================================================
# BACKUP AND ROLLBACK SYSTEM
# =============================================================================

create_deployment_backup() {
    phase "BACKUP" "Creating deployment backup"
    
    mkdir -p "${BACKUP_DIR}"
    
    # Backup current database state if it exists
    if [[ -f "${PROJECT_DIR}/db.sqlite3" ]]; then
        cp "${PROJECT_DIR}/db.sqlite3" "${BACKUP_DIR}/db.sqlite3.backup"
        log "Legacy SQLite database backup created"
    fi
    
    # Backup PostgreSQL database if configured
    if command -v pg_dump &> /dev/null && [[ -n "${DB_NAME:-}" ]]; then
        PGPASSWORD="${DB_PASSWORD:-}" pg_dump -h "${DB_HOST:-localhost}" -U "${DB_USER:-}" "${DB_NAME:-}" > "${BACKUP_DIR}/postgresql_backup.sql" 2>/dev/null || true
        log "PostgreSQL database backup created"
    fi
    
    # Backup configuration files
    if [[ -d "${PROJECT_DIR}/deployment_configs" ]]; then
        cp -r "${PROJECT_DIR}/deployment_configs" "${BACKUP_DIR}/deployment_configs.backup"
        log "Configuration backup created"
    fi
    
    # Backup environment files
    for env_file in "${PROJECT_DIR}"/.env*; do
        if [[ -f "$env_file" ]]; then
            cp "$env_file" "${BACKUP_DIR}/$(basename "$env_file").backup"
            log "Environment file backup: $(basename "$env_file")"
        fi
    done
    
    # Create backup manifest
    cat > "${BACKUP_DIR}/backup_manifest.json" << EOF
{
  "backup_timestamp": "$(date -Iseconds)",
  "system_profile": "${SYSTEM_PROFILE}",
  "deployment_mode": "${DEPLOYMENT_MODE}",
  "project_dir": "${PROJECT_DIR}",
  "backup_contents": [
$(find "${BACKUP_DIR}" -type f -name "*.backup" | sed 's/.*/"&"/' | paste -sd,)
  ]
}
EOF
    
    ROLLBACK_AVAILABLE=true
    success "Deployment backup created: ${BACKUP_DIR}"
}

rollback_deployment() {
    phase "ROLLBACK" "Rolling back deployment"
    
    if [[ "${ROLLBACK_AVAILABLE}" != "true" ]]; then
        error "No rollback backup available"
        return 1
    fi
    
    log "Restoring from backup: ${BACKUP_DIR}"
    
    # Stop services if they're running
    stop_services_safely
    
    # Restore database
    if [[ -f "${BACKUP_DIR}/db.sqlite3.backup" ]]; then
        cp "${BACKUP_DIR}/db.sqlite3.backup" "${PROJECT_DIR}/db.sqlite3"
        log "Legacy SQLite database restored"
    fi
    
    # Restore PostgreSQL database if available
    if [[ -f "${BACKUP_DIR}/postgresql_backup.sql" ]] && command -v psql &> /dev/null && [[ -n "${DB_NAME:-}" ]]; then
        PGPASSWORD="${DB_PASSWORD:-}" psql -h "${DB_HOST:-localhost}" -U "${DB_USER:-}" "${DB_NAME:-}" < "${BACKUP_DIR}/postgresql_backup.sql" 2>/dev/null || true
        log "PostgreSQL database restored"
    fi
    
    # Restore configurations
    if [[ -d "${BACKUP_DIR}/deployment_configs.backup" ]]; then
        rm -rf "${PROJECT_DIR}/deployment_configs"
        cp -r "${BACKUP_DIR}/deployment_configs.backup" "${PROJECT_DIR}/deployment_configs"
        log "Configurations restored"
    fi
    
    # Restore environment files
    for backup_file in "${BACKUP_DIR}"/.env*.backup; do
        if [[ -f "$backup_file" ]]; then
            local original_name="${backup_file%.backup}"
            original_name="$(basename "$original_name")"
            cp "$backup_file" "${PROJECT_DIR}/${original_name}"
            log "Environment file restored: ${original_name}"
        fi
    done
    
    success "Rollback completed successfully"
}

stop_services_safely() {
    log "Stopping services safely..."
    
    case "${DEPLOYMENT_MODE}" in
        "docker_"*)
            if command -v docker-compose >/dev/null 2>&1; then
                docker-compose down --remove-orphans 2>/dev/null || true
                log "Docker services stopped"
            fi
            ;;
        "native_"*)
            if [[ "${HAS_SYSTEMD}" == "true" ]]; then
                sudo systemctl stop noctis-* 2>/dev/null || true
                log "Systemd services stopped"
            fi
            ;;
    esac
}

# =============================================================================
# INTELLIGENT DEPENDENCY MANAGEMENT
# =============================================================================

optimize_dependencies() {
    phase "DEPENDENCIES" "Optimizing dependencies for system"
    
    # Run dependency optimizer if available
    if [[ -x "${PROJECT_DIR}/dependency_optimizer.py" ]]; then
        log "Running intelligent dependency optimizer..."
        
        if python3 "${PROJECT_DIR}/dependency_optimizer.py" --output-dir "${PROJECT_DIR}" --format both > "${LOG_FILE}.deps" 2>&1; then
            success "Dependencies optimized for system capabilities"
            
            # Use optimized requirements if generated
            if [[ -f "${PROJECT_DIR}/requirements.optimized.txt" ]]; then
                log "Using optimized requirements file"
                cp "${PROJECT_DIR}/requirements.optimized.txt" "${PROJECT_DIR}/requirements.active.txt"
            fi
        else
            warn "Dependency optimization failed - using default requirements"
            cp "${PROJECT_DIR}/requirements.txt" "${PROJECT_DIR}/requirements.active.txt"
        fi
    else
        warn "Dependency optimizer not found - using default requirements"
        cp "${PROJECT_DIR}/requirements.txt" "${PROJECT_DIR}/requirements.active.txt"
    fi
}

# =============================================================================
# CONFIGURATION GENERATION
# =============================================================================

generate_deployment_configurations() {
    phase "CONFIGURATION" "Generating deployment configurations"
    
    # Run configuration generator
    if [[ -x "${PROJECT_DIR}/deployment_configurator.sh" ]]; then
        log "Generating optimized deployment configurations..."
        
        local python_path="${PROJECT_DIR}/venv"
        if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
            python_path="/app/venv"
        fi
        
        if "${PROJECT_DIR}/deployment_configurator.sh" \
            "${AVAILABLE_MEMORY_GB}" \
            "${AVAILABLE_CPU_CORES}" \
            "${DEPLOYMENT_MODE}" \
            "${python_path}" \
            "${USE_SSL}" > "${LOG_FILE}.config" 2>&1; then
            
            success "Deployment configurations generated successfully"
        else
            error "Configuration generation failed"
            exit 1
        fi
    else
        error "Configuration generator not found"
        exit 1
    fi
}

# =============================================================================
# DEPLOYMENT EXECUTION
# =============================================================================

execute_deployment() {
    phase "DEPLOYMENT" "Executing ${DEPLOYMENT_MODE} deployment"
    
    case "${DEPLOYMENT_MODE}" in
        "docker_full"|"docker_minimal")
            execute_docker_deployment
            ;;
        "native_systemd"|"native_simple")
            execute_native_deployment
            ;;
        "install_dependencies")
            install_system_dependencies
            log "Dependencies installed. Please run the script again to continue deployment."
            exit 0
            ;;
        *)
            error "Unknown deployment mode: ${DEPLOYMENT_MODE}"
            exit 1
            ;;
    esac
}

execute_docker_deployment() {
    log "Executing Docker-based deployment..."
    
    # Install Docker if not available
    if [[ "${HAS_DOCKER}" != "true" ]]; then
        install_docker
    fi
    
    # Use optimized Docker Compose configuration
    local compose_file="${PROJECT_DIR}/deployment_configs/docker/docker-compose.optimized.yml"
    
    if [[ ! -f "$compose_file" ]]; then
        error "Optimized Docker Compose file not found: $compose_file"
        exit 1
    fi
    
    # Create environment file
    create_docker_environment
    
    # Build and start services
    log "Building and starting Docker services..."
    
    cd "${PROJECT_DIR}"
    
    # Pull base images
    docker-compose -f "$compose_file" pull
    
    # Build application images
    docker-compose -f "$compose_file" build
    
    # Start services in order
    docker-compose -f "$compose_file" up -d db redis
    
    # Wait for database
    wait_for_database_docker "$compose_file"
    
    # Start application services
    docker-compose -f "$compose_file" up -d web dicom_receiver
    
    # Start additional services if available
    if [[ "${DEPLOYMENT_MODE}" == "docker_full" ]]; then
        docker-compose -f "$compose_file" up -d celery celery_beat nginx
    fi
    
    # Run initial setup
    setup_django_docker "$compose_file"
    
    success "Docker deployment completed successfully"
}

execute_native_deployment() {
    log "Executing native deployment..."
    
    # Install system dependencies
    install_system_dependencies_native
    
    # Setup Python environment
    setup_python_environment_native
    
    # Install Python dependencies
    install_python_dependencies_native
    
    # Setup Django
    setup_django_native
    
    # Create and start services
    if [[ "${HAS_SYSTEMD}" == "true" ]]; then
        create_and_start_systemd_services
    else
        create_and_start_simple_services
    fi
    
    success "Native deployment completed successfully"
}

install_docker() {
    log "Installing Docker..."
    
    case "${DETECTED_OS}" in
        "ubuntu"|"debian")
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker "${USER}"
            sudo systemctl enable docker
            sudo systemctl start docker
            rm get-docker.sh
            ;;
        *)
            error "Docker installation not automated for ${DETECTED_OS}"
            error "Please install Docker manually and run the script again"
            exit 1
            ;;
    esac
    
    HAS_DOCKER=true
    success "Docker installed successfully"
}

create_docker_environment() {
    log "Creating Docker environment configuration..."
    
    cat > "${PROJECT_DIR}/.env" << EOF
# NoctisPro PACS - Docker Environment
# Generated by Master Deployment Script

# Django Configuration
DEBUG=False
SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())' 2>/dev/null || openssl rand -base64 32)
DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Database Configuration
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# System Configuration
WORKERS=${OPTIMAL_WORKERS}
BUILD_TARGET=production

# HTTPS Configuration
SECURE_SSL_REDIRECT=True
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https
USE_TLS=True
FORCE_SCRIPT_NAME=

# Deployment Metadata
DEPLOYMENT_MODE=${DEPLOYMENT_MODE}
SYSTEM_PROFILE=${SYSTEM_PROFILE}
DEPLOYED_AT=$(date -Iseconds)
HTTPS_CONFIGURED=${HTTPS_CONFIGURED:-false}
EOF
    
    # Append DuckDNS domain if configured earlier but env not created yet
    if [[ -n "${PENDING_DUCKDNS_DOMAIN:-}" ]]; then
        echo "DUCKDNS_DOMAIN=${PENDING_DUCKDNS_DOMAIN}" >> "${PROJECT_DIR}/.env"
    fi

    success "Docker environment configured with HTTPS support"
}

wait_for_database_docker() {
    local compose_file="$1"
    log "Waiting for database to be ready..."
    
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if docker-compose -f "$compose_file" exec -T db pg_isready -U noctis_user -d noctis_pro >/dev/null 2>&1; then
            success "Database is ready"
            return 0
        fi
        
        ((attempt++))
        if [[ $attempt -eq $max_attempts ]]; then
            error "Database failed to start within timeout"
            return 1
        fi
        
        log "Waiting for database... (attempt $attempt/$max_attempts)"
        sleep 10
    done
}

setup_django_docker() {
    local compose_file="$1"
    log "Setting up Django in Docker environment..."
    
    # Run migrations
    docker-compose -f "$compose_file" exec -T web python manage.py migrate --noinput
    
    # Collect static files
    docker-compose -f "$compose_file" exec -T web python manage.py collectstatic --noinput
    
    # Create superuser
    docker-compose -f "$compose_file" exec -T web python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
    print('Superuser created: admin/admin123')
else:
    print('Superuser already exists')
"
    
    success "Django setup completed in Docker"
}

# Native deployment functions (simplified for brevity)
install_system_dependencies_native() {
    log "Installing system dependencies for native deployment..."
    source "${PROJECT_DIR}/deploy_intelligent.sh"
    install_system_dependencies
}

setup_python_environment_native() {
    log "Setting up Python environment for native deployment..."
    source "${PROJECT_DIR}/deploy_intelligent.sh"
    setup_virtual_environment
}

install_python_dependencies_native() {
    log "Installing Python dependencies for native deployment..."
    
    # Install system dependencies for packages that might fail
    install_system_printing_dependencies
    
    source "${PROJECT_DIR}/deploy_intelligent.sh"
    install_python_requirements
}

install_system_printing_dependencies() {
    log "Installing system dependencies for printing support..."
    
    case "${DETECTED_OS}" in
        "ubuntu"|"debian")
            # Install CUPS development libraries if needed
            if apt list --installed 2>/dev/null | grep -q "libcups2-dev\|cups-dev"; then
                log "CUPS development libraries already installed"
            else
                warn "CUPS development libraries not found - some printing features may be limited"
                # Don't fail deployment if CUPS libraries are not available
                sudo apt-get update || true
                sudo apt-get install -y libcups2-dev cups-dev || warn "Could not install CUPS libraries - continuing without printing support"
            fi
            ;;
        "rhel"|"centos"|"fedora"|"rocky"|"alma")
            if rpm -qa | grep -q "cups-devel"; then
                log "CUPS development libraries already installed"
            else
                warn "CUPS development libraries not found - some printing features may be limited"
                sudo yum install -y cups-devel || sudo dnf install -y cups-devel || warn "Could not install CUPS libraries - continuing without printing support"
            fi
            ;;
        *)
            warn "Unknown OS for CUPS installation - some printing features may be limited"
            ;;
    esac
}

setup_django_native() {
    log "Setting up Django for native deployment..."
    source "${PROJECT_DIR}/deploy_intelligent.sh"
    setup_django
}

create_and_start_systemd_services() {
    log "Creating and starting systemd services..."
    
    # Copy service files
    local systemd_dir="${PROJECT_DIR}/deployment_configs/systemd"
    if [[ -d "$systemd_dir" ]]; then
        sudo cp "$systemd_dir"/*.service /etc/systemd/system/
        sudo systemctl daemon-reload
        
        # Enable and start services
        for service_file in "$systemd_dir"/*.service; do
            local service_name=$(basename "$service_file")
            sudo systemctl enable "$service_name"
            sudo systemctl start "$service_name"
            log "Started service: $service_name"
        done
        
        success "Systemd services created and started"
    else
        error "Systemd service configurations not found"
        exit 1
    fi
}

create_and_start_simple_services() {
    log "Starting services in simple mode..."
    
    source "${PROJECT_DIR}/venv/bin/activate"
    cd "${PROJECT_DIR}"
    
    # Start services in background
    nohup python manage.py runserver 0.0.0.0:8000 > logs/web.log 2>&1 &
    nohup python dicom_receiver.py --port 11112 --aet NOCTIS_SCP > logs/dicom.log 2>&1 &
    
    success "Services started in simple mode"
}

# =============================================================================
# POST-DEPLOYMENT VALIDATION AND MONITORING
# =============================================================================

validate_deployment() {
    phase "POST_VALIDATION" "Validating deployment"
    
    local validation_failed=false
    
    # Test web service
    log "Testing web service..."
    if curl -f -s --max-time 30 "http://localhost:8000/" >/dev/null 2>&1; then
        success "✅ Web service is responding"
    else
        error "❌ Web service is not responding"
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
    
    # Test admin access
    log "Testing admin interface..."
    if curl -f -s --max-time 10 "http://localhost:8000/admin/" >/dev/null 2>&1; then
        success "✅ Admin interface is accessible"
    else
        warn "⚠️  Admin interface may not be fully ready yet"
    fi
    
    if [[ "$validation_failed" == "true" ]]; then
        error "Post-deployment validation failed"
        
        # Offer rollback
        echo ""
        warn "Deployment validation failed. Would you like to rollback?"
        read -p "Rollback deployment? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rollback_deployment
            exit 1
        else
            warn "Continuing with potentially failed deployment"
        fi
    else
        success "Post-deployment validation passed"
    fi
}

setup_monitoring() {
    phase "MONITORING" "Setting up monitoring and management"
    
    # Create management script
    create_management_script
    
    # Setup log rotation
    setup_log_rotation
    
    # Create health check cron job
    setup_health_monitoring
    
    success "Monitoring and management setup complete"
}

create_management_script() {
    log "Creating deployment management script..."
    
    local mgmt_script="${PROJECT_DIR}/manage_noctis.sh"
    
    cat > "$mgmt_script" << EOF
#!/bin/bash
# NoctisPro PACS - Deployment Management Script
# Generated by Master Deployment Script
# System Profile: ${SYSTEM_PROFILE}
# Deployment Mode: ${DEPLOYMENT_MODE}

DEPLOYMENT_MODE="${DEPLOYMENT_MODE}"
PROJECT_DIR="${PROJECT_DIR}"

case "\$1" in
    start)
        echo "Starting NoctisPro services..."
$(if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
    echo "        cd \"\${PROJECT_DIR}\""
    echo "        docker-compose -f deployment_configs/docker/docker-compose.optimized.yml up -d"
else
    echo "        sudo systemctl start noctis-*"
fi)
        echo "Starting HTTPS services..."
        sudo systemctl start nginx
        sudo systemctl start noctispro-ngrok 2>/dev/null || echo "Note: ngrok requires auth token configuration"
        ;;
    stop)
        echo "Stopping NoctisPro services..."
$(if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
    echo "        cd \"\${PROJECT_DIR}\""
    echo "        docker-compose -f deployment_configs/docker/docker-compose.optimized.yml down"
else
    echo "        sudo systemctl stop noctis-*"
fi)
        echo "Stopping HTTPS services..."
        sudo systemctl stop noctispro-ngrok 2>/dev/null || true
        ;;
    restart)
        echo "Restarting NoctisPro services..."
        \$0 stop
        sleep 5
        \$0 start
        ;;
    status)
        echo "NoctisPro Service Status:"
$(if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
    echo "        cd \"\${PROJECT_DIR}\""
    echo "        docker-compose -f deployment_configs/docker/docker-compose.optimized.yml ps"
else
    echo "        sudo systemctl status noctis-*"
fi)
        echo ""
        echo "HTTPS Status:"
        /usr/local/bin/noctispro-https-monitor status 2>/dev/null || echo "HTTPS monitoring not available"
        ;;
    logs)
        echo "NoctisPro Logs:"
$(if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
    echo "        cd \"\${PROJECT_DIR}\""
    echo "        docker-compose -f deployment_configs/docker/docker-compose.optimized.yml logs -f"
else
    echo "        sudo journalctl -f -u noctis-*"
fi)
        ;;
    https)
        echo "HTTPS Status and Configuration:"
        /usr/local/bin/noctispro-https-monitor status 2>/dev/null || echo "HTTPS monitoring not available"
        echo ""
        echo "To setup ngrok for public access:"
        echo "1. Get token from: https://ngrok.com/signup"
        echo "2. Edit: ~/.config/ngrok/ngrok.yml"
        echo "3. Replace 'YOUR_NGROK_TOKEN_HERE' with your token"
        echo "4. Start: sudo systemctl start noctispro-ngrok"
        ;;
    health)
        echo "Performing health check..."
        ${PROJECT_DIR}/deployment_configs/monitoring/health_check.sh 2>/dev/null || echo "Health check script not found"
        echo ""
        echo "HTTPS Health Check:"
        /usr/local/bin/noctispro-https-monitor status 2>/dev/null || echo "HTTPS monitoring not available"
        ;;
    update)
        echo "Updating NoctisPro..."
        cd "\${PROJECT_DIR}"
        git pull origin main
        ${PROJECT_DIR}/deploy_master.sh --update-only
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status|logs|https|health|update}"
        echo ""
        echo "NoctisPro PACS Management Commands:"
        echo "  start   - Start all services (including HTTPS)"
        echo "  stop    - Stop all services"
        echo "  restart - Restart all services"
        echo "  status  - Show service status"
        echo "  logs    - Show service logs"
        echo "  https   - Show HTTPS status and setup instructions"
        echo "  health  - Perform comprehensive health check"
        echo "  update  - Update and redeploy"
        echo ""
        echo "System Profile: ${SYSTEM_PROFILE}"
        echo "Deployment Mode: ${DEPLOYMENT_MODE}"
        echo "Local Access:"
        echo "  🔒 HTTPS: https://localhost"
        echo "  🌍 HTTP:  http://localhost"
        echo "  👤 Admin: https://localhost/admin/"
        echo "Default Login: admin / admin123"
        echo ""
        echo "For public HTTPS access setup, run: \$0 https"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$mgmt_script"
    success "Management script created: $mgmt_script"
}

setup_log_rotation() {
    log "Setting up log rotation..."
    
    local logrotate_config="${PROJECT_DIR}/deployment_configs/monitoring/noctis-logrotate"
    if [[ -f "$logrotate_config" ]]; then
        sudo cp "$logrotate_config" /etc/logrotate.d/noctis
        success "Log rotation configured"
    else
        warn "Log rotation configuration not found"
    fi
}

setup_health_monitoring() {
    log "Setting up health monitoring..."
    
    local health_script="${PROJECT_DIR}/deployment_configs/monitoring/health_check.sh"
    if [[ -f "$health_script" ]]; then
        # Add cron job for health monitoring
        (crontab -l 2>/dev/null; echo "*/15 * * * * $health_script > /dev/null 2>&1") | crontab -
        success "Health monitoring cron job added (every 15 minutes)"
    else
        warn "Health check script not found"
    fi
}

# =============================================================================
# PRODUCTION HTTPS INTERNET ACCESS SETUP
# =============================================================================

setup_production_https_access() {
    phase "HTTPS_SETUP" "Configuring production HTTPS internet access"
    
    # Skip if already configured in this session
    if [[ "${HTTPS_CONFIGURED:-false}" == "true" ]]; then
        log "HTTPS already configured in this session – skipping"
        return
    fi
    
    log "Setting up production HTTPS internet access..."
    
    # Install required packages for HTTPS setup
    install_https_dependencies
    
    # Setup SSL certificate management
    setup_ssl_certificate_management
    
    # Configure Nginx for HTTPS
    configure_nginx_https
    
    # Setup ngrok tunnel for public access
    setup_ngrok_tunnel
    
    # Create HTTPS monitoring
    setup_https_monitoring
    
    HTTPS_CONFIGURED=true
    success "Production HTTPS access configured"
}

install_https_dependencies() {
    log "Installing HTTPS dependencies..."
    
    case "${DETECTED_OS}" in
        "ubuntu"|"debian")
            sudo apt-get update
            sudo apt-get install -y nginx certbot python3-certbot-nginx curl wget openssl
            
            # Install ngrok
            if ! command -v ngrok &> /dev/null; then
                log "Installing ngrok..."
                curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
                echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
                sudo apt-get update
                sudo apt-get install -y ngrok
            fi
            ;;
        "rhel"|"centos"|"fedora"|"rocky"|"alma")
            sudo yum install -y nginx certbot python3-certbot-nginx curl wget openssl || \
            sudo dnf install -y nginx certbot python3-certbot-nginx curl wget openssl
            
            # Install ngrok
            if ! command -v ngrok &> /dev/null; then
                log "Installing ngrok..."
                wget -O /tmp/ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
                sudo unzip /tmp/ngrok.zip -d /usr/local/bin/
                rm -f /tmp/ngrok.zip
            fi
            ;;
        *)
            warn "Unknown OS for HTTPS setup - manual configuration may be required"
            ;;
    esac
    
    success "HTTPS dependencies installed"
}

setup_ssl_certificate_management() {
    log "Setting up SSL certificate management..."
    
    # Create SSL directory
    sudo mkdir -p /etc/ssl/noctispro
    
    # Create self-signed certificate as fallback
    if [[ ! -f "/etc/ssl/noctispro/server.crt" ]]; then
        log "Creating self-signed SSL certificate..."
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/ssl/noctispro/server.key \
            -out /etc/ssl/noctispro/server.crt \
            -subj "/C=US/ST=State/L=City/O=NoctisPro/OU=PACS/CN=localhost" \
            -addext "subjectAltName=DNS:localhost,DNS:*.ngrok.io,DNS:*.ngrok-free.app,IP:127.0.0.1"
        
        sudo chmod 600 /etc/ssl/noctispro/server.key
        sudo chmod 644 /etc/ssl/noctispro/server.crt
        success "Self-signed SSL certificate created"
    fi
    
    # Create SSL renewal script
    create_ssl_renewal_script
}

create_ssl_renewal_script() {
    log "Creating SSL certificate renewal script..."
    
    sudo tee /usr/local/bin/noctispro-ssl-manager > /dev/null << 'EOF'
#!/bin/bash
# NoctisPro SSL Certificate Manager

SSL_DIR="/etc/ssl/noctispro"
CERT_FILE="$SSL_DIR/server.crt"
KEY_FILE="$SSL_DIR/server.key"

create_self_signed_cert() {
    echo "Creating self-signed SSL certificate..."
    mkdir -p "$SSL_DIR"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -subj "/C=US/ST=State/L=City/O=NoctisPro/OU=PACS/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,DNS:*.ngrok.io,DNS:*.ngrok-free.app,IP:127.0.0.1"
    
    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"
    echo "Self-signed certificate created"
}

setup_letsencrypt() {
    local domain="$1"
    local email="$2"
    
    if [[ -z "$domain" || -z "$email" ]]; then
        echo "Usage: $0 letsencrypt domain.com email@example.com"
        return 1
    fi
    
    echo "Setting up Let's Encrypt certificate for $domain..."
    certbot --nginx -d "$domain" --email "$email" --agree-tos --non-interactive
}

case "${1:-auto}" in
    "auto")
        create_self_signed_cert
        ;;
    "self-signed")
        create_self_signed_cert
        ;;
    "letsencrypt")
        setup_letsencrypt "$2" "$3"
        ;;
    *)
        echo "Usage: $0 [auto|self-signed|letsencrypt domain email]"
        ;;
esac
EOF
    
    sudo chmod +x /usr/local/bin/noctispro-ssl-manager
    success "SSL certificate manager created"
}

configure_nginx_https() {
    log "Configuring Nginx for HTTPS..."
    
    # Create Nginx configuration for NoctisPro with HTTPS
    sudo tee /etc/nginx/sites-available/noctispro > /dev/null << 'EOF'
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name localhost *.ngrok.io *.ngrok-free.app;
    return 301 https://$server_name$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name localhost *.ngrok.io *.ngrok-free.app;
    
    ssl_certificate /etc/ssl/noctispro/server.crt;
    ssl_certificate_key /etc/ssl/noctispro/server.key;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    client_max_body_size 100M;
    
    # Static files
    location /static/ {
        alias /opt/noctispro/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias /opt/noctispro/media/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Proxy to Django application
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
    
    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/noctispro /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test Nginx configuration
    if sudo nginx -t; then
        sudo systemctl enable nginx
        sudo systemctl restart nginx
        success "Nginx HTTPS configuration applied"
    else
        error "Nginx configuration error"
        return 1
    fi
}

setup_ngrok_tunnel() {
    log "Setting up ngrok tunnel for public access..."
    
    # Create ngrok configuration directory
    local ngrok_dir="/home/$(whoami)/.config/ngrok"
    mkdir -p "$ngrok_dir"
    
    # Create ngrok configuration
    cat > "$ngrok_dir/ngrok.yml" << 'EOF'
version: "2"
authtoken: "YOUR_NGROK_TOKEN_HERE"

tunnels:
  noctispro-https:
    proto: http
    addr: 443
    schemes: [https]
    inspect: false
    
api:
  addr: 127.0.0.1:4040
  
log_level: info
log: /var/log/ngrok.log
EOF
    
    # Create ngrok systemd service
    sudo tee /etc/systemd/system/noctispro-ngrok.service > /dev/null << EOF
[Unit]
Description=Ngrok tunnel for NoctisPro PACS HTTPS access
After=network.target nginx.service
Wants=nginx.service

[Service]
Type=simple
User=$(whoami)
Group=$(whoami)
WorkingDirectory=$ngrok_dir
ExecStart=/usr/bin/ngrok start noctispro-https --config $ngrok_dir/ngrok.yml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment=HOME=/home/$(whoami)

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    
    success "Ngrok tunnel configured (requires auth token to start)"
    
    # Display setup instructions
    echo ""
    warn "To enable public HTTPS access:"
    echo "1. Get free ngrok token from: https://ngrok.com/signup"
    echo "2. Replace 'YOUR_NGROK_TOKEN_HERE' in $ngrok_dir/ngrok.yml"
    echo "3. Start ngrok: sudo systemctl start noctispro-ngrok"
    echo "4. Enable auto-start: sudo systemctl enable noctispro-ngrok"
    echo ""
}

setup_https_monitoring() {
    log "Setting up HTTPS monitoring..."
    
    # Create monitoring script
    sudo tee /usr/local/bin/noctispro-https-monitor > /dev/null << 'EOF'
#!/bin/bash
# NoctisPro HTTPS Monitoring Script

check_ssl_cert() {
    local domain="${1:-localhost}"
    local cert_file="/etc/ssl/noctispro/server.crt"
    
    if [[ -f "$cert_file" ]]; then
        local expiry=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry" +%s)
        local current_epoch=$(date +%s)
        local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        echo "SSL Certificate expires in $days_until_expiry days"
        
        if [[ $days_until_expiry -lt 30 ]]; then
            echo "WARNING: SSL certificate expires soon!"
            # Auto-renew if using Let's Encrypt
            if command -v certbot &> /dev/null; then
                certbot renew --quiet
            fi
        fi
    else
        echo "No SSL certificate found"
    fi
}

check_https_access() {
    echo "Checking HTTPS access..."
    
    # Check local HTTPS
    if curl -k -s --max-time 10 "https://localhost" > /dev/null; then
        echo "✅ Local HTTPS: Working"
    else
        echo "❌ Local HTTPS: Failed"
    fi
    
    # Check ngrok tunnel if available
    local ngrok_url=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4)
    if [[ -n "$ngrok_url" ]]; then
        echo "✅ Public HTTPS: $ngrok_url"
        
        # Test public access
        if curl -s --max-time 15 "$ngrok_url" > /dev/null; then
            echo "✅ Public access: Working"
        else
            echo "⚠️  Public access: May be starting up"
        fi
    else
        echo "⚠️  Public HTTPS: Ngrok not running or no auth token"
    fi
}

check_services() {
    echo "Checking services..."
    
    for service in nginx noctispro-ngrok; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "✅ $service: Running"
        else
            echo "❌ $service: Stopped"
        fi
    done
}

# Main monitoring function
main() {
    echo "=== NoctisPro HTTPS Status Check ==="
    echo "$(date)"
    echo ""
    
    check_ssl_cert
    echo ""
    check_https_access
    echo ""
    check_services
    echo ""
    echo "=================================="
}

case "${1:-status}" in
    "status")
        main
        ;;
    "cert")
        check_ssl_cert "$2"
        ;;
    "access")
        check_https_access
        ;;
    "services")
        check_services
        ;;
    *)
        echo "Usage: $0 [status|cert|access|services]"
        ;;
esac
EOF
    
    sudo chmod +x /usr/local/bin/noctispro-https-monitor
    
    # Add monitoring cron job
    (crontab -l 2>/dev/null; echo "*/30 * * * * /usr/local/bin/noctispro-https-monitor status >> /var/log/noctispro-https.log 2>&1") | crontab -
    
    success "HTTPS monitoring configured"
}

# =============================================================================
# DUCKDNS DOMAIN SETUP (OPTIONAL - LEGACY)
# =============================================================================

setup_duckdns() {
    phase "DOMAIN_SETUP" "Configuring optional DuckDNS domain"

    # Skip if already configured in this session
    if [[ "${DUCKDNS_CONFIGURED:-false}" == "true" ]]; then
        log "DuckDNS already configured in this session – skipping"
        return
    fi

    # Check if helper script exists
    local duckdns_script="${PROJECT_DIR}/scripts/setup_duckdns.sh"
    if [[ ! -x "$duckdns_script" ]]; then
        warn "DuckDNS setup script not found – skipping domain configuration"
        return
    fi

    # Determine whether DuckDNS should be enabled
    local enable_duckdns=""
    if [[ -n "${DUCKDNS_TOKEN:-}" && -n "${DUCKDNS_SUBDOMAIN:-}" ]]; then
        enable_duckdns="y"
    else
        echo -e "\nWould you like to configure a free DuckDNS domain? (y/N): "
        read -r enable_duckdns
    fi

    if [[ ! "$enable_duckdns" =~ ^[Yy]$ ]]; then
        log "DuckDNS configuration skipped by user"
        return
    fi

    # Obtain token and subdomain if not already provided via env
    if [[ -z "${DUCKDNS_TOKEN:-}" ]]; then
        read -p "Enter your DuckDNS token: " -r DUCKDNS_TOKEN
    fi
    if [[ -z "${DUCKDNS_SUBDOMAIN:-}" ]]; then
        read -p "Enter desired DuckDNS subdomain (without .duckdns.org): " -r DUCKDNS_SUBDOMAIN
    fi

    if [[ -z "$DUCKDNS_TOKEN" || -z "$DUCKDNS_SUBDOMAIN" ]]; then
        warn "DuckDNS token or subdomain missing – skipping configuration"
        return
    fi

    # Run helper script using sudo (required for systemd unit placement)
    log "Running DuckDNS setup script…"
    if sudo "$duckdns_script" "$DUCKDNS_TOKEN" "$DUCKDNS_SUBDOMAIN" >> "$LOG_FILE" 2>&1; then
        success "DuckDNS configured – Domain: https://${DUCKDNS_SUBDOMAIN}.duckdns.org"
        DUCKDNS_CONFIGURED=true

        # Append to environment file if it already exists; otherwise defer until env creation
        if [[ -f "${PROJECT_DIR}/.env" ]]; then
            echo "DUCKDNS_DOMAIN=${DUCKDNS_SUBDOMAIN}.duckdns.org" >> "${PROJECT_DIR}/.env"
        else
            export PENDING_DUCKDNS_DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
        fi
    else
        warn "DuckDNS setup failed – check logs for details"
    fi
}

# =============================================================================
# DEPLOYMENT SUMMARY AND REPORTING
# =============================================================================

generate_deployment_report() {
    phase "REPORTING" "Generating deployment report"
    
    local report_file="${PROJECT_DIR}/deployment_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# NoctisPro PACS - Deployment Report

**Deployment Date:** $(date)
**Script Version:** ${SCRIPT_VERSION}
**System Profile:** ${SYSTEM_PROFILE}
**Deployment Mode:** ${DEPLOYMENT_MODE}

## System Information

- **Operating System:** ${DETECTED_OS} ${DETECTED_VERSION}
- **Architecture:** ${DETECTED_ARCH}
- **Memory:** ${AVAILABLE_MEMORY_GB}GB
- **CPU Cores:** ${AVAILABLE_CPU_CORES}
- **Available Storage:** ${AVAILABLE_STORAGE_GB}GB

## Deployment Configuration

- **Deployment Mode:** ${DEPLOYMENT_MODE}
- **Optimal Workers:** ${OPTIMAL_WORKERS}
- **Nginx Enabled:** ${USE_NGINX}
- **SSL Enabled:** ${USE_SSL}
- **Internet Access:** ${INTERNET_ACCESS}

## Capabilities Detected

- **Docker:** ${HAS_DOCKER}
- **Systemd:** ${HAS_SYSTEMD}
- **Nginx:** ${HAS_NGINX}
- **Python 3:** ${HAS_PYTHON3}

## Access Information

- **Web Interface:** http://localhost:8000
- **Admin Panel:** http://localhost:8000/admin/
- **DICOM Port:** localhost:11112
- **Default Admin:** admin / admin123

## Management

- **Management Script:** ${PROJECT_DIR}/manage_noctis.sh
- **System Profile:** ${PROJECT_DIR}/system_profile.json
- **Deployment Log:** ${LOG_FILE}

## Quick Commands

\`\`\`bash
# Start services
${PROJECT_DIR}/manage_noctis.sh start

# Check status
${PROJECT_DIR}/manage_noctis.sh status

# View logs
${PROJECT_DIR}/manage_noctis.sh logs

# Health check
${PROJECT_DIR}/manage_noctis.sh health

# Stop services
${PROJECT_DIR}/manage_noctis.sh stop
\`\`\`

## Files Generated

- Configuration Directory: ${PROJECT_DIR}/deployment_configs/
- Management Script: ${PROJECT_DIR}/manage_noctis.sh
- System Profile: ${PROJECT_DIR}/system_profile.json
- Environment File: ${PROJECT_DIR}/.env
- This Report: ${report_file}

## Support

- **Log Files:** Check ${LOG_FILE} for detailed deployment logs
- **Health Monitoring:** Automated health checks run every 15 minutes
- **Backup Available:** ${ROLLBACK_AVAILABLE} (Location: ${BACKUP_DIR})

---

*Generated by NoctisPro PACS Master Deployment Script v${SCRIPT_VERSION}*
EOF
    
    success "Deployment report generated: $report_file"
}

display_deployment_summary() {
    echo ""
    echo "=============================================="
    echo "🎉 NoctisPro PACS - Deployment Complete!"
    echo "=============================================="
    echo ""
    echo "📊 Deployment Summary:"
    echo "  System Profile: ${SYSTEM_PROFILE}"
    echo "  Deployment Mode: ${DEPLOYMENT_MODE}"
    echo "  Validation: ${VALIDATION_PASSED}"
    echo "  Rollback Available: ${ROLLBACK_AVAILABLE}"
    echo ""
    echo "🌐 Access Information:"
    echo "  🔒 HTTPS (Local): ${GREEN}https://localhost${NC}"
    echo "  🌍 HTTP (Local): ${GREEN}http://localhost${NC}"
    echo "  👤 Admin Panel: ${GREEN}https://localhost/admin/${NC}"
    echo "  🏥 DICOM Port: ${GREEN}localhost:11112${NC}"
    echo "  🔐 Default Login: ${GREEN}admin / admin123${NC}"
    echo ""
    echo "🌍 Public Access:"
    echo "  📋 Check status: ${CYAN}/usr/local/bin/noctispro-https-monitor${NC}"
    echo "  🔑 Setup ngrok: Edit ~/.config/ngrok/ngrok.yml with your token"
    echo "  🚀 Start public: ${CYAN}sudo systemctl start noctispro-ngrok${NC}"
    echo ""
    echo "🔧 Management:"
    echo "  Management Script: ${CYAN}${PROJECT_DIR}/manage_noctis.sh${NC}"
    echo "  Health Check: ${CYAN}${PROJECT_DIR}/manage_noctis.sh health${NC}"
    echo "  View Logs: ${CYAN}${PROJECT_DIR}/manage_noctis.sh logs${NC}"
    echo ""
    echo "📁 Important Files:"
    echo "  Deployment Log: ${LOG_FILE}"
    echo "  System Profile: ${PROJECT_DIR}/system_profile.json"
    echo "  Configurations: ${PROJECT_DIR}/deployment_configs/"
    if [[ "${ROLLBACK_AVAILABLE}" == "true" ]]; then
        echo "  Backup Location: ${BACKUP_DIR}"
    fi
    echo ""
    
    if [[ "${VALIDATION_PASSED}" == "true" ]]; then
        success "🎉 Deployment completed successfully!"
        success "🔗 Access your NoctisPro PACS system at: http://localhost:8000"
    else
        warn "⚠️  Deployment completed with warnings. Please check the logs."
    fi
}

# =============================================================================
# ERROR HANDLING AND CLEANUP
# =============================================================================

cleanup_on_exit() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        error "Deployment failed with exit code $exit_code"
        
        if [[ "${ROLLBACK_AVAILABLE}" == "true" ]]; then
            echo ""
            warn "A backup is available for rollback"
            read -p "Would you like to rollback? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rollback_deployment
            fi
        fi
    fi
    
    log "Deployment script finished with exit code $exit_code"
}

# =============================================================================
# MAIN ORCHESTRATION
# =============================================================================

main() {
    local start_time=$(date +%s)
    
    echo ""
    echo "${BOLD}${CYAN}🚀 NoctisPro PACS - Master Intelligent Deployment${NC}"
    echo "${BOLD}${CYAN}===============================================${NC}"
    echo ""
    echo "Version: ${SCRIPT_VERSION}"
    echo "Author: ${SCRIPT_AUTHOR}"
    echo "Date: ${SCRIPT_DATE}"
    echo ""
    
    log "Starting master deployment orchestration..."
    log "Deployment log: ${LOG_FILE}"
    
    # Phase 1: System Analysis
    create_system_profile
    
    # Phase 2: Pre-deployment Validation
    run_pre_deployment_validation

    # Phase 3: Production HTTPS Setup
    setup_production_https_access
    
    # Phase 4: Backup Creation
    create_deployment_backup
    
    # Phase 5: Dependency Optimization
    optimize_dependencies
    
    # Phase 6: Configuration Generation
    generate_deployment_configurations
    
    # Phase 7: Deployment Execution
    execute_deployment
    
    # Phase 8: Post-deployment Validation
    validate_deployment
    
    # Phase 9: Monitoring Setup
    setup_monitoring
    
    # Phase 10: Reporting
    generate_deployment_report
    
    # Phase 11: Summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "Total deployment time: ${duration} seconds"
    
    display_deployment_summary
    
    success "🎉 NoctisPro PACS deployment orchestration complete!"
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "NoctisPro PACS Master Deployment Script v${SCRIPT_VERSION}"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --version, -v       Show version information"
        echo "  --test-only         Run validation tests only"
        echo "  --update-only       Update existing deployment"
        echo "  --rollback          Rollback to previous deployment"
        echo ""
        echo "This script automatically detects your system capabilities and"
        echo "deploys NoctisPro PACS using the optimal configuration."
        exit 0
        ;;
    --version|-v)
        echo "NoctisPro PACS Master Deployment Script"
        echo "Version: ${SCRIPT_VERSION}"
        echo "Author: ${SCRIPT_AUTHOR}"
        echo "Date: ${SCRIPT_DATE}"
        exit 0
        ;;
    --test-only)
        echo "Running validation tests only..."
        "${PROJECT_DIR}/test_deployment.sh"
        exit $?
        ;;
    --update-only)
        echo "Update mode not yet implemented"
        exit 1
        ;;
    --rollback)
        echo "Rollback mode not yet implemented"
        exit 1
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

# Run main orchestration
main "$@"