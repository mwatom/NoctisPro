# 🚀 Ubuntu Server Deployment - Refined NoctisPro System

## 📋 Complete Deployment Instructions

### 🎯 What This Deployment Gives You:
- ✅ **Complete refined masterpiece system** with ALL features
- ✅ **Production configuration** (DEBUG=False)
- ✅ **Auto-start on boot** via systemd service
- ✅ **Proper service management** with easy commands
- ✅ **Clean removal** of old conflicting services

## 🚀 Step 1: Deploy to Your Ubuntu Server

### Option A: Clone from Repository (Recommended)
```bash
# Clone the refined system to your server
git clone YOUR_REPO_URL /workspace/noctis_pro_deployment
cd /workspace/noctis_pro_deployment
```

### Option B: Copy Files Manually
```bash
# If you have the files, copy the entire noctis_pro_deployment directory to:
# /workspace/noctis_pro_deployment/
```

## 🛑 Step 2: Remove Old Services & Setup New

**Run this ONE command on your Ubuntu server:**
```bash
cd /workspace/noctis_pro_deployment
sudo ./remove_old_setup_new.sh
```

**This script will:**
1. 🛑 **Remove ALL old services** (systemd, init.d, cron, bashrc entries)
2. 🗑️ **Kill old processes** (Django, ngrok, tmux sessions)
3. 📦 **Install dependencies** for refined system
4. 🆕 **Create new systemd service** (`noctispro-refined`)
5. ⚙️ **Enable auto-start** on boot
6. 🧪 **Test the service** works correctly
7. 📋 **Create management commands**

## ✅ Step 3: Verify Deployment

**Check service status:**
```bash
./manage_service.sh status
```

**Access your system:**
- **Local**: http://localhost:8000/
- **Admin**: http://localhost:8000/admin/ (admin/admin123)
- **DICOM Viewer**: http://localhost:8000/dicom-viewer/

## 🌐 Step 4: Enable Online Access (Optional)

**Configure ngrok for internet access:**
```bash
# 1. Get free ngrok token
# Visit: https://dashboard.ngrok.com/get-started/your-authtoken

# 2. Configure token
/workspace/ngrok config add-authtoken YOUR_TOKEN_HERE

# 3. Restart service to enable tunnel
./manage_service.sh restart
```

**Your system will then be available at:**
- **Online**: https://colt-charmed-lark.ngrok-free.app/

## 📋 Service Management Commands

**Easy management script:**
```bash
cd /workspace/noctis_pro_deployment

# Check status and get access URLs
./manage_service.sh status

# Start service
./manage_service.sh start

# Stop service  
./manage_service.sh stop

# Restart service
./manage_service.sh restart

# View real-time logs
./manage_service.sh logs

# Enable auto-start on boot
./manage_service.sh enable

# Disable auto-start on boot
./manage_service.sh disable
```

**Direct systemd commands:**
```bash
# Service status
sudo systemctl status noctispro-refined

# Start/stop/restart
sudo systemctl start noctispro-refined
sudo systemctl stop noctispro-refined
sudo systemctl restart noctispro-refined

# Enable/disable auto-start
sudo systemctl enable noctispro-refined
sudo systemctl disable noctispro-refined

# View logs
sudo journalctl -u noctispro-refined -f
```

## 🔧 Troubleshooting

**If service fails to start:**
```bash
# Check logs
sudo journalctl -u noctispro-refined --no-pager -n 50

# Check service file
cat /etc/systemd/system/noctispro-refined.service

# Manual start for debugging
cd /workspace/noctis_pro_deployment
source venv/bin/activate
python manage.py runserver 0.0.0.0:8000
```

**If old services interfere:**
```bash
# Force remove any remaining old services
sudo systemctl list-units | grep noctis
sudo rm -f /etc/systemd/system/noctispro*
sudo systemctl daemon-reload
```

## 🎯 What You Get After Deployment:

### ✅ **Complete Masterpiece Features:**
- 🏥 **DICOM Viewer** - Professional medical imaging interface
- 📋 **Worklist** - Study management and PACS integration
- 🤖 **AI Analysis** - Pathology detection and auto-measurements
- 📊 **Reports** - Generate professional medical reports
- 💬 **Chat System** - Secure communication
- 🔔 **Notifications** - Real-time alerts
- 👨‍💼 **Admin Panel** - System management interface

### 🛡️ **Production Ready:**
- 🔒 **Security** - DEBUG=False, secure settings
- 🚀 **Performance** - Optimized dependencies
- 🔄 **Reliability** - Auto-restart on failure
- 📈 **Monitoring** - Comprehensive logging
- ⚡ **Auto-Start** - Boots with server

## 🎊 Final Result:

After running the deployment script, you'll have:
- ❌ **Old system completely removed** (no conflicts)
- ✅ **New refined system running** from `/workspace/noctis_pro_deployment/`
- ✅ **Auto-start configured** (survives reboots)
- ✅ **Easy management** with simple commands
- ✅ **Production ready** configuration

**Your refined masterpiece medical imaging system will be running 24/7 with professional reliability!**