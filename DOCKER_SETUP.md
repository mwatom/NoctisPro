# Running Noctis Pro with Docker

This guide explains how to run the Noctis Pro DICOM medical imaging system using Docker and Docker Compose.

## 🐳 Prerequisites

- Docker Engine 20.10+ or Docker Desktop
- Docker Compose 2.0+
- At least 4GB RAM available for containers
- 20GB+ free disk space

### Install Docker (Ubuntu/Debian)

```bash
# Update packages
sudo apt update

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

## 🚀 Quick Start

1. **Clone and navigate to the project:**
   ```bash
   git clone <your-repo-url>
   cd NoctisPro
   ```

2. **Copy the environment file:**
   ```bash
   cp .env.docker .env
   ```

3. **Start the system:**
   ```bash
   docker compose up -d
   ```

4. **Access the application:**
   - Web Interface: http://localhost:8000
   - Admin Panel: http://localhost:8000/admin-panel/
   - Worklist: http://localhost:8000/worklist/

## 📁 Docker Files Overview

- `Dockerfile` - Multi-stage Docker image for the application
- `docker-compose.yml` - Orchestration for all services
- `.env.docker` - Environment configuration template
- `.dockerignore` - Files to exclude from Docker build

## 🏗️ Architecture

The Docker setup includes these services:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Nginx         │    │   Django Web    │    │   PostgreSQL    │
│   (Port 80/443) │◄───┤   (Port 8000)   │◄───┤   Database      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Celery        │    │   Redis         │
                       │   Worker        │◄───┤   (Port 6379)   │
                       └─────────────────┘    └─────────────────┘
                                │
                       ┌─────────────────┐
                       │   DICOM         │
                       │   Receiver      │
                       │   (Port 11112)  │
                       └─────────────────┘
```

### Services Description

| Service | Purpose | Port | Dependencies |
|---------|---------|------|--------------|
| **db** | PostgreSQL database | 5432 | - |
| **redis** | Cache & message broker | 6379 | - |
| **web** | Django web application | 8000 | db, redis |
| **celery** | Background task worker | - | db, redis |
| **dicom_receiver** | DICOM file receiver | 11112 | db, redis |
| **nginx** | Reverse proxy (production) | 80, 443 | web |

## 🔧 Configuration

### Environment Variables

Copy `.env.docker` to `.env` and customize:

```bash
cp .env.docker .env
```

Key variables to modify:

```bash
# Security (REQUIRED for production)
SECRET_KEY=your-very-long-secret-key-here
POSTGRES_PASSWORD=secure-database-password

# Admin user
ADMIN_USER=admin
ADMIN_EMAIL=admin@example.com
ADMIN_PASS=secure-admin-password

# Build target
BUILD_TARGET=development  # or 'production'
```

### Production Configuration

For production deployment:

1. **Update environment:**
   ```bash
   # In .env file
   DEBUG=False
   BUILD_TARGET=production
   SECRET_KEY=your-production-secret-key
   POSTGRES_PASSWORD=secure-production-password
   ```

2. **Enable Nginx:**
   ```bash
   docker compose --profile production up -d
   ```

## 📋 Common Commands

### Starting the System

```bash
# Start all services (detached)
docker compose up -d

# Start with logs visible
docker compose up

# Start specific services
docker compose up web db redis
```

### Managing the System

```bash
# Stop all services
docker compose down

# Stop and remove volumes (⚠️ deletes data)
docker compose down -v

# Restart services
docker compose restart

# View logs
docker compose logs -f

# View logs for specific service
docker compose logs -f web
```

### Development Tasks

```bash
# Django management commands
docker compose exec web python manage.py migrate
docker compose exec web python manage.py createsuperuser
docker compose exec web python manage.py collectstatic

# Access Django shell
docker compose exec web python manage.py shell

# Access database
docker compose exec db psql -U noctis_user -d noctis_pro

# Access Redis CLI
docker compose exec redis redis-cli
```

### Building and Updates

```bash
# Rebuild images (after code changes)
docker compose build

# Rebuild and start
docker compose up --build -d

# Pull latest base images
docker compose pull

# View container status
docker compose ps
```

## 🔍 Troubleshooting

### Common Issues

#### Services Won't Start

```bash
# Check service status
docker compose ps

# View logs for errors
docker compose logs web
docker compose logs db

# Check if ports are already in use
netstat -tulpn | grep :8000
```

#### Database Connection Issues

```bash
# Ensure database is ready
docker compose exec db pg_isready -U noctis_user

# Check database logs
docker compose logs db

# Reset database (⚠️ deletes all data)
docker compose down -v
docker compose up -d
```

#### Permission Issues

```bash
# Fix file permissions
sudo chown -R $USER:$USER .

# Rebuild with no cache
docker compose build --no-cache
```

#### Out of Disk Space

```bash
# Clean up Docker system
docker system prune -f

# Remove unused volumes
docker volume prune -f

# Remove unused images
docker image prune -a -f
```

### Useful Debug Commands

```bash
# Access container shell
docker compose exec web bash
docker compose exec db bash

# Check container resources
docker stats

# Inspect container configuration
docker compose config

# Check Docker daemon logs
journalctl -u docker.service -f
```

## 📊 Monitoring and Health Checks

### Health Status

```bash
# Check all service health
docker compose ps

# Individual health checks
curl http://localhost:8000/health/
docker compose exec redis redis-cli ping
docker compose exec db pg_isready -U noctis_user
```

### Log Monitoring

```bash
# Real-time logs for all services
docker compose logs -f

# Specific service logs
docker compose logs -f web
docker compose logs -f celery

# Log files in containers
docker compose exec web tail -f /app/noctis_pro.log
```

### Resource Usage

```bash
# Container resource usage
docker stats

# Disk usage
docker system df

# Volume usage
docker volume ls
du -sh $(docker volume inspect noctispro_postgres_data | jq -r '.[0].Mountpoint')
```

## 🔐 Security Considerations

### Production Security

1. **Change default passwords:**
   ```bash
   # Update in .env file
   SECRET_KEY=your-unique-secret-key
   POSTGRES_PASSWORD=secure-password
   ADMIN_PASS=secure-admin-password
   ```

2. **Use environment-specific files:**
   ```bash
   # Create production environment file
   cp .env.docker .env.production
   # Edit .env.production with production values
   ```

3. **Secure file permissions:**
   ```bash
   chmod 600 .env*
   ```

4. **Enable SSL (production):**
   ```bash
   # Configure SSL certificates in nginx configuration
   # Update docker-compose.yml with SSL settings
   ```

## 📦 Backup and Restore

### Database Backup

```bash
# Create backup
docker compose exec db pg_dump -U noctis_user noctis_pro > backup.sql

# Restore backup
docker compose exec -T db psql -U noctis_user noctis_pro < backup.sql
```

### Media Files Backup

```bash
# Backup media files
docker run --rm -v noctispro_media_files:/data -v $(pwd):/backup alpine tar czf /backup/media-backup.tar.gz /data

# Restore media files
docker run --rm -v noctispro_media_files:/data -v $(pwd):/backup alpine tar xzf /backup/media-backup.tar.gz -C /
```

### Complete System Backup

```bash
#!/bin/bash
# backup-noctis.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./backups/$DATE"

mkdir -p "$BACKUP_DIR"

# Database backup
docker compose exec db pg_dump -U noctis_user noctis_pro > "$BACKUP_DIR/database.sql"

# Media files backup
docker run --rm -v noctispro_media_files:/data -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/media.tar.gz /data

# Configuration backup
cp .env "$BACKUP_DIR/"
cp docker-compose.yml "$BACKUP_DIR/"

echo "Backup completed: $BACKUP_DIR"
```

## 🚀 Performance Optimization

### Production Optimizations

1. **Resource limits in docker-compose.yml:**
   ```yaml
   services:
     web:
       deploy:
         resources:
           limits:
             memory: 2G
             cpus: '1.0'
   ```

2. **Database tuning:**
   ```yaml
   services:
     db:
       command: >
         postgres
         -c shared_buffers=256MB
         -c effective_cache_size=1GB
         -c work_mem=4MB
   ```

3. **Redis optimization:**
   ```yaml
   services:
     redis:
       command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
   ```

## 📞 Support

### Getting Help

1. **Check logs first:**
   ```bash
   docker compose logs -f
   ```

2. **Verify configuration:**
   ```bash
   docker compose config
   ```

3. **Test connectivity:**
   ```bash
   curl -f http://localhost:8000/health/
   ```

4. **Common log locations:**
   - Application: `docker compose logs web`
   - Database: `docker compose logs db`
   - Background tasks: `docker compose logs celery`
   - DICOM receiver: `docker compose logs dicom_receiver`

### Useful Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Django Docker Guide](https://docs.djangoproject.com/en/stable/howto/deployment/)

---

**Note:** This Docker setup is configured for both development and production use. Make sure to review and customize the configuration for your specific environment and security requirements.