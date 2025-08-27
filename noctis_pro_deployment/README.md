# NoctisPro - Enterprise Medical Imaging Platform

[![Deploy Status](https://img.shields.io/badge/deploy-ready-green.svg)](https://github.com/mwatom/NoctisPro)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.11+-blue.svg)](https://python.org)
[![Django](https://img.shields.io/badge/django-5.2.5-green.svg)](https://djangoproject.com)

NoctisPro is a comprehensive, production-ready medical imaging platform designed for healthcare professionals to manage, view, and analyze DICOM medical images with advanced AI-powered features, enterprise-grade security, and **high-quality DICOM image printing on glossy paper**.

## 🚀 Features

### Core Functionality
- **DICOM Viewer**: High-performance medical image viewer with advanced visualization tools
- **🖨️ Medical Image Printing**: High-quality DICOM image printing optimized for glossy photo paper
- **Worklist Management**: Complete study and patient management system
- **Multi-format Support**: DICOM, JPEG, PNG, TIFF, and other medical imaging formats
- **Real-time Collaboration**: Live chat and collaboration tools for medical teams
- **Report Generation**: Comprehensive reporting system with PDF export

### Advanced Features
- **AI-Powered Analysis**: Automated image analysis and anomaly detection
- **3D Reconstruction**: Advanced 3D visualization and reconstruction capabilities
- **PACS Integration**: Seamless integration with existing PACS systems
- **Quality Assurance**: Built-in QA tools for image quality assessment
- **Mobile Support**: Responsive design for mobile and tablet devices

### Enterprise Features
- **Multi-tenant Architecture**: Support for multiple facilities and departments
- **Role-based Access Control**: Granular permissions and user management
- **Audit Logging**: Complete audit trail for compliance
- **High Availability**: Load balancing and failover support
- **Scalable Storage**: Support for cloud and distributed storage

## 🛠️ Technology Stack

- **Backend**: Django 5.2.5, Python 3.11+
- **Frontend**: HTML5, CSS3, JavaScript, Bootstrap 5
- **Database**: PostgreSQL 13+ (Production)
- **Cache & Queue**: Redis 6.0+
- **WebSockets**: Django Channels with Redis
- **Image Processing**: OpenCV, SimpleITK, PyDICOM, GDCM
- **AI/ML**: PyTorch, scikit-learn, transformers
- **🖨️ Printing**: CUPS, ReportLab, PyCUPS for high-quality medical image printing
- **Deployment**: Gunicorn, Daphne, Nginx, Systemd
- **Security**: SSL/TLS, UFW Firewall, Fail2ban
- **Containerization**: Docker & Docker Compose with automatic installation

## 📋 System Requirements

### Minimum Requirements
- **OS**: Ubuntu 20.04+, Ubuntu 22.04+, or **Ubuntu 24.04+ LTS** ✨
- **CPU**: 4 cores (8 cores recommended)
- **RAM**: 8GB (16GB recommended)
- **Storage**: 100GB SSD (500GB+ recommended)
- **Network**: Stable internet connection for updates
- **🖨️ Printer**: Any CUPS-compatible printer (Photo printers + film printers recommended)

### Production Requirements
- **OS**: Ubuntu 22.04 LTS or **Ubuntu 24.04 LTS Server** ✨
- **CPU**: 8+ cores
- **RAM**: 16GB+ 
- **Storage**: 1TB+ NVMe SSD
- **Network**: Dedicated IP, Domain name (optional)
- **SSL**: Valid SSL certificate for HTTPS
- **🖨️ Printer**: Professional photo/film printer with multiple media support

### Recommended Server Configuration
- **512GB NVMe SSD**: For OS, Docker containers, and application runtime
- **2TB HDD**: For DICOM images, media files, and long-term storage
- **Dual Storage Benefits**: Fast performance + Large capacity storage

## 🏥 COMPLETE AUTONOMOUS DEPLOYMENT GUIDE FOR TECHNICIANS

> 🎯 **Designed for Autonomous Deployment**: This guide enables technicians to deploy the system independently without requiring the developer's presence.

> 🏥 **Ubuntu 24.04 Production**: For complete production deployment on Ubuntu 24.04, see [UBUNTU_24_PRODUCTION_DEPLOYMENT.md](UBUNTU_24_PRODUCTION_DEPLOYMENT.md) for full system with HTTPS and all features.

> 📖 **Ubuntu 24.04 Users**: See [UBUNTU_24_DEPLOYMENT_GUIDE.md](UBUNTU_24_DEPLOYMENT_GUIDE.md) for Ubuntu 24.04 specific instructions with enhanced features.

### 🔍 Pre-Deployment System Check

**Before starting, verify your server setup:**

```bash
# Check OS version
lsb_release -a

# Check available storage
lsblk
df -h

# Check memory
free -h

# Check CPU
nproc
cat /proc/cpuinfo | grep "model name" | head -1

# Check network connectivity
ping -c 3 google.com
```

### 💾 STORAGE CONFIGURATION (SSD + HDD Setup)

**For servers with 512GB SSD + 2TB HDD configuration:**

#### Step 1: Configure Storage Partitions

```bash
# Check current disk layout
sudo lsblk
sudo fdisk -l

# Identify your disks (typical examples):
# /dev/nvme0n1 - 512GB NVMe SSD (for OS and Docker)
# /dev/sda - 2TB HDD (for data storage)

# Create data partition on HDD (if not already partitioned)
sudo fdisk /dev/sda
# Press 'n' for new partition
# Press 'p' for primary
# Press '1' for partition number
# Press Enter twice for default start/end
# Press 'w' to write changes

# Format the HDD partition for data storage
sudo mkfs.ext4 /dev/sda1

# Create mount point for data storage
sudo mkdir -p /data

# Get UUID of the HDD partition
sudo blkid /dev/sda1

# Add to fstab for permanent mounting
echo "UUID=$(sudo blkid -s UUID -o value /dev/sda1) /data ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab

# Mount the data partition
sudo mount -a
sudo chmod 755 /data
```

#### Step 2: Configure Docker to Use SSD

```bash
# Create Docker daemon configuration for SSD optimization
sudo mkdir -p /etc/docker

# Configure Docker to use SSD efficiently
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "data-root": "/var/lib/docker",
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "experimental": false
}
EOF
```

#### Step 3: Configure Application Data Storage

```bash
# Create directories for different data types
sudo mkdir -p /data/noctis_pro/{media,dicom_images,backups,logs,temp}
sudo mkdir -p /opt/noctis_pro_fast/{cache,sessions,temp_processing}

# Set proper ownership (will be configured during deployment)
sudo chown -R 1000:1000 /data/noctis_pro/
sudo chown -R 1000:1000 /opt/noctis_pro_fast/
```

### Prerequisites Checklist

**✅ TECHNICIAN CHECKLIST - Complete Before Deployment:**

- [ ] **Server Hardware Verified**
  - [ ] 512GB+ NVMe SSD mounted as root filesystem (/)
  - [ ] 2TB+ HDD available for data storage (/data)
  - [ ] 8GB+ RAM available
  - [ ] 4+ CPU cores available
  - [ ] Network connectivity working

- [ ] **Operating System Ready**
  - [ ] Ubuntu 22.04 LTS or Ubuntu 24.04 LTS Server installed ✨
  - [ ] System fully updated (`sudo apt update && sudo apt upgrade -y`)
  - [ ] Root or sudo access confirmed
  - [ ] SSH access working (if remote deployment)

- [ ] **Network Configuration**
  - [ ] Static IP configured (recommended) or DHCP working
  - [ ] Internet connectivity verified
  - [ ] Domain name available (optional but recommended)
  - [ ] Firewall ports 80, 443, 22 will be accessible

- [ ] **Optional Equipment**
  - [ ] CUPS-compatible printer connected (for DICOM printing)
  - [ ] Print media loaded (paper, film, etc.)

### 🚀 AUTOMATED DEPLOYMENT PROCESS

#### Step 1: Initial Server Setup

```bash
# Update system packages (always run first)
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git unzip software-properties-common lsb-release

# Set server hostname (optional but recommended)
sudo hostnamectl set-hostname noctis-server

# Configure timezone (adjust as needed)
sudo timedatectl set-timezone UTC

# Reboot to ensure all updates are applied
sudo reboot
```

#### Step 2: Download and Prepare Deployment

```bash
# Clone the repository
git clone https://github.com/mwatom/NoctisPro.git
cd NoctisPro

# Make all scripts executable
chmod +x *.sh
chmod +x scripts/*.sh
chmod +x ops/*.sh

# Verify script permissions
ls -la *.sh
```

#### Step 3: Configure Storage (SSD + HDD Setup)

**⚠️ IMPORTANT: Run this BEFORE main deployment if you have separate SSD/HDD:**

```bash
# Run storage configuration script
sudo ./scripts/configure_storage.sh

# This script will:
# ✅ Detect SSD and HDD automatically
# ✅ Configure Docker to use SSD for containers
# ✅ Configure HDD for DICOM images and media
# ✅ Optimize file system for medical imaging
# ✅ Set up proper directory structure
```

#### Step 4: Configure Domain (Optional but Recommended)

**If you have a domain name, configure it before deployment:**

```bash
# Edit the deployment script
nano deploy_noctis_production.sh

# Find and update this line (around line 20):
DOMAIN_NAME="your-actual-domain.com"  # Replace with your domain

# If using IP only, leave as:
DOMAIN_NAME="noctis-server.local"
```

#### Step 5: 🐳 AUTOMATED DOCKER INSTALLATION & DEPLOYMENT

**This is the main deployment command that handles everything:**

```bash
sudo ./deploy_noctis_production.sh
```

**🤖 AUTOMATIC INSTALLATION PROCESS:**

The script will automatically detect and install Docker if not present:

**Docker Installation (Automatic):**
- ✅ **Detects if Docker is already installed**
- ✅ **Removes conflicting Docker versions**
- ✅ **Installs Docker CE from official repository**
- ✅ **Installs Docker Compose V2**
- ✅ **Configures Docker for SSD optimization**
- ✅ **Starts and enables Docker service**
- ✅ **Verifies Docker installation**
- ✅ **Handles Ubuntu 24.04 compatibility issues**

**Complete System Setup (Automatic):**
- ✅ **Detects Ubuntu version** (20.04, 22.04, or 24.04) and applies compatibility fixes
- ✅ **Installs Docker and Docker Compose** with automatic detection and setup
- ✅ **Configures storage optimization** for SSD/HDD configuration
- ✅ **Installs PostgreSQL** with production configuration
- ✅ **Installs Redis** with authentication
- ✅ **Installs Nginx** with security headers
- ✅ **Installs Python 3.11+** and creates virtual environment
- ✅ **Installs all Python dependencies** (including enhanced printing libraries)
- ✅ **Installs CUPS printing system** with film and paper support
- ✅ **Installs printer drivers** for all major brands
- ✅ **Creates secure system user** and directories
- ✅ **Generates secure passwords** and keys
- ✅ **Configures Django** with production settings
- ✅ **Sets up Gunicorn** with optimal workers
- ✅ **Configures Daphne** for WebSockets
- ✅ **Sets up Celery** for background tasks
- ✅ **Configures UFW firewall** with secure rules
- ✅ **Sets up Fail2ban** for security
- ✅ **Creates systemd services** for all components
- ✅ **Sets up automatic backups**
- ✅ **Configures GitHub webhook** for auto-deployment

**Expected deployment time: 15-30 minutes**

#### Step 6: Verify Docker Installation

```bash
# Check Docker status
sudo systemctl status docker

# Verify Docker version
docker --version
docker compose version

# Test Docker functionality
sudo docker run hello-world

# Check Docker storage location (should be on SSD)
sudo docker system df
sudo docker system info | grep "Docker Root Dir"
```

#### Step 7: Configure Internet Access (Optional)

**After deployment, the system is accessible locally. To enable internet access:**

```bash
sudo ./setup_secure_access.sh
```

**Internet Access Options:**

1. **🌐 Domain with HTTPS** (Recommended for internet access)
   - Requires your registered domain name
   - Automatic SSL certificate via Let's Encrypt
   - **Internet Access Link**: `https://your-domain.com`
   - **Admin Panel**: `https://your-domain.com/admin`
   - **Webhook URL**: `https://your-domain.com/webhook`

2. **☁️ Cloudflare Tunnel** (Zero Trust internet access)
   - No open ports required on your server
   - Enhanced DDoS protection and global CDN
   - **Internet Access Link**: Provided by Cloudflare
   - Secure tunnel without exposing server IP

3. **🔐 VPN Access** (Private internet access)
   - WireGuard VPN for secure remote access
   - **VPN Connection**: Configured during setup
   - **Internal Access**: `http://10.0.0.1` (via VPN)

4. **🔒 Local Network Only** (No internet access)
   - Maximum security for facility-only use
   - **Local Access**: `http://192.168.100.15`
   - No internet exposure

#### Step 8: Verify Installation

```bash
# Check all services are running
sudo /usr/local/bin/noctis-status.sh

# Expected output should show all services as "active (running)":
# ✅ noctis-django: active (running)
# ✅ noctis-daphne: active (running) 
# ✅ noctis-celery: active (running)
# ✅ postgresql: active (running)
# ✅ redis: active (running)
# ✅ nginx: active (running)
# ✅ cups: active (running)
# ✅ docker: active (running)

# Check Docker containers
sudo docker ps -a

# Check storage configuration
df -h
```

#### Step 9: First Login and Configuration

1. **Access the application:**
   - **Local Access**: `http://192.168.100.15` (always available)
   - **Internet Access**: `https://your-domain.com` (after running setup_secure_access.sh)
   - **Default admin credentials**:
     - Username: `admin`
     - Password: `admin123`

2. **⚠️ IMMEDIATELY change admin password:**
   ```bash
   cd /opt/noctis_pro
   sudo -u noctis ./venv/bin/python manage.py changepassword admin --settings=noctis_pro.settings_production
   ```

3. **Configure facility-specific settings:**
   - Login to admin panel: `/admin`
   - Configure facility information
   - Set up users and permissions
   - **Optionally configure printers** (if your facility uses DICOM printing)

## 💾 STORAGE OPTIMIZATION GUIDE

### Recommended Storage Layout for 512GB SSD + 2TB HDD

**SSD Usage (Fast Storage - 512GB):**
```
/                    - Root filesystem (50GB)
/var/lib/docker      - Docker containers and images (100GB)
/opt/noctis_pro      - Application code and dependencies (10GB)
/opt/noctis_pro_fast - Cache, sessions, temp processing (50GB)
/swap                - Swap file (16GB)
Free space           - System overhead and updates (286GB)
```

**HDD Usage (Large Storage - 2TB):**
```
/data/noctis_pro/media       - DICOM images and studies (1.5TB)
/data/noctis_pro/backups     - System and database backups (300GB)
/data/noctis_pro/logs        - Long-term log storage (50GB)
/data/noctis_pro/exports     - Report exports and archives (100GB)
Free space                   - Future growth (50GB)
```

### Storage Configuration Script

**The deployment automatically configures storage, but you can run it manually:**

```bash
# Create storage configuration script
sudo ./scripts/configure_storage.sh

# Manual storage verification
sudo ./scripts/verify_storage.sh
```

### Storage Performance Optimization

```bash
# Optimize SSD for Docker
sudo tee -a /etc/fstab > /dev/null <<EOF
# SSD optimizations
/var/lib/docker ext4 defaults,noatime,discard 0 2
EOF

# Optimize HDD for large files
sudo tee -a /etc/fstab > /dev/null <<EOF
# HDD optimizations for large medical files
/data ext4 defaults,noatime,data=writeback 0 2
EOF

# Apply optimizations
sudo mount -o remount /var/lib/docker
sudo mount -o remount /data
```

## 🐳 DOCKER INSTALLATION & MANAGEMENT

### Automatic Docker Installation

**The deployment script automatically handles Docker installation:**

```bash
# Docker installation is automatic, but here's what happens:

# 1. Detection phase
if ! command -v docker &> /dev/null; then
    echo "Docker not found - installing automatically..."
fi

# 2. Cleanup old versions
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# 3. Install Docker CE
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 4. Configure Docker for production
sudo systemctl enable docker
sudo systemctl start docker

# 5. Verify installation
docker --version
docker compose version
```

### Manual Docker Installation (If Needed)

**If automatic installation fails, run manual installation:**

```bash
# Use comprehensive Docker installation script
sudo ./install_docker_comprehensive.sh

# Or use the official Docker installation script
sudo ./get-docker.sh

# Verify installation
sudo docker run hello-world
```

### Docker Storage Configuration

```bash
# Check Docker storage location (should be on SSD)
sudo docker system info | grep "Docker Root Dir"

# Check Docker disk usage
sudo docker system df

# Configure Docker data location (if needed)
sudo systemctl stop docker
sudo mkdir -p /var/lib/docker
sudo systemctl start docker
```

### Docker Container Management

```bash
# View running containers
sudo docker ps

# View all containers
sudo docker ps -a

# Check container logs
sudo docker logs <container_name>

# Restart containers
sudo docker compose restart

# Update containers
sudo docker compose pull
sudo docker compose up -d
```

## 🔧 Post-Deployment Configuration

### Email Configuration (Optional)

```bash
sudo nano /opt/noctis_pro/.env

# Add email settings:
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
DEFAULT_FROM_EMAIL=noctis@your-domain.com
```

### 🌐 Getting Your Internet Access Link

**To get your internet access link, run the secure access setup:**

```bash
sudo ./setup_secure_access.sh
```

**The script will provide your internet access link based on your choice:**

- **🌐 Domain + HTTPS**: `https://your-domain.com` (requires domain)
- **☁️ Cloudflare Tunnel**: Secure Cloudflare URL (no domain needed)
- **🔐 VPN Access**: Private VPN connection for remote access
- **🔒 Local Only**: `http://192.168.100.15` (local network only)

**Your access information is saved to:**
```bash
cat /opt/noctis_pro/SECURE_ACCESS_INFO.txt
```

### GitHub Auto-Deployment Setup

1. **Go to GitHub repository settings**
2. **Navigate to Webhooks**
3. **Add webhook using your internet access link:**
   - **URL**: `https://your-domain.com/webhook` (or your Cloudflare URL)
   - **Content Type**: `application/json`
   - **Events**: Push events
   - **Active**: ✅ Checked

### 🖨️ Printer Setup (OPTIONAL - Configure After Deployment)

**NOTE**: Printer setup is **optional** and can be done **after deployment**. Each facility can choose their preferred printers and configure them as needed.

```bash
# CUPS is automatically installed during deployment
# To configure your facility's printer:

# Check if CUPS is running
sudo systemctl status cups

# Access CUPS web interface
# Open browser to: http://localhost:631
# Go to Administration > Add Printer
# Follow the wizard to add your printer

# Or use command line:
sudo lpadmin -p YourPrinterName -E -v "ipp://printer-ip-address/ipp/print" -m everywhere

# Test printer setup
lpstat -p -d
echo "Test print from NoctisPro" | lp -d YourPrinterName
```

## 📊 System Management Commands

### Service Management
```bash
# Check system status
sudo /usr/local/bin/noctis-status.sh

# View all service logs
sudo journalctl -u noctis-django -u noctis-daphne -u noctis-celery -f

# Restart all services
sudo systemctl restart noctis-django noctis-daphne noctis-celery

# Stop all services
sudo systemctl stop noctis-django noctis-daphne noctis-celery

# Start all services
sudo systemctl start noctis-django noctis-daphne noctis-celery
```

### Docker Management
```bash
# Check Docker status
sudo systemctl status docker

# View Docker containers
sudo docker ps -a

# Check Docker resource usage
sudo docker system df

# Clean up Docker (free space)
sudo docker system prune -f

# Update Docker images
cd /opt/noctis_pro
sudo docker compose pull
sudo docker compose up -d
```

### Storage Management
```bash
# Check storage usage
df -h

# Check DICOM storage on HDD
du -sh /data/noctis_pro/

# Check Docker storage on SSD
sudo du -sh /var/lib/docker/

# Clean up old DICOM files (if needed)
find /data/noctis_pro/media -name "*.dcm" -mtime +90 -type f | wc -l

# Monitor storage usage
watch -n 5 'df -h'
```

### 🖨️ Printer Management
```bash
# Check printer status
lpstat -p -d

# View print queue
lpq

# Cancel all print jobs
cancel -a

# Restart CUPS service
sudo systemctl restart cups

# Check CUPS logs
sudo journalctl -u cups -f

# Test printer connection
sudo lpadmin -p TestPrinter -E -v "ipp://printer-ip/ipp/print" -m everywhere
```

### Database Management
```bash
# Connect to database
sudo -u postgres psql -d noctis_pro

# View database size
sudo -u postgres psql -d noctis_pro -c "SELECT pg_size_pretty(pg_database_size('noctis_pro'));"

# Manual backup
sudo /usr/local/bin/noctis-backup.sh

# Restore from backup (replace YYYYMMDD_HHMMSS with actual timestamp)
sudo -u postgres psql -d noctis_pro < /opt/backups/noctis_pro/database_YYYYMMDD_HHMMSS.sql
```

### Application Updates
```bash
# Manual update
cd /opt/noctis_pro
sudo -u noctis git pull origin main
sudo -u noctis ./venv/bin/pip install -r requirements.txt
sudo -u noctis ./venv/bin/python manage.py migrate --settings=noctis_pro.settings_production
sudo -u noctis ./venv/bin/python manage.py collectstatic --noinput --settings=noctis_pro.settings_production
sudo systemctl restart noctis-django noctis-daphne noctis-celery
```

## 🚨 COMPREHENSIVE TROUBLESHOOTING GUIDE

### Docker Installation Issues

**Issue: Docker installation fails**
```bash
# Solution 1: Clean install Docker
sudo apt remove -y docker docker-engine docker.io containerd runc
sudo apt autoremove -y
sudo apt autoclean

# Re-run deployment
./deploy_noctis_production.sh

# Solution 2: Use manual Docker installation
sudo ./install_docker_comprehensive.sh

# Solution 3: Use official Docker script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

**Issue: Docker daemon fails to start**
```bash
# Check Docker service status
sudo systemctl status docker

# Check Docker logs
sudo journalctl -u docker.service -f

# Restart Docker service
sudo systemctl restart docker

# Check Docker configuration
sudo docker system info
```

**Issue: Ubuntu 24.04 Docker compatibility problems**
```bash
# The deployment script automatically handles Ubuntu 24.04, but if issues persist:

# Fix iptables for Ubuntu 24.04
sudo apt install -y iptables-persistent
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# Install additional packages
sudo apt install -y fuse-overlayfs

# Restart Docker
sudo systemctl restart docker

# Re-run deployment
sudo ./deploy_noctis_production.sh
```

**Issue: Docker permission denied**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
sudo usermod -aG docker noctis

# Restart Docker
sudo systemctl restart docker

# Re-login or restart session
newgrp docker
```

### Storage Issues

**Issue: SSD full - Docker images taking too much space**
```bash
# Check Docker disk usage
sudo docker system df

# Clean up unused Docker data
sudo docker system prune -a -f

# Remove old images
sudo docker image prune -a -f

# Check available space
df -h
```

**Issue: HDD not mounted for data storage**
```bash
# Check mount status
mount | grep /data

# Check fstab entry
cat /etc/fstab | grep /data

# Mount manually
sudo mount /data

# Verify permissions
ls -la /data/noctis_pro/
```

**Issue: Poor performance due to wrong storage usage**
```bash
# Verify Docker is using SSD
sudo docker system info | grep "Docker Root Dir"

# Verify DICOM storage is on HDD
ls -la /data/noctis_pro/media/

# Check if application is using correct paths
grep -r "/data" /opt/noctis_pro/.env
```

### Common Deployment Issues

**Issue: PostgreSQL connection fails**
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Restart PostgreSQL
sudo systemctl restart postgresql

# Check logs
sudo journalctl -u postgresql -f

# Reset database password
sudo -u postgres psql -c "ALTER USER noctis_user PASSWORD 'new_password';"
```

**Issue: Services fail to start**
```bash
# Check service status
sudo systemctl status noctis-django noctis-daphne noctis-celery

# Check logs for errors
sudo journalctl -u noctis-django --since "1 hour ago"

# Restart services
sudo systemctl restart noctis-django noctis-daphne noctis-celery
```

**Issue: Nginx configuration errors**
```bash
# Test Nginx configuration
sudo nginx -t

# Check Nginx status
sudo systemctl status nginx

# Restart Nginx
sudo systemctl restart nginx

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log
```

**Issue: Permission errors**
```bash
# Fix ownership of application files
sudo chown -R noctis:noctis /opt/noctis_pro/
sudo chown -R noctis:noctis /data/noctis_pro/

# Fix permissions
sudo chmod -R 755 /opt/noctis_pro/
sudo chmod -R 755 /data/noctis_pro/

# Restart services
sudo systemctl restart noctis-django
```

### 🖨️ Printing Troubleshooting

**Issue: No printers available**
```bash
# Check CUPS service
sudo systemctl status cups

# Restart CUPS
sudo systemctl restart cups

# Check printer detection
lpstat -p -d

# Re-add printer
sudo lpadmin -p YourPrinter -E -v "usb://path" -m everywhere
```

**Issue: Poor print quality on glossy paper**
```bash
# Check printer settings
lpoptions -p YourPrinter

# Set optimal settings for glossy paper
sudo lpadmin -p YourPrinter -o media-type=photographic-glossy
sudo lpadmin -p YourPrinter -o print-quality=5
sudo lpadmin -p YourPrinter -o Resolution=1200dpi

# Test with high quality
echo "Quality test" | lp -d YourPrinter -o print-quality=5 -o media-type=photographic-glossy
```

**Issue: Print jobs stuck in queue**
```bash
# Check print queue
lpq

# Cancel stuck jobs
cancel -a

# Restart CUPS
sudo systemctl restart cups

# Check CUPS error log
sudo tail -f /var/log/cups/error_log
```

### Network Issues

**Issue: Cannot access web interface**
```bash
# Check if services are running
sudo systemctl status nginx noctis-django

# Check firewall
sudo ufw status

# Check if ports are open
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Test local access
curl -I http://localhost
```

**Issue: SSL certificate problems**
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates
sudo certbot renew

# Test certificate
openssl s_client -connect your-domain.com:443 -servername your-domain.com
```

### Performance Issues

**Issue: Slow DICOM loading**
```bash
# Check available disk space
df -h

# Check memory usage
free -h

# Check system load
top

# Restart services to clear memory
sudo systemctl restart noctis-django noctis-daphne noctis-celery
```

**Issue: Database performance problems**
```bash
# Check database connections
sudo -u postgres psql -d noctis_pro -c "SELECT count(*) FROM pg_stat_activity;"

# Restart PostgreSQL
sudo systemctl restart postgresql

# Check PostgreSQL logs
sudo journalctl -u postgresql -f
```

## 🔄 Maintenance Procedures

### Daily Checks
```bash
# Run system status check
sudo /usr/local/bin/noctis-status.sh

# Check disk space (both SSD and HDD)
df -h

# Check system load
uptime

# Check Docker status
sudo docker ps

# Check print queue
lpq
```

### Weekly Maintenance
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Check service logs for errors
sudo journalctl --since "7 days ago" | grep -i error

# Verify backups
ls -la /data/noctis_pro/backups/

# Clean Docker cache
sudo docker system prune -f

# Test printer functionality
echo "Weekly printer test" | lp
```

### Monthly Maintenance
```bash
# Full system backup
sudo /usr/local/bin/noctis-backup.sh

# Clean old log files
sudo journalctl --vacuum-time=30d

# Update SSL certificates
sudo certbot renew

# Check security updates
sudo apt list --upgradable | grep -i security

# Optimize database
sudo -u postgres psql -d noctis_pro -c "VACUUM ANALYZE;"

# Check storage health
sudo smartctl -a /dev/nvme0n1  # SSD health
sudo smartctl -a /dev/sda      # HDD health
```

## 🆘 Emergency Recovery Procedures

### Complete System Recovery
```bash
# If system is completely broken, restore from backup:

# 1. Stop all services
sudo systemctl stop noctis-django noctis-daphne noctis-celery
sudo docker compose down

# 2. Restore database
sudo -u postgres dropdb noctis_pro
sudo -u postgres createdb noctis_pro -O noctis_user
sudo -u postgres psql -d noctis_pro < /data/noctis_pro/backups/database_LATEST.sql

# 3. Restore media files
sudo rm -rf /data/noctis_pro/media/*
sudo tar -xzf /data/noctis_pro/backups/media_LATEST.tar.gz -C /data/noctis_pro/

# 4. Restart services
sudo docker compose up -d
sudo systemctl start noctis-django noctis-daphne noctis-celery
```

### Docker Recovery
```bash
# Reset Docker completely
sudo systemctl stop docker
sudo rm -rf /var/lib/docker/*
sudo systemctl start docker

# Rebuild containers
cd /opt/noctis_pro
sudo docker compose build --no-cache
sudo docker compose up -d
```

### Storage Recovery
```bash
# Check file system integrity
sudo fsck /dev/nvme0n1p1  # SSD check
sudo fsck /dev/sda1       # HDD check

# Remount storage with proper options
sudo umount /data
sudo mount -o defaults,noatime /data

# Verify storage configuration
cat /etc/fstab
mount | grep -E "(nvme|sda)"
```

## 🛡️ Security Configuration

### Firewall Rules
```bash
# Check firewall status
sudo ufw status verbose

# Standard NoctisPro firewall rules:
# 22/tcp (SSH) - ALLOW
# 80/tcp (HTTP) - ALLOW  
# 443/tcp (HTTPS) - ALLOW
# 631/tcp (CUPS) - ALLOW from local network only
```

### SSL Certificate Management
```bash
# Check certificate status
sudo certbot certificates

# Test certificate renewal
sudo certbot renew --dry-run

# Force certificate renewal
sudo certbot renew --force-renewal
```

## 🎯 TECHNICIAN DEPLOYMENT CHECKLIST

### 📋 Pre-Deployment Verification

**Hardware & OS:**
- [ ] Server has 512GB+ SSD for OS and Docker
- [ ] Server has 2TB+ HDD for data storage (or equivalent large storage)
- [ ] 8GB+ RAM available
- [ ] 4+ CPU cores available
- [ ] Ubuntu 22.04 LTS or 24.04 LTS installed
- [ ] System fully updated (`sudo apt update && sudo apt upgrade -y`)
- [ ] Network connectivity working (`ping google.com`)

**Access & Permissions:**
- [ ] Root or sudo access confirmed
- [ ] SSH access working (if remote)
- [ ] Git installed (`sudo apt install git`)

**Optional Equipment:**
- [ ] Printer connected and powered on
- [ ] Print media loaded (paper/film as preferred)

### 🚀 Deployment Execution

**Step-by-Step Deployment:**
- [ ] Repository cloned: `git clone https://github.com/mwatom/NoctisPro.git`
- [ ] Scripts made executable: `chmod +x *.sh`
- [ ] Storage configured: `sudo ./scripts/configure_storage.sh` (if SSD+HDD)
- [ ] Domain configured in script (if using domain)
- [ ] Main deployment executed: `sudo ./deploy_noctis_production.sh`
- [ ] Docker automatically installed and configured
- [ ] All services started successfully
- [ ] System status verified: `sudo /usr/local/bin/noctis-status.sh`

### 🔍 Post-Deployment Validation

**System Verification:**
- [ ] Web interface accessible: `http://192.168.100.15`
- [ ] Admin login works (admin/admin123)
- [ ] Admin password changed immediately
- [ ] DICOM viewer loads correctly
- [ ] All systemd services running
- [ ] Docker containers running: `sudo docker ps`
- [ ] Storage properly configured: `df -h`

**Security Configuration:**
- [ ] Firewall enabled and configured: `sudo ufw status`
- [ ] Fail2ban active: `sudo fail2ban-client status`
- [ ] SSL certificates installed (if using domain)
- [ ] Secure access configured: `sudo ./setup_secure_access.sh`

**Optional Features:**
- [ ] Printer functionality tested (if printer configured)
- [ ] GitHub webhook configured (if using auto-deployment)
- [ ] Email notifications configured (if needed)

### 📞 Technician Support Resources

**Immediate Help:**
- [ ] All commands documented in this README
- [ ] Log locations identified: `/opt/noctis_pro/logs/`
- [ ] Status check command available: `sudo /usr/local/bin/noctis-status.sh`
- [ ] Backup system verified: `/data/noctis_pro/backups/`

**Emergency Procedures:**
- [ ] Service restart commands documented
- [ ] Docker recovery procedures available
- [ ] Database recovery steps provided
- [ ] Storage recovery instructions included

## 📈 Performance Optimization

### Database Optimization
```bash
# Analyze database performance
sudo -u postgres psql -d noctis_pro -c "SELECT schemaname,tablename,attname,n_distinct,correlation FROM pg_stats WHERE tablename = 'worklist_dicomimage';"

# Vacuum database
sudo -u postgres psql -d noctis_pro -c "VACUUM ANALYZE;"
```

### Docker Performance
```bash
# Optimize Docker for SSD
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "storage-driver": "overlay2",
  "storage-opts": ["overlay2.override_kernel_check=true"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo systemctl restart docker
```

### Storage Performance
```bash
# Monitor I/O performance
iostat -x 1

# Check SSD health
sudo smartctl -a /dev/nvme0n1

# Check HDD health
sudo smartctl -a /dev/sda

# Optimize file systems
sudo tune2fs -o journal_data_writeback /dev/sda1
```

### Print Performance
```bash
# Optimize CUPS for high-volume printing
sudo nano /etc/cups/cupsd.conf

# Add these lines:
# MaxJobs 100
# MaxJobsPerPrinter 10
# MaxJobsPerUser 10

sudo systemctl restart cups
```

## 🖨️ DICOM IMAGE PRINTING SETUP

> 🏥 **Important**: Each facility chooses their own printers based on their needs, budget, and preferences. NoctisPro adapts to work with any CUPS-compatible printer.

### Printer Compatibility
NoctisPro supports **any CUPS-compatible printer** that your facility chooses. The system is designed to work with:

**Any Brand/Model That Supports:**
- CUPS printing system (Linux standard)
- Standard paper sizes (A4, Letter, Custom)
- Various media types (paper, photo paper, film)
- Network or USB connectivity

**Facility Choice Examples:**
- **Budget Options**: Any basic inkjet or laser printer
- **Photo Quality**: Canon PIXMA, Epson SureColor, HP PhotoSmart series
- **Medical Film**: Agfa DryPix, Kodak DryView, Fuji DryPix
- **Large Format**: HP DesignJet, Epson SureColor wide-format
- **Existing Printers**: Any printer already used by your facility

**Print Media (Facility's Choice):**
- **Standard Paper**: Any weight and finish preferred by facility
- **Photo Paper**: Glossy, matte, or satin as preferred
- **Medical Film**: Blue-base, clear-base, or standard medical film
- **Custom Sizes**: Any size supported by your facility's printer

### Printer Installation Steps (For Facilities)

**Each facility configures their own chosen printer:**

**1. Physical Setup:**
```bash
# Connect your facility's printer via USB or network
# Load your preferred print media (paper, photo paper, film)
# Power on printer and ensure ready status
```

**2. Install Drivers for Your Facility's Printer:**
```bash
# The deployment script installs common drivers, but you may need specific ones:

# For Canon printers (if your facility uses Canon)
sudo apt install -y printer-driver-canon

# For Epson printers (if your facility uses Epson)
sudo apt install -y printer-driver-epson

# For HP printers (if your facility uses HP)
sudo apt install -y printer-driver-hplip hplip-gui

# For Brother printers (if your facility uses Brother)
sudo apt install -y printer-driver-brlaser

# For other brands, check: apt search printer-driver-[brand]
```

**3. Add Your Facility's Printer to System:**
```bash
# Method 1: Web interface (easiest for any printer)
# Open: http://localhost:631
# Administration > Add Printer
# Follow wizard, select your facility's printer
# Configure with your preferred media settings

# Method 2: Command line (for any printer brand/model)
# USB printer (auto-detect any brand):
sudo lpadmin -p YourFacilityPrinter -E -v "usb://auto" -m everywhere

# Network printer (any brand with IP):
sudo lpadmin -p YourFacilityPrinter -E -v "ipp://YOUR-PRINTER-IP/ipp/print" -m everywhere

# Set as default (optional)
sudo lpadmin -d YourFacilityPrinter
```

**4. Configure for Your Facility's Needs:**
```bash
# Configure your printer with your facility's preferred settings
# Example for high-quality paper printing:
sudo lpadmin -p YourFacilityPrinter -o media=A4 -o print-quality=5 -o ColorModel=RGB

# Example for film printing (if your facility uses film):
sudo lpadmin -p YourFacilityPrinter -o media-type=film -o Resolution=600dpi

# Use whatever settings work best for your facility's printer and media
```

**5. Test Your Facility's Printer:**
```bash
# Test basic printing with your printer
echo "NoctisPro Printer Test - $(date)" | lp -d YourFacilityPrinter

# Test with your facility's preferred media settings
lp -d YourFacilityPrinter -o print-quality=5 /etc/passwd
```

### Print Quality Settings (Facility Configurable)

**Settings are flexible based on your facility's preferences:**

**For High-Quality Paper Printing:**
- **Resolution**: 600-1200 DPI (as supported by your printer)
- **Color Mode**: RGB Color or Grayscale (facility choice)
- **Media Type**: Photo, Glossy, Matte, or Plain (as preferred)
- **Quality**: High/Best available on your printer
- **Paper Size**: A4, Letter, or custom sizes
- **Orientation**: Portrait or Landscape (layout dependent)

**Print Settings in NoctisPro (Adapts to Your Facility's Printer):**
1. Open DICOM image in viewer
2. Click **Print** button
3. **Select Print Medium**: Paper or Film (based on your facility's capabilities)
4. **Choose Layout**: Single, Quad, Comparison, or modality-specific layouts
5. **Select Your Facility's Printer** from detected printers
6. **Choose Media Type**: Whatever your facility has loaded (paper/film/etc.)
7. **Set Quality**: Best available on your facility's printer
8. Set number of copies
9. Click "Print Image"

**Available Print Layouts by Modality:**
- **CT Scans**: Single, Quad, CT Axial Grid (16 slices), CT MPR Trio (3 planes)
- **MRI**: Single, Quad, MRI Sequences, MRI MPR Trio (3 planes)
- **X-Ray (CR/DX/DR)**: Single, Quad, PA & Lateral views
- **Ultrasound**: Single, Quad, US with Measurements
- **Mammography**: Single, Quad, CC & MLO Views
- **PET**: Single, Quad, PET Fusion
- **All Modalities**: Comparison (side-by-side), Film Standard (minimal text)

## 📋 DEPLOYMENT VALIDATION

### Automated Validation
```bash
# Run comprehensive deployment validation
python3 validate_production.py

# Run simple validation
python3 validate_production_simple.py

# Expected output: All checks should pass ✅
```

### Manual Validation Steps

**1. Web Interface:**
- [ ] Homepage loads without errors
- [ ] Login works correctly
- [ ] Admin panel accessible
- [ ] DICOM viewer opens

**2. DICOM Functionality:**
- [ ] Can upload DICOM files
- [ ] Images display correctly
- [ ] Window/level adjustments work
- [ ] Measurements and annotations function

**3. 🖨️ Enhanced Printing Functionality:**
- [ ] Print button appears in viewer
- [ ] Print dialog opens with all options
- [ ] Print medium selection (Paper/Film) works
- [ ] Layout options load based on modality
- [ ] Printers are detected correctly
- [ ] Test print on glossy paper succeeds
- [ ] Test print on medical film succeeds (if available)
- [ ] Modality-specific layouts render correctly
- [ ] Print quality is medical-grade for all layouts

**4. System Services:**
- [ ] All systemd services running
- [ ] Docker containers healthy
- [ ] Database connections work
- [ ] Redis cache functional
- [ ] Background tasks processing

**5. Security:**
- [ ] HTTPS working (if configured)
- [ ] Firewall rules active
- [ ] Fail2ban monitoring
- [ ] SSL certificates valid

**6. Storage Configuration:**
- [ ] SSD used for OS and Docker: `df -h | grep nvme`
- [ ] HDD used for data storage: `df -h | grep sda`
- [ ] Proper mount points configured: `mount | grep data`
- [ ] Storage performance optimized

## 🌐 INTERNET ACCESS SUMMARY

**✅ YES - The system provides internet access links!**

**How to get your internet access link:**

1. **Deploy the system**: `sudo ./deploy_noctis_production.sh`
2. **Configure internet access**: `sudo ./setup_secure_access.sh`
3. **Get your link**: The script provides your internet URL

**Internet Access Options:**
- **🌐 Domain + HTTPS**: `https://your-domain.com` (requires domain)
- **☁️ Cloudflare Tunnel**: Secure Cloudflare URL (no domain needed)
- **🔐 VPN Access**: Private VPN connection for remote access
- **🔒 Local Only**: `http://192.168.100.15` (local network only)

**Your access information is saved to:**
```bash
cat /opt/noctis_pro/SECURE_ACCESS_INFO.txt
```

## 🚀 Quick Reference Commands

```bash
# System status
sudo /usr/local/bin/noctis-status.sh

# Get internet access link
cat /opt/noctis_pro/SECURE_ACCESS_INFO.txt

# Configure internet access
sudo ./setup_secure_access.sh

# View logs
sudo journalctl -u noctis-django -f

# Restart application
sudo systemctl restart noctis-django noctis-daphne noctis-celery

# Restart Docker containers
sudo docker compose restart

# Backup system
sudo /usr/local/bin/noctis-backup.sh

# Test printer (if configured)
lpstat -p && echo "Test print" | lp

# Update application
cd /opt/noctis_pro && sudo -u noctis git pull && sudo systemctl restart noctis-django

# Check security
sudo ufw status && sudo fail2ban-client status

# Monitor performance
htop

# Check storage usage
df -h && du -sh /data/noctis_pro/ && sudo docker system df
```

## 🏥 Facility User Instructions

### Enhanced DICOM Image Printing (Paper & Film)

1. **Open DICOM Study:**
   - Login to NoctisPro
   - Select patient from worklist
   - Open desired study

2. **Prepare Image for Printing:**
   - Adjust window/level for optimal contrast
   - Use measurement tools if needed
   - Add annotations if required

3. **Configure Print Options:**
   - Click **Print** button in toolbar
   - **Select Print Medium**:
     - 📄 **Paper**: For reports, consultations, patient records
     - 🎞️ **Film**: For diagnostic viewing, archival storage
   - **Choose Layout** (automatically adapts to modality):
     - **Single Image**: Full-page detailed view
     - **Quad Layout**: 4 images for comparison
     - **Side-by-Side**: Before/after comparison
     - **Modality-Specific**: CT grids, MRI sequences, X-ray views
   - **Select Printer** and media type
   - **Set Quality**: High Quality (1200 DPI) recommended

4. **Print High-Quality Output:**
   - **For Paper**: Choose "Glossy Photo Paper" for best results
   - **For Film**: Select appropriate film type (blue-base, clear-base)
   - Enter number of copies
   - Click **"Print Image"**

5. **Verify Print Quality:**
   - Check for proper contrast and detail
   - Ensure patient information is clearly printed
   - Verify layout matches selected option
   - Confirm modality-specific formatting

### Print Quality Tips (For Any Facility Printer)

**General Printing Guidelines:**
- Use **highest quality setting** available on your facility's printer
- Choose **appropriate media type** based on your facility's preference
- Ensure adequate **ink/toner levels** for consistent output
- **Clean printer regularly** according to manufacturer instructions

**Layout Selection Tips:**
- **Single Image**: Best for detailed diagnostic viewing
- **Quad Layout**: Ideal for comparison studies
- **Modality-Specific Layouts**: Optimized for each imaging type
- **Film Standard**: Minimal text for diagnostic film viewing

**Facility-Specific Recommendations:**
- **Paper Choice**: Use whatever paper type your facility prefers
- **Film Choice**: Use medical film if your facility has film printers
- **Quality Settings**: Configure based on your facility's standards
- **Storage**: Follow your facility's protocols for printed materials

## 📞 Technical Support

### Emergency Contacts
- **System Issues**: Check logs first, then restart services
- **Docker Issues**: Use `sudo docker ps` and `sudo docker logs <container>`
- **Storage Issues**: Check `df -h` and mount points
- **Printer Issues**: Verify CUPS service and printer connection
- **Security Issues**: Check firewall and fail2ban logs
- **Performance Issues**: Monitor system resources and restart if needed

### Log Locations
- **Application logs**: `/opt/noctis_pro/logs/`
- **System logs**: `sudo journalctl -u noctis-django`
- **Docker logs**: `sudo docker logs <container_name>`
- **Nginx logs**: `/var/log/nginx/`
- **PostgreSQL logs**: `sudo journalctl -u postgresql`
- **CUPS logs**: `/var/log/cups/`

### Configuration Files
- **Main settings**: `/opt/noctis_pro/.env`
- **Docker config**: `/etc/docker/daemon.json`
- **Nginx config**: `/etc/nginx/sites-available/noctis_pro`
- **Systemd services**: `/etc/systemd/system/noctis-*`
- **CUPS config**: `/etc/cups/cupsd.conf`
- **Storage mounts**: `/etc/fstab`

### Key Directories
- **Application**: `/opt/noctis_pro/` (SSD)
- **Fast cache**: `/opt/noctis_pro_fast/` (SSD)
- **Data storage**: `/data/noctis_pro/` (HDD)
- **Docker data**: `/var/lib/docker/` (SSD)
- **Backups**: `/data/noctis_pro/backups/` (HDD)
- **Media files**: `/data/noctis_pro/media/` (HDD)

### Documentation
- **User Manual**: Available in `/opt/noctis_pro/docs/`
- **API Documentation**: `https://your-domain.com/api/docs/`
- **Admin Guide**: `https://your-domain.com/admin/doc/`

---

**NoctisPro** - Professional Medical Imaging Platform with Autonomous Deployment, Docker Auto-Installation, and Optimized Storage Configuration

*Ready for independent technician deployment ✅*