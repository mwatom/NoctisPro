# 🏥 Manual Ubuntu 24.04 Production Deployment Guide - NoctisPro

> **🎯 Complete Manual Deployment**: Step-by-step guide for deploying NoctisPro Medical Imaging Platform on Ubuntu Server 24.04 with HTTPS and domain access

## 📋 DEPLOYMENT OVERVIEW

**System**: NoctisPro - Enterprise Medical Imaging Platform  
**Target**: Ubuntu Server 24.04 LTS  
**Deployment Time**: 45-60 minutes  
**Result**: Production-ready system with HTTPS, domain access, and internet connectivity  

## 🚀 SYSTEM REQUIREMENTS

### Hardware Requirements
- **CPU**: 4+ cores (8+ recommended)
- **RAM**: 8GB minimum (16GB+ recommended)
- **Storage**: 100GB minimum (500GB+ recommended)
- **Network**: Static IP or dynamic DNS capability

### Software Requirements
- Ubuntu Server 24.04 LTS (fresh installation)
- Root/sudo access
- Internet connectivity
- Domain name (for HTTPS access)

## 📍 PRE-DEPLOYMENT CHECKLIST

### 1. Server Verification
```bash
# Check Ubuntu version
lsb_release -a

# Verify system resources
free -h
df -h
nproc

# Test internet connectivity
ping -c 3 google.com
curl -I https://github.com
```

### 2. Domain Prerequisites
You'll need **ONE** of the following:
- **Option A**: Purchased domain (recommended for production)
- **Option B**: Free subdomain from services like DuckDNS, No-IP
- **Option C**: Dynamic DNS setup

---

## 🔧 STEP-BY-STEP DEPLOYMENT

### STEP 1: System Preparation (10 minutes)

#### 1.1 Update System
```bash
# Update package lists and system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git unzip software-properties-common \
                    lsb-release build-essential apt-transport-https \
                    ca-certificates gnupg2

# Set hostname (replace with your preferred name)
sudo hostnamectl set-hostname noctis-medical-server

# Configure timezone (adjust for your location)
sudo timedatectl set-timezone America/New_York
```

#### 1.2 Create System User
```bash
# Create dedicated user for NoctisPro
sudo useradd -m -s /bin/bash noctis
sudo usermod -aG sudo noctis

# Set password for noctis user
sudo passwd noctis

# Switch to noctis user
sudo su - noctis
```

### STEP 2: Domain and DNS Configuration (15 minutes)

#### 2.1 Option A: Purchased Domain Setup
If you have a purchased domain (e.g., from GoDaddy, Namecheap, etc.):

1. **Get your server's public IP**:
```bash
# Get public IP address
curl -4 ifconfig.me
# Note this IP - you'll need it for DNS configuration
```

2. **Configure DNS records** (in your domain provider's control panel):
   - **A Record**: Point your domain to your server's public IP
   - **Example**: `medical.yourdomain.com` → `YOUR_SERVER_IP`
   - **TTL**: Set to 300 (5 minutes) for faster propagation

3. **Verify DNS propagation**:
```bash
# Replace with your actual domain
nslookup medical.yourdomain.com
dig medical.yourdomain.com
```

#### 2.2 Option B: Free Subdomain Setup (DuckDNS Example)
1. **Visit**: https://www.duckdns.org/
2. **Sign up** with Google/GitHub account
3. **Create subdomain**: `yourclinic.duckdns.org`
4. **Get your token** from DuckDNS dashboard
5. **Install DuckDNS updater**:

```bash
# Create directory for DuckDNS
mkdir ~/duckdns
cd ~/duckdns

# Create update script (replace TOKEN and SUBDOMAIN)
cat > duck.sh << 'EOF'
#!/bin/bash
echo url="https://www.duckdns.org/update?domains=YOURCLINIC&token=YOUR_TOKEN&ip=" | curl -k -o ~/duckdns/duck.log -K -
EOF

# Make executable and test
chmod 700 duck.sh
./duck.sh

# Add to crontab for automatic updates
(crontab -l ; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab -
```

#### 2.3 Configure Firewall
```bash
# Configure UFW firewall
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (important - don't lock yourself out!)
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow NoctisPro specific ports
sudo ufw allow 8000/tcp  # Django development
sudo ufw allow 8080/tcp  # Alternative web port

# Enable firewall
sudo ufw --force enable
sudo ufw status verbose
```

### STEP 3: Install Dependencies (10 minutes)

#### 3.1 Install Python and Dependencies
```bash
# Install Python 3.11+
sudo apt install -y python3 python3-pip python3-venv python3-dev

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib postgresql-client

# Install Redis
sudo apt install -y redis-server

# Install Nginx
sudo apt install -y nginx

# Install system libraries for medical imaging
sudo apt install -y libgdcm-dev libvtk9-dev libinsighttoolkit5-dev \
                    libopencv-dev python3-opencv

# Install CUPS for printing support
sudo apt install -y cups cups-client cups-filters
```

#### 3.2 Install Docker (for containerized deployment option)
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker noctis

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Start Docker service
sudo systemctl enable docker
sudo systemctl start docker
```

### STEP 4: Download and Setup NoctisPro (5 minutes)

```bash
# Create project directory
sudo mkdir -p /opt/noctis_pro
sudo chown noctis:noctis /opt/noctis_pro
cd /opt/noctis_pro

# Clone NoctisPro repository
git clone https://github.com/mwatom/NoctisPro.git .

# Make scripts executable
chmod +x *.sh
chmod +x scripts/*.sh
chmod +x ops/*.sh

# Verify download
ls -la
```

### STEP 5: Configure Domain in Deployment Script (3 minutes)

```bash
# Edit the main deployment script
nano deploy_noctis_production.sh

# Update the domain configuration (around line 20):
# Change from: DOMAIN_NAME="noctis-server.local"
# Change to:   DOMAIN_NAME="your-actual-domain.com"
```

**Example domain configurations**:
- Purchased domain: `DOMAIN_NAME="medical.yourdomain.com"`
- DuckDNS: `DOMAIN_NAME="yourclinic.duckdns.org"`
- No-IP: `DOMAIN_NAME="yourclinic.ddns.net"`

### STEP 6: Run Production Deployment (15 minutes)

#### 6.1 Execute Main Deployment
```bash
# Run the complete production deployment
sudo ./deploy_noctis_production.sh

# This script will:
# - Configure PostgreSQL database
# - Setup Redis cache
# - Install Python dependencies
# - Configure Nginx reverse proxy
# - Setup SSL certificates with Let's Encrypt
# - Configure systemd services
# - Start all services
```

#### 6.2 Monitor Deployment Progress
The script will show progress updates. Watch for:
- ✅ Database setup completion
- ✅ SSL certificate generation
- ✅ Service startup confirmation
- ✅ Final success message

### STEP 7: SSL Certificate Setup (Auto-handled by script)

The deployment script automatically:
1. Installs Certbot (Let's Encrypt client)
2. Generates SSL certificates for your domain
3. Configures Nginx with HTTPS
4. Sets up automatic certificate renewal

If SSL setup fails, manual setup:
```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Generate certificate (replace with your domain)
sudo certbot --nginx -d your-domain.com

# Test automatic renewal
sudo certbot renew --dry-run
```

---

## 🌐 ACCESSING YOUR SYSTEM

### After Successful Deployment

1. **HTTPS URL**: `https://your-domain.com`
2. **Admin Panel**: `https://your-domain.com/admin/`
3. **API Endpoint**: `https://your-domain.com/api/`

### Default Login Credentials
- **Username**: `admin`
- **Password**: Generated during deployment (shown in script output)

### Verify Services are Running
```bash
# Check all NoctisPro services
sudo systemctl status noctis-web
sudo systemctl status noctis-worker
sudo systemctl status noctis-scheduler

# Check supporting services
sudo systemctl status postgresql
sudo systemctl status redis
sudo systemctl status nginx

# Check open ports
sudo netstat -tlnp | grep -E ':80|:443|:8000'
```

---

## 🔧 POST-DEPLOYMENT CONFIGURATION

### 1. Create Superuser Account
```bash
cd /opt/noctis_pro
source venv/bin/activate
python manage.py createsuperuser
```

### 2. Configure Email Settings (Optional)
```bash
# Edit Django settings for email
nano noctis_pro/settings/production.py

# Add your email configuration:
# EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
# EMAIL_HOST = 'smtp.your-provider.com'
# EMAIL_PORT = 587
# EMAIL_USE_TLS = True
# EMAIL_HOST_USER = 'your-email@domain.com'
# EMAIL_HOST_PASSWORD = 'your-app-password'
```

### 3. Configure DICOM Settings
```bash
# Configure DICOM receiver
nano dicom_receiver.py

# Update DICOM settings in Django admin:
# https://your-domain.com/admin/
```

---

## 🛠️ TROUBLESHOOTING

### Common Issues and Solutions

#### 1. SSL Certificate Failed
```bash
# Check domain DNS
nslookup your-domain.com

# Manually generate certificate
sudo certbot --nginx -d your-domain.com --email your-email@domain.com

# Check Nginx configuration
sudo nginx -t
sudo systemctl reload nginx
```

#### 2. Services Not Starting
```bash
# Check logs
sudo journalctl -u noctis-web -f
sudo journalctl -u nginx -f

# Restart services
sudo systemctl restart noctis-web
sudo systemctl restart nginx
```

#### 3. Database Connection Issues
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Connect to database
sudo -u postgres psql -d noctis_pro

# Reset database if needed
cd /opt/noctis_pro
source venv/bin/activate
python manage.py migrate
```

#### 4. Port Already in Use
```bash
# Check what's using ports
sudo lsof -i :80
sudo lsof -i :443

# Kill conflicting processes if needed
sudo systemctl stop apache2  # If Apache is running
```

### 5. Firewall Issues
```bash
# Check firewall status
sudo ufw status

# Temporarily disable for testing
sudo ufw disable

# Re-enable with correct rules
sudo ufw enable
```

---

## 📱 MOBILE ACCESS CONFIGURATION

### Enable Mobile-Responsive Features
```bash
# Update settings for mobile optimization
nano noctis_pro/settings/production.py

# Add mobile-specific settings:
# MOBILE_AGENT_DETECTOR = True
# MOBILE_TEMPLATE_DIR = 'mobile'
```

---

## 🔒 SECURITY HARDENING (Recommended)

### 1. Additional Firewall Rules
```bash
# Limit SSH access (optional - be careful!)
sudo ufw limit ssh

# Allow only specific IPs for admin access (optional)
# sudo ufw allow from YOUR_IP_ADDRESS to any port 22
```

### 2. Install Fail2Ban
```bash
# Install fail2ban for brute force protection
sudo apt install -y fail2ban

# Configure fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 3. Setup Automatic Updates
```bash
# Install unattended upgrades
sudo apt install -y unattended-upgrades

# Configure automatic security updates
sudo dpkg-reconfigure unattended-upgrades
```

---

## 📊 MONITORING AND MAINTENANCE

### 1. Setup Log Rotation
```bash
# Configure log rotation for NoctisPro
sudo nano /etc/logrotate.d/noctis

# Add log rotation configuration:
/opt/noctis_pro/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 noctis noctis
}
```

### 2. Database Backup Script
```bash
# Create backup script
cat > ~/backup_noctis.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
sudo -u postgres pg_dump noctis_pro > /opt/noctis_pro/backups/db_backup_$DATE.sql
find /opt/noctis_pro/backups/ -name "db_backup_*.sql" -mtime +7 -delete
EOF

chmod +x ~/backup_noctis.sh

# Add to crontab for daily backups
(crontab -l ; echo "0 2 * * * ~/backup_noctis.sh") | crontab -
```

---

## ✅ DEPLOYMENT SUCCESS VERIFICATION

### Final Verification Checklist

1. **✅ Web Access**: Visit `https://your-domain.com`
2. **✅ SSL Certificate**: Check for green lock icon in browser
3. **✅ Admin Access**: Login to `https://your-domain.com/admin/`
4. **✅ DICOM Upload**: Test DICOM file upload functionality
5. **✅ Mobile Access**: Test on mobile device
6. **✅ Performance**: Check page load times
7. **✅ Email**: Test email notifications (if configured)

### Success Indicators
- ✅ NoctisPro homepage loads without errors
- ✅ HTTPS certificate is valid and trusted
- ✅ All static files load correctly
- ✅ Database operations work
- ✅ File uploads function properly
- ✅ Admin panel is accessible

---

## 🚨 EMERGENCY PROCEDURES

### If Deployment Fails
```bash
# Stop all services
sudo systemctl stop noctis-web noctis-worker noctis-scheduler

# Check logs for errors
sudo journalctl -u noctis-web --since "1 hour ago"

# Re-run deployment
sudo ./deploy_noctis_production.sh
```

### Recovery Commands
```bash
# Reset database
sudo -u postgres dropdb noctis_pro
sudo -u postgres createdb noctis_pro

# Restore from backup
sudo -u postgres psql noctis_pro < /opt/noctis_pro/backups/db_backup_YYYYMMDD_HHMMSS.sql

# Restart all services
sudo systemctl restart noctis-web noctis-worker noctis-scheduler nginx redis postgresql
```

---

## 📞 SUPPORT INFORMATION

### Getting Help
- **Documentation**: Available in `/opt/noctis_pro/docs/`
- **Logs Location**: `/opt/noctis_pro/logs/`
- **Configuration**: `/opt/noctis_pro/noctis_pro/settings/`

### Important File Locations
- **Main Application**: `/opt/noctis_pro/`
- **Nginx Config**: `/etc/nginx/sites-available/noctis_pro`
- **SSL Certificates**: `/etc/letsencrypt/live/your-domain.com/`
- **Database Backups**: `/opt/noctis_pro/backups/`

---

🎉 **Congratulations!** Your NoctisPro Medical Imaging Platform is now deployed and accessible via HTTPS at your custom domain!