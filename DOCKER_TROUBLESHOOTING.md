# 🐳 Docker Deployment Troubleshooting Guide

## Common Issues and Solutions

### 1. Docker Daemon Not Running

**Error**: `Cannot connect to the Docker daemon socket`

**Solutions**:
```bash
# For systemd systems
sudo systemctl start docker
sudo systemctl enable docker

# For non-systemd systems
sudo service docker start

# Manual start (container environments)
sudo dockerd --host=unix:///var/run/docker.sock &
```

### 2. Permission Denied Errors

**Error**: `permission denied while trying to connect to the Docker daemon socket`

**Solutions**:
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Then logout and login again, or use:
newgrp docker

# Or run with sudo
sudo docker-compose up -d
```

### 3. CUPS Library Missing

**Error**: `fatal error: cups/http.h: No such file or directory`

**Solution**: The Dockerfile has been updated to include CUPS libraries:
```dockerfile
RUN apt-get update && apt-get install -y \
    libcups2-dev \
    cups-common \
    # ... other dependencies
```

### 4. Python Dependencies Failing

**Error**: Various pip installation failures

**Solutions**:
```bash
# Update Dockerfile with fallback dependencies
RUN pip install -r requirements.txt || \
    pip install Django Pillow psycopg2-binary redis celery gunicorn \
    djangorestframework django-cors-headers channels daphne pydicom pynetdicom
```

### 5. YAML Syntax Errors in docker-compose.yml

**Error**: `yaml.scanner.ScannerError`

**Solutions**:
- Check indentation (use spaces, not tabs)
- Validate YAML syntax: `docker-compose config --quiet`
- Escape special characters in strings
- Use proper multiline string syntax

### 6. Database Connection Issues

**Error**: `could not connect to server: Connection refused`

**Solutions**:
```bash
# Check if PostgreSQL container is running
docker-compose ps

# Check PostgreSQL logs
docker-compose logs db

# Ensure proper environment variables
DB_HOST=db  # Not localhost in containers
DB_PORT=5432
```

### 7. Port Already in Use

**Error**: `port is already allocated`

**Solutions**:
```bash
# Find process using the port
sudo netstat -tlnp | grep :8000

# Kill the process
sudo kill -9 <PID>

# Or use different ports in docker-compose.yml
ports:
  - "8001:8000"  # Host:Container
```

## Fixed Docker Files

### 1. Updated Dockerfile
```dockerfile
FROM python:3.11-slim as base

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    libpq-dev \
    libjpeg-dev \
    zlib1g-dev \
    libopenjp2-7 \
    libssl-dev \
    libffi-dev \
    libxml2-dev \
    libxslt1-dev \
    libcups2-dev \
    cups-common \
    git \
    curl \
    wget \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd --create-home --shell /bin/bash app

# Set work directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip wheel setuptools && \
    pip install --no-cache-dir -r requirements.txt || \
    pip install --no-cache-dir Django Pillow psycopg2-binary redis celery gunicorn \
    djangorestframework django-cors-headers channels daphne pydicom pynetdicom

# Copy application code
COPY --chown=app:app . .

# Switch to app user
USER app

# Expose ports
EXPOSE 8000 11112

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health/ || exit 1

# Default command for production
CMD ["gunicorn", "noctis_pro.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4"]
```

### 2. Updated docker-compose.yml
```yaml
version: '3.8'

services:
  # PostgreSQL Database
  db:
    image: postgres:15-alpine
    container_name: noctis_db
    environment:
      POSTGRES_DB: noctis_pro
      POSTGRES_USER: noctis_user
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-noctis_secure_password}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U noctis_user -d noctis_pro"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: noctis_redis
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # Django Web Application
  web:
    build:
      context: .
      dockerfile: Dockerfile
      target: ${BUILD_TARGET:-production}
    container_name: noctis_web
    environment:
      - DEBUG=${DEBUG:-False}
      - SECRET_KEY=${SECRET_KEY:-your-secret-key-change-in-production}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - DB_ENGINE=django.db.backends.postgresql
      - DB_NAME=noctis_pro
      - DB_USER=noctis_user
      - DB_PASSWORD=${POSTGRES_PASSWORD:-noctis_secure_password}
      - DB_HOST=db
      - DB_PORT=5432
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
      - ALLOWED_HOSTS=*
    volumes:
      - .:/app
      - media_files:/app/media
      - static_files:/app/staticfiles
    ports:
      - "8000:8000"
      - "11112:11112"
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
      start_period: 40s
    restart: unless-stopped
    command: >
      sh -c "python manage.py migrate --noinput &&
             python manage.py collectstatic --noinput &&
             python -c \"from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').delete(); User.objects.create_superuser('admin', 'admin@noctispro.com', 'NoctisAdmin2024!'); print('✅ Admin user created')\" &&
             gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:8000 --workers 4 --timeout 120"

  # Celery Worker
  celery:
    build:
      context: .
      dockerfile: Dockerfile
      target: ${BUILD_TARGET:-production}
    container_name: noctis_celery
    environment:
      - DEBUG=${DEBUG:-False}
      - SECRET_KEY=${SECRET_KEY:-your-secret-key-change-in-production}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - DB_ENGINE=django.db.backends.postgresql
      - DB_NAME=noctis_pro
      - DB_USER=noctis_user
      - DB_PASSWORD=${POSTGRES_PASSWORD:-noctis_secure_password}
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
    command: celery -A noctis_pro worker --loglevel=info

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
  default:
    name: noctis_network
```

### 3. Environment File (.env)
```env
SECRET_KEY=noctis-secret-key-docker-deployment-2024
POSTGRES_PASSWORD=noctis_secure_password_2024
ADMIN_PASSWORD=NoctisAdmin2024!
DEBUG=False
BUILD_TARGET=production
```

## Deployment Commands

### Standard Docker Deployment
```bash
# Clean deployment
docker-compose down --remove-orphans -v
docker-compose build --no-cache
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f
```

### Alternative: Simple Deployment
If Docker issues persist, use the simple deployment script:
```bash
sudo ./deploy-simple.sh
```

This script:
- Installs system dependencies
- Sets up PostgreSQL and Redis
- Creates Python virtual environment
- Configures systemd services
- Sets up Nginx reverse proxy
- Creates Cloudflare tunnels

## Health Checks

### Application Health
```bash
curl http://localhost:8000/health/
```

### Database Health
```bash
# Docker
docker-compose exec db pg_isready -U noctis_user -d noctis_pro

# Simple deployment
sudo -u postgres psql -d noctis_pro -c "SELECT 1;"
```

### Redis Health
```bash
# Docker
docker-compose exec redis redis-cli ping

# Simple deployment
redis-cli ping
```

## Logs and Debugging

### Docker Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f web
docker-compose logs -f db
docker-compose logs -f redis
```

### Simple Deployment Logs
```bash
# Service logs
sudo journalctl -u noctis-web -f
sudo journalctl -u noctis-celery -f
sudo journalctl -u noctis-dicom -f

# Application logs
tail -f /tmp/noctis_simple_deploy_*.log
```

## Performance Optimization

### Docker Resources
Add to docker-compose.yml:
```yaml
services:
  web:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
```

### Database Tuning
```sql
-- Connect to PostgreSQL and run:
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
SELECT pg_reload_conf();
```

## Security Considerations

1. **Change default passwords** immediately
2. **Use strong SECRET_KEY** in production
3. **Enable SSL/TLS** with proper certificates
4. **Restrict network access** using firewall rules
5. **Regular updates** of Docker images and system packages
6. **Monitor logs** for suspicious activity

## Support

If you encounter issues not covered here:

1. Check the deployment logs
2. Verify all dependencies are installed
3. Ensure ports are not in use
4. Try the simple deployment as fallback
5. Review the health check endpoints

The simple deployment script (`deploy-simple.sh`) provides a reliable fallback when Docker-specific issues occur.