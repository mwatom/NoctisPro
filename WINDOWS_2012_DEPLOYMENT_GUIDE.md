# NoctisPro Windows Server 2012 Deployment Guide

## 🎯 CRITICAL: This Guide Addresses Your Specific Issues

This guide specifically resolves:
1. ✅ **Super user login issues** - The most common cause and solutions
2. ✅ **Windows Server 2012 compatibility** - Tested deployment process  
3. ✅ **Worldwide internet access** - Using Cloudflare tunnels and alternatives

## 🚀 Quick Start (Recommended)

1. **Copy** the NoctisPro repository to `C:\noctis` on your Windows Server 2012
2. **Open PowerShell as Administrator**
3. **Run the deployment script:**

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
powershell -ExecutionPolicy Bypass -File C:\noctis\deploy_windows_2012.ps1
```

**That's it!** The script will automatically:
- Install Python 3.10 (Windows Server 2012 compatible)
- Fix the super user login issue
- Set up worldwide internet access
- Create all necessary startup scripts

## 📋 Prerequisites

### System Requirements
- **Windows Server 2012 or later**
- **4GB RAM minimum** (8GB+ recommended for production)
- **50GB free disk space** (100GB+ for DICOM storage)
- **Internet connection** for downloading dependencies
- **Administrator privileges**

### Network Requirements for Internet Access
- **Port 8000** - Main application (configurable)
- **Port 11112** - DICOM receiver (optional)
- **Outbound internet access** - For Cloudflare tunnel

## 🔧 Manual Installation (If Automatic Script Fails)

### Step 1: Install Python 3.10
```powershell
# Download Python 3.10.11 (Windows Server 2012 compatible)
$pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
Invoke-WebRequest -Uri $pythonUrl -OutFile "python-installer.exe"

# Install Python
.\python-installer.exe /quiet InstallAllUsers=1 PrependPath=1 Include_test=0

# Verify installation
python --version
```

### Step 2: Setup Application Environment
```powershell
cd C:\noctis

# Create virtual environment
python -m venv .venv

# Activate virtual environment
.\.venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements-windows.txt
# OR if that fails:
pip install Django djangorestframework Pillow numpy pydicom waitress
```

### Step 3: Database Setup
```powershell
# Run migrations
python manage.py migrate --noinput

# Collect static files
python manage.py collectstatic --noinput
```

### Step 4: Fix Super User Login Issue (CRITICAL)
```powershell
# Run the login fix script
python fix_login.py

# OR apply manual fix if script not available
python manage.py shell
```

In the Django shell, run:
```python
from accounts.models import User, Facility

# Create facility if needed
if not Facility.objects.exists():
    facility = Facility.objects.create(
        name='Default Medical Center',
        address='123 Healthcare Ave',
        phone='+1-555-0123',
        email='contact@medical.com',
        license_number='MC-2024-001',
        ae_title='NOCTISPRO'
    )

# Fix admin user
try:
    user = User.objects.get(username='admin')
except User.DoesNotExist:
    user = User.objects.create_user(username='admin')

# Apply critical fixes
user.set_password('Admin123!')
user.is_active = True
user.is_verified = True  # THIS IS THE KEY FIX
user.is_staff = True
user.is_superuser = True
user.role = 'admin'
user.facility = Facility.objects.first()
user.save()

print(f"Admin user fixed: {user.username}, Verified: {user.is_verified}")
```

## 🌐 Setting Up Worldwide Internet Access

### Option 1: Cloudflare Tunnel (Recommended - Free)

1. **Download Cloudflare Tunnel:**
```powershell
Invoke-WebRequest -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile "cloudflared.exe"
```

2. **Create tunnel startup script:**
```batch
@echo off
cd /d "C:\noctis"
cloudflared.exe tunnel --no-autoupdate --url http://127.0.0.1:8000
pause
```

3. **Start the tunnel:**
   - Run the script above
   - Look for output like: `https://random-string.trycloudflare.com`
   - This URL is accessible worldwide

### Option 2: Windows Server IIS Reverse Proxy

1. **Install IIS and Application Request Routing:**
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
# Download and install ARR from Microsoft
```

2. **Configure reverse proxy in IIS Manager:**
   - Create new site
   - Set up URL Rewrite rules to proxy to localhost:8000
   - Configure SSL certificate (Let's Encrypt or commercial)

### Option 3: Router Port Forwarding

1. **Configure your router to forward port 8000 to the server**
2. **Configure Windows Firewall:**
```powershell
netsh advfirewall firewall add rule name="NoctisPro" dir=in action=allow protocol=TCP localport=8000
```

3. **Access via your public IP:** `http://YOUR-PUBLIC-IP:8000`

## 🛡️ Security Configuration for Internet Access

### CRITICAL Security Steps

1. **Change Default Password Immediately:**
```powershell
python manage.py shell
```
```python
from accounts.models import User
user = User.objects.get(username='admin')
user.set_password('YOUR-STRONG-PASSWORD-HERE')
user.save()
```

2. **Configure Production Settings:**

Edit `noctis_pro/settings.py`:
```python
# Change this in production
DEBUG = False

# Set your domain
ALLOWED_HOSTS = ['your-domain.com', 'your-server-ip']

# Use a secure secret key
SECRET_KEY = 'your-unique-secret-key-here'

# Enable HTTPS redirects (if using SSL)
SECURE_SSL_REDIRECT = True
```

3. **Enable Windows Updates and Firewall:**
```powershell
# Configure automatic updates
sconfig

# Enable firewall with specific rules
netsh advfirewall set allprofiles state on
netsh advfirewall firewall add rule name="NoctisPro-HTTP" dir=in action=allow protocol=TCP localport=8000
```

4. **Create Regular Backups:**
```batch
@echo off
set BACKUP_DIR=C:\noctis_backups\%date:~-4,4%-%date:~-10,2%-%date:~-7,2%
mkdir "%BACKUP_DIR%"
copy "C:\noctis\db.sqlite3" "%BACKUP_DIR%\"
xcopy "C:\noctis\media" "%BACKUP_DIR%\media\" /E /I
```

## 🚀 Running the System

### Automatic Startup (Recommended)
```powershell
# Run the master startup script
C:\noctis\START_NOCTISPRO.bat
```

This will open two windows:
1. **Django Server** - The main application
2. **Cloudflare Tunnel** - For worldwide access

### Manual Startup
```powershell
# Terminal 1: Start Django server
cd C:\noctis
.\.venv\Scripts\Activate.ps1
waitress-serve --host=0.0.0.0 --port=8000 noctis_pro.wsgi:application

# Terminal 2: Start tunnel (optional)
cd C:\noctis
.\cloudflared.exe tunnel --no-autoupdate --url http://127.0.0.1:8000
```

### Windows Service Installation (For Production)

1. **Download NSSM (Non-Sucking Service Manager):**
   - Download from: https://nssm.cc/download
   - Extract `nssm.exe` to `C:\noctis\`

2. **Install as Windows Service:**
```powershell
cd C:\noctis
.\nssm install NoctisPro "C:\noctis\.venv\Scripts\waitress-serve.exe"
.\nssm set NoctisPro Arguments "--host=0.0.0.0 --port=8000 noctis_pro.wsgi:application"
.\nssm set NoctisPro AppDirectory "C:\noctis"
.\nssm set NoctisPro DisplayName "NoctisPro DICOM System"
.\nssm set NoctisPro Description "NoctisPro Medical Imaging System"
.\nssm start NoctisPro
```

## 🔍 Troubleshooting

### Login Issues

**Problem:** "Super user cannot login"

**Solutions:**
1. **Run the login fix script:**
```powershell
cd C:\noctis
python fix_login.py
```

2. **Check user verification status:**
```powershell
python manage.py shell
```
```python
from accounts.models import User
user = User.objects.get(username='admin')
print(f"Active: {user.is_active}, Verified: {user.is_verified}")
# Both should be True
```

3. **Manual user fix:**
```python
user.is_active = True
user.is_verified = True  # This is usually the issue
user.save()
```

### Python Installation Issues

**Problem:** Python not found or installation fails

**Solutions:**
1. **Manual download and install:**
   - Go to https://www.python.org/downloads/
   - Download Python 3.10.11 for Windows x64
   - Run with Administrator privileges

2. **Add to PATH manually:**
```powershell
$env:PATH += ";C:\Program Files\Python310;C:\Program Files\Python310\Scripts"
```

### Internet Access Issues

**Problem:** Cannot access from outside

**Solutions:**
1. **Check Windows Firewall:**
```powershell
netsh advfirewall firewall show rule name="NoctisPro-HTTP"
```

2. **Verify tunnel is running:**
   - Check tunnel window for HTTPS URL
   - Look for: `https://xxx.trycloudflare.com`

3. **Test local access first:**
   - http://localhost:8000
   - http://127.0.0.1:8000

### Database Migration Issues

**Problem:** Migration fails

**Solutions:**
1. **Delete existing database and recreate:**
```powershell
del db.sqlite3
python manage.py migrate
python fix_login.py
```

2. **Check for template syntax errors:**
```powershell
python manage.py check --deploy
```

## 📱 Accessing the System

### Local Access URLs
- http://localhost:8000
- http://127.0.0.1:8000
- http://[SERVER-IP]:8000

### Internet Access URLs
- **Cloudflare Tunnel:** https://random-string.trycloudflare.com
- **Direct IP:** http://[YOUR-PUBLIC-IP]:8000
- **Custom Domain:** http://your-domain.com (with proper DNS setup)

### Default Login Credentials
- **Username:** admin
- **Password:** Admin123!

**⚠️ IMPORTANT:** Change the password immediately after first login!

## 🎯 System Features

### DICOM Medical Imaging
- DICOM file upload and viewing
- Multi-planar reconstruction (MPR)
- Window/Level adjustments
- Measurements and annotations
- DICOM metadata display

### User Management
- Role-based access control
- Admin, Radiologist, and Facility user roles
- User verification system
- Session management

### Facility Management
- Multi-facility support
- Facility-specific user assignments
- Custom letterheads and branding

### Reports and Analysis
- Study reports
- AI analysis integration
- Export capabilities

## 📞 Support and Maintenance

### Log Files
- **Application logs:** `C:\noctis\noctis_pro.log`
- **Django errors:** Check command window output
- **Tunnel logs:** Check tunnel command window

### Regular Maintenance
1. **Update Python packages monthly:**
```powershell
cd C:\noctis
.\.venv\Scripts\Activate.ps1
pip install --upgrade -r requirements-windows.txt
```

2. **Backup database weekly:**
```powershell
copy C:\noctis\db.sqlite3 C:\noctis_backups\db-backup-%date%.sqlite3
```

3. **Monitor disk space for DICOM files**

### Getting Help
1. Check the troubleshooting section above
2. Review log files for error messages
3. Test with a fresh installation if issues persist

---

## ✅ Quick Reference

**Start System:** Double-click `START_NOCTISPRO.bat`
**Fix Login:** Run `python fix_login.py`
**Admin Login:** admin / Admin123!
**Local URL:** http://localhost:8000
**Tunnel URL:** Check tunnel window output

**🎉 Your NoctisPro system should now be fully deployed and accessible worldwide!**