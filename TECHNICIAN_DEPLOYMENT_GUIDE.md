# 🔧 TECHNICIAN DEPLOYMENT GUIDE - NoctisPro

> **🎯 AUTONOMOUS DEPLOYMENT**: This guide enables technicians to deploy NoctisPro independently without developer assistance.

## 📋 QUICK START CHECKLIST

**⏱️ Total Deployment Time: 30-45 minutes**

### ✅ Pre-Deployment Verification (5 minutes)

**Hardware Requirements:**
- [ ] Server with Ubuntu 22.04 LTS or 24.04 LTS
- [ ] 512GB+ SSD for system and Docker
- [ ] 2TB+ HDD for data storage (optional but recommended)
- [ ] 8GB+ RAM
- [ ] 4+ CPU cores
- [ ] Internet connectivity

**Access Requirements:**
- [ ] Root/sudo access
- [ ] SSH access (if remote)
- [ ] Network connectivity verified: `ping google.com`

## 🚀 AUTOMATED DEPLOYMENT PROCESS

### Step 1: System Preparation (5 minutes)

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y curl wget git unzip software-properties-common lsb-release

# Set hostname
sudo hostnamectl set-hostname noctis-server

# Reboot (recommended)
sudo reboot
```

### Step 2: Download NoctisPro (2 minutes)

```bash
# Clone repository
git clone https://github.com/mwatom/NoctisPro.git
cd NoctisPro

# Make scripts executable
chmod +x *.sh
chmod +x scripts/*.sh

# Verify download
ls -la *.sh
```

### Step 3: Configure Storage (5 minutes) - OPTIONAL

**⚠️ Only run if you have separate SSD + HDD setup:**

```bash
# Configure SSD/HDD storage automatically
sudo ./scripts/configure_storage.sh

# This will:
# ✅ Detect SSD and HDD automatically
# ✅ Configure Docker on SSD
# ✅ Configure data storage on HDD
# ✅ Create optimized directory structure
```

### Step 4: Configure Domain (1 minute) - OPTIONAL

**If you have a domain name:**

```bash
# Edit deployment script
nano deploy_noctis_production.sh

# Change line 20:
DOMAIN_NAME="your-domain.com"  # Replace with your actual domain
```

### Step 5: MAIN DEPLOYMENT (20-30 minutes)

**🤖 This single command installs everything automatically:**

```bash
sudo ./deploy_noctis_production.sh
```

**What this command does automatically:**

**🐳 Docker Installation (if not present):**
- Detects if Docker is installed
- Removes old/conflicting Docker versions
- Installs latest Docker CE from official repository
- Installs Docker Compose V2
- Configures Docker for optimal performance
- Handles Ubuntu 24.04 compatibility issues

**🏥 Complete System Setup:**
- Installs PostgreSQL database
- Installs Redis cache
- Installs Nginx web server
- Installs Python 3.11+ environment
- Installs all dependencies
- Installs CUPS printing system
- Creates secure system user
- Generates secure passwords
- Configures all services
- Sets up firewall and security
- Creates systemd services
- Sets up automatic backups

### Step 6: Verify Installation (2 minutes)

```bash
# Check all services
sudo /usr/local/bin/noctis-status.sh

# Expected output - all should show "active (running)":
# ✅ noctis-django: active (running)
# ✅ noctis-daphne: active (running)
# ✅ noctis-celery: active (running)
# ✅ postgresql: active (running)
# ✅ redis: active (running)
# ✅ nginx: active (running)
# ✅ cups: active (running)
# ✅ docker: active (running)

# Check Docker containers
sudo docker ps

# Check storage
df -h
```

### Step 7: First Access (2 minutes)

```bash
# Access the application
# Local: http://192.168.100.15
# Login: admin / admin123

# IMMEDIATELY change admin password
cd /opt/noctis_pro
sudo -u noctis ./venv/bin/python manage.py changepassword admin --settings=noctis_pro.settings_production
```

### Step 8: Configure Internet Access (5 minutes) - OPTIONAL

```bash
# Enable internet access
sudo ./setup_secure_access.sh

# Choose your option:
# 1. Domain + HTTPS (requires domain)
# 2. Cloudflare Tunnel (no domain needed)
# 3. VPN Access (private)
# 4. Local only (no internet)

# Get your access link
cat /opt/noctis_pro/SECURE_ACCESS_INFO.txt
```

## 🔧 STORAGE CONFIGURATION DETAILS

### Recommended Layout for 512GB SSD + 2TB HDD

**SSD (Fast Storage - 512GB):**
```
/                    - Root filesystem (50GB)
/var/lib/docker      - Docker containers (100GB)
/opt/noctis_pro      - Application code (10GB)
/opt/noctis_pro_fast - Cache & temp (50GB)
/swap                - Swap file (16GB)
Free space           - Updates & overhead (286GB)
```

**HDD (Large Storage - 2TB):**
```
/data/noctis_pro/media    - DICOM images (1.5TB)
/data/noctis_pro/backups  - Backups (300GB)
/data/noctis_pro/logs     - Long-term logs (50GB)
/data/noctis_pro/exports  - Reports (100GB)
Free space                - Future growth (50GB)
```

### Manual Storage Configuration

**If automatic storage configuration fails:**

```bash
# Check available disks
sudo lsblk
sudo fdisk -l

# Create HDD partition (replace /dev/sda with your HDD)
sudo fdisk /dev/sda
# Press: n, p, 1, Enter, Enter, w

# Format HDD
sudo mkfs.ext4 /dev/sda1

# Mount HDD
sudo mkdir -p /data
echo "UUID=$(sudo blkid -s UUID -o value /dev/sda1) /data ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
sudo mount -a

# Create directories
sudo mkdir -p /data/noctis_pro/{media,backups,logs,exports}
sudo mkdir -p /opt/noctis_pro_fast/{cache,sessions,temp}
sudo chown -R 1000:1000 /data/noctis_pro/ /opt/noctis_pro_fast/
```

## 🐳 DOCKER TROUBLESHOOTING

### Docker Installation Issues

**Problem: Docker installation fails**
```bash
# Clean previous installations
sudo apt remove -y docker docker-engine docker.io containerd runc
sudo apt autoremove -y

# Manual Docker installation
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Verify installation
sudo docker run hello-world
```

**Problem: Docker won't start on Ubuntu 24.04**
```bash
# Fix iptables compatibility
sudo apt install -y iptables-persistent
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# Install additional packages
sudo apt install -y fuse-overlayfs

# Restart Docker
sudo systemctl restart docker
```

**Problem: Docker permission denied**
```bash
# Add users to docker group
sudo usermod -aG docker $USER
sudo usermod -aG docker noctis

# Restart Docker
sudo systemctl restart docker

# Test access
sudo docker ps
```

## 🚨 COMMON ISSUES & SOLUTIONS

### Deployment Failures

**Problem: Script stops with permission error**
```bash
# Ensure running as root
sudo ./deploy_noctis_production.sh

# Check script permissions
chmod +x *.sh
```

**Problem: PostgreSQL installation fails**
```bash
# Clean PostgreSQL installation
sudo apt purge -y postgresql* 
sudo apt autoremove -y

# Re-run deployment
sudo ./deploy_noctis_production.sh
```

**Problem: Nginx configuration error**
```bash
# Test Nginx config
sudo nginx -t

# Check for conflicting web servers
sudo systemctl stop apache2 2>/dev/null || true

# Restart Nginx
sudo systemctl restart nginx
```

### Storage Issues

**Problem: HDD not detected**
```bash
# Check available disks
sudo lsblk
sudo fdisk -l

# Manual HDD setup
sudo fdisk /dev/sda  # Replace with your HDD device
sudo mkfs.ext4 /dev/sda1
sudo mkdir -p /data
sudo mount /dev/sda1 /data
```

**Problem: SSD full during deployment**
```bash
# Check disk space
df -h

# Clean package cache
sudo apt clean
sudo apt autoremove -y

# Remove old kernels
sudo apt autoremove --purge -y
```

**Problem: Docker images taking too much space**
```bash
# Clean Docker cache
sudo docker system prune -a -f

# Check Docker usage
sudo docker system df

# Move Docker to different location if needed
sudo systemctl stop docker
sudo mv /var/lib/docker /data/docker
sudo ln -s /data/docker /var/lib/docker
sudo systemctl start docker
```

### Network Issues

**Problem: Cannot access web interface**
```bash
# Check services
sudo systemctl status nginx noctis-django

# Check firewall
sudo ufw status

# Test local access
curl -I http://localhost

# Check if port is in use
sudo netstat -tlnp | grep :80
```

**Problem: SSL certificate fails**
```bash
# Check domain DNS
nslookup your-domain.com

# Test certificate manually
sudo certbot certonly --standalone -d your-domain.com

# Check certificate status
sudo certbot certificates
```

## 📊 MONITORING & MAINTENANCE

### Daily Checks

```bash
# System status
sudo /usr/local/bin/noctis-status.sh

# Storage status
sudo /usr/local/bin/noctis-storage-monitor.sh

# Check logs for errors
sudo journalctl --since "24 hours ago" | grep -i error
```

### Weekly Maintenance

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Clean Docker cache
sudo docker system prune -f

# Check backups
ls -la /data/noctis_pro/backups/

# Test printer (if configured)
lpstat -p && echo "Test print" | lp
```

### Performance Monitoring

```bash
# Check system resources
htop

# Check disk I/O
iostat -x 1

# Check network connections
sudo netstat -tlnp

# Monitor Docker containers
sudo docker stats
```

## 🎯 DEPLOYMENT SUCCESS CRITERIA

### ✅ Successful Deployment Indicators

**System Services:**
- [ ] All services show "active (running)" in status check
- [ ] Web interface accessible at http://192.168.100.15
- [ ] Admin login works (admin/admin123)
- [ ] DICOM viewer loads without errors

**Docker:**
- [ ] Docker service running: `sudo systemctl status docker`
- [ ] Containers running: `sudo docker ps`
- [ ] Docker using SSD: `sudo docker system info | grep "Docker Root Dir"`

**Storage:**
- [ ] SSD used for system: `df -h | grep nvme`
- [ ] HDD used for data: `df -h | grep sda` (if HDD present)
- [ ] Directory structure correct: `ls -la /data/noctis_pro/`

**Security:**
- [ ] Firewall active: `sudo ufw status`
- [ ] Admin password changed
- [ ] Services secured

### 🚨 Failure Indicators

**Red Flags - Contact Support:**
- Services showing "failed" status
- Web interface returns 500 errors
- Docker containers not running
- Database connection errors
- Storage not properly mounted

## 📞 TECHNICIAN SUPPORT

### Emergency Commands

```bash
# Restart everything
sudo systemctl restart noctis-django noctis-daphne noctis-celery nginx postgresql redis docker

# Check all logs
sudo journalctl -u noctis-django -u noctis-daphne -u noctis-celery -f

# Full system status
sudo /usr/local/bin/noctis-status.sh && sudo /usr/local/bin/noctis-storage-monitor.sh
```

### Log Locations

- **Application**: `sudo journalctl -u noctis-django -f`
- **Docker**: `sudo docker logs <container_name>`
- **System**: `sudo journalctl -f`
- **Nginx**: `sudo tail -f /var/log/nginx/error.log`
- **Storage**: `sudo /usr/local/bin/noctis-storage-monitor.sh`

### Configuration Files

- **Main config**: `/opt/noctis_pro/.env`
- **Docker config**: `/etc/docker/daemon.json`
- **Storage mounts**: `/etc/fstab`
- **Services**: `/etc/systemd/system/noctis-*`

## 🔄 POST-DEPLOYMENT TASKS

### Immediate (First 24 hours)

1. **Change admin password** (CRITICAL)
2. **Verify all services running**
3. **Test web interface access**
4. **Configure internet access** (if needed)
5. **Set up basic monitoring**

### Within First Week

1. **Configure facility-specific settings**
2. **Set up user accounts**
3. **Configure printers** (if needed)
4. **Test DICOM upload/viewing**
5. **Set up GitHub webhook** (if using auto-updates)

### Ongoing Maintenance

1. **Weekly system updates**
2. **Monthly backup verification**
3. **Quarterly security review**
4. **Storage monitoring**

---

## 🆘 EMERGENCY CONTACTS

**If deployment fails:**
1. **Check logs**: Use commands in "Emergency Commands" section
2. **Try restart**: Restart all services
3. **Re-run deployment**: `sudo ./deploy_noctis_production.sh`
4. **Document error**: Save error messages for support

**Critical Issues:**
- Database won't start
- Docker installation fails
- Storage configuration errors
- Network access problems

**Non-Critical Issues:**
- Printer configuration
- Email setup
- Performance optimization
- UI customization

---

**✅ DEPLOYMENT COMPLETE**

After successful deployment:
- **Local Access**: http://192.168.100.15
- **Admin Login**: admin / admin123 (change immediately)
- **Status Check**: `sudo /usr/local/bin/noctis-status.sh`
- **Storage Monitor**: `sudo /usr/local/bin/noctis-storage-monitor.sh`

*NoctisPro is now ready for medical imaging operations* 🏥