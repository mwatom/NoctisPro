# 🌐 Static URL Setup Guide

This guide will help you set up a static URL for your NoctisPro DICOM Viewer using Duck DNS and Cloudflare, replacing the previous ngrok setup.

## 🦆 Option 1: Duck DNS (Free Dynamic DNS)

Duck DNS provides free subdomains that automatically update with your changing IP address.

### Step 1: Get Duck DNS Credentials
1. Go to [https://www.duckdns.org](https://www.duckdns.org)
2. Sign in with Google/GitHub/Reddit/Twitter
3. Create a subdomain (e.g., 'noctispro')
4. Copy your token from the top of the page

### Step 2: Set Up Duck DNS
```bash
export DUCKDNS_DOMAIN=noctispro
export DUCKDNS_TOKEN=your-actual-token-here
bash setup_duckdns.sh
```

Your application will be available at: `https://noctispro.duckdns.org`

## ☁️ Option 2: Cloudflare (Enhanced Performance & Security)

Cloudflare provides SSL, CDN, and DDoS protection for your domain.

### Prerequisites
- A domain name (can be registered through Cloudflare)
- Cloudflare account

### Step 2A: Traditional Cloudflare Setup
```bash
export CLOUDFLARE_API_TOKEN=your-api-token
export CLOUDFLARE_ZONE_ID=your-zone-id
bash setup_cloudflare.sh
```

### Step 2B: Cloudflare Tunnel (Recommended for Home Servers)
```bash
bash setup_cloudflare_tunnel.sh
```

**Benefits of Cloudflare Tunnel:**
- ✅ No port forwarding required
- ✅ Works behind NAT/firewall
- ✅ Automatic SSL/TLS encryption
- ✅ DDoS protection
- ✅ Free for personal use

## 🚀 Deploy Your Application

After setting up your preferred DNS solution:

```bash
bash deploy_static_url.sh
```

## 🔧 Configuration Files Created

- `.duckdns_config` - Duck DNS credentials and domain
- `.cloudflare_config` - Cloudflare API credentials
- `.tunnel_config` - Cloudflare Tunnel information
- `update_duckdns.sh` - Auto-update script (runs via cron)

## 📊 Access Your Application

### Web Interface
- **DICOM Viewer**: `/dicom-viewer/`
- **Admin Panel**: `/admin/`
- **API**: `/api/`

### Default Credentials
- **Username**: `admin`
- **Password**: `admin123`

## 🛠️ Maintenance Commands

```bash
# View application logs
tail -f django_server.log

# Stop the server
kill $(cat .django_pid)

# Restart the application
bash deploy_static_url.sh

# Check Duck DNS updates
tail -f duckdns.log

# Check Cloudflare Tunnel status
sudo systemctl status cloudflared-tunnel.service
```

## 🔒 Security Notes

1. **Change default admin password** after first login
2. **Set DEBUG=False** in production
3. **Use strong SECRET_KEY** in production
4. **Enable HTTPS** (automatic with Cloudflare)
5. **Regular backups** of your database

## 🆘 Troubleshooting

### DNS Not Resolving
```bash
# Test DNS resolution
nslookup your-domain.duckdns.org
dig your-domain.duckdns.org
```

### Server Not Starting
```bash
# Check logs
tail -f django_server.log
tail -f gunicorn_error.log

# Check port availability
netstat -tlnp | grep :8000
```

### Cloudflare Tunnel Issues
```bash
# Check tunnel status
sudo systemctl status cloudflared-tunnel.service

# View tunnel logs
sudo journalctl -u cloudflared-tunnel.service -f
```

## 📞 Support

If you encounter issues:

1. Check the logs in `django_server.log`
2. Ensure all dependencies are installed
3. Verify your DNS configuration
4. Check firewall settings (if applicable)

## 🎉 What's Different from ngrok?

| Feature | ngrok | Static URL Setup |
|---------|--------|------------------|
| **Cost** | Limited free tier | Completely free |
| **Reliability** | Session-based | Permanent |
| **Custom Domain** | Paid feature | Yes (with your domain) |
| **SSL/TLS** | Included | Included |
| **Performance** | Variable | CDN-accelerated |
| **Setup Complexity** | Simple | Moderate |
| **Persistence** | Temporary | Permanent |

Your NoctisPro DICOM Viewer now has a professional, permanent URL! 🏥✨