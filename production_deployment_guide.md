# Noctis Pro DICOM System - Production Deployment Guide
## Ubuntu Server 24.04 with Worldwide Access

### 🎯 Overview

This guide will deploy your enhanced Noctis Pro DICOM medical imaging system to Ubuntu Server 24.04 with secure worldwide web access. The system now includes:

- **Enhanced User Management**: Advanced filtering, bulk operations, export functionality, and modern UI
- **Enhanced Facility Management**: Grid/list views, analytics, bulk actions, and comprehensive search
- **Production Security**: SSL/TLS, firewall configuration, fail2ban protection
- **High Performance**: PostgreSQL, Redis, Nginx reverse proxy, systemd services
- **Monitoring & Backup**: Automated backups, log rotation, system monitoring

### 🚀 Quick Deployment (Recommended)

#### Step 1: Prepare Your Server

```bash
# Update your Ubuntu 24.04 server
sudo apt update && sudo apt upgrade -y

# Ensure you have sudo privileges
sudo whoami  # Should return 'root'

# Clone your repository (replace with your actual repo URL)
git clone https://github.com/yourusername/noctis-pro.git
cd noctis-pro
```

#### Step 2: Deploy with Domain Name (Worldwide Access)

```bash
# Deploy with your domain name for SSL and worldwide access
sudo bash deploy_ubuntu24.sh yourdomain.com admin@yourdomain.com

# Or deploy locally first, then configure domain later
sudo bash deploy_ubuntu24.sh
```

#### Step 3: Configure DNS (For Worldwide Access)

Before running the deployment with a domain name, ensure:

1. **Point your domain to your server**:
   - Create an A record: `yourdomain.com` → `YOUR_SERVER_IP`
   - Create an A record: `www.yourdomain.com` → `YOUR_SERVER_IP`

2. **Ensure ports are accessible**:
   - Port 80 (HTTP) - for Let's Encrypt verification
   - Port 443 (HTTPS) - for secure access
   - Port 22 (SSH) - for server management

### 📋 What Gets Installed

The deployment script will install and configure:

#### Core Infrastructure
- **PostgreSQL 16**: High-performance database with optimizations
- **Redis 7**: Caching and message queuing
- **Nginx**: Reverse proxy with security headers
- **Python 3.11**: Virtual environment with all dependencies
- **Node.js & npm**: For frontend asset building

#### Security Components
- **UFW Firewall**: Configured with necessary ports
- **Fail2ban**: Intrusion prevention system
- **Let's Encrypt SSL**: Automatic HTTPS certificates
- **Security Headers**: HSTS, CSP, XSS protection

#### System Services
- **noctis-web**: Django application server (Gunicorn)
- **noctis-celery**: Background task processing
- **noctis-dicom**: DICOM receiver service
- **noctis-chat**: Real-time chat service (Daphne)

#### Monitoring & Backup
- **Automated Backups**: Daily database and media backups
- **Log Rotation**: Prevents disk space issues
- **System Monitoring**: Health checks and alerts

### 🔧 Post-Deployment Configuration

After successful deployment, you'll receive:

#### Access Information
```
🎉 Noctis Pro DICOM System Deployed Successfully!

🌐 Access URLs:
   Web Interface: https://yourdomain.com
   Admin Panel: https://yourdomain.com/admin-panel/
   DICOM Port: yourdomain.com:11112

👤 Administrator Account:
   Username: admin
   Password: [SECURE_RANDOM_PASSWORD]
   Email: admin@yourdomain.com

🔧 Management Commands:
   Status: /opt/noctis/status.sh
   Restart: /opt/noctis/restart.sh
   Update: /opt/noctis/update.sh
   Backup: /opt/noctis/backup.sh
```

#### Enhanced Features Available

1. **User Management** (`/admin-panel/users/`):
   - Advanced search and filtering
   - Bulk operations (activate, deactivate, verify, delete)
   - Export to CSV/Excel/PDF
   - Role-based access control
   - Session tracking and security

2. **Facility Management** (`/admin-panel/facilities/`):
   - Grid and list view modes
   - Comprehensive facility analytics
   - Bulk facility operations
   - Advanced search capabilities
   - DICOM AE Title management

3. **System Dashboard** (`/admin-panel/`):
   - Real-time statistics
   - System health monitoring
   - Recent activity logs
   - Performance metrics

### 🌍 Worldwide Access Setup

#### Option 1: Using Your Own Domain

1. **Purchase a domain** from providers like:
   - Namecheap, GoDaddy, CloudFlare, etc.

2. **Configure DNS**:
   ```bash
   # Point your domain to your server IP
   A record: yourdomain.com → YOUR_SERVER_IP
   A record: www.yourdomain.com → YOUR_SERVER_IP
   ```

3. **Deploy with domain**:
   ```bash
   sudo bash deploy_ubuntu24.sh yourdomain.com admin@yourdomain.com
   ```

#### Option 2: Using Free Dynamic DNS

1. **Sign up for free DNS** services like:
   - DuckDNS, No-IP, FreeDNS, etc.

2. **Get your subdomain**:
   - Example: `yournoctis.duckdns.org`

3. **Deploy with subdomain**:
   ```bash
   sudo bash deploy_ubuntu24.sh yournoctis.duckdns.org admin@yourdomain.com
   ```

#### Option 3: Using Cloud Providers

1. **AWS/Google Cloud/Azure**:
   - Get a public IP address
   - Configure security groups/firewall rules
   - Use cloud DNS services

2. **Deploy with cloud setup**:
   ```bash
   sudo bash deploy_ubuntu24.sh your-cloud-domain.com admin@yourdomain.com
   ```

### 🔒 Security Configuration

The deployment automatically configures:

#### Firewall Rules (UFW)
```bash
# Check firewall status
sudo ufw status

# Allowed ports:
# 22/tcp (SSH)
# 80/tcp (HTTP - redirects to HTTPS)
# 443/tcp (HTTPS)
# 11112/tcp (DICOM)
```

#### SSL/TLS Configuration
```bash
# SSL certificates are automatically obtained from Let's Encrypt
# Certificates auto-renew every 90 days

# Check SSL status
sudo certbot certificates

# Manual renewal (if needed)
sudo certbot renew
```

#### Fail2ban Protection
```bash
# Check fail2ban status
sudo fail2ban-client status

# View banned IPs
sudo fail2ban-client status nginx-http-auth
sudo fail2ban-client status sshd
```

### 📊 System Management

#### Service Management
```bash
# Check all services status
sudo /opt/noctis/status.sh

# Restart all services
sudo /opt/noctis/restart.sh

# View service logs
sudo journalctl -u noctis-web -f
sudo journalctl -u noctis-celery -f
sudo journalctl -u noctis-dicom -f
```

#### Database Management
```bash
# Access PostgreSQL
sudo -u postgres psql noctis_pro

# Create database backup
sudo /opt/noctis/backup.sh

# View backup files
ls -la /opt/backups/noctis/
```

#### System Updates
```bash
# Update application code
sudo /opt/noctis/update.sh

# Update system packages
sudo apt update && sudo apt upgrade -y

# Update SSL certificates
sudo certbot renew
```

### 🔍 Monitoring & Troubleshooting

#### Health Checks
```bash
# Check system health
curl -I https://yourdomain.com/health/
curl -I https://yourdomain.com/admin-panel/

# Check DICOM service
telnet yourdomain.com 11112
```

#### Log Files
```bash
# Application logs
tail -f /var/log/noctis/django.log
tail -f /var/log/noctis/celery.log
tail -f /var/log/noctis/dicom.log

# System logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
tail -f /var/log/postgresql/postgresql-16-main.log
```

#### Performance Monitoring
```bash
# System resources
htop
df -h
free -h

# Database performance
sudo -u postgres psql noctis_pro -c "SELECT * FROM pg_stat_activity;"

# Nginx status
sudo nginx -t
sudo systemctl status nginx
```

### 🚨 Troubleshooting Common Issues

#### Issue 1: SSL Certificate Problems
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates manually
sudo certbot renew --dry-run
sudo certbot renew

# Restart nginx after certificate renewal
sudo systemctl restart nginx
```

#### Issue 2: Database Connection Issues
```bash
# Check PostgreSQL status
sudo systemctl status postgresql
sudo -u postgres psql -c "SELECT version();"

# Restart PostgreSQL
sudo systemctl restart postgresql

# Check database connections
sudo -u postgres psql noctis_pro -c "SELECT * FROM pg_stat_activity;"
```

#### Issue 3: Service Not Starting
```bash
# Check service status
sudo systemctl status noctis-web
sudo systemctl status noctis-celery

# View detailed logs
sudo journalctl -u noctis-web --no-pager
sudo journalctl -u noctis-celery --no-pager

# Restart services
sudo systemctl restart noctis-web
sudo systemctl restart noctis-celery
```

#### Issue 4: Firewall Blocking Access
```bash
# Check firewall rules
sudo ufw status verbose

# Allow additional ports if needed
sudo ufw allow 8000/tcp  # For development
sudo ufw reload

# Check if port is listening
sudo netstat -tulpn | grep :443
sudo netstat -tulpn | grep :80
```

### 📈 Performance Optimization

#### Database Optimization
```bash
# PostgreSQL tuning (already configured in deployment)
# - shared_buffers = 256MB
# - effective_cache_size = 1GB
# - work_mem = 4MB
# - maintenance_work_mem = 64MB

# Monitor database performance
sudo -u postgres psql noctis_pro -c "
SELECT schemaname,tablename,attname,n_distinct,correlation 
FROM pg_stats WHERE tablename = 'accounts_user';
"
```

#### Redis Optimization
```bash
# Check Redis performance
redis-cli info memory
redis-cli info stats

# Monitor Redis
redis-cli monitor
```

#### Nginx Optimization
```bash
# Check Nginx configuration
sudo nginx -t

# Monitor Nginx performance
tail -f /var/log/nginx/access.log | grep -E "HTTP/[0-9\.]+ [45][0-9][0-9]"
```

### 🔄 Backup & Recovery

#### Automated Backups
The system creates daily backups automatically:

```bash
# Backup locations
/opt/backups/noctis/database/  # PostgreSQL dumps
/opt/backups/noctis/media/     # Uploaded files
/opt/backups/noctis/config/    # Configuration files

# Manual backup
sudo /opt/noctis/backup.sh

# Backup to remote location (recommended)
# Configure rsync or cloud storage sync
```

#### Recovery Procedures
```bash
# Restore database
sudo -u postgres psql noctis_pro < /opt/backups/noctis/database/backup_YYYY-MM-DD.sql

# Restore media files
sudo cp -r /opt/backups/noctis/media/* /opt/noctis/media/

# Set correct permissions
sudo chown -R noctis:noctis /opt/noctis/media/
```

### 🎯 Production Best Practices

1. **Regular Updates**:
   - Update system packages monthly
   - Update application code as needed
   - Monitor security advisories

2. **Monitoring**:
   - Set up external monitoring (Uptime Robot, etc.)
   - Configure email alerts for service failures
   - Monitor disk space and performance

3. **Backups**:
   - Test backup restoration regularly
   - Store backups in multiple locations
   - Implement off-site backup strategy

4. **Security**:
   - Change default passwords immediately
   - Enable two-factor authentication
   - Regular security audits
   - Monitor access logs

5. **Documentation**:
   - Keep deployment notes
   - Document custom configurations
   - Maintain user access records

### 📞 Support & Maintenance

#### Regular Maintenance Tasks

**Daily**:
- Check system status
- Monitor log files for errors
- Verify backups completed

**Weekly**:
- Review system performance
- Check SSL certificate status
- Update security patches

**Monthly**:
- Full system updates
- Database maintenance
- Security audit
- Backup testing

#### Getting Help

1. **Check Logs**: Always start with system and application logs
2. **Service Status**: Verify all services are running correctly
3. **Resource Usage**: Monitor CPU, memory, and disk usage
4. **Network Connectivity**: Test external access and internal services

### 🎉 Deployment Complete!

Your Noctis Pro DICOM system is now ready for production use with:

✅ **Enhanced User Management**: Advanced admin interface with bulk operations
✅ **Enhanced Facility Management**: Modern UI with analytics and export features  
✅ **Worldwide Access**: SSL-secured domain with proper firewall configuration
✅ **Production Security**: Fail2ban, UFW firewall, and security headers
✅ **High Performance**: Optimized database and caching layer
✅ **Automated Backups**: Daily backups with rotation
✅ **System Monitoring**: Health checks and log rotation

**Next Steps**:
1. Access your system at `https://yourdomain.com`
2. Log in with the admin credentials provided
3. Configure your first facility and users
4. Test DICOM connectivity on port 11112
5. Set up monitoring and alerts
6. Configure regular backup verification

Your medical imaging system is now ready to serve healthcare facilities worldwide! 🏥🌍