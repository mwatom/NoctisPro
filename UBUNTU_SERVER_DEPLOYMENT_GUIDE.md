# 🏥 NoctisPro Production Deployment Guide - Ubuntu Server 24.04/25.04

> **Complete Medical Imaging Platform Deployment for Production Use**

## 📋 Overview

This guide provides step-by-step instructions for deploying NoctisPro, a comprehensive medical imaging platform, on Ubuntu Server 24.04 or 25.04. The system includes DICOM processing, web-based viewer, AI analysis, printing capabilities, and enterprise security features.

## 🚀 System Requirements

### Hardware Requirements
- **CPU**: 4+ cores (8+ recommended for production)
- **RAM**: 8GB minimum (16GB+ recommended)
- **Storage**: 100GB minimum (500GB+ recommended)
- **Network**: Stable internet connection

### Software Requirements
- **OS**: Ubuntu Server 24.04 LTS or 25.04
- **Architecture**: x86_64 (AMD64)
- **Privileges**: Root/sudo access required
- **Domain**: Optional (required for HTTPS)

## 🛠️ Pre-Deployment Checklist

### 1. System Verification
```bash
# Check Ubuntu version
cat /etc/os-release

# Verify system resources
free -h
df -h
nproc

# Test internet connectivity
curl -I https://google.com
```

### 2. System Preparation
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget git unzip software-properties-common \
    lsb-release build-essential python3-dev

# Set timezone (adjust as needed)
sudo timedatectl set-timezone America/New_York

# Optional: Set hostname
sudo hostnamectl set-hostname noctis-production
```

## 📦 Automated Deployment

### Option 1: Quick Production Deployment

For a complete production deployment with all features:

```bash
# Clone the repository
git clone https://github.com/mwatom/NoctisPro.git
cd NoctisPro

# Make scripts executable
chmod +x *.sh scripts/*.sh

# Configure your domain (optional but recommended)
nano deploy_noctis_production.sh
# Edit line 20: DOMAIN_NAME="your-domain.com"

# Run production deployment
sudo ./deploy_noctis_production.sh
```

This script will:
- ✅ Install Docker with Ubuntu 24.04/25.04 compatibility
- ✅ Configure PostgreSQL database
- ✅ Set up Redis for caching
- ✅ Deploy Django application
- ✅ Configure Nginx reverse proxy
- ✅ Set up systemd services
- ✅ Configure security (firewall, fail2ban)
- ✅ Install printing system (CUPS)
- ✅ Create backup scripts

### Option 2: Manual Step-by-Step Deployment

For more control over the deployment process:

#### Step 1: Install Docker
```bash
# Remove old Docker versions
sudo apt remove -y docker docker-engine docker.io containerd runc

# Install Docker dependencies
sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker
```

#### Step 2: Install System Dependencies
```bash
sudo apt install -y \
    python3 python3-pip python3-venv \
    postgresql postgresql-contrib \
    redis-server nginx certbot python3-certbot-nginx \
    supervisor ufw fail2ban htop tree \
    build-essential libpq-dev libjpeg-dev libpng-dev \
    cups cups-client printer-driver-all
```

#### Step 3: Configure Database
```bash
# Create database and user
sudo -u postgres createdb noctis_pro
sudo -u postgres createuser noctis_user
sudo -u postgres psql -c "ALTER USER noctis_user WITH PASSWORD 'secure_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE noctis_pro TO noctis_user;"
```

#### Step 4: Deploy Application
```bash
# Create project directory
sudo mkdir -p /opt/noctis_pro
sudo useradd -m -s /bin/bash noctis
sudo chown -R noctis:noctis /opt/noctis_pro

# Clone repository
sudo -u noctis git clone https://github.com/mwatom/NoctisPro.git /opt/noctis_pro

# Create virtual environment
cd /opt/noctis_pro
sudo -u noctis python3 -m venv venv
sudo -u noctis ./venv/bin/pip install -r requirements.txt

# Configure environment
sudo -u noctis cp .env.example .env
# Edit .env with your configuration

# Run migrations
sudo -u noctis ./venv/bin/python manage.py migrate --settings=noctis_pro.settings_production
sudo -u noctis ./venv/bin/python manage.py collectstatic --noinput --settings=noctis_pro.settings_production

# Create superuser
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@example.com', 'admin123')" | sudo -u noctis ./venv/bin/python manage.py shell --settings=noctis_pro.settings_production
```

## 🔒 HTTPS Configuration

### Setup Secure Access with SSL

After basic deployment, configure HTTPS:

```bash
# Run secure access setup
sudo ./setup_secure_access.sh

# Choose Option 1: Domain with HTTPS
# Enter your domain name when prompted
```

This will:
- ✅ Configure Let's Encrypt SSL certificate
- ✅ Update Nginx for HTTPS
- ✅ Set up automatic certificate renewal
- ✅ Configure security headers

## 🐳 Docker-based Deployment

### Production Docker Deployment

For containerized deployment:

```bash
# Create environment file
cp .env.example .env
# Edit .env with your configuration

# Deploy with Docker Compose
sudo docker compose -f docker-compose.production.yml up -d

# Check services
sudo docker compose -f docker-compose.production.yml ps
```

## 📊 Validation and Testing

### System Validation

Run the comprehensive validation script:

```bash
# Validate production deployment
python3 validate_production_ubuntu24.py

# Check system status
sudo /usr/local/bin/noctis-status.sh
```

### Access Information

After successful deployment:

- **Web Interface**: `http://your-server-ip` or `https://your-domain.com`
- **Admin Panel**: `http://your-server-ip/admin` or `https://your-domain.com/admin`
- **API Documentation**: `http://your-server-ip/api/docs/`
- **Default Credentials**: admin / admin123 (change immediately!)

## 🖨️ Printing System Setup

### Configure Medical Printing

```bash
# Run printer setup script
sudo ./setup_printer.sh

# Manual printer configuration
sudo system-config-printer
```

Features:
- Medical-grade print quality
- DICOM image printing
- Multiple layout options
- Print queue management

## 🔧 System Management

### Service Management
```bash
# Check service status
sudo systemctl status noctis-django noctis-daphne noctis-celery

# Restart services
sudo systemctl restart noctis-django noctis-daphne noctis-celery nginx

# View logs
sudo journalctl -u noctis-django -f
```

### Backup System
```bash
# Manual backup
sudo /usr/local/bin/noctis-backup.sh

# Restore from backup
sudo /usr/local/bin/noctis-restore.sh /path/to/backup
```

### Monitoring
```bash
# System status
sudo /usr/local/bin/noctis-status.sh

# Resource usage
htop
df -h
```

## 🛡️ Security Features

### Automatic Security Configuration

The deployment includes:
- ✅ UFW firewall configuration
- ✅ Fail2ban intrusion prevention
- ✅ SSL/TLS encryption
- ✅ Security headers
- ✅ Database security
- ✅ Session management

### Security Verification
```bash
# Check firewall status
sudo ufw status verbose

# Verify fail2ban
sudo fail2ban-client status

# Test SSL configuration
curl -I https://your-domain.com
```

## 🏥 Medical Features

### DICOM Processing
- Multi-format DICOM support
- 3D reconstruction capabilities
- Advanced measurement tools
- AI-powered analysis

### Worklist Management
- Patient management system
- Study organization
- Modality support (CT, MRI, X-Ray, etc.)
- Report generation

### Collaboration Tools
- Real-time chat system
- Multi-user viewing
- Annotation sharing
- WebSocket support

## 🔄 Updates and Maintenance

### Automatic Updates

The system includes GitHub webhook support for automatic updates:

```bash
# Webhook URL: https://your-domain.com/webhook
# Configure in GitHub repository settings
```

### Manual Updates
```bash
cd /opt/noctis_pro
sudo -u noctis git pull origin main
sudo -u noctis ./venv/bin/pip install -r requirements.txt
sudo -u noctis ./venv/bin/python manage.py migrate --settings=noctis_pro.settings_production
sudo systemctl restart noctis-django noctis-daphne noctis-celery
```

## ❗ Troubleshooting

### Common Issues

#### Docker Issues on Ubuntu 24.04/25.04
```bash
# Fix iptables compatibility
sudo apt install -y iptables-persistent
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
sudo systemctl restart docker
```

#### Service Startup Issues
```bash
# Check service logs
sudo journalctl -u noctis-django --no-pager -l

# Check dependencies
sudo systemctl status postgresql redis-server

# Restart in order
sudo systemctl restart postgresql redis-server
sudo systemctl restart noctis-django noctis-daphne noctis-celery
```

#### Permission Issues
```bash
# Fix ownership
sudo chown -R noctis:noctis /opt/noctis_pro

# Fix permissions
sudo chmod +x /opt/noctis_pro/manage.py
```

### Log Locations

- **Application Logs**: `/opt/noctis_pro/logs/`
- **System Logs**: `sudo journalctl -u noctis-django`
- **Nginx Logs**: `/var/log/nginx/`
- **Database Logs**: `sudo journalctl -u postgresql`

## 📞 Support

### Getting Help

1. Check the logs for error messages
2. Run the validation script: `python3 validate_production_ubuntu24.py`
3. Check system status: `sudo /usr/local/bin/noctis-status.sh`
4. Review the troubleshooting section above

### System Information

After deployment, save this information:
- Database password (generated during deployment)
- Django secret key (generated during deployment)
- Domain name and SSL certificate details
- Admin credentials (change default password!)

---

## 🎯 Quick Start Summary

For experienced administrators:

```bash
# 1. Clone and prepare
git clone https://github.com/mwatom/NoctisPro.git && cd NoctisPro && chmod +x *.sh

# 2. Configure domain (optional)
nano deploy_noctis_production.sh  # Edit DOMAIN_NAME

# 3. Deploy
sudo ./deploy_noctis_production.sh

# 4. Setup HTTPS (optional)
sudo ./setup_secure_access.sh

# 5. Validate
python3 validate_production_ubuntu24.py
```

**Result**: Complete medical imaging platform with web interface, DICOM processing, AI analysis, printing capabilities, and enterprise security features.

---

**🏥 NoctisPro - Complete Medical Imaging Solution for Ubuntu Server** ✅