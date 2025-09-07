# 🐳 NoctisPro PACS - Docker Deployment Guide

## 🚀 Quick Start (One Command)

### Option 1: Super Simple One-Command Deploy
```bash
./deploy-one-command.sh
```

### Option 2: Full Featured Deploy
```bash
./docker-deploy.sh
```

### Option 3: Manual Docker Commands
```bash
# 1. Create environment
cat > .env << EOF
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
POSTGRES_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
ADMIN_PASSWORD=NoctisAdmin2024!
EOF

# 2. Deploy with Docker Compose
docker-compose up -d --build

# 3. Setup public URLs (optional)
cloudflared tunnel --url http://localhost:8000 &
cloudflared tunnel --url http://localhost:11112 &
```

## 📋 Prerequisites

### System Requirements
- **OS**: Ubuntu/Debian Linux (or any Docker-compatible system)
- **Memory**: 2GB+ RAM (4GB+ recommended)
- **Storage**: 5GB+ free space
- **Network**: Internet connection for Docker images

### Software Dependencies
- **Docker**: Will be installed automatically if missing
- **Docker Compose**: Will be installed automatically
- **Python 3**: For generating secure keys
- **curl**: For health checks

## 🐳 Docker Architecture

### Services Deployed
1. **PostgreSQL Database** (`db`)
   - Image: `postgres:15-alpine`
   - Database: `noctis_pro`
   - User: `noctis_user`
   - Port: 5432 (internal)

2. **Redis Cache** (`redis`)
   - Image: `redis:7-alpine`
   - Persistent storage with AOF
   - Port: 6379 (internal)

3. **Django Web Application** (`web`)
   - Built from project Dockerfile
   - Gunicorn WSGI server
   - Port: 8000 (exposed)

4. **DICOM Receiver** (`dicom`)
   - Same container as web app
   - DICOM SCP service
   - Port: 11112 (exposed)

5. **Celery Worker** (`celery`)
   - Background task processing
   - Connected to Redis broker

## 🔧 Configuration Files

### Docker Compose File (`docker-compose.yml`)
```yaml
version: '3.8'
services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: noctis_pro
      POSTGRES_USER: noctis_user
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U noctis_user -d noctis_pro"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  web:
    build: .
    environment:
      - DEBUG=False
      - SECRET_KEY=${SECRET_KEY}
      - DB_ENGINE=django.db.backends.postgresql
      - DB_NAME=noctis_pro
      - DB_USER=noctis_user
      - DB_PASSWORD=${POSTGRES_PASSWORD}
      - DB_HOST=db
      - DB_PORT=5432
      - REDIS_URL=redis://redis:6379/0
      - ALLOWED_HOSTS=*
    ports:
      - "8000:8000"
      - "11112:11112"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: >
      sh -c "python manage.py migrate --noinput &&
             python manage.py collectstatic --noinput &&
             python manage.py shell -c \"
from django.contrib.auth import get_user_model;
User = get_user_model();
User.objects.filter(username='admin').delete();
User.objects.create_superuser('admin', 'admin@noctispro.com', 'NoctisAdmin2024!');
print('✅ Admin created: admin/NoctisAdmin2024!')
\" &&
             gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:8000 --workers 4 &
             python dicom_receiver.py --port 11112 --aet NOCTIS_SCP --bind 0.0.0.0"
    restart: unless-stopped

  celery:
    build: .
    environment:
      - DEBUG=False
      - SECRET_KEY=${SECRET_KEY}
      - DB_ENGINE=django.db.backends.postgresql
      - DB_NAME=noctis_pro
      - DB_USER=noctis_user
      - DB_PASSWORD=${POSTGRES_PASSWORD}
      - DB_HOST=db
      - DB_PORT=5432
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: celery -A noctis_pro worker --loglevel=info --concurrency=4
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

### Environment File (`.env`)
```env
SECRET_KEY=your-generated-secret-key
POSTGRES_PASSWORD=your-generated-postgres-password
ADMIN_PASSWORD=NoctisAdmin2024!
```

### Dockerfile
```dockerfile
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

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

# Install Python dependencies
COPY requirements*.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy project
COPY . .

# Create directories
RUN mkdir -p logs media staticfiles

# Expose ports
EXPOSE 8000 11112

# Default command
CMD ["gunicorn", "noctis_pro.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4"]
```

## 🌐 Public URL Setup (Cloudflare Tunnel)

### Automatic Setup
The deployment scripts automatically set up Cloudflare tunnels for public access:

```bash
# Web application tunnel
cloudflared tunnel --url http://localhost:8000

# DICOM service tunnel  
cloudflared tunnel --url http://localhost:11112
```

### Manual Tunnel Setup
```bash
# Install cloudflared
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb

# Start tunnels
nohup cloudflared tunnel --url http://localhost:8000 > web_tunnel.log 2>&1 &
nohup cloudflared tunnel --url http://localhost:11112 > dicom_tunnel.log 2>&1 &

# Get URLs
grep "https://" web_tunnel.log
grep "https://" dicom_tunnel.log
```

## 🔧 Management Commands

### Basic Docker Operations
```bash
# View service status
docker-compose ps

# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f web
docker-compose logs -f db
docker-compose logs -f redis

# Restart services
docker-compose restart

# Stop services
docker-compose down

# Start services
docker-compose up -d

# Rebuild and restart
docker-compose up -d --build
```

### Database Operations
```bash
# Access PostgreSQL database
docker-compose exec db psql -U noctis_user -d noctis_pro

# Backup database
docker-compose exec db pg_dump -U noctis_user noctis_pro > backup.sql

# Restore database
docker-compose exec -T db psql -U noctis_user -d noctis_pro < backup.sql

# Check database size
docker-compose exec db psql -U noctis_user -d noctis_pro -c "SELECT pg_size_pretty(pg_database_size('noctis_pro'));"
```

### Redis Operations
```bash
# Access Redis CLI
docker-compose exec redis redis-cli

# Check Redis status
docker-compose exec redis redis-cli ping

# Monitor Redis activity
docker-compose exec redis redis-cli monitor

# Check Redis memory usage
docker-compose exec redis redis-cli info memory
```

### Application Operations
```bash
# Run Django management commands
docker-compose exec web python manage.py migrate
docker-compose exec web python manage.py collectstatic --noinput
docker-compose exec web python manage.py createsuperuser

# Access Django shell
docker-compose exec web python manage.py shell

# Check application health
curl http://localhost:8000/health/
```

## 📊 Monitoring and Health Checks

### Service Health
```bash
# Check all services
docker-compose ps

# Check web application
curl -f http://localhost:8000/

# Check DICOM port
telnet localhost 11112

# Check database
docker-compose exec db pg_isready -U noctis_user -d noctis_pro

# Check Redis
docker-compose exec redis redis-cli ping
```

### Resource Usage
```bash
# Check Docker resource usage
docker stats

# Check container sizes
docker images
docker system df

# Check logs size
docker-compose exec web du -sh logs/
```

## 🔐 Security Considerations

### Default Credentials
- **Admin Username**: admin
- **Admin Password**: NoctisAdmin2024!
- **Database Password**: Auto-generated secure password

### Security Best Practices
1. **Change default admin password** immediately after deployment
2. **Use strong passwords** for production deployments
3. **Enable SSL/TLS** for production use
4. **Restrict network access** using firewall rules
5. **Regular security updates** of Docker images
6. **Monitor logs** for suspicious activity

### Production Security Enhancements
```bash
# Change admin password
docker-compose exec web python manage.py changepassword admin

# Enable SSL in Django settings
# Set SECURE_SSL_REDIRECT=True in environment

# Use secrets management
# Store passwords in Docker secrets or external vault
```

## 🚀 Scaling and Performance

### Horizontal Scaling
```bash
# Scale web workers
docker-compose up -d --scale web=3

# Scale Celery workers
docker-compose up -d --scale celery=2
```

### Performance Tuning
```yaml
# Add resource limits to docker-compose.yml
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

### Database Optimization
```sql
-- Connect to database and run:
VACUUM ANALYZE;
REINDEX DATABASE noctis_pro;

-- Monitor performance
SELECT * FROM pg_stat_activity;
SELECT * FROM pg_stat_user_tables;
```

## 🐛 Troubleshooting

### Common Issues

#### Docker Issues
```bash
# Docker daemon not running
sudo systemctl start docker

# Permission denied
sudo usermod -aG docker $USER
# Then logout and login again

# Port already in use
sudo netstat -tlnp | grep :8000
sudo kill -9 <PID>
```

#### Database Issues
```bash
# Database connection failed
docker-compose logs db

# Reset database
docker-compose down -v
docker-compose up -d

# Check database logs
docker-compose exec db tail -f /var/log/postgresql/postgresql-*.log
```

#### Application Issues
```bash
# View application logs
docker-compose logs web

# Check Django configuration
docker-compose exec web python manage.py check

# Debug database connection
docker-compose exec web python manage.py dbshell
```

### Log Locations
- **Application logs**: `docker-compose logs web`
- **Database logs**: `docker-compose logs db`
- **Redis logs**: `docker-compose logs redis`
- **Celery logs**: `docker-compose logs celery`

## 📈 Backup and Recovery

### Database Backup
```bash
# Create backup
docker-compose exec db pg_dump -U noctis_user noctis_pro > noctis_backup_$(date +%Y%m%d).sql

# Automated backup script
#!/bin/bash
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
docker-compose exec db pg_dump -U noctis_user noctis_pro > "$BACKUP_DIR/noctis_$DATE.sql"
gzip "$BACKUP_DIR/noctis_$DATE.sql"
find "$BACKUP_DIR" -name "noctis_*.sql.gz" -mtime +7 -delete
```

### Full System Backup
```bash
# Backup volumes
docker run --rm -v noctis_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_data.tar.gz -C /data .
docker run --rm -v noctis_redis_data:/data -v $(pwd):/backup alpine tar czf /backup/redis_data.tar.gz -C /data .

# Backup application data
tar czf media_backup.tar.gz media/
tar czf logs_backup.tar.gz logs/
```

### Recovery
```bash
# Stop services
docker-compose down

# Restore database
docker-compose up -d db
docker-compose exec -T db psql -U noctis_user -d noctis_pro < backup.sql

# Restore volumes
docker run --rm -v noctis_postgres_data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres_data.tar.gz -C /data

# Start all services
docker-compose up -d
```

## 🎯 Production Deployment

### Production Checklist
- [ ] Change default passwords
- [ ] Configure SSL/TLS certificates
- [ ] Set up proper backup strategy
- [ ] Configure monitoring and alerting
- [ ] Set up log rotation
- [ ] Configure firewall rules
- [ ] Set up domain name and DNS
- [ ] Configure email settings
- [ ] Set up user authentication (LDAP/SSO)
- [ ] Performance testing
- [ ] Security audit

### Production Environment Variables
```env
DEBUG=False
SECRET_KEY=your-super-secure-secret-key
POSTGRES_PASSWORD=your-super-secure-db-password
ADMIN_PASSWORD=your-super-secure-admin-password
ALLOWED_HOSTS=your-domain.com,www.your-domain.com
SECURE_SSL_REDIRECT=True
SECURE_BROWSER_XSS_FILTER=True
SECURE_CONTENT_TYPE_NOSNIFF=True
EMAIL_HOST=your-smtp-server.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@domain.com
EMAIL_HOST_PASSWORD=your-email-password
```

---

## 🎉 Quick Start Summary

**For the fastest deployment, just run:**
```bash
./deploy-one-command.sh
```

**Then access your system at the provided URL with:**
- Username: `admin`
- Password: `NoctisAdmin2024!`

**Your NoctisPro PACS system will be running with:**
- ✅ PostgreSQL database (production-ready)
- ✅ Redis caching (high performance)
- ✅ Public URLs (no domain needed)
- ✅ DICOM receiver (medical imaging)
- ✅ Admin interface (full control)
- ✅ Background tasks (Celery workers)

**That's it! Your production-ready PACS system is deployed! 🚀**