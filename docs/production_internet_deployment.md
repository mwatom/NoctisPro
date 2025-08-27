# NoctisPro Production Internet Deployment Guide

## 🌐 Deploy to Production Over Internet (Keep Dual-Boot Intact)

This guide helps you deploy your NoctisPro medical imaging platform to production over the internet while preserving your current Ubuntu/Kali dual-boot setup.

## 📋 Production Deployment Strategy

### Phase 1: Current System → Internet Production
- Deploy from current Ubuntu Desktop 24.04 (dual-boot)
- Make system accessible over internet
- Full production features with HTTPS
- Keep Kali Linux intact for now

### Phase 2: Later Migration (Optional)
- Remove Kali Linux to gain more space
- Migrate to Ubuntu Server 24.04
- Optimize for dedicated server environment

---

## 🚀 IMMEDIATE PRODUCTION DEPLOYMENT

### Step 1: Prepare Your Current Ubuntu System

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required tools
sudo apt install -y curl wget git ufw fail2ban certbot

# Check system resources
echo "=== SYSTEM CHECK ==="
echo "OS: $(lsb_release -d | cut -f2)"
echo "CPU Cores: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Storage: $(df -h / | tail -1 | awk '{print $4}') available"
echo "========================"
```

### Step 2: Configure Internet Access

#### Option A: Direct Internet Connection (Recommended)
```bash
# Configure static IP (if needed)
sudo nano /etc/netplan/01-netcfg.yaml

# Example configuration:
network:
  version: 2
  ethernets:
    enp0s3:  # Replace with your interface name
      dhcp4: false
      addresses:
        - 192.168.1.100/24  # Your static IP
      routes:
        - to: default
          via: 192.168.1.1   # Your gateway
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]

# Apply network configuration
sudo netplan apply
```

#### Option B: Dynamic DNS Setup (For Dynamic IP)
```bash
# Install ddclient for dynamic DNS
sudo apt install ddclient

# Configure for your DNS provider (example for No-IP)
sudo nano /etc/ddclient.conf

# Example configuration:
protocol=noip
use=web, web=checkip.dyndns.com/, web-skip='IP Address'
server=dynupdate.no-ip.com
login=your-username
password='your-password'
your-domain.ddns.net

# Start ddclient
sudo systemctl enable ddclient
sudo systemctl start ddclient
```

### Step 3: Configure Firewall for Production

```bash
# Reset UFW to default
sudo ufw --force reset

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (change port if needed)
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow NoctisPro specific ports
sudo ufw allow 8000/tcp  # Django development (if needed)

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

### Step 4: Setup Domain and SSL

#### Option A: Free Domain (For Testing)
```bash
# Use services like:
# - freenom.com (free domains)
# - no-ip.com (free subdomains)
# - duckdns.org (free subdomains)

# Example for DuckDNS:
# 1. Sign up at duckdns.org
# 2. Create subdomain: yourcompany.duckdns.org
# 3. Update your domain with current IP
```

#### Option B: Custom Domain (Recommended for Production)
```bash
# Purchase domain from registrar
# Point A record to your public IP
# Example: noctispro.yourcompany.com → YOUR_PUBLIC_IP
```

### Step 5: Modify Deployment Script for Internet Access

```bash
# Create production internet deployment script
cp deploy_noctis_production.sh deploy_internet_production.sh

# Edit for internet deployment
nano deploy_internet_production.sh
```

**Key modifications needed:**

```bash
# Change these values in deploy_internet_production.sh:

# Domain configuration
DOMAIN_NAME="your-domain.com"  # Your actual domain
SERVER_IP="YOUR_PUBLIC_IP"     # Your public IP address

# Security enhancements for internet exposure
ALLOWED_HOSTS="your-domain.com,www.your-domain.com,YOUR_PUBLIC_IP"

# Additional security settings
SECURE_SSL_REDIRECT=True
SECURE_BROWSER_XSS_FILTER=True
SECURE_CONTENT_TYPE_NOSNIFF=True
X_FRAME_OPTIONS='DENY'
```

### Step 6: Deploy NoctisPro to Production

```bash
# Make script executable
chmod +x deploy_internet_production.sh

# Run deployment (as root)
sudo ./deploy_internet_production.sh
```

### Step 7: Configure HTTPS with Let's Encrypt

```bash
# After deployment, setup SSL certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Step 8: Configure Production Security

```bash
# Configure Fail2ban for additional security
sudo nano /etc/fail2ban/jail.local

[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

# Restart fail2ban
sudo systemctl restart fail2ban
```

### Step 9: Setup Production Monitoring

```bash
# Install system monitoring
sudo apt install htop iotop nethogs

# Setup log monitoring
sudo nano /etc/logrotate.d/noctispro

/opt/noctis_pro/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    copytruncate
}
```

### Step 10: Final Production Checklist

```bash
# Verify deployment
curl -I https://your-domain.com

# Check services
sudo systemctl status noctis_pro
sudo systemctl status nginx
sudo systemctl status postgresql

# Check logs
sudo journalctl -u noctis_pro -f

# Test functionality
# 1. Access web interface
# 2. Test user registration/login
# 3. Upload test DICOM image
# 4. Test printing functionality
# 5. Verify SSL certificate
```

---

## 🌐 PRODUCTION CONFIGURATION

### Environment Variables for Internet Production

Create `/opt/noctis_pro/.env.production`:

```bash
# Django settings
DEBUG=False
ALLOWED_HOSTS=your-domain.com,www.your-domain.com,YOUR_PUBLIC_IP
SECRET_KEY=your-generated-secret-key

# Database
DATABASE_URL=postgresql://noctis_user:password@localhost:5432/noctis_pro

# Security
SECURE_SSL_REDIRECT=True
SECURE_BROWSER_XSS_FILTER=True
SECURE_CONTENT_TYPE_NOSNIFF=True
SECURE_HSTS_SECONDS=31536000
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True

# Email (for notifications)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password

# Storage
MEDIA_URL=https://your-domain.com/media/
STATIC_URL=https://your-domain.com/static/

# Backup
BACKUP_ENABLED=True
BACKUP_SCHEDULE="0 2 * * *"  # Daily at 2 AM
```

### Nginx Configuration for Internet Production

```nginx
# /etc/nginx/sites-available/noctispro
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com www.your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # Security headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;

    # File upload size
    client_max_body_size 500M;
    
    # Timeouts
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /static/ {
        alias /opt/noctis_pro/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /opt/noctis_pro/media/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

---

## 🔄 BACKUP STRATEGY FOR PRODUCTION

### Automated Backup Script

```bash
#!/bin/bash
# /opt/noctis_pro/scripts/backup_production.sh

BACKUP_DIR="/opt/noctis_pro/backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="noctis_pro"
DB_USER="noctis_user"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Database backup
pg_dump -U "$DB_USER" -h localhost "$DB_NAME" > "$BACKUP_DIR/db_backup_$DATE.sql"

# Media files backup
tar -czf "$BACKUP_DIR/media_backup_$DATE.tar.gz" -C /opt/noctis_pro media/

# Configuration backup
tar -czf "$BACKUP_DIR/config_backup_$DATE.tar.gz" -C /opt/noctis_pro .env.production

# Clean old backups (keep 30 days)
find "$BACKUP_DIR" -name "*.sql" -mtime +30 -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete

echo "Backup completed: $DATE"
```

### Setup Automated Backups

```bash
# Make backup script executable
chmod +x /opt/noctis_pro/scripts/backup_production.sh

# Add to crontab
sudo crontab -e
# Add: 0 2 * * * /opt/noctis_pro/scripts/backup_production.sh
```

---

## 📊 MONITORING AND MAINTENANCE

### Performance Monitoring

```bash
# Install monitoring tools
sudo apt install htop iotop nethogs

# Setup Prometheus (optional)
# For detailed monitoring setup, see production monitoring guide
```

### Log Management

```bash
# Check application logs
sudo journalctl -u noctis_pro -f

# Check Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Check system logs
sudo tail -f /var/log/syslog
```

### Health Checks

```bash
# Create health check script
cat > /opt/noctis_pro/scripts/health_check.sh << 'EOF'
#!/bin/bash

# Check services
services=("noctis_pro" "nginx" "postgresql" "redis")
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "✅ $service is running"
    else
        echo "❌ $service is not running"
    fi
done

# Check disk space
disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $disk_usage -gt 80 ]; then
    echo "⚠️  Disk usage is at ${disk_usage}%"
else
    echo "✅ Disk usage is at ${disk_usage}%"
fi

# Check database connection
if pg_isready -U noctis_user -h localhost -d noctis_pro > /dev/null 2>&1; then
    echo "✅ Database connection OK"
else
    echo "❌ Database connection failed"
fi
EOF

chmod +x /opt/noctis_pro/scripts/health_check.sh
```

---

## 🚀 GO LIVE CHECKLIST

### Pre-Launch
- [ ] Domain configured and DNS propagated
- [ ] SSL certificate installed and valid
- [ ] Firewall configured properly
- [ ] Fail2ban configured and active
- [ ] Database backups working
- [ ] All services running and healthy
- [ ] Log rotation configured

### Launch
- [ ] Deploy application to production
- [ ] Verify HTTPS access works
- [ ] Test user registration/login
- [ ] Test DICOM upload and viewing
- [ ] Test printing functionality
- [ ] Verify email notifications work

### Post-Launch
- [ ] Monitor system performance
- [ ] Check error logs regularly
- [ ] Verify backups are running
- [ ] Test disaster recovery procedure
- [ ] Document any custom configurations

---

## 🔧 TROUBLESHOOTING

### Common Issues

**1. 502 Bad Gateway**
```bash
# Check if application is running
sudo systemctl status noctis_pro

# Check logs
sudo journalctl -u noctis_pro -n 50
```

**2. SSL Certificate Issues**
```bash
# Renew certificate
sudo certbot renew

# Check certificate
sudo certbot certificates
```

**3. Database Connection Issues**
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check database logs
sudo tail -f /var/log/postgresql/postgresql-13-main.log
```

**4. High Resource Usage**
```bash
# Check system resources
htop
iotop
```

---

## 📞 PRODUCTION SUPPORT

### Quick Commands for Support

```bash
# Service management
sudo systemctl restart noctis_pro
sudo systemctl restart nginx
sudo systemctl restart postgresql

# View logs
sudo journalctl -u noctis_pro -f
sudo tail -f /var/log/nginx/error.log

# Check system health
/opt/noctis_pro/scripts/health_check.sh
```

### Emergency Procedures

**If system becomes unresponsive:**
1. Check system resources: `htop`, `df -h`
2. Restart services: `sudo systemctl restart noctis_pro nginx`
3. Check logs for errors
4. Contact support if issues persist

**If database corruption occurs:**
1. Stop application: `sudo systemctl stop noctis_pro`
2. Restore from backup
3. Restart services
4. Verify data integrity

---

This deployment strategy allows you to:
1. ✅ **Deploy immediately** to production over the internet
2. ✅ **Keep dual-boot** system intact (Ubuntu + Kali)
3. ✅ **Full production features** with HTTPS, security, monitoring
4. ✅ **Professional deployment** ready for healthcare use
5. ✅ **Later flexibility** to remove Kali and migrate to dedicated server

The system will be fully functional and accessible over the internet while maintaining your current setup!