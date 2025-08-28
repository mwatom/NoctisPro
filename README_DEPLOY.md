# 🚀 NoctisPro - Post Git Clone Deployment

## 📥 After Git Clone - Single Command Setup

**Copy and paste this ONE command after cloning the repository:**

```bash
sudo /workspace/quick_deploy.sh
```

## 🎯 Complete Workflow:

```bash
# 1. Clone the repository (replace with your actual repo URL)
git clone https://github.com/your-username/noctispro.git
cd noctispro

# 2. Run the single deployment command
sudo /workspace/quick_deploy.sh

# 3. Configure ngrok auth token (get from https://dashboard.ngrok.com)
ngrok config add-authtoken YOUR_AUTH_TOKEN_HERE

# 4. Start the application
./start_production.sh
```

## 🌐 Instant Access After Deployment:

- **🏥 Main Application**: https://colt-charmed-lark.ngrok-free.app
- **🔧 Admin Panel**: https://colt-charmed-lark.ngrok-free.app/admin/
- **📱 DICOM Viewer**: https://colt-charmed-lark.ngrok-free.app/dicom-viewer/
- **📋 Worklist Management**: https://colt-charmed-lark.ngrok-free.app/worklist/

## 🔑 Default Credentials:

- **Username**: `admin`
- **Password**: `admin123`

## 📱 Management Commands:

```bash
# Start all services
./start_production.sh

# Stop all services  
./stop_production.sh

# Check system status
./check_status.sh

# View live logs
sudo journalctl -u noctispro-production.service -f

# Restart services
sudo systemctl restart noctispro-production.service
```

## ✨ What The Deployment Script Does:

1. ✅ **Installs ngrok** and all system dependencies
2. ✅ **Creates Python virtual environment** with required packages
3. ✅ **Configures production environment** with security settings
4. ✅ **Sets up static ngrok URL** (`colt-charmed-lark.ngrok-free.app`)
5. ✅ **Runs Django migrations** and creates database
6. ✅ **Creates admin user** (admin/admin123)
7. ✅ **Sets up systemd service** for auto-startup on boot
8. ✅ **Creates management scripts** for easy control
9. ✅ **Production-ready configuration** with health checks

## 🔧 System Requirements:

- Ubuntu 18.04+ or Debian 10+
- 2GB RAM minimum (4GB recommended)
- 10GB disk space
- Internet connection
- Sudo privileges

## 🛡️ Production Features:

- ✅ **Auto-startup on boot** via systemd
- ✅ **Static ngrok URL** (never changes)
- ✅ **Production security settings**
- ✅ **SQLite database** (ready for PostgreSQL upgrade)
- ✅ **Health monitoring** and logging
- ✅ **Automatic restart** on failure
- ✅ **DICOM file processing**
- ✅ **Medical imaging workflow**

## 🔗 Static URL Configuration:

The deployment uses your **existing static URL from previous charts**:
- **URL**: `colt-charmed-lark.ngrok-free.app`
- **Region**: US
- **Always the same** - bookmarkable!

## 📞 Support & Troubleshooting:

### If services don't start:
```bash
sudo systemctl status noctispro-production.service
sudo journalctl -u noctispro-production.service -n 50
```

### If ngrok tunnel fails:
```bash
# Check ngrok auth
ngrok config check

# Add auth token
ngrok config add-authtoken YOUR_TOKEN
```

### Reset everything:
```bash
./stop_production.sh
sudo systemctl disable noctispro-production.service
sudo rm /etc/systemd/system/noctispro-production.service
sudo systemctl daemon-reload
```

## 🎉 You're Done!

Your **NoctisPro medical imaging platform** is now running in production with:

- 🌐 **Persistent static URL**
- 🔄 **Automatic boot startup**
- 🛡️ **Production security**
- 📱 **Complete DICOM workflow**
- 🏥 **Medical imaging tools**

**Access your application at**: https://colt-charmed-lark.ngrok-free.app

---

*Need help? Check the logs or restart the services using the provided commands above.*