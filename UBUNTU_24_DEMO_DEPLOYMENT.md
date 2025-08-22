# 🚀 Ubuntu 24.04 Demo Deployment Guide - NoctisPro

> **🎯 Purpose**: Quick deployment for customer demonstration and system evaluation

## 📋 DEMO DEPLOYMENT OVERVIEW

**Goal**: Get NoctisPro online quickly on Ubuntu 24.04 for customer preview
**Time**: 20-30 minutes
**Result**: Fully functional system with HTTPS access for customer evaluation

## ⚡ QUICK DEMO DEPLOYMENT

### Prerequisites (2 minutes)

**Server Requirements:**
- Ubuntu 24.04 LTS Server (fresh installation)
- 4GB+ RAM (8GB recommended)
- 50GB+ storage
- Internet connectivity
- Domain name (for HTTPS access)
- Root/sudo access

**Pre-deployment Check:**
```bash
# Verify Ubuntu version
lsb_release -a

# Check resources
free -h
df -h
nproc

# Test internet
ping -c 3 google.com
```

### Step 1: System Preparation (5 minutes)

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git unzip software-properties-common lsb-release

# Set hostname
sudo hostnamectl set-hostname noctis-demo

# Reboot to apply updates
sudo reboot
```

### Step 2: Download and Setup (3 minutes)

```bash
# Clone repository
git clone https://github.com/mwatom/NoctisPro.git
cd NoctisPro

# Make scripts executable
chmod +x *.sh
chmod +x scripts/*.sh
chmod +x ops/*.sh

# Verify scripts
ls -la *.sh
```

### Step 3: Configure Domain for HTTPS (2 minutes)

**⚠️ IMPORTANT: Configure your domain before deployment**

```bash
# Edit deployment script
nano deploy_noctis_production.sh

# Find line 20 and update:
DOMAIN_NAME="your-demo-domain.com"  # Replace with your actual domain

# Verify domain DNS is pointing to your server
nslookup your-demo-domain.com
```

### Step 4: Run Demo Deployment (15-20 minutes)

```bash
# Run the main deployment script
sudo ./deploy_noctis_production.sh
```

**This automatically handles:**
- ✅ **Ubuntu 24.04 compatibility** (iptables fixes, package compatibility)
- ✅ **Docker installation** (automatic detection and installation)
- ✅ **PostgreSQL database** setup
- ✅ **Redis cache** configuration
- ✅ **Nginx web server** with SSL
- ✅ **Python environment** and dependencies
- ✅ **CUPS printing system**
- ✅ **Security configuration** (firewall, fail2ban)
- ✅ **SSL certificate** via Let's Encrypt
- ✅ **Systemd services** for all components

### Step 5: Configure HTTPS Internet Access (5 minutes)

```bash
# Configure secure internet access
sudo ./setup_secure_access.sh

# Choose Option 1: Domain with HTTPS
# The script will:
# ✅ Configure Let's Encrypt SSL certificate
# ✅ Set up secure HTTPS access
# ✅ Configure firewall rules
# ✅ Provide internet access URL
```

### Step 6: Verify Complete System (3 minutes)

```bash
# Check all services
sudo /usr/local/bin/noctis-status.sh

# Expected output - ALL should be "active (running)":
# ✅ noctis-django: active (running)
# ✅ noctis-daphne: active (running)
# ✅ noctis-celery: active (running)
# ✅ postgresql: active (running)
# ✅ redis: active (running)
# ✅ nginx: active (running)
# ✅ cups: active (running)

# Get your HTTPS access link
cat /opt/noctis_pro/SECURE_ACCESS_INFO.txt
```

## 🌐 CUSTOMER ACCESS INFORMATION

### Access URLs

**HTTPS Internet Access:**
- **Main Application**: `https://your-demo-domain.com`
- **Admin Panel**: `https://your-demo-domain.com/admin`
- **API Documentation**: `https://your-demo-domain.com/api/docs/`

**Local Access (Backup):**
- **Local Application**: `http://192.168.100.15`
- **Local Admin**: `http://192.168.100.15/admin`

### Default Credentials

**Admin Access:**
- **Username**: `admin`
- **Password**: `admin123`

**⚠️ Change password immediately after first login!**

## ✅ DEMO FUNCTIONALITY VERIFICATION

### 1. Web Interface Testing

```bash
# Test HTTPS access
curl -I https://your-demo-domain.com

# Test local access
curl -I http://localhost

# Expected: HTTP 200 OK responses
```

**Manual Verification:**
1. Open `https://your-demo-domain.com`
2. Verify SSL certificate is valid (green lock)
3. Homepage loads without errors
4. Login form is accessible

### 2. Admin Login Testing

1. **Access Admin Panel**: `https://your-demo-domain.com/admin`
2. **Login with**: admin / admin123
3. **Verify**: Admin dashboard loads
4. **Change Password**: Go to Users > admin > Change password
5. **Test New Login**: Logout and login with new password

### 3. DICOM Viewer Testing

1. **Access Main Application**: `https://your-demo-domain.com`
2. **Login**: Use admin credentials
3. **Navigate to**: Worklist or DICOM Viewer
4. **Verify**: Viewer interface loads
5. **Test**: Upload a sample DICOM file (if available)

### 4. Core Features Testing

**Worklist Management:**
- [ ] Worklist page loads
- [ ] Can create new studies
- [ ] Patient information displays
- [ ] Search functionality works

**DICOM Viewer:**
- [ ] Viewer opens without errors
- [ ] Image display area loads
- [ ] Toolbar and controls visible
- [ ] Window/level controls functional

**User Management:**
- [ ] Admin can access user management
- [ ] Can create new users
- [ ] Role assignment works
- [ ] Permissions are enforced

**System Features:**
- [ ] Reports section accessible
- [ ] Chat functionality available
- [ ] AI analysis features visible
- [ ] Print options available

## 🔧 UBUNTU 24.04 SPECIFIC CONFIGURATION

### Automatic Ubuntu 24.04 Handling

**The deployment script automatically:**
- ✅ **Detects Ubuntu 24.04** and applies compatibility fixes
- ✅ **Installs iptables-persistent** for Docker compatibility
- ✅ **Switches to iptables-legacy** for network compatibility
- ✅ **Installs fuse-overlayfs** for container support
- ✅ **Configures Docker daemon** with Ubuntu 24.04 optimizations

### Manual Ubuntu 24.04 Fixes (if needed)

**If Docker has issues on Ubuntu 24.04:**
```bash
# Apply Ubuntu 24.04 Docker fixes
sudo ./fix_docker_ubuntu24.sh

# Or manual fixes:
sudo apt install -y iptables-persistent fuse-overlayfs
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
sudo systemctl restart docker
```

## 🌐 HTTPS CONFIGURATION VERIFICATION

### SSL Certificate Setup

**Automatic HTTPS Setup:**
```bash
# The setup_secure_access.sh script automatically:
# ✅ Installs certbot
# ✅ Obtains Let's Encrypt certificate
# ✅ Configures Nginx for HTTPS
# ✅ Sets up automatic renewal
# ✅ Configures security headers
```

**Manual SSL Verification:**
```bash
# Check certificate status
sudo certbot certificates

# Test certificate
openssl s_client -connect your-demo-domain.com:443 -servername your-demo-domain.com

# Verify HTTPS redirect
curl -I http://your-demo-domain.com
# Should return 301 redirect to HTTPS
```

### Nginx HTTPS Configuration

**Check Nginx HTTPS Setup:**
```bash
# Test Nginx configuration
sudo nginx -t

# Check HTTPS configuration
sudo cat /etc/nginx/sites-available/noctis_pro | grep -A 10 "listen 443"

# Restart Nginx if needed
sudo systemctl restart nginx
```

## 🔍 COMPLETE WORKFLOW TESTING

### End-to-End Customer Demo Flow

**1. Customer Access Test:**
```bash
# Test from external network
curl -I https://your-demo-domain.com
# Should return HTTP 200 OK with security headers
```

**2. Login Workflow:**
1. Navigate to `https://your-demo-domain.com`
2. Click "Login" or access `/admin`
3. Enter: admin / admin123
4. Verify successful login
5. Change password immediately
6. Test login with new password

**3. DICOM Functionality:**
1. Access main dashboard
2. Navigate to "Worklist" section
3. Verify patient list interface
4. Click "DICOM Viewer"
5. Test viewer controls and interface
6. Verify image upload functionality

**4. Admin Features:**
1. Access admin panel: `/admin`
2. Test user management
3. Verify system settings
4. Check audit logs
5. Test report generation

**5. Print Functionality:**
1. Open DICOM viewer
2. Load any image
3. Click "Print" button
4. Verify print dialog opens
5. Check printer detection (even without physical printer)

## 🚨 TROUBLESHOOTING FOR DEMO

### Common Ubuntu 24.04 Issues

**Issue: Docker won't start**
```bash
# Apply Ubuntu 24.04 fixes
sudo apt install -y iptables-persistent fuse-overlayfs
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo systemctl restart docker
sudo docker ps
```

**Issue: SSL certificate fails**
```bash
# Check domain DNS
nslookup your-demo-domain.com

# Manual certificate request
sudo certbot certonly --standalone -d your-demo-domain.com

# Restart Nginx
sudo systemctl restart nginx
```

**Issue: Services won't start**
```bash
# Check system logs
sudo journalctl -u noctis-django --since "1 hour ago"

# Restart services in order
sudo systemctl restart postgresql
sudo systemctl restart redis
sudo systemctl restart noctis-django
sudo systemctl restart nginx
```

**Issue: Cannot access via HTTPS**
```bash
# Check firewall
sudo ufw status

# Ensure ports are open
sudo ufw allow 80
sudo ufw allow 443
sudo ufw reload

# Test local access first
curl -I http://localhost
```

## 📊 DEMO READINESS CHECKLIST

### ✅ System Ready for Customer Demo When:

**Basic Functionality:**
- [ ] HTTPS access works: `https://your-demo-domain.com`
- [ ] SSL certificate valid (green lock in browser)
- [ ] Homepage loads without errors
- [ ] Login system functional
- [ ] Admin panel accessible

**Core Features Working:**
- [ ] User authentication system
- [ ] DICOM viewer interface loads
- [ ] Worklist management accessible
- [ ] Patient data interface functional
- [ ] Image viewer controls responsive

**Admin Features:**
- [ ] Admin login works
- [ ] User management functional
- [ ] System settings accessible
- [ ] Audit logs available
- [ ] Report generation works

**Performance:**
- [ ] Page load times under 3 seconds
- [ ] No JavaScript errors in browser console
- [ ] Images load smoothly
- [ ] Navigation is responsive

**Security:**
- [ ] HTTPS enforced (HTTP redirects to HTTPS)
- [ ] Admin password changed from default
- [ ] Firewall active and configured
- [ ] SSL certificate valid and trusted

## 🎯 CUSTOMER DEMONSTRATION FLOW

### Recommended Demo Sequence:

**1. System Overview (2 minutes)**
- Show HTTPS access: `https://your-demo-domain.com`
- Demonstrate security (SSL certificate)
- Overview of main dashboard

**2. User Authentication (1 minute)**
- Show login process
- Demonstrate role-based access
- Show user management in admin

**3. DICOM Functionality (5 minutes)**
- Navigate to DICOM viewer
- Show interface and controls
- Demonstrate image manipulation
- Show measurement tools

**4. Worklist Management (3 minutes)**
- Show patient worklist
- Demonstrate study management
- Show search and filter capabilities
- Display patient information

**5. Advanced Features (3 minutes)**
- Show reporting capabilities
- Demonstrate print functionality
- Show AI analysis features (if available)
- Display collaboration tools

**6. Admin Features (2 minutes)**
- Show admin panel
- Demonstrate user management
- Show system monitoring
- Display audit logs

## 🔧 QUICK FIXES FOR DEMO ISSUES

### If Something Breaks During Demo:

**Web Interface Issues:**
```bash
# Restart web services
sudo systemctl restart nginx noctis-django

# Check for errors
sudo journalctl -u nginx -u noctis-django --since "5 minutes ago"
```

**Database Issues:**
```bash
# Restart database
sudo systemctl restart postgresql

# Test database connection
sudo -u postgres psql -d noctis_pro -c "SELECT 1;"
```

**DICOM Viewer Issues:**
```bash
# Restart application
sudo systemctl restart noctis-django noctis-daphne

# Clear cache
sudo systemctl restart redis
```

**HTTPS Issues:**
```bash
# Check SSL certificate
sudo certbot certificates

# Restart Nginx
sudo systemctl restart nginx

# Test HTTPS
curl -I https://your-demo-domain.com
```

## 📱 CUSTOMER ACCESS INSTRUCTIONS

### For Customer Testing:

**Access Information:**
- **Demo URL**: `https://your-demo-domain.com`
- **Admin Access**: `https://your-demo-domain.com/admin`
- **Demo Login**: admin / [new-password-you-set]

**What Customers Can Test:**
1. **Security**: HTTPS access with valid SSL
2. **Interface**: Modern, responsive web interface
3. **DICOM Viewing**: Medical image viewer functionality
4. **Worklist**: Patient and study management
5. **Reports**: Report generation and export
6. **Printing**: Print dialog and options
7. **Admin**: User management and system administration

**Customer Evaluation Points:**
- Ease of use and navigation
- Performance and responsiveness
- Feature completeness
- Security and reliability
- Print quality options
- Mobile responsiveness

## 🛡️ SECURITY FOR DEMO

### Production-Ready Security Features:

**Automatic Security Setup:**
- ✅ **HTTPS/SSL**: Let's Encrypt certificate
- ✅ **Firewall**: UFW configured with secure rules
- ✅ **Fail2ban**: Protection against brute force
- ✅ **Security Headers**: HSTS, CSP, X-Frame-Options
- ✅ **Database Security**: Secure PostgreSQL configuration
- ✅ **Session Security**: Secure session management

**Security Verification:**
```bash
# Check firewall
sudo ufw status verbose

# Check fail2ban
sudo fail2ban-client status

# Check SSL security
curl -I https://your-demo-domain.com | grep -i security

# Test security headers
curl -I https://your-demo-domain.com | grep -E "(Strict-Transport|X-Frame|Content-Security)"
```

## 📊 MONITORING FOR DEMO

### Real-time Monitoring During Demo:

```bash
# System status
sudo /usr/local/bin/noctis-status.sh

# Resource usage
htop

# Service logs (in separate terminal)
sudo journalctl -u noctis-django -f

# Network connections
sudo netstat -tlnp | grep -E "(80|443)"
```

### Performance Monitoring:

```bash
# Check response times
curl -w "@curl-format.txt" -o /dev/null -s https://your-demo-domain.com

# Monitor database performance
sudo -u postgres psql -d noctis_pro -c "SELECT count(*) FROM pg_stat_activity;"

# Check memory usage
free -h && ps aux --sort=-%mem | head -10
```

## 🎭 DEMO PREPARATION CHECKLIST

### Before Customer Demo:

**System Verification:**
- [ ] All services running: `sudo /usr/local/bin/noctis-status.sh`
- [ ] HTTPS access working: `https://your-demo-domain.com`
- [ ] SSL certificate valid: Check browser lock icon
- [ ] Login system functional: Test admin login
- [ ] DICOM viewer loads: Test viewer interface
- [ ] No error messages: Check browser console

**Performance Check:**
- [ ] Page loads under 3 seconds
- [ ] Navigation is smooth
- [ ] Images display quickly
- [ ] No JavaScript errors
- [ ] Mobile interface responsive

**Content Preparation:**
- [ ] Sample DICOM files uploaded (if available)
- [ ] Demo user accounts created
- [ ] Sample studies in worklist
- [ ] Demo scenarios prepared

### Demo Environment Setup:

```bash
# Create demo user account
cd /opt/noctis_pro
sudo -u noctis ./venv/bin/python manage.py shell --settings=noctis_pro.settings_production

# In Django shell:
from django.contrib.auth.models import User
demo_user = User.objects.create_user('demo', 'demo@example.com', 'demo123')
demo_user.is_staff = True
demo_user.save()
exit()
```

## 🚀 GOING LIVE COMMANDS

### Final Pre-Demo Commands:

```bash
# 1. Final system check
sudo /usr/local/bin/noctis-status.sh

# 2. Clear any temporary files
sudo systemctl restart redis

# 3. Restart all services for clean state
sudo systemctl restart noctis-django noctis-daphne noctis-celery

# 4. Test HTTPS access
curl -I https://your-demo-domain.com

# 5. Verify SSL certificate
openssl s_client -connect your-demo-domain.com:443 -servername your-demo-domain.com </dev/null 2>/dev/null | grep -E "(Verify|subject|issuer)"

# 6. Test login
curl -c cookies.txt -b cookies.txt -d "username=admin&password=admin123" -X POST https://your-demo-domain.com/admin/login/
```

## 📋 CUSTOMER DEMO SCRIPT

### Suggested Demo Flow (15 minutes):

**1. Introduction (2 min)**
- "Welcome to NoctisPro - Enterprise Medical Imaging Platform"
- Show HTTPS secure access
- Highlight professional interface

**2. Security & Access (2 min)**
- Demonstrate HTTPS security
- Show admin authentication
- Explain role-based access control

**3. DICOM Viewer (5 min)**
- Navigate to DICOM viewer
- Show image display capabilities
- Demonstrate measurement tools
- Show window/level adjustments

**4. Worklist Management (3 min)**
- Show patient worklist
- Demonstrate study organization
- Show search and filter features
- Display patient information management

**5. Advanced Features (2 min)**
- Show reporting capabilities
- Demonstrate print functionality
- Highlight AI analysis features
- Show collaboration tools

**6. Administration (1 min)**
- Show admin panel
- Demonstrate user management
- Show system monitoring
- Highlight audit capabilities

## 🆘 DEMO EMERGENCY PROCEDURES

### If Issues Occur During Demo:

**Quick Fixes:**
```bash
# Restart application (30 seconds)
sudo systemctl restart noctis-django

# Clear cache (15 seconds)
sudo systemctl restart redis

# Restart web server (15 seconds)
sudo systemctl restart nginx

# Check status (10 seconds)
sudo /usr/local/bin/noctis-status.sh
```

**Backup Access:**
- Use local access: `http://192.168.100.15`
- Switch to different browser
- Use incognito/private mode
- Access admin panel directly: `/admin`

## 📞 POST-DEMO INFORMATION

### Customer Evaluation Checklist:

**Technical Evaluation:**
- [ ] Performance meets expectations
- [ ] Security features adequate
- [ ] Interface user-friendly
- [ ] Features complete for needs
- [ ] Integration possibilities assessed

**Business Evaluation:**
- [ ] Workflow compatibility
- [ ] User training requirements
- [ ] Deployment complexity
- [ ] Maintenance requirements
- [ ] Scalability potential

### Next Steps After Demo:

1. **Gather Customer Feedback**
2. **Document Required Modifications**
3. **Plan Production Deployment**
4. **Schedule Training Sessions**
5. **Prepare Final Implementation**

## 🎯 DEMO SUCCESS CRITERIA

### ✅ Successful Demo When:

**Technical Success:**
- HTTPS access works flawlessly
- All core features demonstrated
- No error messages during demo
- Performance is acceptable
- Security features visible

**Customer Success:**
- Customer can navigate independently
- Features meet stated requirements
- Interface is intuitive
- Performance meets expectations
- Security concerns addressed

---

## 🚀 QUICK DEPLOYMENT SUMMARY

**Ubuntu 24.04 Demo Deployment:**
```bash
# 1. Update system
sudo apt update && sudo apt upgrade -y && sudo reboot

# 2. Download
git clone https://github.com/mwatom/NoctisPro.git && cd NoctisPro && chmod +x *.sh

# 3. Configure domain in deploy_noctis_production.sh

# 4. Deploy
sudo ./deploy_noctis_production.sh

# 5. Configure HTTPS
sudo ./setup_secure_access.sh

# 6. Verify
sudo /usr/local/bin/noctis-status.sh && cat /opt/noctis_pro/SECURE_ACCESS_INFO.txt
```

**Result**: Fully functional NoctisPro with HTTPS access ready for customer demonstration

---

**🏥 NoctisPro Demo - Ready for Customer Evaluation** ✅