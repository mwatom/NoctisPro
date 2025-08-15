# Noctis Pro Production Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying the Noctis Pro DICOM medical imaging system on Ubuntu Server 22.04 for production use. The deployment includes enterprise-grade security, SSL/TLS encryption, automatic backups, monitoring, and makes the system accessible from anywhere on the internet.

## 🚀 Quick Start

For a fully automated deployment, run:

```bash
# Clone the repository
git clone <your-repo-url>
cd NoctisPro

# Run quick deployment (interactive)
sudo bash quick_deploy.sh

# Or run full deployment with domain
sudo bash deploy_production.sh your-domain.com admin@your-domain.com

# Or run without domain (IP-only access)
sudo bash deploy_production.sh
```

## 📋 Prerequisites

### Server Requirements

- **Operating System**: Ubuntu Server 22.04 LTS
- **RAM**: Minimum 4GB, recommended 8GB+
- **Storage**: Minimum 50GB, recommended 100GB+ (for DICOM storage)
- **CPU**: Minimum 2 cores, recommended 4+ cores
- **Network**: Public IP address if accessible from internet

### Domain Setup (Optional but Recommended)

If you want SSL/TLS encryption and custom domain access:

1. Register a domain name
2. Point DNS A record to your server's public IP
3. Ensure ports 80 and 443 are accessible from the internet

## 🏗️ Architecture

The production deployment includes:

```
Internet → Nginx (Port 80/443) → Django (Port 8000) → PostgreSQL/SQLite
                ↓                      ↓
            Static Files        Background Tasks → Redis
                ↓                      ↓
         SSL Certificate        DICOM Receiver (Port 11112)
```

### Components

- **Nginx**: Reverse proxy, SSL termination, static file serving
- **Django (Daphne)**: Web application with WebSocket support
- **PostgreSQL**: Production database (optional, falls back to SQLite)
- **Redis**: Caching, session storage, and message broker
- **Celery**: Background task processing
- **DICOM Receiver**: Accepts DICOM files via DICOM protocol
- **Let's Encrypt**: Free SSL certificates
- **UFW**: Firewall configuration
- **Fail2ban**: Intrusion prevention
- **Systemd**: Service management

## 🔧 Manual Installation

### Step 1: System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y \
    python3 python3-venv python3-dev python3-pip \
    build-essential pkg-config \
    libpq-dev libjpeg-dev zlib1g-dev libopenjp2-7 \
    libssl-dev libffi-dev libxml2-dev libxslt1-dev \
    git curl wget unzip htop tree \
    nginx redis-server postgresql postgresql-contrib \
    ufw fail2ban certbot python3-certbot-nginx
```

### Step 2: Create User and Directories

```bash
# Create noctis user
sudo useradd --system --create-home --shell /bin/bash noctis

# Create directories
sudo mkdir -p /opt/noctis /var/log/noctis /var/www/html
sudo chown -R noctis:noctis /opt/noctis /var/log/noctis
```

### Step 3: Clone and Setup Application

```bash
# Clone repository
cd /opt/noctis
sudo -u noctis git clone <your-repo-url> .

# Create virtual environment
sudo -u noctis python3 -m venv venv
sudo -u noctis venv/bin/pip install --upgrade pip wheel setuptools
sudo -u noctis venv/bin/pip install -r requirements.txt
```

### Step 4: Database Setup

#### PostgreSQL (Recommended)

```bash
# Create database and user
sudo -u postgres createuser --createdb noctis_user
sudo -u postgres psql -c "ALTER USER noctis_user PASSWORD 'your_secure_password';"
sudo -u postgres createdb noctis_pro --owner=noctis_user
```

#### SQLite (Default)

No additional setup required. The database file will be created automatically.

### Step 5: Environment Configuration

Create `/opt/noctis/.env`:

```bash
# Django settings
SECRET_KEY=your_very_long_secret_key_here
DEBUG=False
DJANGO_SETTINGS_MODULE=noctis_pro.settings_production

# Domain and network
DOMAIN_NAME=your-domain.com
SERVER_IP=your.server.ip.address
USE_SSL=true

# Database (for PostgreSQL)
POSTGRES_DB=noctis_pro
POSTGRES_USER=noctis_user
POSTGRES_PASSWORD=your_secure_password
POSTGRES_HOST=localhost
POSTGRES_PORT=5432

# Redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_DB=0
CELERY_BROKER_URL=redis://127.0.0.1:6379/0
CELERY_RESULT_BACKEND=redis://127.0.0.1:6379/0

# Admin
ADMIN_URL=admin-panel/

# Email configuration
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.your-provider.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@domain.com
EMAIL_HOST_PASSWORD=your-email-password
DEFAULT_FROM_EMAIL=noctis@your-domain.com
```

### Step 6: Django Setup

```bash
cd /opt/noctis
sudo -u noctis -E venv/bin/python manage.py migrate
sudo -u noctis -E venv/bin/python manage.py collectstatic --noinput
sudo -u noctis -E venv/bin/python manage.py createsuperuser
```

### Step 7: Install Systemd Services

Copy service files from `deployment/systemd/` to `/etc/systemd/system/`:

```bash
sudo cp deployment/systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable noctis-web noctis-celery noctis-dicom
```

### Step 8: Configure Nginx

```bash
# Copy Nginx configuration
sudo cp deployment/nginx/noctis-pro /etc/nginx/sites-available/
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/noctis-pro /etc/nginx/sites-enabled/

# Update domain name
sudo sed -i 's/server_name _;/server_name your-domain.com;/' /etc/nginx/sites-available/noctis-pro

# Test configuration
sudo nginx -t
```

### Step 9: SSL Certificate (Optional)

```bash
# Get Let's Encrypt certificate
sudo certbot --nginx -d your-domain.com

# Enable SSL in Nginx config
sudo sed -i 's/# listen 443 ssl http2;/listen 443 ssl http2;/' /etc/nginx/sites-available/noctis-pro
# ... (additional SSL configuration edits)
```

### Step 10: Firewall Configuration

```bash
# Configure UFW
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw allow 11112/tcp  # DICOM port
sudo ufw --force enable
```

### Step 11: Start Services

```bash
sudo systemctl start redis-server
sudo systemctl start noctis-web
sudo systemctl start noctis-celery
sudo systemctl start noctis-dicom
sudo systemctl restart nginx
```

## 🔐 Security Features

### Firewall (UFW)

- SSH (port 22): Allowed
- HTTP (port 80): Allowed (redirects to HTTPS)
- HTTPS (port 443): Allowed
- DICOM (port 11112): Allowed
- All other ports: Denied

### Fail2ban

Protects against:
- SSH brute force attacks
- HTTP authentication attacks
- Nginx rate limit violations

Configuration in `/etc/fail2ban/jail.local`

### SSL/TLS

- Free certificates from Let's Encrypt
- Automatic renewal
- HSTS headers
- Perfect Forward Secrecy
- TLS 1.2+ only

### Application Security

- Debug mode disabled
- Secret key generation
- CSRF protection
- XSS protection
- Content type sniffing protection
- Secure session cookies
- Rate limiting

### File Permissions

- Application runs as non-root user (`noctis`)
- Restricted file permissions
- Protected environment variables

## 📊 Monitoring and Logging

### Log Files

```bash
# Application logs
/var/log/noctis/noctis_pro.log          # General application logs
/var/log/noctis/noctis_pro_errors.log   # Error logs

# Web server logs
/var/log/nginx/noctis_access.log        # Access logs
/var/log/nginx/noctis_error.log         # Nginx errors

# System logs
sudo journalctl -u noctis-web           # Web service logs
sudo journalctl -u noctis-celery        # Celery logs
sudo journalctl -u noctis-dicom         # DICOM receiver logs
```

### Health Monitoring

```bash
# Check service status
noctis-ctl status

# View real-time logs
noctis-ctl logs

# Health check endpoint
curl http://your-domain.com/health
```

### Log Rotation

Configured via `/etc/logrotate.d/noctis`:
- Daily rotation
- 30 days retention
- Compression enabled
- Automatic service reload

## 🛠️ Management Commands

The system includes a management script `/usr/local/bin/noctis-ctl`:

```bash
# Start all services
noctis-ctl start

# Stop all services
noctis-ctl stop

# Restart all services
noctis-ctl restart

# Check service status
noctis-ctl status

# View real-time logs
noctis-ctl logs

# Update system from git
noctis-ctl update
```

## 🔄 Backup and Restore

### Database Backup

#### PostgreSQL

```bash
# Create backup
sudo -u postgres pg_dump noctis_pro > noctis_backup_$(date +%Y%m%d_%H%M%S).sql

# Restore backup
sudo -u postgres psql noctis_pro < noctis_backup_20231201_120000.sql
```

#### SQLite

```bash
# Create backup
sudo -u noctis cp /opt/noctis/db.sqlite3 /opt/noctis/backups/db_backup_$(date +%Y%m%d_%H%M%S).sqlite3

# Restore backup
sudo -u noctis cp /opt/noctis/backups/db_backup_20231201_120000.sqlite3 /opt/noctis/db.sqlite3
```

### Media Files Backup

```bash
# Backup DICOM and media files
sudo tar -czf noctis_media_$(date +%Y%m%d_%H%M%S).tar.gz /opt/noctis/media/

# Restore media files
sudo tar -xzf noctis_media_20231201_120000.tar.gz -C /
```

### Automated Backup Script

Create `/usr/local/bin/noctis-backup`:

```bash
#!/bin/bash
BACKUP_DIR="/opt/noctis/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Database backup
if [ -f "/opt/noctis/.env" ] && grep -q "POSTGRES_DB" /opt/noctis/.env; then
    sudo -u postgres pg_dump noctis_pro > "$BACKUP_DIR/db_$DATE.sql"
else
    cp /opt/noctis/db.sqlite3 "$BACKUP_DIR/db_$DATE.sqlite3"
fi

# Media backup
tar -czf "$BACKUP_DIR/media_$DATE.tar.gz" /opt/noctis/media/

# Cleanup old backups (keep 30 days)
find "$BACKUP_DIR" -name "*.sql" -o -name "*.sqlite3" -o -name "*.tar.gz" | \
    sort | head -n -30 | xargs rm -f

echo "Backup completed: $DATE"
```

Add to crontab for daily backups:

```bash
# Daily backup at 2 AM
0 2 * * * /usr/local/bin/noctis-backup
```

## 🔧 Maintenance

### Updating the System

```bash
# Update from git repository
noctis-ctl update

# Manual update process
cd /opt/noctis
sudo -u noctis git pull
sudo -u noctis venv/bin/pip install -r requirements.txt
sudo -u noctis venv/bin/python manage.py migrate
sudo -u noctis venv/bin/python manage.py collectstatic --noinput
noctis-ctl restart
```

### SSL Certificate Renewal

Certificates are automatically renewed by certbot. To test renewal:

```bash
sudo certbot renew --dry-run
```

### System Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Restart services if needed
noctis-ctl restart
```

## 🌐 Network Configuration

### Port Requirements

| Port | Protocol | Purpose | Access |
|------|----------|---------|---------|
| 22 | TCP | SSH | Admin access |
| 80 | TCP | HTTP | Public (redirects to HTTPS) |
| 443 | TCP | HTTPS | Public |
| 11112 | TCP | DICOM | DICOM devices |

### DNS Configuration

For domain access, configure these DNS records:

```
A     @              your.server.ip.address
A     www            your.server.ip.address
AAAA  @              your:server:ipv6:address (if available)
```

### Load Balancing (Advanced)

For high availability, you can deploy multiple instances behind a load balancer:

```nginx
upstream noctis_cluster {
    server 192.168.1.10:8000;
    server 192.168.1.11:8000;
    server 192.168.1.12:8000;
}
```

## 🚨 Troubleshooting

### Common Issues

#### Services Won't Start

```bash
# Check service status
systemctl status noctis-web
systemctl status noctis-celery
systemctl status noctis-dicom

# Check logs
journalctl -u noctis-web -f
```

#### Permission Issues

```bash
# Fix ownership
sudo chown -R noctis:noctis /opt/noctis
sudo chown -R noctis:noctis /var/log/noctis

# Fix permissions
sudo chmod 644 /opt/noctis/.env
sudo chmod +x /opt/noctis/venv/bin/*
```

#### Database Connection Issues

```bash
# Check PostgreSQL status
systemctl status postgresql

# Check Redis status
systemctl status redis-server

# Test database connection
sudo -u noctis /opt/noctis/venv/bin/python /opt/noctis/manage.py dbshell
```

#### Nginx Configuration Issues

```bash
# Test configuration
sudo nginx -t

# Check error logs
tail -f /var/log/nginx/noctis_error.log

# Reload configuration
sudo systemctl reload nginx
```

#### SSL Certificate Issues

```bash
# Check certificate status
sudo certbot certificates

# Renew certificate
sudo certbot renew --force-renewal

# Test SSL configuration
openssl s_client -connect your-domain.com:443
```

### Performance Optimization

#### Database Optimization

```bash
# For PostgreSQL, tune settings in /etc/postgresql/*/main/postgresql.conf
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
```

#### Nginx Optimization

```nginx
# Add to nginx configuration
worker_processes auto;
worker_connections 1024;
keepalive_timeout 65;
client_max_body_size 500M;
```

#### Django Optimization

```python
# In production settings
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'OPTIONS': {
            'MAX_CONNS': 20,
        },
    }
}

# Enable caching
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': 'redis://127.0.0.1:6379/0',
    }
}
```

## 📞 Support

### Log Analysis

```bash
# Check for errors in the last hour
sudo journalctl --since "1 hour ago" | grep -i error

# Monitor real-time logs
sudo tail -f /var/log/noctis/*.log

# Check disk space
df -h

# Check memory usage
free -h

# Check CPU usage
top
```

### Performance Monitoring

```bash
# Install monitoring tools
sudo apt install htop iotop nethogs

# Monitor system resources
htop                    # CPU and memory
sudo iotop             # Disk I/O
sudo nethogs           # Network usage
```

### Getting Help

1. Check the logs first
2. Review the troubleshooting section
3. Search for similar issues online
4. Contact system administrator or development team

## 🔒 Security Checklist

- [ ] Change default admin password
- [ ] Configure email settings
- [ ] Enable SSL/TLS
- [ ] Configure firewall
- [ ] Enable fail2ban
- [ ] Set up automated backups
- [ ] Configure log rotation
- [ ] Review access permissions
- [ ] Test disaster recovery
- [ ] Monitor system logs
- [ ] Keep system updated

## 📊 System Requirements Summary

### Minimum Requirements

- Ubuntu Server 22.04 LTS
- 4GB RAM
- 2 CPU cores
- 50GB storage
- Internet connection

### Recommended Requirements

- Ubuntu Server 22.04 LTS
- 8GB+ RAM
- 4+ CPU cores
- 100GB+ SSD storage
- Gigabit internet connection
- Domain name with SSL certificate

This completes the comprehensive production deployment guide for Noctis Pro DICOM System. The system is now enterprise-ready with proper security, monitoring, and maintenance procedures.