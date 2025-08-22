# 🚀 DEMO DEPLOYMENT COMMANDS - Ubuntu 24.04

> **For Customer Demo**: Get NoctisPro online quickly with HTTPS access

## ⚡ ONE-COMMAND DEPLOYMENT

### Complete Demo Setup (30 minutes)

```bash
# 1. System preparation
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget
sudo reboot

# 2. Download and deploy
git clone https://github.com/mwatom/NoctisPro.git
cd NoctisPro
chmod +x *.sh

# 3. Configure domain (EDIT THIS LINE!)
nano deploy_noctis_production.sh
# Change line 20: DOMAIN_NAME="your-demo-domain.com"

# 4. Deploy everything
sudo ./deploy_noctis_production.sh

# 5. Configure HTTPS access
sudo ./setup_secure_access.sh

# 6. Verify deployment
sudo python3 validate_demo_deployment.py
```

## 🌐 CUSTOMER ACCESS

**After deployment, provide customer with:**

- **Demo URL**: `https://your-demo-domain.com`
- **Admin Panel**: `https://your-demo-domain.com/admin`
- **Login**: admin / admin123 (change immediately)

## ✅ VALIDATION COMMANDS

```bash
# Check all services
sudo /usr/local/bin/noctis-status.sh

# Validate demo readiness
sudo python3 validate_demo_deployment.py

# Get access information
cat /opt/noctis_pro/SECURE_ACCESS_INFO.txt

# Test HTTPS access
curl -I https://your-demo-domain.com
```

## 🚨 EMERGENCY FIXES

```bash
# Restart everything
sudo systemctl restart noctis-django noctis-daphne noctis-celery nginx postgresql redis

# Ubuntu 24.04 Docker fix
sudo apt install -y iptables-persistent fuse-overlayfs
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo systemctl restart docker

# SSL certificate fix
sudo certbot renew --force-renewal
sudo systemctl restart nginx
```

---

**🎯 Result**: Fully functional NoctisPro demo with HTTPS access for customer evaluation