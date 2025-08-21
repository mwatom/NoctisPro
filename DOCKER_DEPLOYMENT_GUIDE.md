# NOCTIS Pro - Docker Deployment Guide
## Ubuntu Desktop to Server Transfer Made Simple

This comprehensive guide helps you run NOCTIS Pro on Ubuntu Desktop and seamlessly transfer it to Ubuntu Server with minimal configuration changes.

## 🎯 Overview

NOCTIS Pro is a medical imaging platform that includes:
- **Django Web Application** with PostgreSQL database
- **Celery Background Processing** with Redis message broker
- **DICOM Medical Image Processing** services
- **File Storage** for media and medical images
- **Production Features** like Nginx, SSL, monitoring, and automated backups

## 🚀 Quick Start Options

### Option 1: Ubuntu Desktop Development (Recommended for Development)

```bash
# One-command setup
./scripts/quick-start-desktop.sh
```

### Option 2: Ubuntu Server Production (For Production Deployment)

```bash
# Server setup
./scripts/setup-ubuntu-server.sh

# Deploy production
./scripts/quick-deploy-server.sh
```

## 📋 Table of Contents

1. [Desktop Development Setup](#desktop-development-setup)
2. [Server Production Setup](#server-production-setup)
3. [Data Transfer Process](#data-transfer-process)
4. [Configuration Management](#configuration-management)
5. [Backup and Recovery](#backup-and-recovery)
6. [Monitoring and Maintenance](#monitoring-and-maintenance)
7. [Troubleshooting](#troubleshooting)

## 💻 Desktop Development Setup

### Prerequisites

- Ubuntu Desktop 18.04+ or 20.04+ (recommended)
- Docker and Docker Compose
- At least 4GB RAM and 20GB disk space
- Internet connection for pulling Docker images

### Step 1: Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose plugin
sudo apt install docker-compose-plugin

# Log out and back in to apply group changes
```

### Step 2: Setup Development Environment

```bash
# Clone your project
git clone <your-repository> noctis-pro
cd noctis-pro

# Quick start (automated)
./scripts/quick-start-desktop.sh

# OR Manual setup:
cp .env.desktop.example .env
nano .env  # Edit configuration
docker compose -f docker-compose.desktop.yml up -d
```

### Step 3: Access Your Application

- **Web Interface**: http://localhost:8000
- **Admin Panel**: http://localhost:8000/admin (admin/admin123)
- **Database**: localhost:5432 (for external tools)
- **DICOM Receiver**: Port 11112

### Development Features

- **Hot Reload**: Code changes reflected immediately
- **Debug Mode**: Detailed error messages and Django debug toolbar
- **Development Tools**: Optional Adminer (DB) and Redis Commander
- **All Ports Exposed**: Easy debugging and testing

## 🖥️ Server Production Setup

### Prerequisites

- Ubuntu Server 18.04+ or 20.04+ (recommended)
- Minimum 2GB RAM, 4GB recommended
- At least 50GB disk space
- Domain name pointed to server IP
- SSH access with sudo privileges

### Step 1: Initial Server Setup

```bash
# Run comprehensive server setup
./scripts/setup-ubuntu-server.sh
```

This script automatically:
- Updates system packages
- Installs Docker and essential tools
- Configures UFW firewall
- Sets up Fail2Ban security
- Configures SSL certificate automation
- Creates application directories
- Sets up log rotation and backups

### Step 2: Transfer Data from Desktop

```bash
# On desktop: Export data
./scripts/export-for-server.sh

# Transfer to server
scp noctis-export-*.tar.gz* user@your-server:/tmp/

# On server: Import data
./scripts/import-from-desktop.sh /tmp/noctis-export-*.tar.gz
```

### Step 3: Configure Production Environment

```bash
cd /opt/noctis
cp .env.server.example .env
nano .env  # Configure for your server
```

**Important settings to change:**
- `SECRET_KEY`: Generate a strong secret key
- `DOMAIN_NAME`: Your server's domain name
- `POSTGRES_PASSWORD`: Strong database password
- `LETSENCRYPT_EMAIL`: Your email for SSL certificates
- `ALLOWED_HOSTS`: Your domain and IP

### Step 4: Deploy Production

```bash
# Quick production deployment
./scripts/quick-deploy-server.sh

# OR Manual deployment:
docker compose -f docker-compose.production.yml up -d
sudo certbot --nginx  # Configure SSL
```

## 🔄 Data Transfer Process

### Desktop to Server Transfer

The transfer process preserves:
- **Complete database** with all user data
- **Media files** (uploaded documents, images)
- **DICOM storage** (medical imaging files)
- **Configuration files** and scripts
- **Application logs** for debugging

### Transfer Steps

1. **Export from Desktop**:
   ```bash
   ./scripts/export-for-server.sh
   ```
   Creates compressed archive with checksums

2. **Transfer to Server**:
   ```bash
   scp noctis-export-*.tar.gz* user@server:/tmp/
   ```

3. **Import on Server**:
   ```bash
   ./scripts/import-from-desktop.sh /tmp/noctis-export-*.tar.gz
   ```

4. **Configure and Deploy**:
   ```bash
   cp .env.server.example .env
   nano .env  # Configure production settings
   ./scripts/quick-deploy-server.sh
   ```

## ⚙️ Configuration Management

### Environment Files

| File | Purpose | Usage |
|------|---------|-------|
| `.env.desktop.example` | Desktop development template | Copy to `.env` for development |
| `.env.server.example` | Server production template | Copy to `.env` for production |
| `.env` | Active configuration | Used by Docker Compose |

### Docker Compose Files

| File | Purpose | Features |
|------|---------|----------|
| `docker-compose.desktop.yml` | Development environment | Hot reload, debug mode, exposed ports |
| `docker-compose.production.yml` | Production deployment | Security hardened, optimized, SSL ready |
| `docker-compose.yml` | Base configuration | Shared settings and services |

### Key Differences: Desktop vs Server

| Component | Desktop | Server |
|-----------|---------|---------|
| **Security** | Relaxed for development | Production hardened |
| **Ports** | All exposed | Only necessary ports |
| **SSL/TLS** | Disabled | Required with auto-renewal |
| **Debug Mode** | Enabled | Disabled |
| **File Permissions** | Permissive | Strict |
| **Monitoring** | Optional | Recommended |
| **Backups** | Manual | Automated |

## 💾 Backup and Recovery

### Automated Backups

Production servers automatically backup:
- PostgreSQL database (full dump + compressed)
- Redis data
- Media files and DICOM storage
- Configuration files
- Application logs
- System information

### Backup Commands

```bash
# Manual backup
./scripts/backup-system.sh

# List available backups
ls -la /opt/noctis/backups/

# Restore from backup
./scripts/restore-system.sh backup-file.tar.gz
```

### Backup Schedule

- **Frequency**: Daily at 2 AM (configurable)
- **Retention**: 30 days (configurable)
- **Location**: `/opt/noctis/backups/`
- **Format**: Compressed tar.gz with checksums

## 📊 Monitoring and Maintenance

### Health Monitoring

```bash
# Check service status
docker compose ps

# View logs
docker compose logs -f

# System resources
htop
docker stats

# Health endpoints
curl http://localhost:8000/health/
```

### Optional Monitoring Stack

Enable Prometheus + Grafana:
```bash
ENABLE_MONITORING=true docker compose --profile monitoring up -d
```

Access:
- **Prometheus**: http://your-server:9090
- **Grafana**: http://your-server:3000 (admin/admin123)

### Maintenance Tasks

- **Update containers**: `docker compose pull && docker compose up -d`
- **Clean unused images**: `docker system prune -a`
- **Rotate logs**: Automatic with logrotate
- **SSL renewal**: Automatic with certbot
- **Security updates**: Automatic with unattended-upgrades

## 🔧 Troubleshooting

### Common Issues

#### 1. Port Conflicts
```bash
# Check port usage
sudo netstat -tlnp | grep :8000

# Change ports in docker-compose.yml
ports:
  - "8001:8000"  # Change external port
```

#### 2. Permission Issues
```bash
# Fix data directory permissions
sudo chown -R $USER:$USER ./data/
chmod -R 755 ./data/
```

#### 3. Database Connection Failed
```bash
# Check database container
docker compose logs db

# Verify database is ready
docker compose exec db pg_isready -U noctis_user -d noctis_pro

# Reset database (⚠️  destroys data)
docker compose down
docker volume rm $(docker volume ls -q | grep postgres)
docker compose up -d
```

#### 4. SSL Certificate Issues
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates manually
sudo certbot renew --dry-run

# Fix nginx configuration
sudo nginx -t
sudo systemctl restart nginx
```

### Diagnostic Commands

```bash
# Container health
docker compose ps
docker compose logs service-name

# System resources
df -h          # Disk usage
free -h        # Memory usage
docker stats   # Container resources

# Network connectivity
curl -f http://localhost:8000/health/
telnet localhost 11112  # DICOM port

# Database diagnostics
docker compose exec db psql -U noctis_user -d noctis_pro -c "SELECT version();"
```

### Log Locations

- **Application logs**: `/opt/noctis/logs/`
- **Container logs**: `docker compose logs service-name`
- **Nginx logs**: `/var/log/nginx/`
- **System logs**: `/var/log/syslog`

## 📞 Support and Resources

### Getting Help

1. **Check logs first**: `docker compose logs -f`
2. **Verify configuration**: Review `.env` file settings
3. **Test connectivity**: Use diagnostic commands above
4. **Check documentation**: Review service-specific docs

### Useful Commands Reference

```bash
# Development
docker compose -f docker-compose.desktop.yml up -d     # Start dev
docker compose -f docker-compose.desktop.yml down      # Stop dev
docker compose -f docker-compose.desktop.yml logs -f   # View logs

# Production
docker compose -f docker-compose.production.yml up -d  # Start prod
docker compose -f docker-compose.production.yml down   # Stop prod
docker compose -f docker-compose.production.yml ps     # Status

# Maintenance
./scripts/backup-system.sh                             # Backup
./scripts/export-for-server.sh                         # Export
sudo certbot --nginx                                   # SSL setup
docker system prune -a                                 # Cleanup
```

### File Structure Overview

```
noctis-pro/
├── scripts/                    # Automation scripts
│   ├── quick-start-desktop.sh  # Desktop setup
│   ├── quick-deploy-server.sh  # Server deployment
│   ├── setup-ubuntu-server.sh # Server preparation
│   ├── export-for-server.sh   # Data export
│   ├── import-from-desktop.sh # Data import
│   └── backup-system.sh       # Backup automation
├── docker-compose.desktop.yml  # Development config
├── docker-compose.production.yml # Production config
├── .env.desktop.example        # Development env template
├── .env.server.example         # Production env template
├── Dockerfile                  # Development image
├── Dockerfile.production       # Production image
└── data/                       # Persistent data (runtime)
    ├── postgres/               # Database files
    ├── redis/                  # Redis data
    ├── media/                  # User uploads
    ├── dicom_storage/          # Medical images
    └── staticfiles/            # Web assets
```

---

## 🎉 Success!

You now have a complete Docker-based deployment system that:

✅ **Runs seamlessly** on Ubuntu Desktop for development  
✅ **Transfers easily** to Ubuntu Server for production  
✅ **Maintains data integrity** during migration  
✅ **Provides security** with SSL, firewall, and hardening  
✅ **Includes monitoring** and automated backups  
✅ **Requires minimal changes** between environments  

Your NOCTIS Pro medical imaging platform is ready for both development and production use!

---

*For additional support or custom configurations, refer to the individual script files which contain detailed documentation and error handling.*