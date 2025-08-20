# NoctisPro - Production-Ready Medical Imaging Platform

NoctisPro is a comprehensive medical imaging platform designed for healthcare professionals to manage, view, and analyze DICOM medical images with advanced AI-powered features.

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

## 🛠️ Technology Stack

- **Backend**: Django 5.2.5, Python 3.11+
- **Frontend**: HTML5, CSS3, JavaScript, Bootstrap
- **Database**: PostgreSQL (Production)
- **Cache**: Redis
- **WebSockets**: Django Channels with Redis
- **Image Processing**: OpenCV, SimpleITK, PyDICOM
- **AI/ML**: PyTorch, scikit-learn, transformers
- **Deployment**: Gunicorn, Nginx, Systemd

## 📋 System Requirements

- Ubuntu 20.04+ or Ubuntu 22.04+
- Python 3.11 or higher
- PostgreSQL 13+
- Redis 6.0+
- Nginx 1.18+
- 4GB RAM minimum (8GB recommended)
- 50GB storage minimum
- SSL certificate (for HTTPS)

## 🚀 Production Deployment

### One-Click Deployment for Ubuntu Server

For a complete production deployment on Ubuntu server with automatic GitHub integration:

1. **Clone the repository on your server**
   ```bash
   git clone https://github.com/yourusername/noctis_pro.git
   cd noctis_pro
   ```

2. **Update the deployment script**
   Edit `deploy_noctis_production.sh` and update:
   - `GITHUB_REPO` with your actual repository URL
   - `DOMAIN_NAME` with your actual domain (or keep noctis-server.local)

3. **Run the deployment script**
   ```bash
   sudo ./deploy_noctis_production.sh
   ```

This script will:
- Install all required system packages
- Setup PostgreSQL with optimized configuration
- Configure Redis with authentication
- Create a dedicated user and project structure
- Install Python dependencies in a virtual environment
- Setup Django with production settings
- Configure Gunicorn, Daphne, and Celery services
- Setup Nginx with security headers
- Configure firewall and fail2ban
- Setup GitHub webhook for automatic deployments
- Create backup and monitoring scripts

### Manual SSL Setup (Optional)

After deployment, setup SSL certificate:

```bash
sudo ./setup_ssl.sh
```

### Server Information

- **Server Name**: noctis-server
- **IP Address**: 192.168.100.15
- **HTTP Access**: http://192.168.100.15
- **Admin Panel**: http://192.168.100.15/admin
- **Default Admin**: username: `admin`, password: `admin123`

### GitHub Integration

The deployment includes automatic GitHub webhook integration:

1. **Webhook URL**: `http://192.168.100.15/webhook`
2. **Content Type**: `application/json`
3. **Events**: Push events on main branch

Any push to the main branch will automatically:
- Pull latest code
- Install/update dependencies
- Run migrations
- Collect static files
- Restart services

## 🔧 Configuration Files

### Production Settings
- **Django Settings**: `noctis_pro/settings_production.py`
- **Environment File**: `/opt/noctis_pro/.env`
- **Gunicorn Config**: `/opt/noctis_pro/gunicorn.conf.py`
- **Nginx Config**: `/etc/nginx/sites-available/noctis-pro`

### Systemd Services
- **Django App**: `noctis-django.service`
- **WebSocket Server**: `noctis-daphne.service`
- **Background Tasks**: `noctis-celery.service`
- **GitHub Webhook**: `noctis-webhook.service`

## 📊 Management Commands

### System Status
```bash
sudo /usr/local/bin/noctis-status.sh
```

### Create Backup
```bash
sudo /usr/local/bin/noctis-backup.sh
```

### View Logs
```bash
# Django application logs
sudo journalctl -u noctis-django -f

# All services
sudo journalctl -u noctis-django -u noctis-daphne -u noctis-celery -f
```

### Restart Services
```bash
sudo systemctl restart noctis-django noctis-daphne noctis-celery
```

## 🔐 Security Features

- **Firewall**: UFW configured with minimal open ports
- **Fail2ban**: Protection against brute force attacks
- **SSL/TLS**: HTTPS with automatic certificate renewal
- **Security Headers**: Comprehensive security headers via Nginx
- **Database Security**: PostgreSQL with dedicated user and strong passwords
- **Redis Authentication**: Password-protected Redis instance

## 📈 Performance Optimizations

- **Database**: PostgreSQL with production-optimized settings
- **Caching**: Redis-based caching and session storage
- **Static Files**: Nginx serving with compression and caching
- **Process Management**: Gunicorn with optimal worker configuration
- **WebSockets**: Daphne for real-time features
- **Background Tasks**: Celery for async processing

## 🔄 Automatic Updates

The system is configured for automatic updates from GitHub:
1. Push changes to the main branch
2. GitHub webhook triggers deployment
3. Server automatically updates and restarts services
4. Zero-downtime deployment process

## 🛡️ Backup Strategy

- **Database**: Daily PostgreSQL dumps at 2:00 AM
- **Media Files**: Daily compressed backups
- **Retention**: 30 days automatic cleanup
- **Location**: `/opt/backups/noctis_pro/`

## 🆘 Troubleshooting

### Check Service Status
```bash
systemctl status noctis-django noctis-daphne noctis-celery
```

### View Error Logs
```bash
tail -f /opt/noctis_pro/logs/gunicorn_error.log
```

### Database Connection Issues
```bash
sudo -u postgres psql -d noctis_pro -c "SELECT version();"
```

### Redis Connection Issues
```bash
redis-cli ping
```

## 📞 Support

For production deployment support:
- Check service logs: `/opt/noctis_pro/logs/`
- System status: `/usr/local/bin/noctis-status.sh`
- Database backups: `/opt/backups/noctis_pro/`

---

**NoctisPro** - Enterprise-Ready Medical Imaging Platform