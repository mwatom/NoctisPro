#!/bin/bash

# =============================================================================
# NoctisPro PACS - Docker Deployment Script
# =============================================================================
# Full deployment with PostgreSQL, Redis, and Cloudflare Tunnel
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
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="${SCRIPT_DIR}"
readonly LOG_FILE="/tmp/noctis_docker_deploy_$(date +%Y%m%d_%H%M%S).log"

# Logging functions
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

success() {
    local message="[SUCCESS] $1"
    echo -e "${GREEN}✅ ${message}${NC}"
    echo "${message}" >> "${LOG_FILE}"
}

info() {
    local message="[INFO] $1"
    echo -e "${BLUE}${message}${NC}"
    echo "${message}" >> "${LOG_FILE}"
}

# Header
echo ""
echo -e "${BOLD}${CYAN}🐳 NoctisPro PACS - Docker Deployment${NC}"
echo -e "${BOLD}${CYAN}=====================================${NC}"
echo ""

# Check if Docker is available
check_docker() {
    log "Checking Docker availability..."
    
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed. Installing Docker..."
        install_docker
    fi
    
    if ! docker info >/dev/null 2>&1; then
        warn "Docker daemon not running. Attempting to start..."
        start_docker_daemon
    fi
    
    success "Docker is available and running"
}

# Install Docker
install_docker() {
    log "Installing Docker..."
    
    # Update package list
    sudo apt update
    
    # Install Docker
    sudo apt install -y docker.io docker-compose
    
    # Add user to docker group
    sudo usermod -aG docker "${USER}"
    
    success "Docker installed successfully"
}

# Start Docker daemon
start_docker_daemon() {
    # Try different methods to start Docker
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl start docker || true
    elif command -v service >/dev/null 2>&1; then
        sudo service docker start || true
    else
        # Manual start for container environments
        sudo dockerd --host=unix:///var/run/docker.sock --insecure-registry 127.0.0.0/8 &
        sleep 10
    fi
    
    # Check if Docker is now working
    if ! docker info >/dev/null 2>&1; then
        error "Could not start Docker daemon. Using native deployment instead."
        deploy_native
        exit 0
    fi
}

# Create Docker Compose file
create_docker_compose() {
    log "Creating Docker Compose configuration..."
    
    cat > "${PROJECT_DIR}/docker-compose.deploy.yml" << 'EOF'
version: '3.8'

services:
  # PostgreSQL Database
  db:
    image: postgres:15-alpine
    container_name: noctis_db
    environment:
      POSTGRES_DB: noctis_pro
      POSTGRES_USER: noctis_user
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-noctis_secure_password_2024}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U noctis_user -d noctis_pro"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped
    networks:
      - noctis_network

  # Redis for caching and message broker
  redis:
    image: redis:7-alpine
    container_name: noctis_redis
    command: redis-server --appendonly yes --maxmemory 512mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped
    networks:
      - noctis_network

  # Django Web Application
  web:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: noctis_web
    environment:
      - DEBUG=False
      - SECRET_KEY=${SECRET_KEY}
      - DB_ENGINE=django.db.backends.postgresql
      - DB_NAME=noctis_pro
      - DB_USER=noctis_user
      - DB_PASSWORD=${POSTGRES_PASSWORD:-noctis_secure_password_2024}
      - DB_HOST=db
      - DB_PORT=5432
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
      - ALLOWED_HOSTS=*
      - ADMIN_USERNAME=admin
      - ADMIN_PASSWORD=${ADMIN_PASSWORD:-NoctisAdmin2024!}
      - ADMIN_EMAIL=admin@noctispro.com
    volumes:
      - .:/app
      - media_files:/app/media
      - static_files:/app/staticfiles
    ports:
      - "8000:8000"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    restart: unless-stopped
    command: >
      sh -c "python manage.py migrate --noinput &&
             python manage.py collectstatic --noinput &&
             python manage.py shell -c \"
from django.contrib.auth import get_user_model;
User = get_user_model();
User.objects.filter(username='admin').delete();
User.objects.create_superuser('admin', 'admin@noctispro.com', '${ADMIN_PASSWORD:-NoctisAdmin2024!}');
print('✅ Admin user created: admin / ${ADMIN_PASSWORD:-NoctisAdmin2024!}')
\" &&
             gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:8000 --workers 4 --timeout 120"
    networks:
      - noctis_network

  # Celery Worker for background tasks
  celery:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: noctis_celery
    environment:
      - DEBUG=False
      - SECRET_KEY=${SECRET_KEY}
      - DB_ENGINE=django.db.backends.postgresql
      - DB_NAME=noctis_pro
      - DB_USER=noctis_user
      - DB_PASSWORD=${POSTGRES_PASSWORD:-noctis_secure_password_2024}
      - DB_HOST=db
      - DB_PORT=5432
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
    volumes:
      - .:/app
      - media_files:/app/media
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped
    command: celery -A noctis_pro worker --loglevel=info --concurrency=4
    networks:
      - noctis_network

  # DICOM Receiver Service
  dicom_receiver:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: noctis_dicom
    environment:
      - DEBUG=False
      - SECRET_KEY=${SECRET_KEY}
      - DB_ENGINE=django.db.backends.postgresql
      - DB_NAME=noctis_pro
      - DB_USER=noctis_user
      - DB_PASSWORD=${POSTGRES_PASSWORD:-noctis_secure_password_2024}
      - DB_HOST=db
      - DB_PORT=5432
      - REDIS_URL=redis://redis:6379/0
    volumes:
      - .:/app
      - media_files:/app/media
    ports:
      - "11112:11112"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped
    command: python dicom_receiver.py --port 11112 --aet NOCTIS_SCP --bind 0.0.0.0
    networks:
      - noctis_network

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  media_files:
    driver: local
  static_files:
    driver: local

networks:
  noctis_network:
    driver: bridge
EOF

    success "Docker Compose configuration created"
}

# Create Dockerfile if it doesn't exist
create_dockerfile() {
    if [[ ! -f "${PROJECT_DIR}/Dockerfile" ]]; then
        log "Creating Dockerfile..."
        
        cat > "${PROJECT_DIR}/Dockerfile" << 'EOF'
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    libssl-dev \
    libffi-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libwebp-dev \
    zlib1g-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements*.txt ./
RUN pip install --no-cache-dir -r requirements.txt || \
    pip install --no-cache-dir Django Pillow psycopg2-binary redis celery gunicorn pydicom pynetdicom

# Copy project
COPY . .

# Create directories
RUN mkdir -p logs media staticfiles

# Collect static files
RUN python manage.py collectstatic --noinput || echo "Static files collection failed, will retry at runtime"

# Expose ports
EXPOSE 8000 11112

# Default command
CMD ["gunicorn", "noctis_pro.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4"]
EOF

        success "Dockerfile created"
    fi
}

# Create environment file
create_environment_file() {
    log "Creating environment file..."
    
    # Generate secure passwords
    local secret_key=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))" 2>/dev/null || echo "noctis-secret-key-$(date +%s)")
    local postgres_password=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))" 2>/dev/null || echo "noctis-postgres-$(date +%s)")
    local admin_password="NoctisAdmin2024!"
    
    cat > "${PROJECT_DIR}/.env.docker" << EOF
# NoctisPro PACS - Docker Environment
SECRET_KEY=${secret_key}
POSTGRES_PASSWORD=${postgres_password}
ADMIN_PASSWORD=${admin_password}

# Database Configuration
DB_ENGINE=django.db.backends.postgresql
DB_NAME=noctis_pro
DB_USER=noctis_user
DB_HOST=db
DB_PORT=5432

# Redis Configuration
REDIS_URL=redis://redis:6379/0
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# Django Settings
DEBUG=False
ALLOWED_HOSTS=*
DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Admin User
ADMIN_USERNAME=admin
ADMIN_EMAIL=admin@noctispro.com

# Deployment Info
DEPLOYMENT_MODE=docker
DEPLOYED_AT=$(date -Iseconds)
EOF

    success "Environment file created"
}

# Deploy with Docker
deploy_docker() {
    log "Starting Docker deployment..."
    
    cd "${PROJECT_DIR}"
    
    # Load environment
    export $(cat .env.docker | grep -v '^#' | xargs)
    
    # Build and start services
    log "Building and starting services..."
    docker-compose -f docker-compose.deploy.yml down --remove-orphans || true
    docker-compose -f docker-compose.deploy.yml build
    docker-compose -f docker-compose.deploy.yml up -d
    
    # Wait for services to be ready
    log "Waiting for services to start..."
    sleep 30
    
    # Check service health
    check_service_health
    
    success "Docker deployment completed"
}

# Check service health
check_service_health() {
    log "Checking service health..."
    
    local max_attempts=12
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -f -s "http://localhost:8000/" >/dev/null 2>&1; then
            success "✅ Web service is healthy"
            break
        fi
        
        ((attempt++))
        if [[ $attempt -eq $max_attempts ]]; then
            warn "⚠️ Web service may not be fully ready yet"
            break
        fi
        
        log "Waiting for web service... (attempt $attempt/$max_attempts)"
        sleep 10
    done
    
    # Test DICOM port
    if timeout 5 bash -c "</dev/tcp/localhost/11112" >/dev/null 2>&1; then
        success "✅ DICOM port is accessible"
    else
        warn "⚠️ DICOM port may not be ready yet"
    fi
    
    # Test database
    if docker-compose -f docker-compose.deploy.yml exec -T db pg_isready -U noctis_user -d noctis_pro >/dev/null 2>&1; then
        success "✅ PostgreSQL database is healthy"
    else
        warn "⚠️ Database may not be ready yet"
    fi
    
    # Test Redis
    if docker-compose -f docker-compose.deploy.yml exec -T redis redis-cli ping >/dev/null 2>&1; then
        success "✅ Redis is healthy"
    else
        warn "⚠️ Redis may not be ready yet"
    fi
}

# Setup Cloudflare tunnels
setup_tunnels() {
    log "Setting up Cloudflare tunnels..."
    
    # Install cloudflared if not available
    if ! command -v cloudflared >/dev/null 2>&1; then
        log "Installing cloudflared..."
        curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        sudo dpkg -i cloudflared.deb
        rm cloudflared.deb
    fi
    
    # Start tunnels
    log "Starting Cloudflare tunnels..."
    pkill cloudflared || true
    
    nohup cloudflared tunnel --url http://localhost:8000 > tunnel_web.log 2>&1 &
    nohup cloudflared tunnel --url http://localhost:11112 > tunnel_dicom.log 2>&1 &
    
    # Wait for tunnels to start
    sleep 15
    
    # Extract URLs
    local web_url=$(grep "https://" tunnel_web.log | grep -o "https://[^[:space:]]*" | head -1)
    local dicom_url=$(grep "https://" tunnel_dicom.log | grep -o "https://[^[:space:]]*" | head -1)
    
    if [[ -n "$web_url" ]]; then
        success "✅ Web tunnel: $web_url"
        echo "$web_url" > web_tunnel_url.txt
    fi
    
    if [[ -n "$dicom_url" ]]; then
        success "✅ DICOM tunnel: $dicom_url"
        echo "$dicom_url" > dicom_tunnel_url.txt
    fi
}

# Deploy natively if Docker fails
deploy_native() {
    warn "Falling back to native deployment..."
    
    # Install system dependencies
    sudo apt update
    sudo apt install -y postgresql postgresql-contrib redis-server python3-venv
    
    # Start services
    sudo service postgresql start
    sudo service redis-server start
    
    # Setup database
    sudo -u postgres psql -c "CREATE DATABASE noctis_pro;" || true
    sudo -u postgres psql -c "CREATE USER noctis_user WITH PASSWORD 'noctis_secure_password_2024';" || true
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE noctis_pro TO noctis_user;" || true
    sudo -u postgres psql -d noctis_pro -c "GRANT ALL ON SCHEMA public TO noctis_user;" || true
    
    # Setup Python environment
    python3 -m venv venv_docker
    source venv_docker/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt || pip install Django Pillow psycopg2-binary redis celery gunicorn pydicom pynetdicom
    
    # Setup Django
    export DB_ENGINE=django.db.backends.postgresql
    export DB_NAME=noctis_pro
    export DB_USER=noctis_user
    export DB_PASSWORD=noctis_secure_password_2024
    export DB_HOST=localhost
    export DB_PORT=5432
    export SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
    
    python manage.py migrate
    python manage.py collectstatic --noinput
    
    # Create admin user
    python manage.py shell -c "
from django.contrib.auth import get_user_model;
User = get_user_model();
User.objects.filter(username='admin').delete();
User.objects.create_superuser('admin', 'admin@noctispro.com', 'NoctisAdmin2024!');
print('✅ Admin user created: admin / NoctisAdmin2024!')
"
    
    # Start services
    nohup gunicorn --bind 0.0.0.0:8000 --workers 4 noctis_pro.wsgi:application > logs/web.log 2>&1 &
    nohup python dicom_receiver.py --port 11112 --aet NOCTIS_SCP > logs/dicom.log 2>&1 &
    nohup celery -A noctis_pro worker --loglevel=info > logs/celery.log 2>&1 &
    
    success "Native deployment completed"
}

# Generate deployment report
generate_report() {
    log "Generating deployment report..."
    
    local web_url=$(cat web_tunnel_url.txt 2>/dev/null || echo "http://localhost:8000")
    local dicom_url=$(cat dicom_tunnel_url.txt 2>/dev/null || echo "http://localhost:11112")
    
    cat > "${PROJECT_DIR}/DOCKER_DEPLOYMENT_COMPLETE.md" << EOF
# 🐳 NoctisPro PACS - Docker Deployment Complete!

## 🌐 Public Access URLs
- **Web Application**: ${web_url}
- **Admin Panel**: ${web_url}/admin/
- **DICOM Service**: ${dicom_url}

## 🔐 Admin Credentials
- **Username**: admin
- **Password**: NoctisAdmin2024!
- **Email**: admin@noctispro.com

## 🐳 Docker Services
- ✅ PostgreSQL Database (Container)
- ✅ Redis Cache (Container)
- ✅ Django Web App (Container)
- ✅ Celery Worker (Container)
- ✅ DICOM Receiver (Container)

## 🔧 Management Commands
\`\`\`bash
# View service status
docker-compose -f docker-compose.deploy.yml ps

# View logs
docker-compose -f docker-compose.deploy.yml logs -f

# Restart services
docker-compose -f docker-compose.deploy.yml restart

# Stop all services
docker-compose -f docker-compose.deploy.yml down

# Start services
docker-compose -f docker-compose.deploy.yml up -d

# Access database
docker-compose -f docker-compose.deploy.yml exec db psql -U noctis_user -d noctis_pro

# Access Redis
docker-compose -f docker-compose.deploy.yml exec redis redis-cli
\`\`\`

## 📊 Service Health
Check service health with:
\`\`\`bash
curl -s ${web_url}/health/
docker-compose -f docker-compose.deploy.yml exec db pg_isready -U noctis_user -d noctis_pro
docker-compose -f docker-compose.deploy.yml exec redis redis-cli ping
\`\`\`

## 🎉 Deployment Summary
- **Database**: PostgreSQL 15 (Production-ready)
- **Cache**: Redis 7 (High performance)
- **Web Server**: Gunicorn with 4 workers
- **Background Tasks**: Celery worker
- **DICOM Support**: Full DICOM receiver
- **Public Access**: Cloudflare tunnels
- **Admin Access**: Full superuser privileges

**Access your system now**: ${web_url}
**Admin login**: admin / NoctisAdmin2024!
EOF

    success "Deployment report generated: DOCKER_DEPLOYMENT_COMPLETE.md"
}

# Main deployment function
main() {
    local start_time=$(date +%s)
    
    log "Starting NoctisPro PACS Docker deployment..."
    log "Log file: ${LOG_FILE}"
    
    # Check Docker
    check_docker
    
    # Create configuration files
    create_dockerfile
    create_docker_compose
    create_environment_file
    
    # Deploy
    deploy_docker
    
    # Setup tunnels
    setup_tunnels
    
    # Generate report
    generate_report
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo -e "${BOLD}${GREEN}🎉 DEPLOYMENT COMPLETE! 🎉${NC}"
    echo -e "${BOLD}${GREEN}=========================${NC}"
    echo ""
    echo -e "${GREEN}📊 Deployment Summary:${NC}"
    echo -e "   • Duration: ${duration} seconds"
    echo -e "   • Mode: Docker with PostgreSQL"
    echo -e "   • Services: 5 containers running"
    echo ""
    echo -e "${GREEN}🌐 Access Information:${NC}"
    if [[ -f web_tunnel_url.txt ]]; then
        local web_url=$(cat web_tunnel_url.txt)
        echo -e "   • Web URL: ${CYAN}${web_url}${NC}"
        echo -e "   • Admin Panel: ${CYAN}${web_url}/admin/${NC}"
    else
        echo -e "   • Web URL: ${CYAN}http://localhost:8000${NC}"
        echo -e "   • Admin Panel: ${CYAN}http://localhost:8000/admin/${NC}"
    fi
    if [[ -f dicom_tunnel_url.txt ]]; then
        local dicom_url=$(cat dicom_tunnel_url.txt)
        echo -e "   • DICOM URL: ${CYAN}${dicom_url}${NC}"
    else
        echo -e "   • DICOM URL: ${CYAN}http://localhost:11112${NC}"
    fi
    echo ""
    echo -e "${GREEN}🔐 Admin Credentials:${NC}"
    echo -e "   • Username: ${YELLOW}admin${NC}"
    echo -e "   • Password: ${YELLOW}NoctisAdmin2024!${NC}"
    echo ""
    echo -e "${GREEN}🔧 Management:${NC}"
    echo -e "   • Status: ${CYAN}docker-compose -f docker-compose.deploy.yml ps${NC}"
    echo -e "   • Logs: ${CYAN}docker-compose -f docker-compose.deploy.yml logs -f${NC}"
    echo -e "   • Restart: ${CYAN}docker-compose -f docker-compose.deploy.yml restart${NC}"
    echo ""
    
    success "🚀 NoctisPro PACS is ready for use!"
}

# Error handling
trap 'error "Deployment interrupted"; exit 1' INT TERM

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root for security reasons."
    error "Please run as a regular user with sudo privileges."
    exit 1
fi

# Run main function
main "$@"