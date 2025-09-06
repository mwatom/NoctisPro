#!/bin/bash

# =============================================================================
# NoctisPro PACS - Deployment Configuration Generator
# =============================================================================
# Generates deployment configurations based on system analysis
# =============================================================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="${SCRIPT_DIR}"
readonly CONFIG_DIR="${PROJECT_DIR}/deployment_configs"

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}" >&2
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# =============================================================================
# CONFIGURATION GENERATORS
# =============================================================================

create_nginx_config() {
    local memory_gb=$1
    local cpu_cores=$2
    local ssl_enabled=$3
    
    log "Generating optimized Nginx configuration..."
    
    # Calculate worker processes and connections
    local worker_processes=$cpu_cores
    local worker_connections=1024
    
    if [[ $memory_gb -ge 8 ]]; then
        worker_connections=2048
    elif [[ $memory_gb -ge 4 ]]; then
        worker_connections=1024
    else
        worker_connections=512
    fi
    
    # Cap worker processes at 8 for stability
    if [[ $worker_processes -gt 8 ]]; then
        worker_processes=8
    fi
    
    mkdir -p "${CONFIG_DIR}/nginx"
    
    cat > "${CONFIG_DIR}/nginx/nginx.optimized.conf" << EOF
# NoctisPro PACS - Optimized Nginx Configuration
# Generated for system with ${memory_gb}GB RAM and ${cpu_cores} CPU cores

user www-data;
worker_processes ${worker_processes};
pid /run/nginx.pid;

# Performance optimizations
worker_rlimit_nofile 65535;

events {
    worker_connections ${worker_connections};
    use epoll;
    multi_accept on;
}

http {
    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    # File handling
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Logging
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=login:10m rate=1r/s;
    
    # File upload limits for DICOM images
    client_max_body_size 500M;
    client_body_timeout 300s;
    client_header_timeout 300s;
    
    # Proxy settings
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
    proxy_busy_buffers_size 8k;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    
    upstream noctis_web {
        server web:8000;
        keepalive 32;
    }
    
    server {
        listen 80;
        server_name _;
        
        # Security
        location = /favicon.ico { 
            access_log off; 
            log_not_found off; 
        }
        
        location = /robots.txt { 
            access_log off; 
            log_not_found off; 
        }
        
        # Static files
        location /static/ {
            alias /var/www/static/;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
        
        location /media/ {
            alias /var/www/media/;
            expires 30d;
            add_header Cache-Control "public";
            
            # DICOM file security
            location ~* \.dcm$ {
                # Only allow authenticated access to DICOM files
                auth_request /auth;
                expires off;
                add_header Cache-Control "no-cache";
            }
        }
        
        # Authentication endpoint for media files
        location = /auth {
            internal;
            proxy_pass http://noctis_web/api/auth-check/;
            proxy_pass_request_body off;
            proxy_set_header Content-Length "";
            proxy_set_header X-Original-URI \$request_uri;
        }
        
        # API rate limiting
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://noctis_web;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
        
        # Login rate limiting
        location /admin/login/ {
            limit_req zone=login burst=5 nodelay;
            proxy_pass http://noctis_web;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
        
        # Main application
        location / {
            proxy_pass http://noctis_web;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
        }
        
        # Health check endpoint
        location /health/ {
            access_log off;
            proxy_pass http://noctis_web;
            proxy_set_header Host \$host;
        }
    }
EOF

    if [[ "$ssl_enabled" == "true" ]]; then
        cat >> "${CONFIG_DIR}/nginx/nginx.optimized.conf" << 'EOF'
    
    # SSL/HTTPS server configuration
    server {
        listen 443 ssl http2;
        server_name _;
        
        # SSL configuration
        ssl_certificate /etc/letsencrypt/live/domain/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/domain/privkey.pem;
        ssl_session_timeout 1d;
        ssl_session_cache shared:SSL:50m;
        ssl_session_tickets off;
        
        # Modern SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        
        # HSTS
        add_header Strict-Transport-Security "max-age=63072000" always;
        
        # Include all location blocks from HTTP server
        include /etc/nginx/sites-available/noctis-locations.conf;
    }
    
    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name _;
        return 301 https://$server_name$request_uri;
    }
EOF
    fi
    
    cat >> "${CONFIG_DIR}/nginx/nginx.optimized.conf" << 'EOF'
}
EOF

    success "Nginx configuration generated: ${CONFIG_DIR}/nginx/nginx.optimized.conf"
}

create_systemd_services() {
    local memory_gb=$1
    local cpu_cores=$2
    local python_path=$3
    
    log "Generating systemd service configurations..."
    
    mkdir -p "${CONFIG_DIR}/systemd"
    
    # Calculate optimal worker count
    local web_workers=$cpu_cores
    if [[ $web_workers -gt 8 ]]; then
        web_workers=8
    elif [[ $web_workers -lt 1 ]]; then
        web_workers=1
    fi
    
    # Web service
    cat > "${CONFIG_DIR}/systemd/noctis-web.service" << EOF
[Unit]
Description=NoctisPro PACS Web Application
After=network.target postgresql.service redis.service
Wants=postgresql.service redis.service

[Service]
Type=notify
User=noctis
Group=noctis
WorkingDirectory=${PROJECT_DIR}
Environment=PATH=${python_path}/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
Environment=DEBUG=False
Environment=PYTHONPATH=${PROJECT_DIR}

# Performance settings based on system resources
ExecStart=${python_path}/bin/gunicorn \\
    --bind 0.0.0.0:8000 \\
    --workers ${web_workers} \\
    --worker-class gevent \\
    --worker-connections 1000 \\
    --max-requests 1000 \\
    --max-requests-jitter 100 \\
    --timeout 120 \\
    --keepalive 2 \\
    --preload \\
    noctis_pro.wsgi:application

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

# Memory limits based on available RAM
$(if [[ $memory_gb -ge 8 ]]; then
    echo "MemoryMax=2G"
    echo "MemoryHigh=1.5G"
elif [[ $memory_gb -ge 4 ]]; then
    echo "MemoryMax=1G"
    echo "MemoryHigh=800M"
else
    echo "MemoryMax=512M"
    echo "MemoryHigh=400M"
fi)

# Restart configuration
Restart=always
RestartSec=5
StartLimitInterval=60
StartLimitBurst=3

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=${PROJECT_DIR}
ProtectHome=true

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=noctis-web

[Install]
WantedBy=multi-user.target
EOF

    # DICOM receiver service
    cat > "${CONFIG_DIR}/systemd/noctis-dicom.service" << EOF
[Unit]
Description=NoctisPro PACS DICOM Receiver
After=network.target postgresql.service redis.service noctis-web.service
Wants=postgresql.service redis.service
Requires=noctis-web.service

[Service]
Type=simple
User=noctis
Group=noctis
WorkingDirectory=${PROJECT_DIR}
Environment=PATH=${python_path}/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
Environment=DEBUG=False
Environment=PYTHONPATH=${PROJECT_DIR}

ExecStart=${python_path}/bin/python dicom_receiver.py --port 11112 --aet NOCTIS_SCP

# Resource limits
LimitNOFILE=65536
MemoryMax=512M
MemoryHigh=400M

# Restart configuration
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=${PROJECT_DIR}
ProtectHome=true

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=noctis-dicom

[Install]
WantedBy=multi-user.target
EOF

    # Celery service (if system has enough resources)
    if [[ $memory_gb -ge 4 ]]; then
        local celery_workers=$((cpu_cores / 2))
        if [[ $celery_workers -lt 1 ]]; then
            celery_workers=1
        elif [[ $celery_workers -gt 4 ]]; then
            celery_workers=4
        fi
        
        cat > "${CONFIG_DIR}/systemd/noctis-celery.service" << EOF
[Unit]
Description=NoctisPro PACS Celery Worker
After=network.target postgresql.service redis.service noctis-web.service
Wants=postgresql.service redis.service
Requires=noctis-web.service

[Service]
Type=simple
User=noctis
Group=noctis
WorkingDirectory=${PROJECT_DIR}
Environment=PATH=${python_path}/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
Environment=DEBUG=False
Environment=PYTHONPATH=${PROJECT_DIR}

ExecStart=${python_path}/bin/celery -A noctis_pro worker \\
    --loglevel=info \\
    --concurrency=${celery_workers} \\
    --max-tasks-per-child=1000 \\
    --time-limit=300 \\
    --soft-time-limit=240

# Resource limits
LimitNOFILE=65536
$(if [[ $memory_gb -ge 8 ]]; then
    echo "MemoryMax=1G"
    echo "MemoryHigh=800M"
else
    echo "MemoryMax=512M"
    echo "MemoryHigh=400M"
fi)

# Restart configuration
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=${PROJECT_DIR}
ProtectHome=true

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=noctis-celery

[Install]
WantedBy=multi-user.target
EOF

        # Celery beat service for scheduled tasks
        cat > "${CONFIG_DIR}/systemd/noctis-celery-beat.service" << EOF
[Unit]
Description=NoctisPro PACS Celery Beat Scheduler
After=network.target postgresql.service redis.service noctis-web.service
Wants=postgresql.service redis.service
Requires=noctis-web.service

[Service]
Type=simple
User=noctis
Group=noctis
WorkingDirectory=${PROJECT_DIR}
Environment=PATH=${python_path}/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
Environment=DEBUG=False
Environment=PYTHONPATH=${PROJECT_DIR}

ExecStart=${python_path}/bin/celery -A noctis_pro beat --loglevel=info

# Resource limits
LimitNOFILE=1024
MemoryMax=256M
MemoryHigh=200M

# Restart configuration
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=${PROJECT_DIR}
ProtectHome=true

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=noctis-celery-beat

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    success "Systemd services generated in ${CONFIG_DIR}/systemd/"
}

create_docker_configs() {
    local memory_gb=$1
    local cpu_cores=$2
    local deployment_mode=$3
    
    log "Generating Docker configurations..."
    
    mkdir -p "${CONFIG_DIR}/docker"
    
    # Generate optimized Dockerfile
    cat > "${CONFIG_DIR}/docker/Dockerfile.optimized" << EOF
# NoctisPro PACS - Optimized Multi-stage Dockerfile
FROM python:3.12-slim as base

# System dependencies
RUN apt-get update && apt-get install -y \\
    build-essential \\
    pkg-config \\
    libssl-dev \\
    libffi-dev \\
    libjpeg-dev \\
    libpng-dev \\
    libtiff-dev \\
    libwebp-dev \\
    zlib1g-dev \\
    libsqlite3-dev \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN groupadd -r noctis && useradd -r -g noctis noctis

# Set work directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.optimized.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip wheel setuptools && \\
    pip install --no-cache-dir -r requirements.optimized.txt

# Development stage
FROM base as development
ENV DEBUG=True
COPY . .
RUN chown -R noctis:noctis /app
USER noctis
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]

# Production stage
FROM base as production
ENV DEBUG=False
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Copy application code
COPY . .

# Collect static files
RUN python manage.py collectstatic --noinput

# Set proper ownership
RUN chown -R noctis:noctis /app

# Switch to non-root user
USER noctis

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \\
    CMD curl -f http://localhost:8000/health/ || exit 1

# Default command
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "${cpu_cores}", "noctis_pro.wsgi:application"]
EOF

    # Generate Docker Compose with resource limits
    local db_memory_limit="512m"
    local web_memory_limit="1g"
    local redis_memory_limit="256m"
    
    if [[ $memory_gb -ge 8 ]]; then
        db_memory_limit="1g"
        web_memory_limit="2g"
        redis_memory_limit="512m"
    elif [[ $memory_gb -ge 4 ]]; then
        db_memory_limit="512m"
        web_memory_limit="1g"
        redis_memory_limit="256m"
    else
        db_memory_limit="256m"
        web_memory_limit="512m"
        redis_memory_limit="128m"
    fi
    
    cat > "${CONFIG_DIR}/docker/docker-compose.optimized.yml" << EOF
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: noctis_db
    environment:
      POSTGRES_DB: noctis_pro
      POSTGRES_USER: noctis_user
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    ports:
      - "5432:5432"
    deploy:
      resources:
        limits:
          memory: ${db_memory_limit}
          cpus: '$(echo "scale=1; $cpu_cores * 0.3" | bc)'
        reservations:
          memory: $(echo $db_memory_limit | sed 's/[a-z]//g' | awk '{print int($1/2)}')m
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U noctis_user -d noctis_pro"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped
    networks:
      - noctis_network

  redis:
    image: redis:7-alpine
    container_name: noctis_redis
    command: redis-server --appendonly yes --maxmemory $(echo $redis_memory_limit | sed 's/m/mb/') --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    deploy:
      resources:
        limits:
          memory: ${redis_memory_limit}
          cpus: '0.5'
        reservations:
          memory: $(echo $redis_memory_limit | sed 's/[a-z]//g' | awk '{print int($1/2)}')m
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    networks:
      - noctis_network

  web:
    build:
      context: .
      dockerfile: deployment_configs/docker/Dockerfile.optimized
      target: production
    container_name: noctis_web
    environment:
      - DEBUG=False
      - SECRET_KEY=\${SECRET_KEY}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - POSTGRES_DB=noctis_pro
      - POSTGRES_USER=noctis_user
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
      - POSTGRES_HOST=db
      - POSTGRES_PORT=5432
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
    volumes:
      - media_files:/app/media
      - static_files:/app/staticfiles
      - ./logs:/app/logs
    ports:
      - "8000:8000"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: ${web_memory_limit}
          cpus: '$(echo "scale=1; $cpu_cores * 0.6" | bc)'
        reservations:
          memory: $(echo $web_memory_limit | sed 's/[a-z]//g' | awk '{print int($1/2)}')m
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    restart: unless-stopped
    networks:
      - noctis_network

  dicom_receiver:
    build:
      context: .
      dockerfile: deployment_configs/docker/Dockerfile.optimized
      target: production
    container_name: noctis_dicom
    environment:
      - DEBUG=False
      - SECRET_KEY=\${SECRET_KEY}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - POSTGRES_HOST=db
      - POSTGRES_PORT=5432
      - REDIS_URL=redis://redis:6379/0
    volumes:
      - media_files:/app/media
      - ./logs:/app/logs
    ports:
      - "11112:11112"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: 512m
          cpus: '1'
        reservations:
          memory: 256m
    command: python dicom_receiver.py --port 11112 --aet NOCTIS_SCP
    restart: unless-stopped
    networks:
      - noctis_network
EOF

    # Add Celery service for resource-sufficient systems
    if [[ $memory_gb -ge 4 ]]; then
        local celery_workers=$((cpu_cores / 2))
        [[ $celery_workers -lt 1 ]] && celery_workers=1
        [[ $celery_workers -gt 4 ]] && celery_workers=4
        
        cat >> "${CONFIG_DIR}/docker/docker-compose.optimized.yml" << EOF

  celery:
    build:
      context: .
      dockerfile: deployment_configs/docker/Dockerfile.optimized
      target: production
    container_name: noctis_celery
    environment:
      - DEBUG=False
      - SECRET_KEY=\${SECRET_KEY}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - POSTGRES_HOST=db
      - POSTGRES_PORT=5432
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
    volumes:
      - media_files:/app/media
      - ./logs:/app/logs
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: 512m
          cpus: '$(echo "scale=1; $cpu_cores * 0.4" | bc)'
        reservations:
          memory: 256m
    command: celery -A noctis_pro worker --loglevel=info --concurrency=${celery_workers}
    restart: unless-stopped
    networks:
      - noctis_network

  celery_beat:
    build:
      context: .
      dockerfile: deployment_configs/docker/Dockerfile.optimized
      target: production
    container_name: noctis_celery_beat
    environment:
      - DEBUG=False
      - SECRET_KEY=\${SECRET_KEY}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - POSTGRES_HOST=db
      - POSTGRES_PORT=5432
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
    volumes:
      - media_files:/app/media
      - ./logs:/app/logs
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: 256m
          cpus: '0.2'
        reservations:
          memory: 128m
    command: celery -A noctis_pro beat --loglevel=info
    restart: unless-stopped
    networks:
      - noctis_network
EOF
    fi
    
    # Add Nginx service if needed
    if [[ "$deployment_mode" == "docker_full" ]]; then
        cat >> "${CONFIG_DIR}/docker/docker-compose.optimized.yml" << EOF

  nginx:
    image: nginx:alpine
    container_name: noctis_nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./deployment_configs/nginx/nginx.optimized.conf:/etc/nginx/nginx.conf:ro
      - static_files:/var/www/static:ro
      - media_files:/var/www/media:ro
      - ./ssl:/etc/ssl:ro
    depends_on:
      - web
    deploy:
      resources:
        limits:
          memory: 256m
          cpus: '0.5'
        reservations:
          memory: 128m
    restart: unless-stopped
    networks:
      - noctis_network
EOF
    fi
    
    # Add volumes and networks
    cat >> "${CONFIG_DIR}/docker/docker-compose.optimized.yml" << EOF

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
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

    success "Docker configurations generated in ${CONFIG_DIR}/docker/"
}

create_environment_templates() {
    log "Generating environment configuration templates..."
    
    mkdir -p "${CONFIG_DIR}/env"
    
    # Development environment
    cat > "${CONFIG_DIR}/env/.env.development" << 'EOF'
# NoctisPro PACS - Development Environment Configuration

# Django Configuration
DEBUG=True
SECRET_KEY=dev-secret-key-change-in-production
DJANGO_SETTINGS_MODULE=noctis_pro.settings
ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0

# Database Configuration (SQLite for development)
DATABASE_URL=sqlite:///db.sqlite3

# Redis Configuration (optional for development)
REDIS_URL=redis://localhost:6379/0
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/0

# DICOM Configuration
DICOM_AET=NOCTIS_SCP
DICOM_PORT=11112

# Email Configuration (console backend for development)
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend

# Logging
LOG_LEVEL=DEBUG
EOF

    # Production environment template
    cat > "${CONFIG_DIR}/env/.env.production.template" << 'EOF'
# NoctisPro PACS - Production Environment Configuration Template
# Copy this file to .env.production and fill in the values

# Django Configuration
DEBUG=False
SECRET_KEY=CHANGE-THIS-TO-A-STRONG-SECRET-KEY-FOR-PRODUCTION
DJANGO_SETTINGS_MODULE=noctis_pro.settings
ALLOWED_HOSTS=your-domain.com,www.your-domain.com,localhost

# Database Configuration
POSTGRES_DB=noctis_pro
POSTGRES_USER=noctis_user
POSTGRES_PASSWORD=CHANGE-THIS-TO-A-STRONG-DATABASE-PASSWORD
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
DATABASE_URL=postgresql://noctis_user:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}

# Redis Configuration
REDIS_URL=redis://localhost:6379/0
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/0

# DICOM Configuration
DICOM_AET=NOCTIS_SCP
DICOM_PORT=11112
DICOM_EXTERNAL_ACCESS=True

# SSL/Security Configuration
SECURE_SSL_REDIRECT=True
SECURE_HSTS_SECONDS=31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS=True
SECURE_HSTS_PRELOAD=True
SECURE_CONTENT_TYPE_NOSNIFF=True
SECURE_BROWSER_XSS_FILTER=True
X_FRAME_OPTIONS=DENY

# Domain Configuration
DOMAIN_NAME=your-domain.com
LETSENCRYPT_EMAIL=your-email@example.com

# Email Configuration
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.your-provider.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@example.com
EMAIL_HOST_PASSWORD=your-email-password

# Logging
LOG_LEVEL=INFO
SENTRY_DSN=  # Optional: Add Sentry DSN for error tracking

# Backup Configuration
BACKUP_ENABLED=True
BACKUP_SCHEDULE=0 2 * * *  # Daily at 2 AM
BACKUP_RETENTION_DAYS=30
EOF

    # Docker environment
    cat > "${CONFIG_DIR}/env/.env.docker" << 'EOF'
# NoctisPro PACS - Docker Environment Configuration

# Django Configuration
DEBUG=False
SECRET_KEY=${SECRET_KEY:-generate-secret-key}
DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Database Configuration (Docker PostgreSQL)
POSTGRES_DB=noctis_pro
POSTGRES_USER=noctis_user
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-generate-password}
POSTGRES_HOST=db
POSTGRES_PORT=5432

# Redis Configuration (Docker Redis)
REDIS_URL=redis://redis:6379/0
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# DICOM Configuration
DICOM_AET=NOCTIS_SCP
DICOM_PORT=11112

# Build Configuration
BUILD_TARGET=production
COMPOSE_PROJECT_NAME=noctispro
EOF

    success "Environment templates generated in ${CONFIG_DIR}/env/"
}

create_monitoring_configs() {
    log "Generating monitoring and logging configurations..."
    
    mkdir -p "${CONFIG_DIR}/monitoring"
    
    # Logrotate configuration
    cat > "${CONFIG_DIR}/monitoring/noctis-logrotate" << 'EOF'
/opt/noctis/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 noctis noctis
    postrotate
        systemctl reload noctis-web noctis-dicom noctis-celery 2>/dev/null || true
    endscript
}
EOF

    # Health check script
    cat > "${CONFIG_DIR}/monitoring/health_check.sh" << 'EOF'
#!/bin/bash
# NoctisPro PACS Health Check Script

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}" >&2; }
error() { echo -e "${RED}[ERROR] $1${NC}" >&2; }

check_web_service() {
    if curl -f -s --max-time 10 "http://localhost:8000/health/" >/dev/null 2>&1; then
        log "✅ Web service: Healthy"
        return 0
    else
        error "❌ Web service: Unhealthy"
        return 1
    fi
}

check_dicom_port() {
    if timeout 5 bash -c "</dev/tcp/localhost/11112" >/dev/null 2>&1; then
        log "✅ DICOM port: Accessible"
        return 0
    else
        error "❌ DICOM port: Not accessible"
        return 1
    fi
}

check_database() {
    if command -v psql >/dev/null 2>&1; then
        if PGPASSWORD="${POSTGRES_PASSWORD:-}" psql -h localhost -U noctis_user -d noctis_pro -c "SELECT 1;" >/dev/null 2>&1; then
            log "✅ Database: Connected"
            return 0
        else
            error "❌ Database: Connection failed"
            return 1
        fi
    else
        warn "⚠️  Database: psql not available for testing"
        return 0
    fi
}

check_redis() {
    if command -v redis-cli >/dev/null 2>&1; then
        if redis-cli ping >/dev/null 2>&1; then
            log "✅ Redis: Connected"
            return 0
        else
            error "❌ Redis: Connection failed"
            return 1
        fi
    else
        warn "⚠️  Redis: redis-cli not available for testing"
        return 0
    fi
}

check_disk_space() {
    local usage=$(df /opt/noctis 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $usage -lt 90 ]]; then
        log "✅ Disk space: ${usage}% used"
        return 0
    else
        error "❌ Disk space: ${usage}% used (critical)"
        return 1
    fi
}

check_memory_usage() {
    local usage=$(free | grep '^Mem:' | awk '{print int($3/$2 * 100)}')
    if [[ $usage -lt 90 ]]; then
        log "✅ Memory usage: ${usage}%"
        return 0
    else
        warn "⚠️  Memory usage: ${usage}% (high)"
        return 1
    fi
}

main() {
    log "Starting NoctisPro health check..."
    
    local failed_checks=0
    
    check_web_service || ((failed_checks++))
    check_dicom_port || ((failed_checks++))
    check_database || ((failed_checks++))
    check_redis || ((failed_checks++))
    check_disk_space || ((failed_checks++))
    check_memory_usage || ((failed_checks++))
    
    if [[ $failed_checks -eq 0 ]]; then
        log "🎉 All health checks passed!"
        exit 0
    else
        error "❌ $failed_checks health check(s) failed"
        exit 1
    fi
}

main "$@"
EOF

    chmod +x "${CONFIG_DIR}/monitoring/health_check.sh"
    
    # Prometheus configuration (if monitoring is needed)
    cat > "${CONFIG_DIR}/monitoring/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "noctis_rules.yml"

scrape_configs:
  - job_name: 'noctis-web'
    static_configs:
      - targets: ['localhost:8000']
    metrics_path: '/metrics/'
    scrape_interval: 30s

  - job_name: 'noctis-system'
    static_configs:
      - targets: ['localhost:9100']
    scrape_interval: 30s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093
EOF

    success "Monitoring configurations generated in ${CONFIG_DIR}/monitoring/"
}

generate_all_configs() {
    local memory_gb=$1
    local cpu_cores=$2
    local deployment_mode=$3
    local python_path=$4
    local ssl_enabled=${5:-false}
    
    log "Generating all deployment configurations..."
    
    # Create base directory structure
    mkdir -p "${CONFIG_DIR}"/{nginx,systemd,docker,env,monitoring}
    
    # Generate configurations
    create_nginx_config "$memory_gb" "$cpu_cores" "$ssl_enabled"
    create_systemd_services "$memory_gb" "$cpu_cores" "$python_path"
    create_docker_configs "$memory_gb" "$cpu_cores" "$deployment_mode"
    create_environment_templates
    create_monitoring_configs
    
    # Create configuration summary
    cat > "${CONFIG_DIR}/README.md" << EOF
# NoctisPro PACS - Deployment Configurations

Generated configurations for system with:
- Memory: ${memory_gb}GB
- CPU Cores: ${cpu_cores}
- Deployment Mode: ${deployment_mode}
- Python Path: ${python_path}
- SSL Enabled: ${ssl_enabled}

## Directory Structure

- \`nginx/\` - Nginx reverse proxy configuration
- \`systemd/\` - Systemd service files for native deployment
- \`docker/\` - Docker and Docker Compose configurations
- \`env/\` - Environment configuration templates
- \`monitoring/\` - Health check and monitoring configurations

## Usage

### Docker Deployment
\`\`\`bash
cp deployment_configs/docker/docker-compose.optimized.yml .
cp deployment_configs/env/.env.docker .env
docker-compose -f docker-compose.optimized.yml up -d
\`\`\`

### Native Deployment
\`\`\`bash
sudo cp deployment_configs/systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable noctis-web noctis-dicom
sudo systemctl start noctis-web noctis-dicom
\`\`\`

### Nginx Setup
\`\`\`bash
sudo cp deployment_configs/nginx/nginx.optimized.conf /etc/nginx/sites-available/noctis
sudo ln -s /etc/nginx/sites-available/noctis /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
\`\`\`

## Health Monitoring
\`\`\`bash
./deployment_configs/monitoring/health_check.sh
\`\`\`

Generated on: $(date)
EOF
    
    success "All deployment configurations generated in ${CONFIG_DIR}/"
    success "Configuration summary: ${CONFIG_DIR}/README.md"
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    local memory_gb=${1:-4}
    local cpu_cores=${2:-2}
    local deployment_mode=${3:-"docker_minimal"}
    local python_path=${4:-"/opt/noctis/venv"}
    local ssl_enabled=${5:-false}
    
    echo ""
    echo "🔧 NoctisPro PACS - Deployment Configuration Generator"
    echo "===================================================="
    echo ""
    
    log "Generating deployment configurations for:"
    info "  Memory: ${memory_gb}GB"
    info "  CPU Cores: ${cpu_cores}"
    info "  Deployment Mode: ${deployment_mode}"
    info "  Python Path: ${python_path}"
    info "  SSL Enabled: ${ssl_enabled}"
    echo ""
    
    generate_all_configs "$memory_gb" "$cpu_cores" "$deployment_mode" "$python_path" "$ssl_enabled"
    
    echo ""
    success "🎉 Configuration generation complete!"
    success "📁 Configurations saved to: ${CONFIG_DIR}/"
    echo ""
    
    log "Next steps:"
    info "1. Review generated configurations in ${CONFIG_DIR}/"
    info "2. Copy appropriate configuration files to their destinations"
    info "3. Customize environment variables in .env files"
    info "4. Test configurations before production deployment"
}

# Handle command line arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi