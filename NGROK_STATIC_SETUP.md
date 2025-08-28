# 🌐 NoctisPro Static Ngrok URL Setup Guide

## 🎯 Overview

This guide shows you how to configure NoctisPro with **static ngrok URLs** that remain the same every time you restart the tunnel. No more changing URLs!

## 🆓 Free vs Paid Accounts

| Feature | Free Account | Paid Account |
|---------|--------------|--------------|
| Random URLs | ✅ Yes | ✅ Yes |
| Static Subdomains | ❌ No | ✅ Yes |
| Custom Domains | ❌ No | ✅ Yes |
| Multiple Tunnels | Limited | ✅ Yes |

## 🚀 Quick Setup (2 Steps)

### Step 1: Configure Static URL
```bash
cd /workspace
./setup_ngrok_static.sh
```

### Step 2: Start with Static URL
```bash
./start_with_ngrok.sh
```

**That's it!** Your URL will now be fixed every time.

## 📋 Detailed Setup Options

### Option 1: Static Subdomain (Paid Account Required)

**Result**: `https://noctispro.ngrok.io` (always the same)

1. **Get paid ngrok account**:
   - Go to: https://dashboard.ngrok.com/billing
   - Choose a plan (starts at $8/month)

2. **Configure subdomain**:
   ```bash
   ./setup_ngrok_static.sh
   # Choose option 1
   # Enter your preferred subdomain (e.g., "noctispro")
   ```

3. **Start application**:
   ```bash
   ./start_with_ngrok.sh
   ```

### Option 2: Custom Domain (Paid Account + Domain Required)

**Result**: `https://noctis.yourdomain.com` (your own domain)

1. **Requirements**:
   - Paid ngrok account
   - Your own domain (e.g., yourdomain.com)

2. **Configure domain in ngrok**:
   - Go to: https://dashboard.ngrok.com/domains
   - Add your domain: `noctis.yourdomain.com`
   - Follow verification instructions

3. **Setup DNS**:
   ```
   # Add CNAME record in your DNS
   noctis.yourdomain.com -> CNAME -> tunnel.ngrok.com
   ```

4. **Configure NoctisPro**:
   ```bash
   ./setup_ngrok_static.sh
   # Choose option 2
   # Enter your domain: noctis.yourdomain.com
   ```

5. **Start application**:
   ```bash
   ./start_with_ngrok.sh
   ```

### Option 3: Free Random URLs (Default)

**Result**: `https://abc123.ngrok.io` (changes each restart)

```bash
./setup_ngrok_static.sh
# Choose option 3 to disable static URLs
```

## 🔧 Manual Configuration

### Environment Variables (`.env.ngrok`)

```bash
# Enable static URLs
NGROK_USE_STATIC=true

# For static subdomain:
NGROK_SUBDOMAIN=noctispro

# For custom domain:
NGROK_DOMAIN=noctis.yourdomain.com

# Other settings
NGROK_REGION=us
NGROK_TUNNEL_NAME=noctispro-http
```

### Ngrok Config (`~/.config/ngrok/ngrok.yml`)

```yaml
version: "2"
authtoken: your_auth_token_here

tunnels:
  # Static subdomain tunnel
  noctispro-static:
    proto: http
    addr: 8000
    subdomain: noctispro
    inspect: true
  
  # Custom domain tunnel
  noctispro-domain:
    proto: http
    addr: 8000
    hostname: noctis.yourdomain.com
    inspect: true
```

## 🛠️ Advanced Usage

### Multiple Environments

Create environment-specific configs:

```bash
# Development
cp .env.ngrok .env.ngrok.dev
# Edit for dev subdomain: noctispro-dev

# Production  
cp .env.ngrok .env.ngrok.prod
# Edit for prod subdomain: noctispro
```

### Systemd Service with Static URLs

```bash
# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable noctispro-ngrok.service
sudo systemctl start noctispro-ngrok.service

# Check status
sudo systemctl status noctispro-ngrok.service
```

### Testing Configuration

```bash
# Test ngrok config
ngrok config check

# Test tunnel manually
ngrok start noctispro-static

# View active tunnels
curl -s http://localhost:4040/api/tunnels | jq
```

## 🔍 Troubleshooting

### Error: "Subdomain not available"
```
❌ The subdomain 'noctispro' is not available on the ngrok hostname
```
**Solution**: Choose a different subdomain or upgrade to a paid plan.

### Error: "Domain verification required"
```
❌ Domain 'noctis.yourdomain.com' requires verification
```
**Solution**: 
1. Go to https://dashboard.ngrok.com/domains
2. Complete domain verification
3. Add required DNS records

### Error: "Tunnel not found"
```
❌ Tunnel noctispro-static not found
```
**Solution**: Check your `~/.config/ngrok/ngrok.yml` configuration.

### URL Changes on Restart
If your URL still changes:
1. Verify `NGROK_USE_STATIC=true` in `.env.ngrok`
2. Check your ngrok account has paid features
3. Ensure subdomain/domain is properly configured

## 📊 Monitoring Static URLs

### View Current URL
```bash
# Get current ngrok URL
curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url'

# Or check saved URL
cat .ngrok_url
```

### Ngrok Dashboard
Access the ngrok web interface:
- URL: http://localhost:4040
- View request logs, replay requests, etc.

### Service Logs
```bash
# View ngrok service logs
sudo journalctl -u noctispro-ngrok.service -f

# View Django logs
sudo journalctl -u noctispro.service -f
```

## 💡 Best Practices

### 1. Use Descriptive Subdomains
```bash
# Good
noctispro-clinic
noctispro-demo
noctispro-dev

# Avoid
x123
test
temp
```

### 2. Secure Your Static URLs
```bash
# Add authentication
SECURE_SSL_REDIRECT=True
SECURE_PROXY_SSL_HEADER=('HTTP_X_FORWARDED_PROTO', 'https')

# Restrict hosts (optional)
ALLOWED_HOSTS=["noctispro.ngrok.io"]
```

### 3. Monitor Usage
- Check ngrok dashboard for usage statistics
- Set up monitoring for tunnel availability
- Keep backup random URL option available

## 🎉 Success!

Your NoctisPro installation now has a **fixed ngrok URL** that never changes!

### Quick Verification
1. Start application: `./start_with_ngrok.sh`
2. Note the URL (e.g., `https://noctispro.ngrok.io`)
3. Stop and restart
4. Verify URL is the same ✅

### Access Your Application
- **Main App**: `https://your-static-url/`
- **Admin Panel**: `https://your-static-url/admin-panel/`
- **DICOM Viewer**: `https://your-static-url/dicom-viewer/`
- **Worklist**: `https://your-static-url/worklist/`

**No more URL hunting! Your medical imaging platform is now accessible at a consistent address.** 🏥✨

## 📞 Support

- **Ngrok Documentation**: https://ngrok.com/docs
- **Ngrok Dashboard**: https://dashboard.ngrok.com
- **Pricing**: https://ngrok.com/pricing