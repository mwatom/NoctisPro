# 🦆 NoctisPro PACS - DuckDNS Deployment Guide

## 🚀 Quick Start - One Command Deployment

```bash
# Clone and deploy with DuckDNS in one command
cd /workspace && ./deploy_master.sh
```

When prompted, choose **YES** to configure DuckDNS for global access.

## 📋 Why DuckDNS Over Ngrok?

| Feature | DuckDNS | Ngrok |
|---------|---------|-------|
| **HTTP Request Limits** | ✅ Unlimited | ❌ Limited (40 requests/min free) |
| **Permanent URL** | ✅ Never changes | ❌ Changes on restart |
| **Session Timeout** | ✅ No timeout | ❌ 2 hour limit (free) |
| **SSL Certificates** | ✅ Free Let's Encrypt | ✅ Included |
| **Cost** | ✅ 100% Free | 💰 $8-25/month for static URL |
| **Production Ready** | ✅ Yes | ❌ Development only (free) |
| **Bandwidth** | ✅ Unlimited | ❌ Limited |
| **Custom Domains** | ✅ Supports CNAME | ❌ Paid only |

## 🎯 Features of Our DuckDNS Integration

### ✨ Zero Configuration Required
- Automatic IP detection
- Auto-renewal every 5 minutes
- SSL certificates auto-configured
- Nginx reverse proxy setup

### 🔒 Production-Ready Security
- Free SSL/TLS certificates via Let's Encrypt
- Automatic certificate renewal
- Secure headers configured
- CSRF protection enabled

### 🌐 Global Accessibility
- Access from anywhere in the world
- Works behind NAT/firewalls
- No port forwarding needed
- Dynamic IP support

### 📊 No Limitations
- **Unlimited HTTP requests** (unlike ngrok's 40/min limit)
- **No session timeouts** (unlike ngrok's 2-hour limit)
- **Unlimited bandwidth**
- **Permanent URL** that never changes

## 📝 Step-by-Step Setup

### Step 1: Get Your DuckDNS Account

1. Visit [https://www.duckdns.org](https://www.duckdns.org)
2. Sign in with:
   - Google
   - GitHub
   - Twitter
   - Reddit

### Step 2: Create Your Subdomain

1. After signing in, enter your desired subdomain
2. Click "add domain"
3. Your subdomain will be: `yourname.duckdns.org`

### Step 3: Get Your Token

1. Your token is displayed at the top of the page
2. It looks like: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
3. Keep this token secure!

### Step 4: Run the Deployment

```bash
# Option 1: Full deployment with DuckDNS
./deploy_master.sh

# Option 2: DuckDNS only (if already deployed)
./deploy_duckdns_master.sh
```

### Step 5: Enter Your Configuration

When prompted:
```
Enter your DuckDNS subdomain (without .duckdns.org): myhospital
Enter your DuckDNS token: your-token-here
```

## 🔧 Manual DuckDNS Setup (Alternative)

If you prefer manual setup or need to reconfigure:

```bash
# Run the standalone DuckDNS configuration
sudo ./deploy_duckdns_master.sh --subdomain myhospital --token your-token-here
```

## 🌍 Access Your Deployment

After successful deployment, access your NoctisPro PACS at:

- **Main Application**: `https://yoursubdomain.duckdns.org`
- **Admin Panel**: `https://yoursubdomain.duckdns.org/admin/`
- **DICOM Viewer**: `https://yoursubdomain.duckdns.org/dicom-viewer/`
- **API Endpoint**: `https://yoursubdomain.duckdns.org/api/`

Default credentials:
- Username: `admin`
- Password: `admin123`

## 🔄 Automatic Updates

The deployment automatically:
- Updates your IP with DuckDNS every 5 minutes
- Renews SSL certificates before expiry
- Monitors service health
- Restarts services if needed

## 📊 Monitoring Your Deployment

### Check DuckDNS Update Status
```bash
sudo systemctl status duckdns-update.timer
sudo journalctl -u duckdns-update -f
```

### Check NoctisPro Services
```bash
./manage_noctis.sh status
./manage_noctis.sh health
```

### View Logs
```bash
# All logs
./manage_noctis.sh logs

# DuckDNS specific
sudo journalctl -u duckdns-update -n 50
```

## 🛠️ Troubleshooting

### DNS Not Resolving

```bash
# Check if DuckDNS is updated
curl "https://www.duckdns.org/update?domains=yoursubdomain&token=yourtoken&ip="

# Should return "OK"
```

### SSL Certificate Issues

```bash
# Manually obtain certificate
sudo certbot --nginx -d yoursubdomain.duckdns.org

# Check certificate status
sudo certbot certificates
```

### Service Not Accessible

```bash
# Check if services are running
sudo systemctl status nginx
sudo systemctl status noctis-web

# Check firewall
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### Update IP Manually

```bash
# Force update now
sudo systemctl start duckdns-update

# Check last update
sudo journalctl -u duckdns-update -n 1
```

## 🔐 Security Best Practices

1. **Change Default Password**
   ```bash
   python manage.py changepassword admin
   ```

2. **Enable Firewall**
   ```bash
   sudo ufw allow 22/tcp    # SSH
   sudo ufw allow 80/tcp    # HTTP
   sudo ufw allow 443/tcp   # HTTPS
   sudo ufw allow 11112/tcp # DICOM
   sudo ufw enable
   ```

3. **Regular Updates**
   ```bash
   sudo apt update && sudo apt upgrade
   ./manage_noctis.sh update
   ```

4. **Backup Configuration**
   ```bash
   sudo cp -r /etc/noctis /backup/noctis-$(date +%Y%m%d)
   ```

## 📁 Configuration Files

- **DuckDNS Config**: `/etc/noctis/duckdns.env`
- **NoctisPro Config**: `/etc/noctis/noctis.env`
- **Nginx Config**: `/etc/nginx/sites-available/noctis-duckdns`
- **Systemd Timer**: `/etc/systemd/system/duckdns-update.timer`
- **Update Script**: `/usr/local/bin/duckdns-update`

## 🔄 Migrating from Ngrok

If you're currently using ngrok:

1. **No Changes Needed**: The DuckDNS setup is completely independent
2. **Better Performance**: No request limits or timeouts
3. **Permanent URL**: Share once, works forever
4. **Cost Savings**: No need for ngrok paid plans

## 💡 Advanced Configuration

### Custom Domain with CNAME

Point your domain to DuckDNS:
```
CNAME: pacs.yourhospital.com -> yoursubdomain.duckdns.org
```

### Multiple Deployments

Create multiple subdomains for different environments:
- `production.duckdns.org` - Production
- `staging.duckdns.org` - Staging
- `demo.duckdns.org` - Demo

### API Integration

Access the API programmatically:
```python
import requests

api_url = "https://yoursubdomain.duckdns.org/api/"
headers = {"Authorization": "Token your-api-token"}
response = requests.get(f"{api_url}patients/", headers=headers)
```

## 📞 Support

### Common Issues Resolved

✅ **No HTTP request limits** - Process unlimited DICOM studies  
✅ **Permanent URL** - No need to update configurations  
✅ **24/7 availability** - No session timeouts  
✅ **Production ready** - Suitable for hospital use  
✅ **Free forever** - No hidden costs  

### Getting Help

1. Check the logs: `./manage_noctis.sh logs`
2. Run health check: `./manage_noctis.sh health`
3. Review this guide
4. Check system status: `sudo systemctl status noctis-*`

## 🎉 Success Indicators

You know your deployment is successful when:

✅ DuckDNS URL responds with HTTPS  
✅ SSL certificate shows as valid  
✅ Admin panel is accessible  
✅ DICOM port 11112 is open  
✅ Auto-update timer is active  
✅ No errors in logs  

## 🚀 Next Steps

After successful deployment:

1. **Change admin password**
2. **Configure DICOM nodes**
3. **Set up user accounts**
4. **Test DICOM send/receive**
5. **Configure backup strategy**

---

## 📌 Quick Reference

```bash
# Deployment
./deploy_master.sh                    # Full deployment with DuckDNS

# Management
./manage_noctis.sh start             # Start services
./manage_noctis.sh stop              # Stop services
./manage_noctis.sh restart           # Restart services
./manage_noctis.sh status            # Check status
./manage_noctis.sh logs              # View logs

# DuckDNS
sudo systemctl status duckdns-update.timer    # Check auto-update
sudo systemctl start duckdns-update           # Force update now
sudo journalctl -u duckdns-update -f          # Watch update logs

# Access URLs
https://yoursubdomain.duckdns.org             # Main application
https://yoursubdomain.duckdns.org/admin/      # Admin panel
https://yoursubdomain.duckdns.org/dicom-viewer/ # DICOM viewer
```

---

**🦆 Enjoy your unlimited, production-ready NoctisPro PACS deployment with DuckDNS!**