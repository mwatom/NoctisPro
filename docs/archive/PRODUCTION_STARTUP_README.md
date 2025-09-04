# NoctisPro Production Startup Service

Complete production-ready systemd service for NoctisPro with ngrok static URL integration on Ubuntu Server.

## 🚀 Quick Start

### Option 1: Complete Automated Setup
Run the complete setup script that handles everything:

```bash
# Make sure you're in the workspace directory
cd /workspace

# Run the complete setup (requires sudo)
sudo ./setup_noctispro_production.sh
```

This script will:
- Install all system dependencies
- Configure PostgreSQL and Redis
- Set up Python environment
- Configure ngrok with static URL
- Install and enable systemd service
- Start the service automatically

### Option 2: Manual Installation
If you prefer to install components manually:

```bash
# 1. Install the systemd service
sudo ./install_production_startup.sh

# 2. Start the service
sudo systemctl start noctispro-production-startup

# 3. Enable autostart on boot
sudo systemctl enable noctispro-production-startup
```

## 📋 Service Management

### Basic Commands
```bash
# Start the service
sudo systemctl start noctispro-production-startup

# Stop the service
sudo systemctl stop noctispro-production-startup

# Restart the service
sudo systemctl restart noctispro-production-startup

# Check service status
sudo systemctl status noctispro-production-startup

# View real-time logs
sudo journalctl -u noctispro-production-startup -f

# Check if service is enabled for autostart
sudo systemctl is-enabled noctispro-production-startup
```

### Status Monitoring
Use the built-in status checker:

```bash
# Comprehensive status check
./check_noctispro_status.sh
```

## 🔧 Configuration

### Environment Files

#### `.env.production` - Main production settings
```bash
# Key settings for production
DEBUG=False
ALLOWED_HOSTS=*,your-static-url.ngrok-free.app,localhost
POSTGRES_HOST=localhost
REDIS_URL=redis://localhost:6379/0
```

#### `.env.ngrok` - Ngrok tunnel configuration
```bash
# Static URL configuration
NGROK_USE_STATIC=true
NGROK_STATIC_URL=your-static-url.ngrok-free.app

# Alternative configurations
# NGROK_SUBDOMAIN=your-subdomain  # For paid accounts
# NGROK_DOMAIN=your.custom.domain  # For custom domains
```

### Ngrok Static URL Setup

1. **Get your ngrok auth token:**
   - Visit: https://dashboard.ngrok.com/get-started/your-authtoken
   - Copy your auth token
   - Configure: `ngrok config add-authtoken <your-token>`

2. **Configure static URL:**
   - Edit `.env.ngrok`
   - Set `NGROK_STATIC_URL` to your desired URL
   - Update `ALLOWED_HOSTS` in `.env.production`

3. **For paid accounts (optional):**
   - Use custom subdomains: `NGROK_SUBDOMAIN=yourname`
   - Use custom domains: `NGROK_DOMAIN=your.domain.com`

## 🏗️ Architecture

### Service Components

The production service manages these components:

1. **Django Application** (Port 8000)
   - Main web application
   - Serves on localhost:8000
   - Production-optimized settings

2. **Ngrok Tunnel**
   - Creates HTTPS tunnel to Django
   - Uses static URL for consistent access
   - Web interface on localhost:4040

3. **PostgreSQL Database** (Port 5432)
   - Primary data storage
   - Automatically started as dependency

4. **Redis Cache** (Port 6379)
   - Session storage and caching
   - Celery message broker

### Process Management

```
systemd (noctispro-production-startup)
├── PostgreSQL (dependency)
├── Redis (dependency)
├── Django Server (runserver 0.0.0.0:8000)
└── Ngrok Tunnel (tunneling to port 8000)
```

## 📁 Important Files

### Service Files
- `/etc/systemd/system/noctispro-production-startup.service` - Systemd service definition
- `/workspace/start_production_with_ngrok.sh` - Main startup script
- `/workspace/stop_production_system.sh` - Graceful shutdown script

### Configuration Files
- `/workspace/.env.production` - Production environment variables
- `/workspace/.env.ngrok` - Ngrok configuration
- `/workspace/requirements.txt` - Python dependencies

### Log Files
- `/workspace/noctispro_production.log` - Main application log
- `/workspace/django_production.log` - Django server log
- `/workspace/ngrok_production.log` - Ngrok tunnel log
- `journalctl -u noctispro-production-startup` - Systemd service log

### PID Files
- `/workspace/noctispro_production.pid` - Main process PID
- `/workspace/django_production.pid` - Django server PID
- `/workspace/ngrok_production.pid` - Ngrok tunnel PID

## 🔐 Security Considerations

### Production Security
- `DEBUG=False` - Debug mode disabled
- Strong secret keys required
- Database credentials secured
- HTTPS enforced through ngrok

### Firewall Configuration
```bash
# Allow SSH (if using SSH)
sudo ufw allow ssh

# Allow HTTP for local access (optional)
sudo ufw allow 80

# Enable firewall
sudo ufw enable
```

### Recommended Security Updates
1. Change default secret keys in `.env.production`
2. Update database passwords
3. Configure proper Django secret key
4. Set up SSL certificates for custom domains

## 🚨 Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check service status
sudo systemctl status noctispro-production-startup

# Check detailed logs
sudo journalctl -u noctispro-production-startup -f

# Check if dependencies are running
sudo systemctl status postgresql redis-server
```

#### Ngrok Authentication Issues
```bash
# Verify ngrok config
ngrok config check

# Reconfigure auth token
ngrok config add-authtoken <your-token>

# Test ngrok manually
ngrok http 8000
```

#### Database Connection Issues
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Test database connection
sudo -u postgres psql -c "\\l"

# Check database user
sudo -u postgres psql -c "\\du"
```

#### Port Conflicts
```bash
# Check what's using port 8000
sudo netstat -tlnp | grep :8000

# Kill conflicting processes
sudo pkill -f "runserver"
sudo pkill -f "ngrok"
```

### Recovery Procedures

#### Complete Service Reset
```bash
# Stop service
sudo systemctl stop noctispro-production-startup

# Clean up processes
sudo pkill -f "runserver"
sudo pkill -f "ngrok"

# Remove PID files
sudo rm -f /workspace/*.pid

# Restart dependencies
sudo systemctl restart postgresql redis-server

# Start service
sudo systemctl start noctispro-production-startup
```

#### Database Recovery
```bash
# Backup current database
sudo -u postgres pg_dump noctis_pro > /workspace/backups/backup_$(date +%Y%m%d_%H%M%S).sql

# Restore from backup
sudo -u postgres psql noctis_pro < /workspace/backups/backup_file.sql
```

## 📊 Monitoring

### Health Checks
```bash
# Quick status
./check_noctispro_status.sh

# Detailed service status
sudo systemctl status noctispro-production-startup --no-pager -l

# Check all logs
sudo journalctl -u noctispro-production-startup --since "1 hour ago"
```

### Performance Monitoring
```bash
# Check resource usage
htop

# Check disk space
df -h

# Check memory usage
free -h

# Check database performance
sudo -u postgres psql noctis_pro -c "SELECT * FROM pg_stat_activity;"
```

## 🔄 Updates and Maintenance

### Updating the Application
```bash
# Stop the service
sudo systemctl stop noctispro-production-startup

# Update code (if using git)
git pull origin main

# Update dependencies
source venv/bin/activate
pip install -r requirements.txt

# Run migrations
python manage.py migrate

# Collect static files
python manage.py collectstatic --noinput

# Restart service
sudo systemctl start noctispro-production-startup
```

### Backup Procedures
```bash
# Create backup directory
mkdir -p /workspace/backups

# Backup database
sudo -u postgres pg_dump noctis_pro > /workspace/backups/db_backup_$(date +%Y%m%d).sql

# Backup media files
tar -czf /workspace/backups/media_backup_$(date +%Y%m%d).tar.gz /workspace/media

# Backup configuration
cp /workspace/.env.* /workspace/backups/
```

## 🌐 Access Information

### Default URLs
- **Local Application:** http://localhost:8000
- **Ngrok Web Interface:** http://localhost:4040
- **Public URL:** https://your-static-url.ngrok-free.app

### Default Credentials
- **Username:** admin
- **Password:** admin123
- **Change immediately after first login!**

## 📞 Support

### Useful Commands Reference
```bash
# Service management
sudo systemctl {start|stop|restart|status|enable|disable} noctispro-production-startup

# Log viewing
sudo journalctl -u noctispro-production-startup {-f|-l|--since="1 hour ago"}

# Configuration editing
nano /workspace/.env.production
nano /workspace/.env.ngrok

# Manual testing
cd /workspace && source venv/bin/activate && python manage.py runserver
ngrok http 8000

# Status checking
./check_noctispro_status.sh
systemctl is-active noctispro-production-startup
```

---

## 🎯 Production Checklist

Before going live, ensure:

- [ ] Ngrok auth token configured
- [ ] Static URL properly set
- [ ] Secret keys changed from defaults
- [ ] Database passwords updated
- [ ] Admin password changed
- [ ] Firewall configured appropriately
- [ ] Backup procedures in place
- [ ] Monitoring set up
- [ ] Service starts automatically on boot
- [ ] All logs are accessible and rotating

**Your NoctisPro instance is now production-ready with automatic startup on Ubuntu Server!**