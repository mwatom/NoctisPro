# 🚀 NoctisPro Complete Auto-Deployment for Windows Server 2019

## ⚡ ONE-CLICK DEPLOYMENT

**Everything automated - from fresh Windows Server 2019 to universal HTTPS access!**

### 🎯 What Gets Deployed Automatically:

✅ **Python 3.11** - Auto-downloaded and installed  
✅ **PostgreSQL 17** - Auto-configured with NoctisPro database  
✅ **Redis Cache** - Auto-installed and configured  
✅ **DICOM SCP Receiver** - Global reception with AE title "MAE"  
✅ **Universal HTTPS** - Secure tunnel accessible from anywhere  
✅ **Windows Services** - Auto-start on boot  
✅ **Admin User** - Pre-configured with secure credentials  
✅ **Firewall Rules** - Auto-configured for internet access  

---

## 🚀 DEPLOYMENT STEPS

### Option 1: Ultimate One-Click (Recommended)
```
1. Copy NoctisPro files to Windows Server 2019
2. Right-click: DEPLOY_EVERYTHING_AUTO.bat
3. Select: "Run as administrator"
4. Wait 10-15 minutes
5. Get your universal HTTPS URL!
```

### Option 2: PowerShell Direct
```powershell
# Run as Administrator
.\FULL_AUTO_DEPLOY_WINDOWS2019.ps1 -AETitle "MAE"
```

### Option 3: Check Readiness First
```powershell
# Verify system is ready
.\CHECK_WINDOWS2019_READY.ps1

# Then deploy
.\DEPLOY_EVERYTHING_AUTO.bat
```

---

## 🌐 AFTER DEPLOYMENT

### Your System URLs:
- **🌍 Universal HTTPS**: `https://[random-string].trycloudflare.com`
- **💻 Local Access**: `http://localhost:8000`
- **📱 Admin Panel**: `https://[tunnel-url]/admin`

### DICOM Reception:
- **📡 Global Host**: `[YOUR-PUBLIC-IP]:11112`
- **🏷️ AE Title**: `MAE` (set during facility registration)
- **🌍 Reception**: From anywhere on the internet

### Admin Access:
- **👤 Username**: `admin`
- **🔑 Password**: Auto-generated (displayed during deployment)

---

## 🏥 FACILITY REGISTRATION WITH AE TITLE "MAE"

1. **Access admin panel** via your HTTPS URL
2. **Login** with admin credentials
3. **Create facility** in admin interface
4. **Set AE Title to "MAE"** during registration
5. **DICOM devices** can now send to your system using AE title "MAE"

---

## 🔧 WHAT HAPPENS AUTOMATICALLY

### Pre-Installation:
- ✅ Checks administrator privileges
- ✅ Verifies Windows Server 2019 compatibility
- ✅ Tests internet connectivity
- ✅ Configures PowerShell execution policy

### Installation Phase:
- ✅ Downloads and installs Python 3.11
- ✅ Downloads and installs PostgreSQL 17
- ✅ Downloads and installs Redis
- ✅ Creates virtual environment
- ✅ Installs all Python dependencies
- ✅ Configures PostgreSQL 17 database

### Configuration Phase:
- ✅ Creates NoctisPro database and user
- ✅ Runs Django migrations
- ✅ Creates admin user with secure password
- ✅ Configures environment variables
- ✅ Sets up Windows Firewall rules

### Service Setup:
- ✅ Downloads Cloudflare tunnel
- ✅ Downloads NSSM service manager
- ✅ Creates Windows services for auto-start
- ✅ Configures service dependencies

### Launch Phase:
- ✅ Starts all services
- ✅ Establishes universal HTTPS tunnel
- ✅ Displays your secure HTTPS URL
- ✅ Opens local web interface

---

## 🛡️ SECURITY FEATURES

- 🔒 **Auto-generated secure passwords**
- 🔥 **Windows Firewall auto-configuration**
- 🌐 **HTTPS-only access via secure tunnel**
- 👤 **Role-based access control**
- 🏥 **Facility isolation via AE titles**
- 📊 **Comprehensive audit logging**

---

## 🎯 ESTIMATED DEPLOYMENT TIME

- **Fresh Windows Server 2019**: 15-20 minutes
- **With Python 3 installed**: 10-15 minutes  
- **With PostgreSQL 17 installed**: 8-12 minutes
- **Full system ready**: 5-8 minutes

---

## 🆘 TROUBLESHOOTING

### If Deployment Fails:
1. **Check internet connection**
2. **Run as Administrator**
3. **Ensure 10GB+ free disk space**
4. **Run**: `.\CHECK_WINDOWS2019_READY.ps1`

### If Services Don't Start:
1. **Reboot the server**
2. **Run**: `START_NOCTISPRO_AUTO.bat`
3. **Check**: Windows Services console

### If HTTPS URL Doesn't Appear:
1. **Wait 2-3 minutes** for tunnel establishment
2. **Check tunnel window** for URL
3. **Restart tunnel**: Run `start_https_tunnel.bat`

---

## 📞 SUPPORT

- **📧 Email**: admin@noctispro.com
- **📖 Documentation**: See deployment guides
- **🐛 Issues**: Create GitHub issue

---

## 🎉 SUCCESS INDICATORS

When deployment is complete, you'll see:

1. **✅ Multiple command windows** running services
2. **✅ HTTPS URL** displayed in tunnel window
3. **✅ Web interface** accessible locally
4. **✅ Admin login** working
5. **✅ DICOM port** listening on 11112

**Your system is ready for global DICOM reception and universal HTTPS access!**