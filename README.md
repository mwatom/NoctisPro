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

## 📋 System Requirements

### Minimum Requirements
- **OS**: Ubuntu 20.04+ or Ubuntu 22.04+ LTS
- **CPU**: 4 cores (8 cores recommended)
- **RAM**: 8GB (16GB recommended)
- **Storage**: 100GB SSD (500GB+ recommended)
- **Network**: Stable internet connection for updates
- **🖨️ Printer**: Any CUPS-compatible printer (Photo printers recommended for glossy paper)

### Production Requirements
- **OS**: Ubuntu 22.04 LTS Server
- **CPU**: 8+ cores
- **RAM**: 16GB+ 
- **Storage**: 1TB+ NVMe SSD
- **Network**: Dedicated IP, Domain name (optional)
- **SSL**: Valid SSL certificate for HTTPS
- **🖨️ Printer**: Professional photo printer with glossy paper support (Canon, Epson, HP recommended)

## 🏥 COMPLETE DEPLOYMENT GUIDE FOR TECHNICIANS

### Prerequisites Checklist
Before starting deployment, ensure you have:
- [ ] Ubuntu 22.04 LTS Server installed and updated
- [ ] Root or sudo access to the server
- [ ] Network connectivity for package downloads
- [ ] Domain name (optional but recommended)
- [ ] Photo printer connected and configured (for DICOM printing)
- [ ] Glossy photo paper loaded in printer

### Step 1: Initial Server Setup

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git unzip software-properties-common

# Set server hostname (optional)
sudo hostnamectl set-hostname noctis-server

# Reboot to apply updates (recommended)
sudo reboot
```

### Step 2: Clone Repository and Prepare

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

### Step 3: Configure Domain (Optional but Recommended)

If you have a domain name, configure it before deployment:

```bash
# Edit the deployment script
nano deploy_noctis_production.sh

# Find and update this line (around line 20):
DOMAIN_NAME="your-actual-domain.com"  # Replace with your domain

# If using IP only, leave as:
DOMAIN_NAME="noctis-server.local"
```

### Step 4: 🖨️ Printer Setup (ESSENTIAL FOR DICOM PRINTING)

**IMPORTANT**: Set up printing BEFORE running the main deployment to avoid errors.

```bash
# Install CUPS printing system
sudo apt install -y cups cups-client cups-filters printer-driver-all

# Install additional printer drivers for major brands
sudo apt install -y printer-driver-canon printer-driver-epson printer-driver-hplip

# Start and enable CUPS service
sudo systemctl start cups
sudo systemctl enable cups

# Add your user to lpadmin group for printer management
sudo usermod -a -G lpadmin $USER

# Configure CUPS for network access (if needed)
sudo cupsctl --remote-any
sudo systemctl restart cups
```

**Configure Your Printer:**

```bash
# Option 1: Web interface (recommended)
# Open browser to: http://localhost:631
# Go to Administration > Add Printer
# Follow the wizard to add your printer

# Option 2: Command line
sudo lpadmin -p YourPrinterName -E -v "ipp://printer-ip-address/ipp/print" -m everywhere

# Test printer setup
lpstat -p -d
lp -d YourPrinterName /etc/passwd  # Test print
```

### Step 5: Run Main Production Deployment

**CRITICAL**: Run this command exactly as shown:

```bash
sudo ./deploy_noctis_production.sh
```

**This script will automatically:**
- ✅ Install Docker and Docker Compose
- ✅ Install PostgreSQL with production configuration
- ✅ Install Redis with authentication
- ✅ Install Nginx with security headers
- ✅ Install Python 3.11+ and create virtual environment
- ✅ Install all Python dependencies (including printing libraries)
- ✅ Install CUPS printing system and drivers
- ✅ Create secure system user and directories
- ✅ Generate secure passwords and keys
- ✅ Configure Django with production settings
- ✅ Set up Gunicorn with optimal workers
- ✅ Configure Daphne for WebSockets
- ✅ Set up Celery for background tasks
- ✅ Configure UFW firewall with secure rules
- ✅ Set up Fail2ban for security
- ✅ Create systemd services for all components
- ✅ Set up automatic backups
- ✅ Configure GitHub webhook for auto-deployment

**Expected deployment time: 15-25 minutes**

### Step 6: Configure Secure Access

```bash
sudo ./setup_secure_access.sh
```

**Choose your access method:**

1. **🌐 Domain with SSL Certificate** (Recommended for internet access)
   - Requires registered domain name
   - Automatic SSL via Let's Encrypt
   - Access: `https://your-domain.com`

2. **🔒 Local Network Only** (Recommended for facility-only use)
   - No internet exposure
   - Access: `http://192.168.100.15`
   - Maximum security for internal use

3. **☁️ Cloudflare Tunnel** (Zero Trust option)
   - No open ports required
   - Enhanced DDoS protection
   - Global CDN acceleration

4. **🔐 VPN Access Only**
   - WireGuard VPN setup
   - Private network access
   - Ultra-secure for sensitive environments

### Step 7: Verify Installation

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
```

### Step 8: First Login and Configuration

1. **Access the application:**
   - Web: `https://your-domain.com` or `http://192.168.100.15`
   - Default admin credentials:
     - Username: `admin`
     - Password: `admin123`

2. **⚠️ IMMEDIATELY change admin password:**
   ```bash
   cd /opt/noctis_pro
   sudo -u noctis ./venv/bin/python manage.py changepassword admin --settings=noctis_pro.settings_production
   ```

3. **Configure printer settings:**
   - Login to admin panel: `/admin`
   - Go to DICOM Viewer settings
   - Test printer connectivity
   - Set default glossy paper settings

### Step 9: 🖨️ Configure DICOM Image Printing

**Test Printer Setup:**

```bash
# Verify printer is detected
lpstat -p -d

# Test basic printing
echo "Test print from NoctisPro" | lp

# Check print queue
lpq

# If printer not working, check status:
sudo systemctl status cups
sudo journalctl -u cups -f
```

**Configure Glossy Paper Settings:**

1. **Access CUPS web interface**: `http://localhost:631`
2. **Go to Printers > Your Printer > Set Default Options**
3. **Configure for medical imaging:**
   - **Media Type**: Photo/Glossy
   - **Print Quality**: High/Best
   - **Color Mode**: Color
   - **Resolution**: 1200 DPI or highest available
   - **Paper Size**: A4 or Letter

**Test DICOM Printing:**

1. Login to NoctisPro
2. Open any DICOM study
3. Click the **Print** button in the viewer
4. Select your printer and "Glossy Photo Paper"
5. Click "Print Image"
6. Verify high-quality output on glossy paper

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

### GitHub Auto-Deployment Setup

1. **Go to GitHub repository settings**
2. **Navigate to Webhooks**
3. **Add webhook:**
   - **URL**: `https://your-domain.com/webhook`
   - **Content Type**: `application/json`
   - **Events**: Push events
   - **Active**: ✅ Checked

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

## 🖨️ DICOM IMAGE PRINTING SETUP

### Supported Printers
NoctisPro supports any CUPS-compatible printer. **Recommended printers for medical imaging:**

**Professional Photo Printers:**
- Canon PIXMA Pro series (Pro-200, Pro-300)
- Epson SureColor series (P400, P600, P800)
- HP DesignJet series
- Brother MFC-J series with photo capabilities

**Paper Recommendations:**
- **Glossy Photo Paper**: 4"x6", 8.5"x11", A4 glossy
- **Weight**: 200-300 GSM for durability
- **Brands**: Canon Pro Platinum, Epson Premium Glossy, HP Advanced Photo Paper

### Printer Installation Steps

**1. Physical Setup:**
```bash
# Connect printer via USB or network
# Load glossy photo paper in correct tray
# Power on printer and ensure ready status
```

**2. Install Printer Drivers:**
```bash
# For Canon printers
sudo apt install -y printer-driver-canon

# For Epson printers  
sudo apt install -y printer-driver-epson

# For HP printers
sudo apt install -y printer-driver-hplip hplip-gui

# For Brother printers
sudo apt install -y printer-driver-brlaser
```

**3. Add Printer to System:**
```bash
# Method 1: Web interface (easiest)
# Open: http://localhost:631
# Administration > Add Printer
# Follow wizard, select your printer
# Set default options for photo/glossy paper

# Method 2: Command line
# USB printer:
sudo lpadmin -p MedicalPrinter -E -v "usb://Canon/PIXMA%20Pro-200" -m everywhere

# Network printer:
sudo lpadmin -p MedicalPrinter -E -v "ipp://192.168.1.100/ipp/print" -m everywhere

# Set as default
sudo lpadmin -d MedicalPrinter
```

**4. Configure for Medical Imaging:**
```bash
# Set optimal defaults for medical images
sudo lpadmin -p MedicalPrinter -o media=A4 -o print-quality=5 -o ColorModel=RGB
sudo lpadmin -p MedicalPrinter -o media-type=photographic-glossy -o Resolution=1200dpi
```

**5. Test Printing:**
```bash
# Test basic printing
echo "NoctisPro Printer Test" | lp -d MedicalPrinter

# Test photo quality
lp -d MedicalPrinter -o media-type=photographic-glossy -o print-quality=5 /etc/passwd
```

### Print Quality Settings

**For Glossy Paper (Recommended):**
- **Resolution**: 1200 DPI minimum
- **Color Mode**: RGB Color
- **Media Type**: Photographic Glossy
- **Quality**: Best/High (Level 5)
- **Paper Size**: A4 or Letter
- **Orientation**: Portrait

**Print Settings in NoctisPro:**
1. Open DICOM image in viewer
2. Click **Print** button
3. Select printer and "Glossy Photo Paper"
4. Choose "High Quality (1200 DPI)"
5. Set number of copies
6. Click "Print Image"

## 🚨 TROUBLESHOOTING GUIDE

### Common Deployment Issues

**Issue: Docker installation fails**
```bash
# Solution: Clean install Docker
sudo apt remove -y docker docker-engine docker.io containerd runc
sudo apt autoremove -y
sudo apt autoclean
./deploy_noctis_production.sh  # Re-run deployment
```

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

**Issue: Permission denied for printing**
```bash
# Add noctis user to lp group
sudo usermod -a -G lp noctis

# Restart NoctisPro services
sudo systemctl restart noctis-django
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

# Check disk space
df -h

# Check system load
uptime

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
ls -la /opt/backups/noctis_pro/

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
```

## 📈 Performance Optimization

### Database Optimization
```bash
# Analyze database performance
sudo -u postgres psql -d noctis_pro -c "SELECT schemaname,tablename,attname,n_distinct,correlation FROM pg_stats WHERE tablename = 'worklist_dicomimage';"

# Vacuum database
sudo -u postgres psql -d noctis_pro -c "VACUUM ANALYZE;"
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

## 🆘 Emergency Recovery Procedures

### Complete System Recovery
```bash
# If system is completely broken, restore from backup:

# 1. Stop all services
sudo systemctl stop noctis-django noctis-daphne noctis-celery

# 2. Restore database
sudo -u postgres dropdb noctis_pro
sudo -u postgres createdb noctis_pro -O noctis_user
sudo -u postgres psql -d noctis_pro < /opt/backups/noctis_pro/database_LATEST.sql

# 3. Restore media files
sudo rm -rf /opt/noctis_pro/media/*
sudo tar -xzf /opt/backups/noctis_pro/media_LATEST.tar.gz -C /opt/noctis_pro/

# 4. Restart services
sudo systemctl start noctis-django noctis-daphne noctis-celery
```

### Printer Recovery
```bash
# Reset CUPS completely
sudo systemctl stop cups
sudo rm -rf /etc/cups/printers.conf
sudo rm -rf /etc/cups/ppd/*
sudo systemctl start cups

# Re-add printers
sudo lpadmin -p MedicalPrinter -E -v "usb://path" -m everywhere
sudo lpadmin -p MedicalPrinter -o media-type=photographic-glossy -o print-quality=5
```

## 📞 Support Information

### Log Locations
- **Application logs**: `/opt/noctis_pro/logs/`
- **System logs**: `sudo journalctl -u noctis-django`
- **Nginx logs**: `/var/log/nginx/`
- **PostgreSQL logs**: `sudo journalctl -u postgresql`
- **CUPS logs**: `/var/log/cups/`

### Configuration Files
- **Main settings**: `/opt/noctis_pro/.env`
- **Nginx config**: `/etc/nginx/sites-available/noctis_pro`
- **Systemd services**: `/etc/systemd/system/noctis-*`
- **CUPS config**: `/etc/cups/cupsd.conf`

### Key Directories
- **Application**: `/opt/noctis_pro/`
- **Backups**: `/opt/backups/noctis_pro/`
- **Media files**: `/opt/noctis_pro/media/`
- **Static files**: `/opt/noctis_pro/static/`

## 🎯 DEPLOYMENT CHECKLIST

**Pre-Deployment:**
- [ ] Ubuntu 22.04 LTS installed and updated
- [ ] Network connectivity verified
- [ ] Domain name configured (if using)
- [ ] Printer connected and tested
- [ ] Glossy photo paper loaded

**During Deployment:**
- [ ] Repository cloned successfully
- [ ] Scripts made executable
- [ ] Main deployment script completed without errors
- [ ] All services started successfully
- [ ] Secure access configured
- [ ] Admin password changed
- [ ] Printer configured for glossy paper

**Post-Deployment:**
- [ ] Web interface accessible
- [ ] DICOM viewer loads correctly
- [ ] Print functionality tested with glossy paper
- [ ] GitHub webhook configured (if using auto-deployment)
- [ ] Backup system verified
- [ ] Security scan completed
- [ ] Documentation provided to facility users

## 🏥 Facility User Instructions

### Printing DICOM Images on Glossy Paper

1. **Open DICOM Study:**
   - Login to NoctisPro
   - Select patient from worklist
   - Open desired study

2. **Prepare Image for Printing:**
   - Adjust window/level for optimal contrast
   - Use measurement tools if needed
   - Add annotations if required

3. **Print High-Quality Image:**
   - Click **Print** button in toolbar
   - Select your photo printer
   - Choose **"Glossy Photo Paper"**
   - Set quality to **"High Quality (1200 DPI)"**
   - Enter number of copies
   - Click **"Print Image"**

4. **Verify Print Quality:**
   - Check for proper contrast and detail
   - Ensure patient information is clearly printed
   - Verify timestamp and facility information

### Print Quality Tips
- Always use **glossy photo paper** for medical images
- Set printer to **highest quality** (1200 DPI)
- Ensure adequate ink/toner levels
- Clean printer heads regularly for optimal output
- Store printed images in protective sleeves

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

**3. 🖨️ Printing Functionality:**
- [ ] Print button appears in viewer
- [ ] Print dialog opens correctly
- [ ] Printers are detected
- [ ] Test print on glossy paper succeeds
- [ ] Print quality is medical-grade

**4. System Services:**
- [ ] All systemd services running
- [ ] Database connections work
- [ ] Redis cache functional
- [ ] Background tasks processing

**5. Security:**
- [ ] HTTPS working (if configured)
- [ ] Firewall rules active
- [ ] Fail2ban monitoring
- [ ] SSL certificates valid

## 🚀 Quick Reference Commands

```bash
# System status
sudo /usr/local/bin/noctis-status.sh

# View logs
sudo journalctl -u noctis-django -f

# Restart application
sudo systemctl restart noctis-django noctis-daphne noctis-celery

# Backup system
sudo /usr/local/bin/noctis-backup.sh

# Test printer
lpstat -p && echo "Test print" | lp

# Update application
cd /opt/noctis_pro && sudo -u noctis git pull && sudo systemctl restart noctis-django

# Check security
sudo ufw status && sudo fail2ban-client status

# Monitor performance
htop
```

---

## 📞 Technical Support

### Emergency Contacts
- **System Issues**: Check logs first, then restart services
- **Printer Issues**: Verify CUPS service and printer connection
- **Security Issues**: Check firewall and fail2ban logs
- **Performance Issues**: Monitor system resources and restart if needed

### Documentation
- **User Manual**: Available in `/opt/noctis_pro/docs/`
- **API Documentation**: `https://your-domain.com/api/docs/`
- **Admin Guide**: `https://your-domain.com/admin/doc/`

---

**NoctisPro** - Professional Medical Imaging Platform with High-Quality DICOM Printing Support

*Deployment completed successfully ✅*