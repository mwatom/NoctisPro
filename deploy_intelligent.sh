#!/bin/bash

# =============================================================================
# NoctisPro PACS - Intelligent Auto-Detection Deployment Script
# =============================================================================
# This script automatically detects server capabilities and deploys the system
# optimally based on available resources and system configuration
# =============================================================================

set -euo pipefail

# Colors for output (only declare if not already set)
if [[ -z "${RED:-}" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly PURPLE='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m' # No Color
fi

# Global variables for system detection
declare -g DETECTED_OS=""
declare -g DETECTED_VERSION=""
declare -g DETECTED_ARCH=""
declare -g AVAILABLE_MEMORY_GB=0
declare -g AVAILABLE_CPU_CORES=0
declare -g AVAILABLE_STORAGE_GB=0
declare -g HAS_DOCKER=false
declare -g HAS_SYSTEMD=false
declare -g HAS_NGINX=false
declare -g HAS_PYTHON3=false
declare -g PYTHON3_VERSION=""
declare -g DEPLOYMENT_MODE=""
declare -g OPTIMAL_WORKERS=1
declare -g USE_NGINX=false
declare -g USE_SSL=false
declare -g INTERNET_ACCESS=false

# Configuration
# Only declare PROJECT_DIR if not already set (to avoid readonly conflicts)
if [[ -z "${PROJECT_DIR:-}" ]]; then
    if [[ -d "/workspace" ]]; then
        readonly PROJECT_DIR="/workspace"
    else
        readonly PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
fi
# Only declare SCRIPT_DIR if not already set (to avoid readonly conflicts)
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# Only declare LOG_FILE if not already set (to avoid readonly conflicts)
if [[ -z "${LOG_FILE:-}" ]]; then
    readonly LOG_FILE="/tmp/noctis_deploy_$(date +%Y%m%d_%H%M%S).log"
fi

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
# SYSTEM DETECTION FUNCTIONS
# =============================================================================

detect_operating_system() {
    log "Detecting operating system..."
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DETECTED_OS="${ID}"
        DETECTED_VERSION="${VERSION_ID}"
        
        case "${DETECTED_OS}" in
            ubuntu)
                info "Detected Ubuntu ${DETECTED_VERSION}"
                ;;
            debian)
                info "Detected Debian ${DETECTED_VERSION}"
                ;;
            centos|rhel|rocky|almalinux)
                info "Detected RHEL-based system: ${DETECTED_OS} ${DETECTED_VERSION}"
                ;;
            fedora)
                info "Detected Fedora ${DETECTED_VERSION}"
                ;;
            *)
                warn "Detected unsupported OS: ${DETECTED_OS} ${DETECTED_VERSION}"
                warn "Will attempt generic Linux deployment"
                ;;
        esac
    elif [[ -f /etc/redhat-release ]]; then
        DETECTED_OS="rhel"
        DETECTED_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
        info "Detected RHEL-based system from /etc/redhat-release"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        DETECTED_OS="macos"
        DETECTED_VERSION=$(sw_vers -productVersion)
        info "Detected macOS ${DETECTED_VERSION}"
    else
        error "Unable to detect operating system"
        return 1
    fi
    
    # Detect architecture
    DETECTED_ARCH=$(uname -m)
    info "Detected architecture: ${DETECTED_ARCH}"
    
    # Validate supported architecture
    case "${DETECTED_ARCH}" in
        x86_64|amd64)
            info "Architecture ${DETECTED_ARCH} is fully supported"
            ;;
        aarch64|arm64)
            info "Architecture ${DETECTED_ARCH} is supported with some limitations"
            ;;
        *)
            warn "Architecture ${DETECTED_ARCH} may have limited support"
            ;;
    esac
}

detect_system_resources() {
    log "Detecting system resources..."
    
    # Detect available memory in GB
    if command -v free >/dev/null 2>&1; then
        local memory_kb=$(free | grep '^Mem:' | awk '{print $2}')
        AVAILABLE_MEMORY_GB=$((memory_kb / 1024 / 1024))
    elif [[ -r /proc/meminfo ]]; then
        local memory_kb=$(grep '^MemTotal:' /proc/meminfo | awk '{print $2}')
        AVAILABLE_MEMORY_GB=$((memory_kb / 1024 / 1024))
    else
        warn "Unable to detect memory, assuming 2GB"
        AVAILABLE_MEMORY_GB=2
    fi
    
    # Detect CPU cores
    if command -v nproc >/dev/null 2>&1; then
        AVAILABLE_CPU_CORES=$(nproc)
    elif [[ -r /proc/cpuinfo ]]; then
        AVAILABLE_CPU_CORES=$(grep -c '^processor' /proc/cpuinfo)
    else
        warn "Unable to detect CPU cores, assuming 1"
        AVAILABLE_CPU_CORES=1
    fi
    
    # Detect available storage in GB (robust fallback if path is unavailable)
    local storage_kb=""
    storage_kb=$(df -P "${PROJECT_DIR}" 2>/dev/null | tail -1 | awk '{print $4}') || true
    if [[ -z "${storage_kb}" ]]; then
        storage_kb=$(df -P . | tail -1 | awk '{print $4}')
    fi
    if [[ -z "${storage_kb}" ]]; then
        storage_kb=$(df -P / | tail -1 | awk '{print $4}')
    fi
    storage_kb=${storage_kb:-0}
    AVAILABLE_STORAGE_GB=$((storage_kb / 1024 / 1024))
    
    info "System Resources:"
    info "  Memory: ${AVAILABLE_MEMORY_GB}GB"
    info "  CPU Cores: ${AVAILABLE_CPU_CORES}"
    info "  Available Storage: ${AVAILABLE_STORAGE_GB}GB"
    
    # Calculate optimal worker processes
    if [[ ${AVAILABLE_MEMORY_GB} -ge 8 ]] && [[ ${AVAILABLE_CPU_CORES} -ge 4 ]]; then
        OPTIMAL_WORKERS=$((AVAILABLE_CPU_CORES * 2))
    elif [[ ${AVAILABLE_MEMORY_GB} -ge 4 ]] && [[ ${AVAILABLE_CPU_CORES} -ge 2 ]]; then
        OPTIMAL_WORKERS=${AVAILABLE_CPU_CORES}
    else
        OPTIMAL_WORKERS=1
    fi
    
    # Cap workers at 8 for stability
    if [[ ${OPTIMAL_WORKERS} -gt 8 ]]; then
        OPTIMAL_WORKERS=8
    fi
    
    info "Optimal worker processes: ${OPTIMAL_WORKERS}"
}

detect_installed_software() {
    log "Detecting installed software and capabilities..."
    
    # Check for Docker
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        HAS_DOCKER=true
        local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        info "Docker detected: ${docker_version}"
    else
        # Check if Docker is installed but daemon not running
        if command -v docker >/dev/null 2>&1; then
            warn "Docker installed but daemon not running (container environment)"
        else
            info "Docker not available"
        fi
        HAS_DOCKER=false
    fi
    
    # Check for systemd
    if command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1; then
        # Check if systemd is actually running as init system
        if [[ -d /run/systemd/system ]]; then
            HAS_SYSTEMD=true
            info "Systemd detected and running"
        else
            HAS_SYSTEMD=false
            warn "Systemd installed but not running as init system (container environment)"
        fi
    else
        HAS_SYSTEMD=false
        info "Systemd not available"
    fi
    
    # Check for nginx
    if command -v nginx >/dev/null 2>&1; then
        HAS_NGINX=true
        local nginx_version=$(nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        info "Nginx detected: ${nginx_version}"
    else
        info "Nginx not available"
    fi
    
    # Check for Python 3
    local python_candidates=("python3.12" "python3.11" "python3.10" "python3.9" "python3.8" "python3")
    for python_cmd in "${python_candidates[@]}"; do
        if command -v "${python_cmd}" >/dev/null 2>&1; then
            HAS_PYTHON3=true
            PYTHON3_VERSION=$("${python_cmd}" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
            info "Python 3 detected: ${python_cmd} (${PYTHON3_VERSION})"
            break
        fi
    done
    
    if [[ "${HAS_PYTHON3}" == false ]]; then
        warn "Python 3 not detected, will need to install"
    fi
    
    # Check internet connectivity
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        INTERNET_ACCESS=true
        info "Internet access confirmed"
    else
        warn "No internet access detected"
    fi
}

determine_deployment_mode() {
    log "Determining optimal deployment mode..."
    
    # Decision matrix for deployment mode
    if [[ "${HAS_DOCKER}" == true ]] && [[ ${AVAILABLE_MEMORY_GB} -ge 4 ]]; then
        if [[ ${AVAILABLE_MEMORY_GB} -ge 8 ]] && [[ ${AVAILABLE_CPU_CORES} -ge 4 ]]; then
            DEPLOYMENT_MODE="docker_full"
            USE_NGINX=true
            info "Selected deployment mode: Docker with full services"
        else
            DEPLOYMENT_MODE="docker_minimal"
            info "Selected deployment mode: Docker with minimal services"
        fi
    elif [[ "${HAS_PYTHON3}" == true ]] && [[ ${AVAILABLE_MEMORY_GB} -ge 2 ]]; then
        if [[ "${HAS_SYSTEMD}" == true ]]; then
            DEPLOYMENT_MODE="native_systemd"
            info "Selected deployment mode: Native with systemd services"
        else
            DEPLOYMENT_MODE="native_simple"
            info "Selected deployment mode: Native simple deployment"
        fi
    else
        DEPLOYMENT_MODE="install_dependencies"
        info "Selected deployment mode: Install dependencies first"
    fi
    
    # Determine if SSL should be used
    if [[ "${INTERNET_ACCESS}" == true ]] && [[ "${HAS_NGINX}" == true || "${DEPLOYMENT_MODE}" == "docker_full" ]]; then
        USE_SSL=true
        info "SSL/TLS will be configured"
    fi
    
    info "Deployment configuration:"
    info "  Mode: ${DEPLOYMENT_MODE}"
    info "  Workers: ${OPTIMAL_WORKERS}"
    info "  Nginx: ${USE_NGINX}"
    info "  SSL: ${USE_SSL}"
}

# =============================================================================
# SYSTEM PREPARATION FUNCTIONS
# =============================================================================

install_system_dependencies() {
    log "Installing system dependencies based on detected OS..."
    
    case "${DETECTED_OS}" in
        ubuntu|debian)
            install_debian_dependencies
            ;;
        centos|rhel|rocky|almalinux)
            install_rhel_dependencies
            ;;
        fedora)
            install_fedora_dependencies
            ;;
        *)
            warn "Using generic dependency installation"
            install_generic_dependencies
            ;;
    esac
}

install_debian_dependencies() {
    log "Installing dependencies for Debian-based system..."
    
    # Update package list
    sudo apt update
    
    local packages=(
        "curl" "wget" "git" "unzip" "build-essential" "pkg-config"
        "libssl-dev" "libffi-dev" "libjpeg-dev" "libpng-dev" "libtiff-dev"
        "libwebp-dev" "zlib1g-dev" "sqlite3" "libsqlite3-dev"
    )
    
    # Add Python if not detected
    if [[ "${HAS_PYTHON3}" == false ]]; then
        if [[ "${DETECTED_VERSION}" == "24.04" ]] || [[ "${DETECTED_VERSION}" == "22.04" ]]; then
            packages+=("python3.12" "python3.12-venv" "python3.12-dev" "python3-pip")
        else
            packages+=("python3" "python3-venv" "python3-dev" "python3-pip")
        fi
    else
        # Even if Python is detected, we might need the venv package
        # Check Python version and add appropriate venv package
        local python_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+')
        case "${python_version}" in
            "3.13")
                packages+=("python3.13-venv")
                ;;
            "3.12")
                packages+=("python3.12-venv")
                ;;
            "3.11")
                packages+=("python3.11-venv")
                ;;
            "3.10")
                packages+=("python3.10-venv")
                ;;
            *)
                packages+=("python3-venv")
                ;;
        esac
    fi
    
    # Add Docker if not detected and system has enough resources
    if [[ "${HAS_DOCKER}" == false ]] && [[ ${AVAILABLE_MEMORY_GB} -ge 2 ]]; then
        packages+=("docker.io" "docker-compose")
    fi
    
    # Add nginx if deployment mode requires it
    if [[ "${USE_NGINX}" == true ]] && [[ "${HAS_NGINX}" == false ]]; then
        packages+=("nginx")
    fi
    
    # Add systemd if not available (rare case)
    if [[ "${HAS_SYSTEMD}" == false ]]; then
        packages+=("systemd")
    fi
    
    # Install packages
    sudo apt install -y "${packages[@]}"
    
    # Configure Docker if just installed
    if [[ "${HAS_DOCKER}" == false ]] && [[ ${AVAILABLE_MEMORY_GB} -ge 2 ]]; then
        sudo usermod -aG docker "${USER}"
        # Only try to start Docker service if systemd is running
        if [[ -d /run/systemd/system ]]; then
            sudo systemctl enable docker
            sudo systemctl start docker
            # Re-check if Docker is now working
            if docker info >/dev/null 2>&1; then
                HAS_DOCKER=true
                info "Docker service started successfully"
            else
                warn "Docker installed but service failed to start"
            fi
        else
            warn "Docker installed but cannot start service (no systemd init)"
            warn "Docker daemon needs to be started manually or by container runtime"
        fi
        warn "You may need to log out and back in for group changes to take effect."
    fi
}

install_rhel_dependencies() {
    log "Installing dependencies for RHEL-based system..."
    
    # Update package list
    sudo yum update -y || sudo dnf update -y
    
    local packages=(
        "curl" "wget" "git" "unzip" "gcc" "gcc-c++" "make" "pkgconfig"
        "openssl-devel" "libffi-devel" "libjpeg-turbo-devel" "libpng-devel"
        "libtiff-devel" "libwebp-devel" "zlib-devel" "sqlite-devel"
    )
    
    # Add Python if not detected
    if [[ "${HAS_PYTHON3}" == false ]]; then
        packages+=("python3" "python3-devel" "python3-pip" "python3-venv")
    fi
    
    # Install packages using available package manager
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y "${packages[@]}"
        if [[ "${HAS_DOCKER}" == false ]] && [[ ${AVAILABLE_MEMORY_GB} -ge 2 ]]; then
            sudo dnf install -y docker docker-compose
        fi
    else
        sudo yum install -y "${packages[@]}"
        if [[ "${HAS_DOCKER}" == false ]] && [[ ${AVAILABLE_MEMORY_GB} -ge 2 ]]; then
            sudo yum install -y docker docker-compose
        fi
    fi
    
    # Configure Docker if just installed
    if [[ "${HAS_DOCKER}" == false ]] && [[ ${AVAILABLE_MEMORY_GB} -ge 2 ]]; then
        sudo usermod -aG docker "${USER}"
        # Only try to start Docker service if systemd is running
        if [[ -d /run/systemd/system ]]; then
            sudo systemctl enable docker
            sudo systemctl start docker
            # Re-check if Docker is now working
            if docker info >/dev/null 2>&1; then
                HAS_DOCKER=true
                info "Docker service started successfully"
            else
                warn "Docker installed but service failed to start"
            fi
        else
            warn "Docker installed but cannot start service (no systemd init)"
        fi
    fi
}

install_fedora_dependencies() {
    log "Installing dependencies for Fedora..."
    
    sudo dnf update -y
    
    local packages=(
        "curl" "wget" "git" "unzip" "gcc" "gcc-c++" "make" "pkgconf-pkg-config"
        "openssl-devel" "libffi-devel" "libjpeg-turbo-devel" "libpng-devel"
        "libtiff-devel" "libwebp-devel" "zlib-devel" "sqlite-devel"
        "python3" "python3-devel" "python3-pip" "python3-virtualenv"
    )
    
    if [[ "${HAS_DOCKER}" == false ]] && [[ ${AVAILABLE_MEMORY_GB} -ge 2 ]]; then
        packages+=("docker" "docker-compose")
    fi
    
    sudo dnf install -y "${packages[@]}"
    
    # Configure Docker if just installed
    if [[ "${HAS_DOCKER}" == false ]] && [[ ${AVAILABLE_MEMORY_GB} -ge 2 ]]; then
        sudo usermod -aG docker "${USER}"
        # Only try to start Docker service if systemd is running
        if [[ -d /run/systemd/system ]]; then
            sudo systemctl enable docker
            sudo systemctl start docker
            # Re-check if Docker is now working
            if docker info >/dev/null 2>&1; then
                HAS_DOCKER=true
                info "Docker service started successfully"
            else
                warn "Docker installed but service failed to start"
            fi
        else
            warn "Docker installed but cannot start service (no systemd init)"
        fi
    fi
}

install_generic_dependencies() {
    warn "Using generic dependency installation - some features may not work"
    
    # Try to install basic dependencies using available package managers
    local package_managers=("apt" "yum" "dnf" "pacman" "zypper")
    local found_pm=false
    
    for pm in "${package_managers[@]}"; do
        if command -v "${pm}" >/dev/null 2>&1; then
            found_pm=true
            case "${pm}" in
                apt)
                    install_debian_dependencies
                    ;;
                yum|dnf)
                    install_rhel_dependencies
                    ;;
                *)
                    warn "Package manager ${pm} detected but not fully supported"
                    ;;
            esac
            break
        fi
    done
    
    if [[ "${found_pm}" == false ]]; then
        error "No supported package manager found"
        error "Please install dependencies manually:"
        error "- Python 3.8+ with pip and venv"
        error "- Build tools (gcc, make, pkg-config)"
        error "- Development libraries (ssl, ffi, jpeg, png, etc.)"
        return 1
    fi
}

# =============================================================================
# DEPLOYMENT EXECUTION FUNCTIONS
# =============================================================================

execute_docker_deployment() {
    log "Executing Docker-based deployment..."
    
    cd "${PROJECT_DIR}"
    
    # Create optimized docker-compose configuration
    create_optimized_docker_compose
    
    # Create environment file
    create_environment_file
    
    # Build and start services
    if [[ "${DEPLOYMENT_MODE}" == "docker_full" ]]; then
        docker-compose -f docker-compose.optimized.yml up -d --build
    else
        # Start minimal services for resource-constrained systems
        docker-compose -f docker-compose.optimized.yml up -d --build db redis web
    fi
    
    # Wait for services to be ready
    wait_for_services_docker
    
    # Run initial setup
    setup_django_docker
}

execute_native_deployment() {
    log "Executing native deployment..."
    
    cd "${PROJECT_DIR}"
    
    # Setup Python virtual environment
    setup_python_environment
    
    # Install Python dependencies
    install_python_dependencies
    
    # Setup Django
    setup_django_native
    
    # Create services based on capabilities
    if [[ "${HAS_SYSTEMD}" == true ]]; then
        create_systemd_services
    else
        create_simple_services
    fi
    
    # Start services
    start_native_services
}

create_optimized_docker_compose() {
    log "Creating optimized Docker Compose configuration..."
    
    local compose_file="docker-compose.optimized.yml"
    
    cat > "${compose_file}" << EOF
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: noctis_db_optimized
    environment:
      POSTGRES_DB: noctis_pro
      POSTGRES_USER: noctis_user
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:-noctis_secure_password}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: ${AVAILABLE_MEMORY_GB}G
        reservations:
          memory: 512M

  redis:
    image: redis:7-alpine
    container_name: noctis_redis_optimized
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    restart: unless-stopped

  web:
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    container_name: noctis_web_optimized
    environment:
      - DEBUG=False
      - SECRET_KEY=\${SECRET_KEY}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - POSTGRES_DB=noctis_pro
      - POSTGRES_USER=noctis_user
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD:-noctis_secure_password}
      - POSTGRES_HOST=db
      - REDIS_URL=redis://redis:6379/0
    volumes:
      - .:/app
      - media_files:/app/media
      - static_files:/app/staticfiles
    ports:
      - "8000:8000"
    depends_on:
      - db
      - redis
    restart: unless-stopped
    command: >
      sh -c "python manage.py migrate --noinput &&
             python manage.py collectstatic --noinput &&
             gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:8000 --workers ${OPTIMAL_WORKERS} --timeout 120"
    deploy:
      resources:
        limits:
          memory: $((AVAILABLE_MEMORY_GB * 60 / 100))G
        reservations:
          memory: 512M

  dicom_receiver:
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    container_name: noctis_dicom_optimized
    environment:
      - DEBUG=False
      - SECRET_KEY=\${SECRET_KEY}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - POSTGRES_HOST=db
      - REDIS_URL=redis://redis:6379/0
    volumes:
      - .:/app
      - media_files:/app/media
    ports:
      - "11112:11112"
    depends_on:
      - db
      - redis
    restart: unless-stopped
    command: python dicom_receiver.py --port 11112 --aet NOCTIS_SCP
EOF

    if [[ "${DEPLOYMENT_MODE}" == "docker_full" ]]; then
        cat >> "${compose_file}" << EOF

  celery:
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    container_name: noctis_celery_optimized
    environment:
      - DEBUG=False
      - SECRET_KEY=\${SECRET_KEY}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - POSTGRES_HOST=db
      - REDIS_URL=redis://redis:6379/0
    volumes:
      - .:/app
      - media_files:/app/media
    depends_on:
      - db
      - redis
    restart: unless-stopped
    command: celery -A noctis_pro worker --loglevel=info --concurrency=${OPTIMAL_WORKERS}
EOF
    fi

    if [[ "${USE_NGINX}" == true ]]; then
        cat >> "${compose_file}" << EOF

  nginx:
    image: nginx:alpine
    container_name: noctis_nginx_optimized
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./deployment/nginx/nginx.optimized.conf:/etc/nginx/nginx.conf:ro
      - static_files:/var/www/static:ro
      - media_files:/var/www/media:ro
    depends_on:
      - web
    restart: unless-stopped
EOF
    fi

    cat >> "${compose_file}" << EOF

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  media_files:
    driver: local
  static_files:
    driver: local
EOF

    success "Optimized Docker Compose configuration created"
}

create_environment_file() {
    log "Creating environment configuration..."
    
    local env_file=".env.optimized"
    
    cat > "${env_file}" << EOF
# Django Configuration
DEBUG=False
SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Database Configuration
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# System Optimization
WORKERS=${OPTIMAL_WORKERS}
MEMORY_LIMIT=${AVAILABLE_MEMORY_GB}G
CPU_CORES=${AVAILABLE_CPU_CORES}

# Deployment Information
DEPLOYMENT_MODE=${DEPLOYMENT_MODE}
DETECTED_OS=${DETECTED_OS}
DETECTED_VERSION=${DETECTED_VERSION}
DETECTED_ARCH=${DETECTED_ARCH}
EOF

    success "Environment file created: ${env_file}"
}

setup_python_environment() {
    log "Setting up Python virtual environment..."
    
    local python_cmd="python3"
    if command -v python3.12 >/dev/null 2>&1; then
        python_cmd="python3.12"
    elif command -v python3.11 >/dev/null 2>&1; then
        python_cmd="python3.11"
    fi
    
    local venv_dir="${PROJECT_DIR}/venv_optimized"
    
    # Remove existing venv if it exists
    if [[ -d "${venv_dir}" ]]; then
        rm -rf "${venv_dir}"
    fi
    
    # Create virtual environment
    "${python_cmd}" -m venv "${venv_dir}"
    source "${venv_dir}/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip setuptools wheel
    
    success "Python virtual environment created"
}

install_python_dependencies() {
    log "Installing Python dependencies with optimizations..."
    
    source "${PROJECT_DIR}/venv_optimized/bin/activate"
    
    # Create optimized requirements based on system capabilities
    create_optimized_requirements
    
    # Install with appropriate flags for system
    local pip_args="--no-cache-dir"
    if [[ ${AVAILABLE_MEMORY_GB} -lt 2 ]]; then
        pip_args+=" --no-build-isolation"
    fi
    
    pip install ${pip_args} -r requirements.optimized.txt
    
    success "Python dependencies installed"
}

create_optimized_requirements() {
    log "Creating optimized requirements based on system capabilities..."
    
    local req_file="requirements.optimized.txt"
    
    # Base requirements
    cat > "${req_file}" << EOF
# Core Django
Django>=4.2,<5.0
Pillow
django-widget-tweaks
python-dotenv

# Production server
gunicorn
whitenoise

# Database
psycopg2-binary
dj-database-url

# Redis and caching
redis
django-redis

# API
djangorestframework
django-cors-headers
requests

# DICOM processing
pydicom
pynetdicom
highdicom
numpy
EOF

    # Add optional dependencies based on system resources
    if [[ ${AVAILABLE_MEMORY_GB} -ge 4 ]]; then
        cat >> "${req_file}" << EOF

# Background tasks (requires more memory)
celery

# Advanced image processing
opencv-python
scikit-image
matplotlib
EOF
    fi
    
    if [[ ${AVAILABLE_MEMORY_GB} -ge 8 ]] && [[ "${DETECTED_ARCH}" == "x86_64" ]]; then
        cat >> "${req_file}" << EOF

# AI and machine learning (high memory requirement)
scipy
pandas
torch
torchvision
scikit-learn
EOF
    fi
    
    # Add architecture-specific optimizations
    if [[ "${DETECTED_ARCH}" == "aarch64" ]] || [[ "${DETECTED_ARCH}" == "arm64" ]]; then
        cat >> "${req_file}" << EOF

# ARM-optimized packages
# Note: Some packages may need to be compiled from source
EOF
    fi
    
    success "Optimized requirements file created"
}

# =============================================================================
# SERVICE MANAGEMENT FUNCTIONS
# =============================================================================

wait_for_services_docker() {
    log "Waiting for Docker services to be ready..."
    
    local max_attempts=30
    local attempt=0
    
    while [[ ${attempt} -lt ${max_attempts} ]]; do
        if docker-compose -f docker-compose.optimized.yml exec -T db pg_isready -U noctis_user -d noctis_pro >/dev/null 2>&1; then
            success "Database is ready"
            break
        fi
        
        ((attempt++))
        if [[ ${attempt} -eq ${max_attempts} ]]; then
            error "Database failed to start within timeout"
            return 1
        fi
        
        sleep 10
    done
    
    # Wait for web service
    attempt=0
    while [[ ${attempt} -lt ${max_attempts} ]]; do
        if curl -f -s "http://localhost:8000/" >/dev/null 2>&1; then
            success "Web service is ready"
            break
        fi
        
        ((attempt++))
        if [[ ${attempt} -eq ${max_attempts} ]]; then
            warn "Web service may not be fully ready yet"
            break
        fi
        
        sleep 5
    done
}

setup_django_docker() {
    log "Setting up Django in Docker environment..."
    
    # Run Django setup commands
    docker-compose -f docker-compose.optimized.yml exec -T web python manage.py migrate --noinput
    docker-compose -f docker-compose.optimized.yml exec -T web python manage.py collectstatic --noinput
    
    # Create superuser if it doesn't exist
    docker-compose -f docker-compose.optimized.yml exec -T web python manage.py shell -c "
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

setup_django_native() {
    log "Setting up Django in native environment..."
    
    # Setup PostgreSQL if not already configured
    if [[ -f "${PROJECT_DIR}/setup_postgresql.sh" ]]; then
        log "Setting up PostgreSQL database..."
        bash "${PROJECT_DIR}/setup_postgresql.sh" || {
            warn "PostgreSQL setup failed, but continuing with deployment..."
        }
    fi
    
    source "${PROJECT_DIR}/venv_optimized/bin/activate"
    cd "${PROJECT_DIR}"
    
    # Set environment variables
    export DJANGO_SETTINGS_MODULE=noctis_pro.settings
    export DEBUG=False
    
    # Load environment variables from .env
    if [[ -f .env ]]; then
        export $(grep -v '^#' .env | xargs)
    fi
    
    # Create logs directory
    mkdir -p logs
    
    # Run Django management commands
    python manage.py collectstatic --noinput
    python manage.py makemigrations
    python manage.py migrate
    
    # Create superuser if it doesn't exist
    python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
    print('Superuser created: admin/admin123')
else:
    print('Superuser already exists')
"
    
    success "Django setup completed natively"
}

create_systemd_services() {
    log "Creating systemd services..."
    
    # Main web service
    sudo tee /etc/systemd/system/noctis-web-optimized.service > /dev/null << EOF
[Unit]
Description=NoctisPro PACS Web Application (Optimized)
After=network.target

[Service]
Type=simple
User=${USER}
Group=${USER}
WorkingDirectory=${PROJECT_DIR}
Environment=PATH=${PROJECT_DIR}/venv_optimized/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
Environment=DEBUG=False
ExecStart=${PROJECT_DIR}/venv_optimized/bin/gunicorn --bind 0.0.0.0:8000 --workers ${OPTIMAL_WORKERS} --timeout 120 noctis_pro.wsgi:application
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # DICOM receiver service
    sudo tee /etc/systemd/system/noctis-dicom-optimized.service > /dev/null << EOF
[Unit]
Description=NoctisPro PACS DICOM Receiver (Optimized)
After=network.target noctis-web-optimized.service

[Service]
Type=simple
User=${USER}
Group=${USER}
WorkingDirectory=${PROJECT_DIR}
Environment=PATH=${PROJECT_DIR}/venv_optimized/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
Environment=DEBUG=False
ExecStart=${PROJECT_DIR}/venv_optimized/bin/python dicom_receiver.py --port 11112 --aet NOCTIS_SCP
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Celery service (if system has enough resources)
    if [[ ${AVAILABLE_MEMORY_GB} -ge 4 ]]; then
        sudo tee /etc/systemd/system/noctis-celery-optimized.service > /dev/null << EOF
[Unit]
Description=NoctisPro PACS Celery Worker (Optimized)
After=network.target noctis-web-optimized.service

[Service]
Type=simple
User=${USER}
Group=${USER}
WorkingDirectory=${PROJECT_DIR}
Environment=PATH=${PROJECT_DIR}/venv_optimized/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
Environment=DEBUG=False
ExecStart=${PROJECT_DIR}/venv_optimized/bin/celery -A noctis_pro worker --loglevel=info --concurrency=${OPTIMAL_WORKERS}
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    sudo systemctl daemon-reload
    sudo systemctl enable noctis-web-optimized noctis-dicom-optimized
    
    if [[ ${AVAILABLE_MEMORY_GB} -ge 4 ]]; then
        sudo systemctl enable noctis-celery-optimized
    fi
    
    success "Systemd services created"
}

create_simple_services() {
    log "Creating simple service management scripts..."
    
    # Create logs directory
    mkdir -p "${PROJECT_DIR}/logs"
    
    # Create simple start script
    cat > "${PROJECT_DIR}/start_services.sh" << EOF
#!/bin/bash
# Simple service starter for NoctisPro PACS

cd "${PROJECT_DIR}"
source venv_optimized/bin/activate

echo "Starting NoctisPro PACS services..."

# Start web service
nohup gunicorn --bind 0.0.0.0:8000 --workers ${OPTIMAL_WORKERS} --timeout 120 noctis_pro.wsgi:application > logs/web.log 2>&1 &
echo \$! > logs/web.pid
echo "Web service started (PID: \$(cat logs/web.pid))"

# Start DICOM receiver
nohup python dicom_receiver.py --port 11112 --aet NOCTIS_SCP > logs/dicom.log 2>&1 &
echo \$! > logs/dicom.pid
echo "DICOM receiver started (PID: \$(cat logs/dicom.pid))"

echo "All services started successfully"
echo "Web interface: http://localhost:8000"
echo "DICOM port: localhost:11112"
EOF
    
    # Create simple stop script
    cat > "${PROJECT_DIR}/stop_services.sh" << EOF
#!/bin/bash
# Simple service stopper for NoctisPro PACS

cd "${PROJECT_DIR}"

echo "Stopping NoctisPro PACS services..."

# Stop web service
if [[ -f logs/web.pid ]]; then
    PID=\$(cat logs/web.pid)
    if kill -0 "\$PID" 2>/dev/null; then
        kill "\$PID"
        echo "Web service stopped (PID: \$PID)"
    else
        echo "Web service was not running"
    fi
    rm -f logs/web.pid
fi

# Stop DICOM receiver
if [[ -f logs/dicom.pid ]]; then
    PID=\$(cat logs/dicom.pid)
    if kill -0 "\$PID" 2>/dev/null; then
        kill "\$PID"
        echo "DICOM receiver stopped (PID: \$PID)"
    else
        echo "DICOM receiver was not running"
    fi
    rm -f logs/dicom.pid
fi

echo "All services stopped"
EOF
    
    # Make scripts executable
    chmod +x "${PROJECT_DIR}/start_services.sh"
    chmod +x "${PROJECT_DIR}/stop_services.sh"
    
    success "Simple service management scripts created"
}

start_native_services() {
    log "Starting native services..."
    
    if [[ "${HAS_SYSTEMD}" == true ]]; then
        sudo systemctl start noctis-web-optimized
        sudo systemctl start noctis-dicom-optimized
        
        if [[ ${AVAILABLE_MEMORY_GB} -ge 4 ]]; then
            sudo systemctl start noctis-celery-optimized
        fi
        
        success "Systemd services started"
    else
        # Fallback to simple background processes
        source "${PROJECT_DIR}/venv_optimized/bin/activate"
        cd "${PROJECT_DIR}"
        
        nohup python manage.py runserver 0.0.0.0:8000 > logs/web.log 2>&1 &
        nohup python dicom_receiver.py --port 11112 --aet NOCTIS_SCP > logs/dicom.log 2>&1 &
        
        success "Services started in background"
    fi
}

# =============================================================================
# MONITORING AND HEALTH CHECK FUNCTIONS
# =============================================================================

perform_health_checks() {
    log "Performing comprehensive health checks..."
    
    local health_status=true
    
    # Wait for services to fully start
    log "Waiting for services to initialize..."
    sleep 10
    
    # Check web service with retries
    log "Testing web service..."
    local web_attempts=0
    local max_attempts=6
    while [[ $web_attempts -lt $max_attempts ]]; do
        if curl -f -s --max-time 10 "http://localhost:8000/" >/dev/null 2>&1; then
            success "✅ Web service is healthy"
            break
        else
            ((web_attempts++))
            if [[ $web_attempts -eq $max_attempts ]]; then
                error "❌ Web service is not responding after $max_attempts attempts"
                health_status=false
            else
                log "Web service not ready yet, attempt $web_attempts/$max_attempts..."
                sleep 5
            fi
        fi
    done
    
    # Check DICOM port with retries
    log "Testing DICOM port..."
    local dicom_attempts=0
    while [[ $dicom_attempts -lt $max_attempts ]]; do
        if timeout 5 bash -c "</dev/tcp/localhost/11112" >/dev/null 2>&1; then
            success "✅ DICOM port is accessible"
            break
        else
            ((dicom_attempts++))
            if [[ $dicom_attempts -eq $max_attempts ]]; then
                error "❌ DICOM port is not accessible after $max_attempts attempts"
                health_status=false
            else
                log "DICOM port not ready yet, attempt $dicom_attempts/$max_attempts..."
                sleep 5
            fi
        fi
    done
    
    # Check database (Docker or native)
    if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
        if docker-compose -f docker-compose.optimized.yml exec -T db pg_isready -U noctis_user -d noctis_pro >/dev/null 2>&1; then
            success "✅ Database is healthy"
        else
            error "❌ Database is not responding"
            health_status=false
        fi
    fi
    
    # Check system resources
    local current_memory=$(free | grep '^Mem:' | awk '{print int($3/$2 * 100)}')
    local current_disk=$(df "${PROJECT_DIR}" | tail -1 | awk '{print int($3/$2 * 100)}')
    
    if [[ ${current_memory} -lt 90 ]]; then
        success "✅ Memory usage: ${current_memory}%"
    else
        warn "⚠️  High memory usage: ${current_memory}%"
    fi
    
    if [[ ${current_disk} -lt 90 ]]; then
        success "✅ Disk usage: ${current_disk}%"
    else
        warn "⚠️  High disk usage: ${current_disk}%"
    fi
    
    if [[ "${health_status}" == true ]]; then
        success "🎉 All health checks passed!"
        return 0
    else
        error "❌ Some health checks failed"
        return 1
    fi
}

create_monitoring_script() {
    log "Creating monitoring and management script..."
    
    local management_script="${PROJECT_DIR}/manage_noctis_optimized.sh"
    
    cat > "${management_script}" << 'EOF'
#!/bin/bash

# NoctisPro Optimized Management Script

DEPLOYMENT_MODE="{{DEPLOYMENT_MODE}}"
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")" && pwd)}"

case "$1" in
    start)
        echo "Starting NoctisPro services..."
        if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
            cd "${PROJECT_DIR}"
            docker-compose -f docker-compose.optimized.yml up -d
        else
            sudo systemctl start noctis-web-optimized noctis-dicom-optimized
            [[ -f /etc/systemd/system/noctis-celery-optimized.service ]] && sudo systemctl start noctis-celery-optimized
        fi
        ;;
    stop)
        echo "Stopping NoctisPro services..."
        if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
            cd "${PROJECT_DIR}"
            docker-compose -f docker-compose.optimized.yml down
        else
            sudo systemctl stop noctis-web-optimized noctis-dicom-optimized noctis-celery-optimized
        fi
        ;;
    restart)
        echo "Restarting NoctisPro services..."
        $0 stop
        sleep 5
        $0 start
        ;;
    status)
        echo "NoctisPro Service Status:"
        if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
            cd "${PROJECT_DIR}"
            docker-compose -f docker-compose.optimized.yml ps
        else
            sudo systemctl status noctis-web-optimized noctis-dicom-optimized noctis-celery-optimized
        fi
        ;;
    logs)
        echo "NoctisPro Logs:"
        if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
            cd "${PROJECT_DIR}"
            docker-compose -f docker-compose.optimized.yml logs -f
        else
            sudo journalctl -f -u noctis-web-optimized -u noctis-dicom-optimized -u noctis-celery-optimized
        fi
        ;;
    health)
        echo "Performing health checks..."
        # Web service check
        if curl -f -s "http://localhost:8000/" >/dev/null 2>&1; then
            echo "✅ Web service: Healthy"
        else
            echo "❌ Web service: Unhealthy"
        fi
        
        # DICOM port check
        if timeout 5 bash -c "</dev/tcp/localhost/11112" >/dev/null 2>&1; then
            echo "✅ DICOM port: Accessible"
        else
            echo "❌ DICOM port: Not accessible"
        fi
        
        # Resource usage
        echo "📊 Memory usage: $(free | grep '^Mem:' | awk '{print int($3/$2 * 100)}')%"
        echo "📊 Disk usage: $(df "${PROJECT_DIR}" | tail -1 | awk '{print int($3/$2 * 100)}')%"
        ;;
    update)
        echo "Updating NoctisPro..."
        cd "${PROJECT_DIR}"
        git pull origin main
        if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
            docker-compose -f docker-compose.optimized.yml down
            docker-compose -f docker-compose.optimized.yml up -d --build
        else
            source venv_optimized/bin/activate
            pip install -r requirements.optimized.txt
            python manage.py migrate --noinput
            python manage.py collectstatic --noinput
            $0 restart
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|health|update}"
        echo ""
        echo "Commands:"
        echo "  start   - Start all NoctisPro services"
        echo "  stop    - Stop all NoctisPro services"
        echo "  restart - Restart all NoctisPro services"
        echo "  status  - Show service status"
        echo "  logs    - Show service logs"
        echo "  health  - Perform health checks"
        echo "  update  - Update and restart services"
        exit 1
        ;;
esac
EOF

    # Replace placeholders
    sed -i "s|{{DEPLOYMENT_MODE}}|${DEPLOYMENT_MODE}|g" "${management_script}"
    sed -i "s|{{PROJECT_DIR}}|${PROJECT_DIR}|g" "${management_script}"
    
    chmod +x "${management_script}"
    
    success "Management script created: ${management_script}"
}

# =============================================================================
# MAIN DEPLOYMENT ORCHESTRATION
# =============================================================================

display_deployment_summary() {
    log "Deployment Summary"
    echo ""
    echo "=============================================="
    echo "🚀 NoctisPro PACS - Intelligent Deployment"
    echo "=============================================="
    echo ""
    echo "📊 System Information:"
    echo "  OS: ${DETECTED_OS} ${DETECTED_VERSION}"
    echo "  Architecture: ${DETECTED_ARCH}"
    echo "  Memory: ${AVAILABLE_MEMORY_GB}GB"
    echo "  CPU Cores: ${AVAILABLE_CPU_CORES}"
    echo "  Storage: ${AVAILABLE_STORAGE_GB}GB"
    echo ""
    echo "⚙️  Deployment Configuration:"
    echo "  Mode: ${DEPLOYMENT_MODE}"
    echo "  Worker Processes: ${OPTIMAL_WORKERS}"
    echo "  Docker: ${HAS_DOCKER}"
    echo "  Systemd: ${HAS_SYSTEMD}"
    echo "  Nginx: ${USE_NGINX}"
    echo "  SSL: ${USE_SSL}"
    echo ""
    echo "🌐 Access Information:"
    echo "  Web Interface: http://localhost:8000"
    echo "  Admin Panel: http://localhost:8000/admin/"
    echo "  DICOM Port: localhost:11112"
    echo "  Default Login: admin / admin123"
    echo ""
    echo "🔧 Management:"
    echo "  Management Script: ${PROJECT_DIR}/manage_noctis_optimized.sh"
    echo "  Log File: ${LOG_FILE}"
    echo ""
    
    if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
        echo "🐳 Docker Commands:"
        echo "  View Status: docker-compose -f docker-compose.optimized.yml ps"
        echo "  View Logs: docker-compose -f docker-compose.optimized.yml logs -f"
        echo "  Stop Services: docker-compose -f docker-compose.optimized.yml down"
    else
        echo "🔧 System Commands:"
        echo "  View Status: sudo systemctl status noctis-*-optimized"
        echo "  View Logs: sudo journalctl -f -u noctis-*-optimized"
        echo "  Stop Services: sudo systemctl stop noctis-*-optimized"
    fi
    echo ""
}

main() {
    echo ""
    echo "🤖 NoctisPro PACS - Intelligent Auto-Detection Deployment"
    echo "========================================================="
    echo ""
    
    log "Starting intelligent deployment process..."
    log "Log file: ${LOG_FILE}"
    
    # Phase 1: System Detection
    log "=== Phase 1: System Detection ==="
    detect_operating_system
    detect_system_resources
    detect_installed_software
    determine_deployment_mode
    
    # Phase 2: System Preparation
    log "=== Phase 2: System Preparation ==="
    install_system_dependencies
    
    # Phase 3: Deployment Execution
    log "=== Phase 3: Deployment Execution ==="
    case "${DEPLOYMENT_MODE}" in
        docker_*)
            execute_docker_deployment
            ;;
        native_*)
            execute_native_deployment
            ;;
        install_dependencies)
            log "Dependencies installed. Please run the script again."
            exit 0
            ;;
        *)
            error "Unknown deployment mode: ${DEPLOYMENT_MODE}"
            exit 1
            ;;
    esac
    
    # Phase 4: Health Checks and Monitoring
    log "=== Phase 4: Health Checks and Monitoring ==="
    perform_health_checks
    create_monitoring_script
    
    # Phase 5: Summary
    log "=== Phase 5: Deployment Complete ==="
    display_deployment_summary
    
    success "🎉 NoctisPro PACS has been successfully deployed with intelligent optimization!"
    success "🔗 Access your application at: http://localhost:8000"
    
    # Mark todo as completed
    log "Deployment completed successfully. Check the management script for ongoing operations."
}

# Error handling
trap 'error "Deployment interrupted"; exit 1' INT TERM

# Ensure running with appropriate permissions
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root for security reasons."
    error "Please run as a regular user with sudo privileges."
    exit 1
fi

# Run main function
main "$@"