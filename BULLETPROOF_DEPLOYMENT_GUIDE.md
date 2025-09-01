# 🏥 NoctisPro Bulletproof Production Deployment Guide

Complete guide for deploying NoctisPro as a production service with full DICOM viewer and auto-startup capabilities.

## 🚀 Quick Deployment (One Command)

For immediate deployment with all features:

```bash
sudo ./deploy_bulletproof_production.sh
```

This script will:
- ✅ Install all system dependencies
- ✅ Configure PostgreSQL and Redis
- ✅ Set up Python virtual environment
- ✅ Install all required packages
- ✅ Configure production settings with full DICOM viewer
- ✅ Create systemd services for auto-startup
- ✅ Set up Nginx reverse proxy
- ✅ Enable all services to start on boot

## 📋 What Gets Deployed

### 🔧 System Services
- **PostgreSQL**: Production database
- **Redis**: Caching and message broker
- **Nginx**: Reverse proxy and static file server
- **NoctisPro Django**: Main web application
- **NoctisPro Celery**: Background task processor
- **NoctisPro DICOM**: DICOM receiver service

### 🏥 DICOM Viewer Features
- **Full Production Template**: Complete base.html with all features
- **3D Reconstruction**: MPR, MIP, Volume Rendering
- **AI Analysis**: Integrated analysis tools
- **Multi-modality Support**: CT, MRI, PET, SPECT, Nuclear Medicine
- **Professional Tools**: Measurements, annotations, quality assurance
- **Advanced Algorithms**: Real medical imaging processing

### 🔄 Auto-Startup Configuration
All services are configured to automatically start on server boot:
- System services (PostgreSQL, Redis, Nginx)
- Application services (Django, Celery, DICOM receiver)
- Proper dependency management and health checks

## 📁 Directory Structure After Deployment

```
/workspace/
├── venv/                          # Python virtual environment
├── media/
│   └── dicom/                     # DICOM file storage
├── staticfiles/                   # Web assets
├── logs/                          # Application logs
├── backups/                       # System backups
├── manage.py                      # Django management
├── .env.production               # Production configuration
├── start_complete_production_system.sh
├── stop_complete_production_system.sh
└── check_noctispro_production.sh

/etc/systemd/system/
├── noctispro-django.service       # Main application service
├── noctispro-celery.service       # Background tasks service
└── noctispro-dicom.service        # DICOM receiver service

/etc/nginx/sites-available/
└── noctispro                      # Nginx configuration
```

## 🎯 Management Commands

### Starting the System
```bash
# Start all services
./start_complete_production_system.sh

# Or use systemd
sudo systemctl start noctispro-django noctispro-celery noctispro-dicom
```

### Stopping the System
```bash
# Stop all services
./stop_complete_production_system.sh

# Or use systemd
sudo systemctl stop noctispro-django noctispro-celery noctispro-dicom
```

### Checking Status
```bash
# Check system status
./check_noctispro_production.sh

# Check individual services
sudo systemctl status noctispro-django
sudo systemctl status noctispro-celery
sudo systemctl status noctispro-dicom
```

### Viewing Logs
```bash
# Application logs
tail -f logs/django.log
tail -f logs/celery.log

# System logs
sudo journalctl -u noctispro-django -f
sudo journalctl -u noctispro-celery -f
sudo journalctl -u noctispro-dicom -f
```

## 🌐 Access URLs

After deployment, access the system at:

- **Main Interface**: http://localhost or http://server-ip
- **DICOM Viewer**: http://localhost/dicom_viewer/
- **Admin Panel**: http://localhost/admin/
- **API Documentation**: http://localhost/api/docs/

## 🔧 Post-Deployment Setup

### 1. Create Admin User
```bash
cd /workspace
source venv/bin/activate
python manage.py createsuperuser --settings=noctis_pro.settings_production
```

### 2. Configure Domain (Optional)
Edit `/workspace/.env.production` and add your domain:
```bash
ALLOWED_HOSTS=*,localhost,127.0.0.1,your-domain.com
```

### 3. SSL Setup (Recommended for Production)
```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d your-domain.com
```

## 🔄 Auto-Startup Verification

To verify auto-startup is working:

1. **Reboot the server**:
   ```bash
   sudo reboot
   ```

2. **After reboot, check services**:
   ```bash
   ./check_noctispro_production.sh
   ```

All services should be running automatically.

## 🧪 Testing the Deployment

### 1. Basic Functionality Test
```bash
# Test main application
curl http://localhost/health/

# Test DICOM viewer
curl http://localhost/dicom_viewer/

# Test admin interface
curl http://localhost/admin/
```

### 2. DICOM Viewer Feature Test
1. Access http://localhost/dicom_viewer/
2. Upload a DICOM file
3. Verify all buttons are present:
   - Window/Level controls
   - 3D reconstruction tools
   - Measurement tools
   - AI analysis button
   - Export functions

### 3. Service Auto-Start Test
```bash
# Stop all services
sudo systemctl stop noctispro-django noctispro-celery noctispro-dicom

# Reboot server
sudo reboot

# After reboot, check if services started automatically
./check_noctispro_production.sh
```

## 🔒 Security Features

The deployment includes:
- ✅ Secure environment variables
- ✅ Database authentication
- ✅ Redis security
- ✅ Nginx security headers
- ✅ Systemd security hardening
- ✅ File permission restrictions
- ✅ Process isolation

## 🚨 Troubleshooting

### Service Won't Start
```bash
# Check service status
sudo systemctl status noctispro-django

# View detailed logs
sudo journalctl -u noctispro-django -n 50

# Check configuration
cd /workspace && source venv/bin/activate && python manage.py check
```

### Database Issues
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Connect to database
sudo -u postgres psql noctis_pro

# Run migrations manually
cd /workspace && source venv/bin/activate && python manage.py migrate
```

### DICOM Viewer Issues
```bash
# Check if production template is being used
grep -n "base.html" dicom_viewer/views.py

# Verify static files
python manage.py collectstatic --noinput
```

## 📊 Performance Monitoring

### System Resources
```bash
# Check memory usage
free -h

# Check disk usage
df -h

# Check processes
htop
```

### Application Monitoring
```bash
# Django performance
tail -f logs/django.log

# Database performance
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"

# Redis performance
redis-cli info stats
```

## 🔄 Updates and Maintenance

### Updating the Application
```bash
# Stop services
./stop_complete_production_system.sh

# Update code
git pull origin main

# Install new dependencies
source venv/bin/activate
pip install -r requirements.txt

# Run migrations
python manage.py migrate --settings=noctis_pro.settings_production

# Collect static files
python manage.py collectstatic --noinput --settings=noctis_pro.settings_production

# Start services
./start_complete_production_system.sh
```

### Backup and Restore
```bash
# Create backup
pg_dump -U noctis_user -h localhost noctis_pro > backup_$(date +%Y%m%d).sql

# Restore backup
psql -U noctis_user -h localhost noctis_pro < backup_20240101.sql
```

## ✅ Deployment Checklist

- [ ] Run bulletproof deployment script
- [ ] Verify all services are running
- [ ] Test web interface access
- [ ] Test DICOM viewer functionality
- [ ] Create admin user
- [ ] Configure domain/SSL (if needed)
- [ ] Test auto-startup after reboot
- [ ] Set up monitoring/backups
- [ ] Document access credentials

## 🎉 Success!

Your NoctisPro system is now deployed as a production service with:
- ✅ Full production DICOM viewer with all features
- ✅ Auto-startup on server boot
- ✅ Professional medical imaging capabilities
- ✅ Robust service management
- ✅ Production-grade security and performance

The system will automatically start all services when the server boots, ensuring maximum uptime and reliability for your medical imaging workflow.