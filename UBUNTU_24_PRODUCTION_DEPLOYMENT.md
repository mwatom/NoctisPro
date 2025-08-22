# 🏥 Ubuntu 24.04 Production Deployment - NoctisPro

> **🎯 Full Production System**: Complete medical imaging platform for customer evaluation and production use

## 📋 PRODUCTION DEPLOYMENT OVERVIEW

**Goal**: Deploy complete, production-ready NoctisPro on Ubuntu 24.04 for customer evaluation
**Time**: 25-35 minutes
**Result**: Full production system with HTTPS, security, and all features operational

## 🚀 PRODUCTION DEPLOYMENT PROCESS

### Prerequisites (3 minutes)

**Server Requirements:**
- Ubuntu 24.04 LTS Server (fresh installation recommended)
- 8GB+ RAM (16GB recommended for production)
- 100GB+ storage (500GB+ recommended)
- Internet connectivity
- Domain name (required for HTTPS)
- Root/sudo access

**Pre-deployment Verification:**
```bash
# Verify Ubuntu 24.04
lsb_release -a

# Check system resources
free -h
df -h
nproc

# Verify internet connectivity
ping -c 3 google.com

# Check domain DNS (replace with your domain)
nslookup your-production-domain.com
```

### Step 1: System Preparation (5 minutes)

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git unzip software-properties-common lsb-release build-essential

# Set production hostname
sudo hostnamectl set-hostname noctis-production

# Configure timezone for your location
sudo timedatectl set-timezone America/New_York  # Adjust as needed

# Reboot to apply all updates
sudo reboot
```

### Step 2: Download NoctisPro (3 minutes)

```bash
# Clone the complete repository
git clone https://github.com/mwatom/NoctisPro.git
cd NoctisPro

# Make all scripts executable
chmod +x *.sh
chmod +x scripts/*.sh
chmod +x ops/*.sh

# Verify all deployment scripts
ls -la *.sh | grep deploy
```

### Step 3: Configure Production Domain (2 minutes)

**⚠️ CRITICAL: Configure your production domain**

```bash
# Edit the main deployment script
nano deploy_noctis_production.sh

# Update line 20 with your production domain:
DOMAIN_NAME="your-production-domain.com"  # Replace with actual domain

# Verify your domain points to this server
dig your-production-domain.com
nslookup your-production-domain.com
```

### Step 4: Production Deployment (20-25 minutes)

```bash
# Run complete production deployment
sudo ./deploy_noctis_production.sh
```

**🏥 COMPLETE PRODUCTION INSTALLATION:**

**Ubuntu 24.04 Optimizations:**
- ✅ **Automatic Ubuntu 24.04 detection** and compatibility fixes
- ✅ **iptables-persistent** installation for network compatibility
- ✅ **iptables-legacy** configuration for Docker
- ✅ **fuse-overlayfs** for advanced container support
- ✅ **Ubuntu 24.04 Docker daemon** optimization

**Core Infrastructure:**
- ✅ **Docker & Docker Compose** (automatic installation with Ubuntu 24.04 support)
- ✅ **PostgreSQL 14+** with production configuration
- ✅ **Redis 6.0+** with authentication and persistence
- ✅ **Nginx** with production security headers
- ✅ **Python 3.11+** virtual environment
- ✅ **All dependencies** including medical imaging libraries

**Medical Imaging Features:**
- ✅ **DICOM processing** (PyDICOM, GDCM, SimpleITK)
- ✅ **Image processing** (OpenCV, PIL, medical codecs)
- ✅ **3D reconstruction** capabilities
- ✅ **AI/ML frameworks** (PyTorch, scikit-learn)
- ✅ **PACS integration** libraries

**Printing System:**
- ✅ **CUPS printing system** with medical-grade configuration
- ✅ **Printer drivers** for all major brands (Canon, Epson, HP, Brother)
- ✅ **Medical printing** optimizations for film and paper
- ✅ **Print queue management** and monitoring

**Security & Compliance:**
- ✅ **UFW firewall** with medical facility security rules
- ✅ **Fail2ban** intrusion prevention
- ✅ **SSL/TLS** encryption for all communications
- ✅ **Audit logging** for compliance tracking
- ✅ **Session security** with secure cookies

**Production Services:**
- ✅ **Gunicorn** WSGI server with multiple workers
- ✅ **Daphne** ASGI server for WebSockets
- ✅ **Celery** background task processing
- ✅ **Systemd services** for all components
- ✅ **Automatic startup** configuration

**Backup & Monitoring:**
- ✅ **Automated backups** (database and media)
- ✅ **Log rotation** and management
- ✅ **Health monitoring** scripts
- ✅ **Performance monitoring** tools

### Step 5: Configure Production HTTPS (5 minutes)

```bash
# Configure secure production access
sudo ./setup_secure_access.sh

# Choose Option 1: Domain with HTTPS for production
# This will:
# ✅ Install and configure Let's Encrypt SSL certificate
# ✅ Set up automatic certificate renewal
# ✅ Configure Nginx with production security headers
# ✅ Enable HTTPS enforcement (HTTP redirects to HTTPS)
# ✅ Configure firewall for secure access
# ✅ Set up monitoring for certificate expiration
```

### Step 6: Production System Verification (5 minutes)

```bash
# Comprehensive system status check
sudo /usr/local/bin/noctis-status.sh

# Expected output - ALL services active:
# ✅ noctis-django: active (running)
# ✅ noctis-daphne: active (running)
# ✅ noctis-celery: active (running)
# ✅ postgresql: active (running)
# ✅ redis: active (running)
# ✅ nginx: active (running)
# ✅ cups: active (running)
# ✅ docker: active (running)

# Validate production deployment
python3 validate_production.py

# Get production access information
cat /opt/noctis_pro/SECURE_ACCESS_INFO.txt
```

## 🌐 PRODUCTION ACCESS INFORMATION

### Customer Production Access

**Primary Access:**
- **Production URL**: `https://your-production-domain.com`
- **Admin Panel**: `https://your-production-domain.com/admin`
- **API Documentation**: `https://your-production-domain.com/api/docs/`
- **WebSocket Support**: Automatic (for real-time features)

**Backup Access:**
- **Local Network**: `http://192.168.100.15`
- **Direct IP**: `http://[server-ip]`

### Production Credentials

**Initial Admin Account:**
- **Username**: `admin`
- **Password**: `admin123`

**⚠️ CRITICAL: Change admin password immediately after first login!**

```bash
# Change admin password
cd /opt/noctis_pro
sudo -u noctis ./venv/bin/python manage.py changepassword admin --settings=noctis_pro.settings_production
```

## ✅ PRODUCTION FUNCTIONALITY VERIFICATION

### 1. Complete System Testing

**Web Interface Verification:**
```bash
# Test HTTPS access
curl -I https://your-production-domain.com

# Test SSL certificate
openssl s_client -connect your-production-domain.com:443 -servername your-production-domain.com

# Test HTTP to HTTPS redirect
curl -I http://your-production-domain.com
```

**Expected Results:**
- HTTPS returns HTTP 200 OK
- SSL certificate is valid and trusted
- HTTP automatically redirects to HTTPS (301/302)

### 2. Medical Imaging Features Testing

**DICOM Functionality:**
1. **Access System**: `https://your-production-domain.com`
2. **Login**: Use admin credentials
3. **Navigate to Worklist**: Verify patient management interface
4. **Open DICOM Viewer**: Test medical image viewer
5. **Test Image Tools**: Window/level, measurements, annotations
6. **Verify 3D Features**: 3D reconstruction capabilities
7. **Test AI Analysis**: Automated analysis features

**Worklist Management:**
1. **Patient Management**: Create, edit, search patients
2. **Study Organization**: Manage medical studies
3. **Modality Support**: Test CT, MRI, X-Ray, Ultrasound
4. **Search & Filter**: Advanced search capabilities
5. **Report Generation**: Create and export reports

### 3. Advanced Features Testing

**Real-time Collaboration:**
1. **Chat System**: Test real-time messaging
2. **Live Collaboration**: Multi-user image viewing
3. **WebSocket Features**: Real-time updates
4. **Notification System**: Alert and notification features

**Enterprise Features:**
1. **User Management**: Role-based access control
2. **Audit Logging**: Complete activity tracking
3. **Multi-tenant Support**: Department/facility separation
4. **API Access**: RESTful API for integrations

### 4. Printing System Testing

**Medical Printing Features:**
1. **Access Print Options**: From DICOM viewer
2. **Print Layouts**: Single, quad, comparison layouts
3. **Modality-Specific**: CT grids, MRI sequences, X-ray views
4. **Print Quality**: High-resolution medical-grade output
5. **Media Support**: Paper, film, custom sizes
6. **Print Queue**: Management and monitoring

**Print Configuration:**
```bash
# Verify CUPS printing system
sudo systemctl status cups

# Check available printers
lpstat -p -d

# Test print functionality (if printer available)
echo "NoctisPro Production Test" | lp
```

## 🛡️ PRODUCTION SECURITY FEATURES

### Automatic Security Configuration

**SSL/TLS Security:**
- ✅ **Let's Encrypt SSL** certificate (automatically renewed)
- ✅ **TLS 1.2+** encryption for all communications
- ✅ **HSTS headers** for security enforcement
- ✅ **Secure cookie** configuration
- ✅ **CSP headers** for XSS protection

**Network Security:**
- ✅ **UFW firewall** with production rules
- ✅ **Fail2ban** intrusion prevention
- ✅ **Rate limiting** for API endpoints
- ✅ **DDoS protection** via Nginx
- ✅ **Secure headers** (X-Frame-Options, etc.)

**Application Security:**
- ✅ **Database encryption** at rest
- ✅ **Session security** with secure tokens
- ✅ **CSRF protection** for all forms
- ✅ **SQL injection** prevention
- ✅ **File upload** security scanning

**Compliance Features:**
- ✅ **Audit logging** for all user actions
- ✅ **Data encryption** for DICOM files
- ✅ **Access control** with role-based permissions
- ✅ **Session management** with timeout
- ✅ **Backup encryption** for data protection

### Security Verification

```bash
# Check firewall status
sudo ufw status verbose

# Verify fail2ban
sudo fail2ban-client status

# Test SSL security rating
curl -I https://your-production-domain.com | grep -E "(Strict-Transport|X-Frame|Content-Security)"

# Check certificate validity
sudo certbot certificates
```

## 📊 PRODUCTION MONITORING & MAINTENANCE

### Real-time Monitoring

**System Health Monitoring:**
```bash
# Comprehensive status check
sudo /usr/local/bin/noctis-status.sh

# Resource monitoring
htop

# Network monitoring
sudo netstat -tlnp

# Service logs
sudo journalctl -u noctis-django -f
```

**Performance Monitoring:**
```bash
# Database performance
sudo -u postgres psql -d noctis_pro -c "SELECT count(*) FROM pg_stat_activity;"

# Cache performance
redis-cli info memory

# Web server performance
sudo tail -f /var/log/nginx/access.log
```

### Production Maintenance

**Daily Operations:**
```bash
# System health check
sudo /usr/local/bin/noctis-status.sh

# Check disk space
df -h

# Monitor active users
sudo -u postgres psql -d noctis_pro -c "SELECT count(DISTINCT user_id) FROM django_session WHERE expire_date > NOW();"

# Check print queue
lpq
```

**Weekly Maintenance:**
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Database maintenance
sudo -u postgres psql -d noctis_pro -c "VACUUM ANALYZE;"

# Clean temporary files
sudo systemctl restart redis

# Verify backups
ls -la /opt/backups/noctis_pro/
```

**Monthly Maintenance:**
```bash
# Full system backup
sudo /usr/local/bin/noctis-backup.sh

# SSL certificate renewal check
sudo certbot renew --dry-run

# Security audit
sudo fail2ban-client status
sudo ufw status verbose

# Performance optimization
sudo systemctl restart noctis-django noctis-daphne noctis-celery
```

## 🔧 UBUNTU 24.04 PRODUCTION OPTIMIZATIONS

### Automatic Ubuntu 24.04 Configuration

**The deployment script automatically handles:**
- ✅ **Network compatibility** with iptables-legacy
- ✅ **Container support** with fuse-overlayfs
- ✅ **Docker optimization** for Ubuntu 24.04
- ✅ **Package compatibility** resolution
- ✅ **Performance tuning** for medical workloads

### Manual Ubuntu 24.04 Optimizations

**Additional Performance Tuning:**
```bash
# Optimize kernel parameters for medical imaging
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF
# Medical imaging optimizations
vm.swappiness=10
vm.dirty_ratio=15
vm.dirty_background_ratio=5
net.core.rmem_max=134217728
net.core.wmem_max=134217728
EOF

# Apply optimizations
sudo sysctl -p

# Optimize PostgreSQL for medical data
sudo nano /etc/postgresql/*/main/postgresql.conf
# Add these lines:
# shared_buffers = 256MB
# effective_cache_size = 1GB
# work_mem = 4MB
# maintenance_work_mem = 64MB
# max_connections = 200

sudo systemctl restart postgresql
```

## 🏥 PRODUCTION FEATURES FOR CUSTOMER EVALUATION

### Complete Medical Imaging Platform

**Core Medical Features:**
1. **DICOM Viewer**
   - Multi-planar reconstruction (MPR)
   - 3D volume rendering
   - Advanced measurement tools
   - Window/level presets for all modalities
   - Cine loop playback
   - Zoom, pan, rotate functionality

2. **Worklist Management**
   - HL7 integration ready
   - PACS connectivity
   - Modality worklist (MWL)
   - Study routing and distribution
   - Patient demographics management
   - Study status tracking

3. **Advanced Imaging Tools**
   - Multi-planar reconstruction
   - Maximum intensity projection (MIP)
   - Volume rendering
   - Curved planar reconstruction
   - Fusion imaging capabilities
   - Quantitative analysis tools

**Enterprise Features:**
1. **User Management**
   - Role-based access control
   - Department-based permissions
   - Audit trail for all actions
   - Single sign-on (SSO) ready
   - LDAP integration support

2. **Reporting System**
   - Structured reporting templates
   - Voice-to-text integration ready
   - PDF report generation
   - Report distribution
   - Template customization

3. **Quality Assurance**
   - Image quality metrics
   - Automated QA checks
   - Compliance monitoring
   - Performance analytics
   - Error tracking and reporting

### Production Printing System

**Medical-Grade Printing:**
1. **High-Quality Output**
   - 1200+ DPI resolution support
   - Medical film printing
   - Glossy paper optimization
   - Grayscale accuracy
   - Color calibration

2. **Print Layouts**
   - Modality-specific layouts
   - Multi-image comparisons
   - Before/after studies
   - Measurement annotations
   - Patient information headers

3. **Print Management**
   - Print queue monitoring
   - Batch printing capabilities
   - Print history tracking
   - Cost tracking per print
   - Printer status monitoring

## 🌐 HTTPS PRODUCTION CONFIGURATION

### SSL Certificate Setup

**Automatic Production SSL:**
```bash
# The setup_secure_access.sh script provides:
# ✅ Let's Encrypt SSL certificate (90-day validity)
# ✅ Automatic renewal (systemd timer)
# ✅ Strong SSL configuration (A+ rating)
# ✅ Security headers (HSTS, CSP, etc.)
# ✅ HTTP to HTTPS redirect
```

**SSL Configuration Verification:**
```bash
# Check certificate status
sudo certbot certificates

# Test SSL configuration
openssl s_client -connect your-production-domain.com:443 -servername your-production-domain.com

# Verify SSL rating (should be A+)
curl -I https://your-production-domain.com | grep -E "(Strict-Transport|X-Frame|Content-Security)"

# Test automatic renewal
sudo certbot renew --dry-run
```

### Production Nginx Configuration

**Optimized for Medical Imaging:**
```bash
# View production Nginx configuration
sudo cat /etc/nginx/sites-available/noctis_pro

# Key production features:
# - Large file upload support (up to 2GB DICOM files)
# - Gzip compression for web assets
# - Browser caching for static files
# - Security headers for medical compliance
# - Rate limiting for API endpoints
# - WebSocket support for real-time features
```

## 🔍 COMPLETE WORKFLOW TESTING

### End-to-End Production Testing

**1. Secure Access Verification:**
```bash
# Test HTTPS access from external network
curl -I https://your-production-domain.com

# Verify security headers
curl -I https://your-production-domain.com | grep -i security

# Test redirect from HTTP
curl -L -I http://your-production-domain.com
```

**2. User Authentication Flow:**
1. Navigate to `https://your-production-domain.com`
2. Verify secure login page (HTTPS with green lock)
3. Login with admin credentials
4. Change admin password immediately
5. Test logout and re-login with new password
6. Verify session security and timeout

**3. DICOM Workflow Testing:**
1. **Upload DICOM Studies**
   - Test drag-and-drop upload
   - Verify DICOM parsing and metadata extraction
   - Test large file uploads (>100MB)
   - Verify thumbnail generation

2. **Image Viewing**
   - Open studies in DICOM viewer
   - Test window/level adjustments
   - Verify measurement tools accuracy
   - Test annotation features
   - Check 3D reconstruction (if applicable)

3. **Study Management**
   - Organize studies by patient
   - Test search and filter functions
   - Verify study routing
   - Test batch operations

**4. Advanced Features Testing:**
1. **AI Analysis**
   - Test automated analysis features
   - Verify AI model integration
   - Check analysis report generation
   - Test anomaly detection

2. **Collaboration Features**
   - Test real-time chat
   - Verify multi-user viewing
   - Test annotation sharing
   - Check notification system

3. **Reporting System**
   - Create structured reports
   - Test template system
   - Verify PDF generation
   - Test report distribution

**5. Print System Testing:**
1. **Print Configuration**
   - Access print settings
   - Configure print quality
   - Set up paper/film preferences
   - Test printer detection

2. **Print Operations**
   - Print single images
   - Test comparison layouts
   - Verify print queue management
   - Check print history

## 🏥 CUSTOMER EVALUATION GUIDE

### What Customers Should Test

**Clinical Workflow:**
1. **Patient Registration**
   - Add new patients
   - Import patient data
   - Manage patient demographics
   - Test patient search

2. **Study Management**
   - Upload DICOM studies
   - Organize by modality
   - Schedule studies
   - Track study status

3. **Image Analysis**
   - View images with optimal quality
   - Use measurement tools
   - Apply window/level presets
   - Generate analysis reports

4. **Collaboration**
   - Share studies with colleagues
   - Use real-time chat
   - Annotate images collaboratively
   - Review and approve reports

**Administrative Features:**
1. **User Management**
   - Create user accounts
   - Assign roles and permissions
   - Manage department access
   - Monitor user activity

2. **System Administration**
   - Configure system settings
   - Monitor system performance
   - Manage backups
   - Review audit logs

3. **Integration Testing**
   - Test API endpoints
   - Verify PACS connectivity
   - Check HL7 message handling
   - Test external integrations

### Performance Evaluation

**Response Time Testing:**
- Page load times should be under 2 seconds
- DICOM image loading under 5 seconds
- Search results under 1 second
- Report generation under 10 seconds

**Concurrent User Testing:**
- Multiple users can access simultaneously
- Real-time features work with multiple users
- System performance remains stable
- Database queries remain fast

**Large File Handling:**
- Upload DICOM files up to 2GB
- Process multi-frame studies
- Handle large series (1000+ images)
- Maintain performance with large datasets

## 🚨 PRODUCTION TROUBLESHOOTING

### Ubuntu 24.04 Specific Issues

**Docker Compatibility Issues:**
```bash
# Apply Ubuntu 24.04 Docker fixes
sudo apt install -y iptables-persistent fuse-overlayfs
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# Restart Docker with new configuration
sudo systemctl restart docker

# Verify Docker functionality
sudo docker ps && sudo docker system info
```

**Network Configuration Issues:**
```bash
# Check network configuration
ip addr show
sudo netstat -tlnp | grep -E "(80|443)"

# Reset network if needed
sudo systemctl restart networking
sudo systemctl restart nginx
```

**Service Startup Issues:**
```bash
# Check service dependencies
sudo systemctl list-dependencies noctis-django

# Restart services in correct order
sudo systemctl restart postgresql
sudo systemctl restart redis
sudo systemctl restart noctis-django
sudo systemctl restart noctis-daphne
sudo systemctl restart noctis-celery
sudo systemctl restart nginx
```

### Production Performance Issues

**Database Performance:**
```bash
# Check database performance
sudo -u postgres psql -d noctis_pro -c "SELECT pg_stat_reset();"
sudo -u postgres psql -d noctis_pro -c "SELECT schemaname,tablename,seq_scan,seq_tup_read,idx_scan,idx_tup_fetch FROM pg_stat_user_tables;"

# Optimize database
sudo -u postgres psql -d noctis_pro -c "REINDEX DATABASE noctis_pro;"
sudo -u postgres psql -d noctis_pro -c "VACUUM ANALYZE;"
```

**Application Performance:**
```bash
# Check application performance
sudo systemctl status noctis-django noctis-daphne noctis-celery

# Monitor resource usage
htop
iotop

# Check for memory leaks
ps aux --sort=-%mem | head -10
```

**Web Server Performance:**
```bash
# Check Nginx performance
sudo nginx -t
sudo systemctl status nginx

# Monitor web server logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Check connection limits
sudo netstat -an | grep :80 | wc -l
```

## 📈 PRODUCTION OPTIMIZATION

### Performance Tuning

**Database Optimization:**
```bash
# Tune PostgreSQL for production
sudo nano /etc/postgresql/*/main/postgresql.conf

# Recommended settings for medical imaging:
# shared_buffers = 25% of RAM
# effective_cache_size = 75% of RAM
# work_mem = 4MB
# maintenance_work_mem = 256MB
# max_connections = 200
# checkpoint_completion_target = 0.9

sudo systemctl restart postgresql
```

**Application Optimization:**
```bash
# Optimize Django settings
sudo nano /opt/noctis_pro/noctis_pro/settings_production.py

# Key production settings:
# - Database connection pooling
# - Cache configuration
# - Session optimization
# - Static file serving
# - Media file handling
```

**Web Server Optimization:**
```bash
# Optimize Nginx for medical imaging
sudo nano /etc/nginx/sites-available/noctis_pro

# Key optimizations:
# - Large file upload support
# - Gzip compression
# - Browser caching
# - Connection keep-alive
# - Worker process optimization
```

## 🎯 PRODUCTION DEPLOYMENT CHECKLIST

### ✅ Production Ready When:

**System Infrastructure:**
- [ ] Ubuntu 24.04 LTS running
- [ ] All services active and stable
- [ ] Docker containers healthy
- [ ] Database optimized for production
- [ ] Redis cache configured
- [ ] Nginx optimized for medical imaging

**Security Configuration:**
- [ ] HTTPS with valid SSL certificate
- [ ] Firewall configured and active
- [ ] Fail2ban monitoring active
- [ ] Admin password changed
- [ ] Security headers configured
- [ ] Audit logging enabled

**Medical Imaging Features:**
- [ ] DICOM viewer fully functional
- [ ] All imaging tools working
- [ ] Print system configured
- [ ] Worklist management operational
- [ ] Report generation working
- [ ] AI analysis features active

**Performance & Reliability:**
- [ ] Page load times under 2 seconds
- [ ] DICOM loading under 5 seconds
- [ ] Multiple concurrent users supported
- [ ] Large file uploads working
- [ ] Backup system operational
- [ ] Monitoring tools active

**Customer Evaluation Ready:**
- [ ] Complete workflow testable
- [ ] All features accessible
- [ ] Performance acceptable
- [ ] Security features visible
- [ ] Integration capabilities demonstrated

## 📞 PRODUCTION SUPPORT

### Customer Access Information

**Production System Access:**
- **Main Application**: `https://your-production-domain.com`
- **Admin Panel**: `https://your-production-domain.com/admin`
- **API Documentation**: `https://your-production-domain.com/api/docs/`
- **System Status**: `https://your-production-domain.com/status/`

**Support Commands:**
```bash
# System status
sudo /usr/local/bin/noctis-status.sh

# Performance check
htop && df -h

# Service logs
sudo journalctl -u noctis-django -f

# Security status
sudo ufw status && sudo fail2ban-client status
```

### Production Log Locations

- **Application Logs**: `/opt/noctis_pro/logs/`
- **System Logs**: `sudo journalctl -u noctis-django`
- **Web Server Logs**: `/var/log/nginx/`
- **Database Logs**: `sudo journalctl -u postgresql`
- **Security Logs**: `sudo journalctl -u fail2ban`
- **Print Logs**: `/var/log/cups/`

---

## 🚀 PRODUCTION DEPLOYMENT SUMMARY

**Ubuntu 24.04 Production Deployment:**
```bash
# Complete production deployment
sudo apt update && sudo apt upgrade -y && sudo reboot
git clone https://github.com/mwatom/NoctisPro.git && cd NoctisPro && chmod +x *.sh
# Configure domain in deploy_noctis_production.sh
sudo ./deploy_noctis_production.sh
sudo ./setup_secure_access.sh
python3 validate_production.py
```

**Result**: Complete production-ready NoctisPro system with:
- ✅ **Full medical imaging capabilities**
- ✅ **Enterprise security and compliance**
- ✅ **HTTPS access with valid SSL**
- ✅ **Complete workflow functionality**
- ✅ **Production performance optimization**
- ✅ **Comprehensive monitoring and maintenance**

---

**🏥 NoctisPro Production - Complete Medical Imaging Platform Ready for Customer Evaluation** ✅