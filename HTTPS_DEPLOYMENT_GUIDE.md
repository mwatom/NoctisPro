# NoctisPro PACS - HTTPS Static URL Deployment Guide

## 🔒 Overview

This guide provides multiple methods to deploy NoctisPro with a static HTTPS URL, ensuring secure access to your PACS system from anywhere on the internet.

## 🚀 Quick Setup Options

### Option 1: Kubernetes with Automatic SSL (Recommended)

**Prerequisites:**
- Kubernetes cluster
- Domain name pointing to your cluster
- kubectl configured

```bash
# 1. Set your domain and email
export DOMAIN="noctispro.yourdomain.com"
export EMAIL="admin@yourdomain.com"

# 2. Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# 3. Deploy NoctisPro with HTTPS
kubectl apply -f deployment/kubernetes/
```

### Option 2: Docker with Let's Encrypt

**Prerequisites:**
- Docker and Docker Compose
- Domain name pointing to your server
- Ports 80 and 443 open

```bash
# 1. Set your domain and email
export DOMAIN="noctispro.yourdomain.com"
export EMAIL="admin@yourdomain.com"

# 2. Run the HTTPS setup script
DOMAIN=$DOMAIN EMAIL=$EMAIL ./setup_https_internet_access.sh

# 3. Start services
docker-compose -f docker-compose.yml -f docker-compose.ssl.yml up -d
```

### Option 3: Native Linux with Nginx + Let's Encrypt

**Prerequisites:**
- Linux server with systemd
- Domain name pointing to your server
- Sudo privileges

```bash
# 1. Set your domain and email
export DOMAIN="noctispro.yourdomain.com"
export EMAIL="admin@yourdomain.com"

# 2. Run the HTTPS setup script
DOMAIN=$DOMAIN EMAIL=$EMAIL DEPLOYMENT_TYPE=native ./setup_https_internet_access.sh
```

### Option 4: Cloudflare Tunnel (Zero Trust)

**Prerequisites:**
- Cloudflare account
- Domain managed by Cloudflare

```bash
# 1. Install cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# 2. Login and create tunnel
cloudflared tunnel login
cloudflared tunnel create noctispro

# 3. Configure DNS in Cloudflare dashboard
# 4. Run tunnel
cloudflared tunnel run noctispro
```

## 🏥 DICOM Configuration for HTTPS

Once your HTTPS deployment is running, configure your DICOM devices:

```
Called AE Title:   NOCTIS_SCP
Calling AE Title:  [Your facility's AE Title]
Hostname:          your-domain.com
Port:              11112
Protocol:          DICOM TCP/IP
```

## 🌐 DNS Configuration

For all options (except Cloudflare Tunnel), configure these DNS records:

```
Type    Name                    Value
A       noctispro.yourdomain.com    YOUR_SERVER_IP
A       www.noctispro.yourdomain.com    YOUR_SERVER_IP
```

## 🔧 Troubleshooting

### SSL Certificate Issues
```bash
# Check certificate status
kubectl describe certificate noctispro-tls -n noctispro

# Force certificate renewal
kubectl delete certificate noctispro-tls -n noctispro
kubectl apply -f deployment/kubernetes/ingress.yaml
```

### Domain Not Resolving
```bash
# Test DNS resolution
nslookup your-domain.com
dig your-domain.com

# Test connectivity
curl -I https://your-domain.com/health
```

### Firewall Issues
```bash
# Open required ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 11112/tcp
```

## 📊 Access Information

After successful deployment:

- **🌐 Web Interface**: https://your-domain.com
- **👤 Admin Panel**: https://your-domain.com/admin/
- **🏥 Worklist**: https://your-domain.com/worklist/
- **🔐 Default Login**: admin / admin123
- **🏥 DICOM Port**: your-domain.com:11112

## 🛡️ Security Features

All HTTPS deployments include:

- ✅ SSL/TLS encryption (Let's Encrypt certificates)
- ✅ Automatic certificate renewal
- ✅ Security headers (HSTS, XSS protection)
- ✅ HTTP to HTTPS redirects
- ✅ Secure cookie settings
- ✅ Content Security Policy

## 📈 Monitoring

Check your deployment status:

```bash
# Kubernetes
kubectl get pods -n noctispro
kubectl get ingress -n noctispro
kubectl get certificates -n noctispro

# Docker
docker-compose ps
docker-compose logs nginx

# Native
sudo systemctl status nginx noctispro
sudo journalctl -f -u nginx
```

---

**🎉 Your NoctisPro PACS is now securely accessible via HTTPS!**

For additional support, check the troubleshooting section or open an issue on GitHub.