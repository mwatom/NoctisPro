# Noctis Pro DICOM System - Ubuntu 24.04 Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying the Noctis Pro DICOM medical imaging system on fresh Ubuntu 24.04 servers. Two deployment options are available:

1. **Native Deployment** - Direct installation with systemd services
2. **Docker Deployment** - Containerized deployment with Docker Compose

Both options provide production-ready deployments with security, monitoring, and backup capabilities.

## 🚀 Quick Start Options

### Option 1: Native Deployment (Recommended for Production)

```bash
# Clone the repository to your server
git clone <your-repo-url>
cd noctis-system

# Run native deployment
sudo bash deploy_ubuntu24.sh [domain_name] [admin_email]

# Examples:
sudo bash deploy_ubuntu24.sh                                    # Local IP only
sudo bash deploy_ubuntu24.sh example.com admin@example.com      # With domain and SSL
```

### Option 2: Docker Deployment (Recommended for Development/Testing)

```bash
# Clone the repository to your server
git clone <your-repo-url>
cd noctis-system

# Run Docker deployment
sudo bash deploy_docker_ubuntu24.sh [domain_name] [admin_email]

# Examples:
sudo bash deploy_docker_ubuntu24.sh                             # Local IP only
sudo bash deploy_docker_ubuntu24.sh example.com admin@example.com # With domain and SSL
```

## 📋 Prerequisites

### Server Requirements

- **Operating System**: Ubuntu 24.04 LTS (fresh installation)
- **RAM**: Minimum 4GB, recommended 8GB+
- **Storage**: Minimum 50GB, recommended 100GB+ (for DICOM storage)
- **CPU**: Minimum 2 cores, recommended 4+ cores
- **Network**: Stable internet connection
- **Optional**: Public IP address and domain name for SSL/external access

### Before You Begin

1. **Update your server**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Ensure you have sudo privileges**:
   ```bash
   sudo whoami  # Should return 'root'
   ```

3. **Optional - Set up a domain name**:
   - Point your domain's A record to your server's public IP
   - Ensure ports 80 and 443 are accessible from the internet

## 🏗️ Native Deployment (Option 1)

### What Gets Installed

- PostgreSQL 16 database with optimizations
- Redis server for caching and message queuing
- Python 3.11 virtual environment with all dependencies
- Nginx reverse proxy with security headers
- Systemd services for Django, Celery, and DICOM receiver
- UFW firewall configuration
- Fail2ban for intrusion prevention
- Let's Encrypt SSL certificates (if domain provided)
- Automatic backup system
- Log rotation and monitoring

### Installation Process

```bash
# From the project directory
sudo bash deploy_ubuntu24.sh

# With domain and email for SSL
sudo bash deploy_ubuntu24.sh yourdomain.com admin@yourdomain.com
```

### What Happens During Installation

1. **System Update**: Updates all packages to latest versions
2. **Dependencies**: Installs Python, PostgreSQL, Redis, Nginx, and system libraries
3. **Firewall**: Configures UFW with necessary ports
4. **Database**: Sets up PostgreSQL with optimized configuration
5. **Application**: Creates dedicated user, virtual environment, and application structure
6. **Services**: Creates and starts systemd services
7. **Web Server**: Configures Nginx with security headers
8. **SSL**: Obtains Let's Encrypt certificate (if domain provided)
9. **Security**: Sets up Fail2ban and hardens configuration
10. **Backups**: Creates automated backup system

### Post-Installation Structure

```
/opt/noctis/
├── source/           # Application code
├── venv/            # Python virtual environment
├── media/           # Uploaded files
├── staticfiles/     # Static web assets
├── .env             # Environment configuration
├── status.sh        # System status script
├── restart.sh       # Service restart script
├── update.sh        # Update script
└── backup.sh        # Backup script

/var/log/noctis/     # Application logs
/opt/backups/noctis/ # Automated backups
```

### Service Management

```bash
# Check status
sudo systemctl status noctis-web noctis-celery noctis-dicom

# Start services
sudo systemctl start noctis-web noctis-celery noctis-dicom

# Stop services
sudo systemctl stop noctis-web noctis-celery noctis-dicom

# Restart services
sudo systemctl restart noctis-web noctis-celery noctis-dicom

# View logs
sudo journalctl -u noctis-web -f
sudo journalctl -u noctis-celery -f
sudo journalctl -u noctis-dicom -f
```

## 🐳 Docker Deployment (Option 2)

### What Gets Installed

- Docker Engine and Docker Compose
- PostgreSQL 16 container with optimizations
- Redis container with production configuration
- Django web application container
- Celery worker and beat scheduler containers
- DICOM receiver container
- Nginx reverse proxy container
- Optional monitoring stack (Prometheus + Grafana)
- Automated backup container

### Installation Process

```bash
# From the project directory
sudo bash deploy_docker_ubuntu24.sh

# With domain and email for SSL
sudo bash deploy_docker_ubuntu24.sh yourdomain.com admin@yourdomain.com
```

### What Happens During Installation

1. **System Update**: Updates all packages
2. **Docker Installation**: Installs Docker Engine and Compose
3. **Firewall**: Configures UFW firewall
4. **Project Setup**: Copies files to `/opt/noctis`
5. **Configuration**: Creates environment and Docker configs
6. **Container Build**: Builds application containers
7. **Service Start**: Starts all containers
8. **SSL Setup**: Configures SSL if domain provided
9. **Management Scripts**: Creates helper scripts

### Post-Installation Structure

```
/opt/noctis/
├── docker-compose.production.yml  # Main compose file
├── Dockerfile.production         # Production Dockerfile
├── .env                         # Environment variables
├── deployment/                  # Configuration files
│   ├── nginx/                  # Nginx configs
│   ├── postgres/               # PostgreSQL configs
│   ├── redis/                  # Redis configs
│   └── backup/                 # Backup scripts
├── data/                       # Persistent data
│   ├── postgres/               # Database files
│   └── redis/                  # Redis data
├── media/                      # Uploaded files
├── staticfiles/                # Static assets
├── logs/                       # Application logs
├── status.sh                   # Container status
├── restart.sh                  # Container restart
├── update.sh                   # Update containers
├── backup.sh                   # Run backup
└── logs.sh                     # View logs
```

### Container Management

```bash
cd /opt/noctis

# View container status
docker compose -f docker-compose.production.yml ps

# View logs
docker compose -f docker-compose.production.yml logs -f

# Restart all containers
docker compose -f docker-compose.production.yml restart

# Restart specific service
docker compose -f docker-compose.production.yml restart web

# Stop all containers
docker compose -f docker-compose.production.yml down

# Start with monitoring
docker compose -f docker-compose.production.yml --profile monitoring up -d
```

## 🔧 Post-Deployment Configuration

### Initial Setup

1. **Save Admin Credentials**: The deployment will generate secure admin credentials. Save them immediately.

2. **Access the System**:
   - Web Interface: `http://your-server-ip` or `https://your-domain.com`
   - Admin Panel: `/admin-panel/`
   - Worklist: `/worklist/`

3. **Test DICOM Receiver**:
   ```bash
   # Test DICOM connectivity (port 11112)
   telnet your-server-ip 11112
   ```

### Environment Configuration

Edit the environment file to customize settings:

```bash
# Native deployment
sudo nano /opt/noctis/.env

# Docker deployment
sudo nano /opt/noctis/.env
```

Key settings to configure:
- `EMAIL_BACKEND`: Configure email settings
- `DEFAULT_FROM_EMAIL`: Set sender email
- `ALLOWED_HOSTS`: Add additional domains
- Security settings for production use

### SSL Certificate Setup

If you didn't provide a domain during installation, you can add SSL later:

```bash
# Native deployment
sudo certbot --nginx -d yourdomain.com

# Docker deployment
sudo certbot certonly --webroot -w /opt/noctis/ssl -d yourdomain.com
# Then update nginx configuration
```

## 📊 Monitoring and Maintenance

### System Status

```bash
# Native deployment
/opt/noctis/status.sh

# Docker deployment
/opt/noctis/status.sh
```

### Log Monitoring

```bash
# Native deployment
sudo journalctl -u noctis-web -f       # Web server logs
sudo journalctl -u noctis-celery -f    # Background tasks
sudo journalctl -u noctis-dicom -f     # DICOM receiver

# Docker deployment
/opt/noctis/logs.sh web                 # Web server logs
/opt/noctis/logs.sh celery              # Background tasks
/opt/noctis/logs.sh dicom_receiver      # DICOM receiver
```

### Backup Management

```bash
# Run manual backup
/opt/noctis/backup.sh

# View backups
ls -la /opt/backups/noctis/  # Native
ls -la /opt/noctis/backups/  # Docker

# Restore from backup (manual process)
# 1. Stop services
# 2. Restore database from SQL dump
# 3. Restore media files from tar.gz
# 4. Restart services
```

### Updates

```bash
# Update the system
/opt/noctis/update.sh

# Manual update process:
cd /opt/noctis/source  # Native
cd /opt/noctis         # Docker
git pull
# Follow deployment-specific restart procedures
```

## 🔒 Security Considerations

### Firewall Rules

Both deployments configure UFW with these rules:
- SSH (22/tcp) - Allow
- HTTP (80/tcp) - Allow
- HTTPS (443/tcp) - Allow
- DICOM (11112/tcp) - Allow
- All other ports - Deny

### Security Features

1. **Fail2ban**: Automatically bans IPs after failed login attempts
2. **SSL/TLS**: HTTPS encryption with Let's Encrypt
3. **Security Headers**: XSS protection, content type sniffing prevention
4. **Non-root Execution**: All services run as non-privileged users
5. **Firewall**: UFW configured with minimal necessary ports
6. **Secure Passwords**: Auto-generated strong passwords

### Hardening Recommendations

1. **Change Default Passwords**: Update admin password after first login
2. **Regular Updates**: Keep system and application updated
3. **Monitor Logs**: Regular log review for suspicious activity
4. **Backup Verification**: Test backup restoration procedures
5. **Access Control**: Use VPN or IP whitelisting for admin access

## 🛠️ Troubleshooting

### Common Issues

1. **Services Not Starting**:
   ```bash
   # Check service status
   sudo systemctl status noctis-web
   
   # View detailed logs
   sudo journalctl -u noctis-web -n 50
   ```

2. **Database Connection Issues**:
   ```bash
   # Check PostgreSQL status
   sudo systemctl status postgresql
   
   # Test database connection
   sudo -u postgres psql -c "\l"
   ```

3. **Permission Problems**:
   ```bash
   # Fix file permissions
   sudo chown -R noctis:noctis /opt/noctis/
   sudo chmod 755 /opt/noctis/
   ```

4. **Docker Issues**:
   ```bash
   # Check container status
   docker compose -f docker-compose.production.yml ps
   
   # View container logs
   docker compose -f docker-compose.production.yml logs web
   
   # Rebuild containers
   docker compose -f docker-compose.production.yml build --no-cache
   ```

### Log Locations

**Native Deployment**:
- Application logs: `/var/log/noctis/`
- System logs: `journalctl -u noctis-*`
- Nginx logs: `/var/log/nginx/`

**Docker Deployment**:
- Container logs: `docker compose logs`
- Application logs: `/opt/noctis/logs/`
- Nginx logs: `/opt/noctis/logs/nginx/`

### Getting Help

1. **Check System Status**: Run the status script first
2. **Review Logs**: Look for error messages in logs
3. **Verify Configuration**: Check `.env` file settings
4. **Test Connectivity**: Verify network and firewall settings
5. **Resource Usage**: Check CPU, memory, and disk usage

## 📈 Performance Optimization

### Database Tuning

The deployments include optimized PostgreSQL configurations, but you can further tune:

```bash
# Edit PostgreSQL config
sudo nano /etc/postgresql/16/main/postgresql.conf

# Key settings to adjust based on your hardware:
# shared_buffers = 25% of RAM
# effective_cache_size = 75% of RAM
# work_mem = Total RAM / max_connections / 2
```

### Application Tuning

1. **Gunicorn Workers**: Adjust worker count based on CPU cores
2. **Celery Concurrency**: Tune based on workload
3. **Redis Memory**: Adjust maxmemory setting
4. **File Storage**: Use SSD for better performance

### Monitoring

Enable optional monitoring stack (Docker deployment):

```bash
docker compose -f docker-compose.production.yml --profile monitoring up -d
```

Access Grafana at `http://your-server:3000` (admin/admin123)

## 🎯 Next Steps

After successful deployment:

1. **User Training**: Train staff on system usage
2. **Integration**: Connect DICOM modalities
3. **Workflow Setup**: Configure worklists and workflows
4. **Backup Testing**: Verify backup and restore procedures
5. **Monitoring Setup**: Configure alerting and monitoring
6. **Documentation**: Document custom configurations
7. **Performance Testing**: Test with actual workloads

## 📞 Support

For technical support:
1. Check this documentation first
2. Review system logs for error messages
3. Verify configuration settings
4. Test with minimal setup
5. Contact system administrator or development team

---

**Note**: This deployment guide is specifically optimized for Ubuntu 24.04. While it may work on other Ubuntu versions, testing and validation are recommended for production deployments on different versions.