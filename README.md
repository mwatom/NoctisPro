# NoctisPro - Enterprise Medical Imaging Platform

[![Deploy Status](https://img.shields.io/badge/deploy-ready-green.svg)](https://github.com/mwatom/NoctisPro)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.11+-blue.svg)](https://python.org)
[![Django](https://img.shields.io/badge/django-5.2.5-green.svg)](https://djangoproject.com)

NoctisPro is a comprehensive, production-ready medical imaging platform designed for healthcare professionals to manage, view, and analyze DICOM medical images with advanced AI-powered features and enterprise-grade security.

## 🚀 Features

### Core Functionality
- **DICOM Viewer**: High-performance medical image viewer with advanced visualization tools
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
- **Deployment**: Gunicorn, Daphne, Nginx, Systemd
- **Security**: SSL/TLS, UFW Firewall, Fail2ban

## 📋 System Requirements

### Minimum Requirements
- **OS**: Ubuntu 20.04+ or Ubuntu 22.04+ LTS
- **CPU**: 4 cores (8 cores recommended)
- **RAM**: 8GB (16GB recommended)
- **Storage**: 100GB SSD (500GB+ recommended)
- **Network**: Stable internet connection for updates

### Production Requirements
- **OS**: Ubuntu 22.04 LTS Server
- **CPU**: 8+ cores
- **RAM**: 16GB+ 
- **Storage**: 1TB+ NVMe SSD
- **Network**: Dedicated IP, Domain name (optional)
- **SSL**: Valid SSL certificate for HTTPS

## 🚀 Quick Setup Options

### 🖥️ Desktop Development Setup (Easiest)

Perfect for testing, development, or small clinic use on Ubuntu Desktop:

```bash
# Clone the repository
git clone https://github.com/mwatom/NoctisPro.git
cd NoctisPro

# Option 1: Complete automated setup (installs Docker + NoctisPro)
chmod +x scripts/complete-desktop-setup.sh
./scripts/complete-desktop-setup.sh

# Option 2: If you already have Docker installed
chmod +x scripts/quick-start-desktop.sh
./scripts/quick-start-desktop.sh
```

**What this does:**
- ✅ Automatically installs Docker if not present
- ✅ Sets up PostgreSQL database
- ✅ Sets up Redis cache
- ✅ Creates admin user (admin/admin123)
- ✅ Starts web interface on http://localhost:8000

### 🏥 Production Server Deployment

## 🚀 Complete Deployment Guide

### Step 1: Server Preparation

1. **Set up your Ubuntu server** (22.04 LTS recommended)
2. **Update system packages**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```
3. **Set server hostname**:
   ```bash
   sudo hostnamectl set-hostname noctis-server
   ```

### Step 2: Clone Repository

```bash
# Clone the repository
git clone https://github.com/mwatom/NoctisPro.git
cd NoctisPro

# Make deployment scripts executable
chmod +x deploy_noctis_production.sh
chmod +x setup_secure_access.sh
chmod +x setup_ssl.sh
```

### Step 3: Configure Domain (Optional but Recommended)

If you have a domain name, update the deployment script:

```bash
# Edit the deployment script
nano deploy_noctis_production.sh

# Update this line with your domain:
DOMAIN_NAME="your-domain.com"  # Change from noctis-server.local
```

### Step 4: Run Production Deployment

Execute the main deployment script:

```bash
sudo ./deploy_noctis_production.sh
```

This comprehensive script will:
- ✅ Install all required system packages (PostgreSQL, Redis, Nginx, etc.)
- ✅ Create dedicated system user and secure directory structure
- ✅ Set up PostgreSQL with production-optimized configuration
- ✅ Configure Redis with authentication and security
- ✅ Create Python virtual environment and install dependencies
- ✅ Generate secure passwords and Django secret key
- ✅ Configure Django with production settings
- ✅ Set up Gunicorn with optimal worker configuration
- ✅ Configure Daphne for WebSocket support
- ✅ Set up Celery for background tasks
- ✅ Configure Nginx with security headers and optimizations
- ✅ Set up UFW firewall with secure rules
- ✅ Configure Fail2ban for intrusion prevention
- ✅ Create systemd services for all components
- ✅ Set up GitHub webhook for automatic deployments
- ✅ Configure automatic backups with 30-day retention
- ✅ Create monitoring and status check scripts

### Step 5: Configure Secure Access

Choose your preferred access method:

```bash
sudo ./setup_secure_access.sh
```

**Access Options:**

1. **Domain with SSL Certificate** (Recommended)
   - Requires a registered domain name
   - Automatic SSL certificate via Let's Encrypt
   - HTTPS access: `https://your-domain.com`
   - No IP exposure

2. **Cloudflare Tunnel** (Zero Trust)
   - No open ports on your server
   - Access via Cloudflare's network
   - Enhanced DDoS protection
   - Global CDN acceleration

3. **VPN Access Only**
   - WireGuard VPN setup
   - Private network access only
   - Maximum security for internal use

4. **Reverse Proxy**
   - For use with existing proxy infrastructure
   - Custom domain support
   - Load balancing capability

5. **Local Network Only**
   - Restricted to private IP ranges
   - No internet exposure
   - Perfect for internal deployments

### Step 6: GitHub Integration Setup

1. **Go to your GitHub repository settings**
2. **Navigate to Webhooks**
3. **Add webhook with these settings**:
   - **URL**: `https://your-domain.com/webhook` (or `http://192.168.100.15/webhook`)
   - **Content Type**: `application/json`
   - **Events**: Push events
   - **Active**: ✅ Checked

Now any push to the main branch will automatically deploy to your server!

## 🔧 Post-Deployment Configuration

### Access Your Installation

- **Main Application**: `https://your-domain.com` or `http://192.168.100.15`
- **Admin Panel**: `https://your-domain.com/admin`
- **Default Admin Credentials**: 
  - Username: `admin`
  - Password: `admin123` (⚠️ Change immediately!)

### Change Default Password

```bash
cd /opt/noctis_pro
sudo -u noctis ./venv/bin/python manage.py changepassword admin --settings=noctis_pro.settings_production
```

### Configure Email (Optional)

Edit the environment file:
```bash
sudo nano /opt/noctis_pro/.env

# Add your email configuration
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
DEFAULT_FROM_EMAIL=noctis@your-domain.com
```

## 📊 System Management

### Check System Status
```bash
sudo /usr/local/bin/noctis-status.sh
```

### View Service Logs
```bash
# All services
sudo journalctl -u noctis-django -u noctis-daphne -u noctis-celery -f

# Specific service
sudo journalctl -u noctis-django -f
```

### Restart Services
```bash
sudo systemctl restart noctis-django noctis-daphne noctis-celery
```

### Create Manual Backup
```bash
sudo /usr/local/bin/noctis-backup.sh
```

### Update Application
```bash
cd /opt/noctis_pro
sudo -u noctis git pull origin main
sudo systemctl restart noctis-django noctis-daphne noctis-celery
```

## 🔐 Security Features

### Built-in Security
- **SSL/TLS Encryption**: Automatic HTTPS with Let's Encrypt
- **Firewall Protection**: UFW with minimal open ports
- **Intrusion Prevention**: Fail2ban with custom rules
- **Database Security**: Dedicated users with strong passwords
- **Session Security**: Secure cookies and CSRF protection
- **Security Headers**: Comprehensive HTTP security headers

### Security Best Practices
- Change default admin password immediately
- Regular security updates via automatic deployment
- Monitor access logs regularly
- Use strong passwords for all accounts
- Enable two-factor authentication (configure manually)
- Regular backup verification

## 📈 Performance & Scaling

### Built-in Optimizations
- **Database**: PostgreSQL with production tuning
- **Caching**: Redis for sessions and application cache
- **Static Files**: Nginx with compression and long-term caching
- **Process Management**: Gunicorn with optimal worker count
- **Background Tasks**: Celery for async processing
- **WebSockets**: Daphne for real-time features

### Scaling Options
- **Horizontal Scaling**: Multiple app servers behind load balancer
- **Database Scaling**: Read replicas and connection pooling
- **Storage Scaling**: Network-attached storage or cloud storage
- **CDN Integration**: Static file delivery via CDN
- **Monitoring**: Integration with monitoring services

## 🔄 Automatic Updates & CI/CD

The system includes built-in continuous deployment:

1. **Push code** to the main branch
2. **GitHub webhook** triggers deployment
3. **Server automatically**:
   - Pulls latest code
   - Installs new dependencies
   - Runs database migrations
   - Collects static files
   - Restarts services with zero downtime

### Manual Deployment Control
```bash
# Disable auto-deployment
sudo systemctl stop noctis-webhook

# Enable auto-deployment
sudo systemctl start noctis-webhook
```

## 🛡️ Backup & Recovery

### Automatic Backups
- **Daily database dumps** at 2:00 AM
- **Media file backups** with compression
- **30-day retention** policy
- **Storage location**: `/opt/backups/noctis_pro/`

### Manual Recovery
```bash
# Restore database from backup
sudo -u postgres psql -d noctis_pro < /opt/backups/noctis_pro/database_YYYYMMDD_HHMMSS.sql

# Restore media files
sudo tar -xzf /opt/backups/noctis_pro/media_YYYYMMDD_HHMMSS.tar.gz -C /opt/noctis_pro/
```

## 🆘 Troubleshooting

### Common Issues

**Services not starting:**
```bash
sudo systemctl status noctis-django noctis-daphne noctis-celery
sudo journalctl -u noctis-django --since "1 hour ago"
```

**Database connection issues:**
```bash
sudo -u postgres psql -d noctis_pro -c "SELECT version();"
```

**Redis connection issues:**
```bash
redis-cli -a $(grep REDIS_PASSWORD /opt/noctis_pro/.env | cut -d= -f2) ping
```

**Nginx configuration issues:**
```bash
sudo nginx -t
sudo systemctl status nginx
```

**SSL certificate issues:**
```bash
sudo certbot certificates
sudo certbot renew --dry-run
```

### Support Resources
- **System logs**: `/opt/noctis_pro/logs/`
- **Status script**: `/usr/local/bin/noctis-status.sh`
- **Configuration**: `/opt/noctis_pro/.env`
- **Backup location**: `/opt/backups/noctis_pro/`

## 🏥 Use Cases

### Healthcare Facilities
- **Hospitals**: Primary diagnostic workstation for radiology departments
- **Clinics**: Specialized imaging for orthopedics, cardiology, oncology
- **Teleradiology**: Remote diagnostic services
- **Teaching Hospitals**: Medical education and training

### Research Institutions
- **Clinical Trials**: Medical image analysis and data collection
- **AI Research**: Machine learning model development and testing
- **Academic Research**: Image processing and analysis studies
- **Collaborative Research**: Multi-site research coordination

## 📞 Support & Maintenance

### Professional Support
- **Documentation**: Comprehensive deployment and user guides
- **Community Support**: GitHub issues and discussions
- **Enterprise Support**: Available for production deployments
- **Training**: User and administrator training available

### Maintenance Schedule
- **Security Updates**: Automatic via CI/CD pipeline
- **System Updates**: Monthly maintenance windows
- **Backup Verification**: Weekly automated tests
- **Performance Monitoring**: 24/7 system monitoring

## 🚀 Roadmap

### Version 2.0 (Q2 2024)
- [ ] Multi-tenant architecture
- [ ] Cloud storage integration (AWS S3, Azure Blob)
- [ ] Mobile applications (iOS/Android)
- [ ] Advanced AI models for specialized imaging
- [ ] Integration with major EHR systems

### Version 1.5 (Current)
- [x] Production-ready deployment automation
- [x] Enterprise security features
- [x] Comprehensive monitoring and logging
- [x] Automatic backup and recovery
- [x] GitHub integration and CI/CD

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🎯 Quick Start Summary

1. **Clone**: `git clone https://github.com/mwatom/NoctisPro.git`
2. **Deploy**: `sudo ./deploy_noctis_production.sh`
3. **Secure**: `sudo ./setup_secure_access.sh`
4. **Access**: `https://your-domain.com` or `http://192.168.100.15`
5. **GitHub**: Set up webhook for automatic updates

**NoctisPro** - Enterprise-Ready Medical Imaging Platform for the Modern Healthcare Environment