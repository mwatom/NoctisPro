# 🚀 Deploy NoctisPro PACS to Your Ubuntu 22.04 Server

## ✨ One Command Deployment + FREE Public URLs!

**No domain needed! Get instant public HTTPS URLs with Cloudflare tunnels!**

## 🔥 Super Simple Deployment

### Method 1: Git Clone (Recommended)
```bash
# On your Ubuntu 22.04 server:
git clone <YOUR_REPOSITORY_URL> noctis-pro
cd noctis-pro
sudo ./deploy-ubuntu-server.sh
```

### Method 2: Manual Upload
```bash
# Upload files to your server, then:
cd noctis-pro
sudo ./deploy-ubuntu-server.sh
```

### Method 3: One-Liner (if you have the files)
```bash
sudo bash deploy-ubuntu-server.sh
```

## ⏱️ What Happens (5-10 minutes)

1. **System Setup** - Installs all dependencies
2. **Database** - Creates PostgreSQL database  
3. **Redis** - Sets up caching
4. **Python** - Creates virtual environment
5. **Django** - Runs migrations, creates admin user
6. **Services** - Creates systemd services
7. **Nginx** - Sets up reverse proxy
8. **Firewall** - Configures security
9. **🌐 FREE Public URLs** - Creates Cloudflare tunnels
10. **✅ Done!** - Your system is live!

## 🎯 You Get

### ✨ FREE Public URLs (No Domain Required!)
- **Web App**: `https://random-name.trycloudflare.com`
- **Admin**: `https://random-name.trycloudflare.com/admin/`
- **DICOM**: `https://random-name.trycloudflare.com` (port 11112)

### 🔐 Login Details
- **Username**: `admin`
- **Password**: `NoctisAdmin2024!`

### 🏥 DICOM Ready
- **Port**: `11112`
- **AET**: `NOCTIS_SCP`
- **Supports**: CT, MRI, X-Ray, Ultrasound, etc.

## 📋 Requirements

- **Server**: Ubuntu 22.04 LTS
- **RAM**: 2GB minimum (4GB+ recommended)
- **Storage**: 20GB+ free space
- **Network**: Internet connection
- **Access**: SSH with sudo privileges

## 🚨 Important Notes

### Security
- **Change password immediately** after first login
- **Firewall enabled** - only necessary ports open
- **HTTPS automatic** with Cloudflare tunnels

### Public URLs
- **Completely FREE** - no domain registration needed
- **HTTPS included** - secure by default  
- **May change** if tunnels restart (check logs)
- **No traffic limits** for normal use

### DICOM Integration
- Configure your medical devices to send to your public DICOM URL
- Or use server IP:11112 for local network access

## 🔧 After Deployment

### 1. Access Your System
Visit the public URL shown after deployment completes

### 2. Change Password
Login to `/admin/` and change the default password

### 3. Add DICOM Devices
Configure your medical equipment in the admin panel

### 4. Start Using
Upload DICOM files and start managing medical images!

## 📞 Support Commands

```bash
# Check if everything is running
sudo systemctl status noctis-web noctis-celery noctis-dicom

# View logs
sudo journalctl -u noctis-web -f

# Get your public URLs
cat /opt/noctis-pro/web_tunnel_url.txt
cat /opt/noctis-pro/dicom_tunnel_url.txt

# Restart if needed
sudo systemctl restart noctis-web noctis-celery noctis-dicom
```

## 🎉 That's It!

**One command gets you:**
- ✅ Full PACS system
- ✅ FREE public HTTPS URLs  
- ✅ Database & caching
- ✅ DICOM receiver
- ✅ Admin interface
- ✅ Automatic backups
- ✅ Production-ready setup

**No domain registration, no SSL certificates, no complex configuration needed!**

Your medical imaging system will be live in minutes! 🏥✨