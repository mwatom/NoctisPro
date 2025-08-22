# 📋 TECHNICIAN QUICK REFERENCE CARD

> **Print this page for easy reference during deployment**

## 🚀 DEPLOYMENT COMMANDS (Copy & Paste)

### 1. System Prep
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget
sudo reboot
```

### 2. Download
```bash
git clone https://github.com/mwatom/NoctisPro.git
cd NoctisPro
chmod +x *.sh scripts/*.sh
```

### 3. Storage (SSD+HDD only)
```bash
sudo ./scripts/configure_storage.sh
```

### 4. Deploy
```bash
sudo ./deploy_noctis_production.sh
```

### 5. Verify
```bash
sudo /usr/local/bin/noctis-status.sh
```

## 🔍 VERIFICATION CHECKLIST

**✅ Success Indicators:**
- [ ] All services show "active (running)"
- [ ] Web access: http://192.168.100.15
- [ ] Login works: admin/admin123
- [ ] Docker running: `sudo docker ps`
- [ ] Storage mounted: `df -h`

## 🚨 EMERGENCY COMMANDS

### Restart Everything
```bash
sudo systemctl restart noctis-django noctis-daphne noctis-celery nginx postgresql redis docker
```

### Check Status
```bash
sudo /usr/local/bin/noctis-status.sh
sudo /usr/local/bin/noctis-storage-monitor.sh
```

### View Logs
```bash
sudo journalctl -u noctis-django -f
sudo docker logs <container_name>
```

### Fix Permissions
```bash
sudo chown -R noctis:noctis /opt/noctis_pro/ /data/noctis_pro/
sudo chmod -R 755 /opt/noctis_pro/ /data/noctis_pro/
```

## 🐳 DOCKER TROUBLESHOOTING

### Docker Won't Install
```bash
sudo apt remove -y docker docker-engine docker.io containerd runc
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### Ubuntu 24.04 Docker Fix
```bash
sudo apt install -y iptables-persistent fuse-overlayfs
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo systemctl restart docker
```

### Docker Permission Fix
```bash
sudo usermod -aG docker $USER
sudo usermod -aG docker noctis
sudo systemctl restart docker
```

## 💾 STORAGE QUICK FIX

### Manual HDD Setup
```bash
sudo lsblk                    # Check disks
sudo fdisk /dev/sda           # Partition HDD
sudo mkfs.ext4 /dev/sda1      # Format
sudo mkdir -p /data           # Create mount
sudo mount /dev/sda1 /data    # Mount
```

### Storage Check
```bash
df -h                         # Disk usage
sudo docker system df         # Docker usage
du -sh /data/noctis_pro/      # Data usage
```

## 🌐 INTERNET ACCESS

### Enable Internet Access
```bash
sudo ./setup_secure_access.sh
cat /opt/noctis_pro/SECURE_ACCESS_INFO.txt
```

## 🖨️ PRINTER SETUP

### Add Printer
```bash
sudo systemctl status cups
# Web: http://localhost:631
sudo lpadmin -p PrinterName -E -v "ipp://printer-ip/ipp/print" -m everywhere
echo "Test" | lp -d PrinterName
```

## 📊 MONITORING

### Daily Commands
```bash
sudo /usr/local/bin/noctis-status.sh
df -h
free -h
sudo docker ps
```

### Weekly Commands
```bash
sudo apt update && sudo apt upgrade -y
sudo docker system prune -f
ls -la /data/noctis_pro/backups/
```

## 🔧 CONFIGURATION FILES

| Component | Location |
|-----------|----------|
| Main App | `/opt/noctis_pro/.env` |
| Docker | `/etc/docker/daemon.json` |
| Storage | `/etc/fstab` |
| Web Server | `/etc/nginx/sites-available/noctis_pro` |
| Services | `/etc/systemd/system/noctis-*` |

## 📞 CRITICAL INFO

**Default Access:**
- **URL**: http://192.168.100.15
- **Login**: admin / admin123
- **Change password immediately!**

**Key Directories:**
- **App**: `/opt/noctis_pro/`
- **Data**: `/data/noctis_pro/` (HDD)
- **Cache**: `/opt/noctis_pro_fast/` (SSD)
- **Docker**: `/var/lib/docker/` (SSD)

**Essential Commands:**
- **Status**: `sudo /usr/local/bin/noctis-status.sh`
- **Storage**: `sudo /usr/local/bin/noctis-storage-monitor.sh`
- **Logs**: `sudo journalctl -u noctis-django -f`
- **Docker**: `sudo docker ps`

## ⏱️ DEPLOYMENT TIMELINE

| Step | Time | Command |
|------|------|---------|
| Prep | 5 min | `sudo apt update && apt upgrade -y` |
| Download | 2 min | `git clone ...` |
| Storage | 5 min | `sudo ./scripts/configure_storage.sh` |
| Deploy | 20 min | `sudo ./deploy_noctis_production.sh` |
| Verify | 3 min | `sudo /usr/local/bin/noctis-status.sh` |
| **Total** | **35 min** | **Complete autonomous deployment** |

---

**🎯 DEPLOYMENT SUCCESS = All services active + Web access working + Docker running**

*Keep this reference handy during deployment* 📋