# 🦆 NoctisPro PACS - DuckDNS Deployment Guide

## Why Choose DuckDNS Over ngrok?

| Feature | DuckDNS | ngrok |
|---------|---------|-------|
| **Cost** | ✅ **FREE Forever** | ❌ Limited free tier |
| **HTTP Limits** | ✅ **No limits** | ❌ 40 requests/minute (free) |
| **Permanent Domain** | ✅ **Your own subdomain** | ❌ Random URLs |
| **SSL Certificates** | ✅ **Free Let's Encrypt** | ❌ Limited on free tier |
| **Uptime** | ✅ **No session limits** | ❌ 8-hour sessions (free) |
| **Medical Use** | ✅ **Perfect for hospitals** | ❌ Not suitable for production |

## 🚀 Quick Start (3 Commands)

```bash
# 1. Get your free DuckDNS domain
# Visit https://www.duckdns.org and create a subdomain

# 2. Run the deployment script
./deploy_duckdns.sh

# 3. Access your system
# https://yourname.duckdns.org
```

## 📋 Detailed Setup Instructions

### Step 1: Get Your Free DuckDNS Domain

1. **Visit** https://www.duckdns.org
2. **Sign in** with Google, GitHub, or Reddit (free)
3. **Create a subdomain** (e.g., `myclinic` → myclinic.duckdns.org)
4. **Copy your token** from the dashboard

### Step 2: Choose Your Deployment Method

#### Option A: DuckDNS-Specific Deployment (Recommended)
```bash
./deploy_duckdns.sh
```
- Interactive setup with DuckDNS configuration
- Automatic SSL certificate setup
- Production-ready configuration

#### Option B: Master Deployment with DuckDNS
```bash
export DUCKDNS_SUBDOMAIN="yourname"
export DUCKDNS_TOKEN="your-token"
./deploy_master.sh
```

#### Option C: Intelligent Deployment with DuckDNS
```bash
export DUCKDNS_SUBDOMAIN="yourname"
export DUCKDNS_TOKEN="your-token"  
./deploy_intelligent.sh
```

### Step 3: Access Your System

- **Web Interface**: https://yourname.duckdns.org
- **Admin Panel**: https://yourname.duckdns.org/admin/
- **DICOM Port**: yourname.duckdns.org:11112
- **Default Login**: admin / admin123

## 🔧 What Gets Configured Automatically

### DuckDNS Features
- ✅ **Automatic IP Updates**: Every 5 minutes via systemd timer
- ✅ **DNS Configuration**: Instant global access
- ✅ **SSL Certificates**: Free Let's Encrypt certificates
- ✅ **Auto-Renewal**: Certificates renew automatically

### System Services
- ✅ **Web Application**: Django with Gunicorn
- ✅ **DICOM Receiver**: Port 11112 for medical imaging
- ✅ **Database**: PostgreSQL or SQLite
- ✅ **Background Tasks**: Celery (if sufficient resources)

### Security Features
- ✅ **HTTPS Redirect**: Automatic HTTP to HTTPS
- ✅ **CORS Configuration**: Proper cross-origin setup
- ✅ **CSRF Protection**: Django security enabled
- ✅ **Secure Headers**: Production security headers

## 🏥 Perfect for Medical Facilities

### Hospitals & Clinics
```bash
# Examples of professional subdomains:
# https://stmaryhospital.duckdns.org
# https://citymedicalcenter.duckdns.org
# https://radiologyassociates.duckdns.org
```

### Private Practices
```bash
# Examples for private practices:
# https://drsmith.duckdns.org
# https://johnsonclinic.duckdns.org
# https://mainstreetradiology.duckdns.org
```

### Research Institutions
```bash
# Examples for research:
# https://medresearch.duckdns.org
# https://imaginglab.duckdns.org
# https://biomedical.duckdns.org
```

## 📱 Management Commands

### Service Control
```bash
# Start all services
./manage_noctis_optimized.sh start

# Stop all services
./manage_noctis_optimized.sh stop

# Restart services
./manage_noctis_optimized.sh restart

# Check status
./manage_noctis_optimized.sh status

# View logs
./manage_noctis_optimized.sh logs

# Health check
./manage_noctis_optimized.sh health
```

### DuckDNS Management
```bash
# Check DuckDNS status
systemctl status duckdns-update.timer

# Manual IP update
sudo systemctl start duckdns-update.service

# View DuckDNS logs
sudo journalctl -u duckdns-update.service
```

### SSL Certificate Management
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates manually
sudo certbot renew

# Test renewal
sudo certbot renew --dry-run
```

## 🔍 Troubleshooting

### Common Issues

#### DNS Not Resolving
```bash
# Check if DuckDNS is updating
sudo systemctl status duckdns-update.timer
sudo journalctl -u duckdns-update.service

# Test DNS resolution
nslookup yourname.duckdns.org
```

#### SSL Certificate Issues
```bash
# Check certificate status
sudo certbot certificates

# Manually renew certificate
sudo certbot --nginx -d yourname.duckdns.org

# Check nginx configuration
sudo nginx -t
```

#### Service Not Starting
```bash
# Check service status
systemctl status noctis-web-optimized
systemctl status noctis-dicom-optimized

# View detailed logs
journalctl -u noctis-web-optimized -f
journalctl -u noctis-dicom-optimized -f
```

### Getting Help

#### Log Files
- **Deployment Log**: `/tmp/noctis_duckdns_deploy_*.log`
- **Application Logs**: `logs/web.log`, `logs/dicom.log`
- **System Logs**: `journalctl -u noctis-*`

#### Configuration Files
- **DuckDNS Config**: `/etc/noctis/duckdns.env`
- **Django Settings**: `noctis_pro/settings.py`
- **Environment**: `.env.optimized`

## 🌟 Advanced Configuration

### Custom Domain (Optional)
If you have your own domain, you can use CNAME records:
```
# DNS Record:
pacs.yourdomain.com CNAME yourname.duckdns.org
```

### Multiple Subdomains
You can create multiple DuckDNS subdomains for different purposes:
- `pacs-prod.duckdns.org` - Production system
- `pacs-test.duckdns.org` - Testing system
- `pacs-dev.duckdns.org` - Development system

### Firewall Configuration
```bash
# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow DICOM port
sudo ufw allow 11112/tcp

# Enable firewall
sudo ufw enable
```

## 🔒 Security Best Practices

### Change Default Credentials
```bash
# Access admin panel: https://yourname.duckdns.org/admin/
# Login with: admin / admin123
# Immediately change the password!
```

### Regular Updates
```bash
# Update system packages
sudo apt update && sudo apt upgrade

# Update application
cd /workspace
git pull origin main
./manage_noctis_optimized.sh restart
```

### Monitor Logs
```bash
# Set up log monitoring
tail -f logs/web.log logs/dicom.log
```

## 📊 Performance Optimization

### System Requirements
- **Minimum**: 2GB RAM, 2 CPU cores, 10GB storage
- **Recommended**: 4GB RAM, 4 CPU cores, 20GB storage
- **Optimal**: 8GB RAM, 8 CPU cores, 50GB storage

### Scaling Options
- **Database**: Upgrade to dedicated PostgreSQL server
- **Storage**: Add dedicated storage for DICOM files
- **Load Balancing**: Multiple application servers behind nginx
- **Monitoring**: Add Prometheus + Grafana for metrics

## 🎯 Production Checklist

### Before Going Live
- [ ] DuckDNS domain configured and resolving
- [ ] SSL certificate obtained and auto-renewal working
- [ ] Default admin password changed
- [ ] Firewall configured properly
- [ ] Regular backups scheduled
- [ ] Monitoring and alerting set up
- [ ] Staff training completed
- [ ] DICOM connectivity tested
- [ ] Performance testing completed

### Post-Deployment
- [ ] Document all URLs and credentials
- [ ] Set up regular maintenance schedule
- [ ] Configure automated backups
- [ ] Monitor system performance
- [ ] Plan for scaling as needed

---

## 🚀 Ready to Deploy?

```bash
# Clone the repository
git clone <your-repo-url>
cd noctispro

# Run the DuckDNS deployment
./deploy_duckdns.sh

# Access your system
open https://yourname.duckdns.org
```

**Need help?** Check the troubleshooting section above or review the deployment logs.

---

*🏥 NoctisPro PACS - Professional Medical Imaging Solution*
*🦆 Powered by DuckDNS - Free, Reliable, No Limits*