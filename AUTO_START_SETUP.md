# Auto-Start Setup for Noctis Pro on Ubuntu Server

This guide shows you how to configure your Noctis Pro system to automatically start when your Ubuntu server reboots, using native systemd services (not Docker).

## Prerequisites

- Ubuntu Server (18.04+ recommended)
- Your Noctis Pro application deployed in `/workspace` (or your chosen directory)
- Root/sudo access

## Quick Setup (Automated)

If you haven't already, run the installation script that sets up everything automatically:

```bash
sudo bash /workspace/ops/install_services.sh [YOUR_DOMAIN] [DUCKDNS_SUBDOMAIN] [DUCKDNS_TOKEN]
```

**Example:**
```bash
sudo bash /workspace/ops/install_services.sh myserver.com myapp duckdns_token_here
```

This script automatically:
- Installs all dependencies
- Creates systemd service files
- Enables auto-start for all services
- Configures nginx
- Sets up health monitoring

## Manual Setup (Step by Step)

If you prefer manual setup or need to troubleshoot:

### 1. Install Dependencies

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y python3 python3-pip python3-venv nginx redis-server git curl

# Enable Redis to start on boot
sudo systemctl enable redis-server
sudo systemctl start redis-server
```

### 2. Install Systemd Services

Copy the service files and enable them:

```bash
# Copy service files to systemd directory
sudo cp /workspace/ops/noctis-web.service /etc/systemd/system/
sudo cp /workspace/ops/noctis-celery.service /etc/systemd/system/
sudo cp /workspace/ops/noctis-dicom.service /etc/systemd/system/

# Optional: Copy webhook service if you need GitHub integration
sudo cp /workspace/ops/webhook.service /etc/systemd/system/noctis-webhook.service

# Reload systemd to recognize new services
sudo systemctl daemon-reload

# Enable services to start on boot
sudo systemctl enable noctis-web.service
sudo systemctl enable noctis-celery.service
sudo systemctl enable noctis-dicom.service
sudo systemctl enable noctis-webhook.service  # Optional

# Start services now
sudo systemctl start noctis-web.service
sudo systemctl start noctis-celery.service
sudo systemctl start noctis-dicom.service
sudo systemctl start noctis-webhook.service  # Optional
```

### 3. Configure Environment

Create the environment file that services will use:

```bash
sudo mkdir -p /etc/noctis
sudo cp /workspace/ops/noctis.env.example /etc/noctis/noctis.env

# Edit the environment file with your settings
sudo nano /etc/noctis/noctis.env
```

**Key environment variables to set:**
```bash
APP_DIR=/workspace
VENV_DIR=/workspace/venv
HOST=0.0.0.0
PORT=8000
ASGI_APP=noctis_pro.asgi:application
CELERY_APP=noctis_pro
DEBUG=False
SECRET_KEY=your-production-secret-key
```

### 4. Configure Nginx (Optional but Recommended)

```bash
# Copy nginx configuration
sudo cp /workspace/ops/nginx-noctis.conf.template /etc/nginx/sites-available/noctis

# Edit the configuration file to match your domain
sudo nano /etc/nginx/sites-available/noctis

# Enable the site
sudo ln -s /etc/nginx/sites-available/noctis /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
sudo nginx -t

# Enable nginx to start on boot and restart
sudo systemctl enable nginx
sudo systemctl restart nginx
```

## Service Management Commands

### Check Service Status
```bash
# Check all Noctis services
sudo systemctl status noctis-web.service
sudo systemctl status noctis-celery.service
sudo systemctl status noctis-dicom.service
sudo systemctl status noctis-webhook.service

# Quick status check
systemctl is-active noctis-web noctis-celery noctis-dicom
```

### Start/Stop/Restart Services
```bash
# Start all services
sudo systemctl start noctis-web noctis-celery noctis-dicom noctis-webhook

# Stop all services
sudo systemctl stop noctis-web noctis-celery noctis-dicom noctis-webhook

# Restart all services
sudo systemctl restart noctis-web noctis-celery noctis-dicom noctis-webhook
```

### View Service Logs
```bash
# View logs for web service
sudo journalctl -u noctis-web.service -f

# View logs for celery service
sudo journalctl -u noctis-celery.service -f

# View logs for DICOM service
sudo journalctl -u noctis-dicom.service -f
```

## Verify Auto-Start Configuration

### Check if Services are Enabled for Auto-Start
```bash
# Check if services are enabled
sudo systemctl is-enabled noctis-web.service
sudo systemctl is-enabled noctis-celery.service
sudo systemctl is-enabled noctis-dicom.service
sudo systemctl is-enabled redis-server.service
sudo systemctl is-enabled nginx.service

# Should all return "enabled"
```

### Test Auto-Start (Optional)
```bash
# Simulate a reboot to test auto-start
sudo reboot

# After reboot, check if services started automatically
sudo systemctl status noctis-web noctis-celery noctis-dicom
```

## Health Monitoring

Your system includes automatic health monitoring:

### Startup Check Service
A special service runs after boot to verify all components are healthy:

```bash
# Check startup verification logs
sudo journalctl -u noctis-startup-check.service

# Run manual health check
sudo bash /workspace/ops/startup_check.sh
```

### Manual Health Check
```bash
# Run comprehensive health check
sudo bash /workspace/ops/startup_check.sh check

# Restart all services and check health
sudo bash /workspace/ops/startup_check.sh restart-all

# View service status
sudo bash /workspace/ops/startup_check.sh status
```

## Troubleshooting

### Services Won't Start
1. Check service logs:
   ```bash
   sudo journalctl -u noctis-web.service -n 50
   ```

2. Verify environment file:
   ```bash
   sudo cat /etc/noctis/noctis.env
   ```

3. Check permissions:
   ```bash
   sudo chown -R root:root /workspace
   sudo chmod +x /workspace/venv/bin/*
   ```

### Services Start but Don't Work
1. Check if Redis is running:
   ```bash
   sudo systemctl status redis-server
   redis-cli ping  # Should return "PONG"
   ```

2. Verify database migrations:
   ```bash
   cd /workspace
   source venv/bin/activate
   python manage.py migrate
   ```

3. Check application logs:
   ```bash
   tail -f /workspace/noctis_pro.log
   ```

### Services Don't Auto-Start After Reboot
1. Verify services are enabled:
   ```bash
   sudo systemctl list-unit-files | grep noctis
   ```

2. Check for failed services:
   ```bash
   sudo systemctl --failed
   ```

3. Re-enable services:
   ```bash
   sudo systemctl enable noctis-web noctis-celery noctis-dicom
   ```

## Service Dependencies

The services are configured with proper dependencies:

- **noctis-web**: Requires Redis, starts after network
- **noctis-celery**: Requires Redis and noctis-web
- **noctis-dicom**: Requires Redis, independent of web service
- **noctis-webhook**: Requires noctis-web (optional)

## Security Notes

- Services run as root by default (can be changed for production)
- Environment file contains sensitive information - protect it:
  ```bash
  sudo chmod 600 /etc/noctis/noctis.env
  ```
- Consider using a dedicated user for production deployments

## Additional Features

### DuckDNS Integration (Optional)
If you provided DuckDNS credentials during setup, a timer service automatically updates your dynamic DNS:

```bash
# Check DuckDNS update status
sudo systemctl status duckdns-update.timer
sudo systemctl status duckdns-update.service
```

### GitHub Webhook Integration (Optional)
If configured, the webhook service enables automatic deployments:

```bash
# Check webhook service
sudo systemctl status noctis-webhook.service

# View webhook logs
sudo journalctl -u noctis-webhook.service -f
```

## Summary

After following this guide, your Noctis Pro system will:

✅ **Auto-start** all services when the server reboots  
✅ **Monitor health** and restart failed services automatically  
✅ **Log everything** for easy troubleshooting  
✅ **Handle dependencies** correctly (Redis → Web → Celery)  
✅ **Provide management commands** for easy administration  

Your system is now production-ready and will survive server reboots!