# NoctisPro DICOM System - Windows Server 2019 Installation Guide with PostgreSQL

## 🎯 Complete Step-by-Step Installation for Universal HTTPS Access

This guide will take you from a fresh Windows Server 2019 installation to a fully functional DICOM PACS system accessible via HTTPS from anywhere on the internet, using PostgreSQL as the database backend.

---

## 📋 Prerequisites

### System Requirements
- **Windows Server 2019** (Standard or Datacenter)
- **4 GB RAM minimum** (8 GB recommended)
- **50 GB free disk space** (100 GB+ for production)
- **Internet connection** (for downloads and tunnel access)
- **Administrator privileges**

### Network Requirements
- **Port 8000** - Web interface (internal)
- **Port 11112** - DICOM SCP receiver (external)
- **Port 5432** - PostgreSQL (internal)
- **Port 6379** - Redis (internal)

---

## 🚀 Step-by-Step Installation

### Step 1: Prepare Windows Server 2019

#### 1.1 Enable Required Windows Features
```powershell
# Open PowerShell as Administrator
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
Enable-WindowsOptionalFeature -Online -FeatureName IIS-CommonHttpFeatures
Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpErrors
Enable-WindowsOptionalFeature -Online -FeatureName IIS-HttpLogging
Enable-WindowsOptionalFeature -Online -FeatureName IIS-RequestFiltering
Enable-WindowsOptionalFeature -Online -FeatureName IIS-StaticContent
```

#### 1.2 Configure Windows Firewall
```powershell
# Allow required ports through Windows Firewall
New-NetFirewallRule -DisplayName "NoctisPro Web" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
New-NetFirewallRule -DisplayName "NoctisPro DICOM" -Direction Inbound -Protocol TCP -LocalPort 11112 -Action Allow
New-NetFirewallRule -DisplayName "PostgreSQL" -Direction Inbound -Protocol TCP -LocalPort 5432 -Action Allow
New-NetFirewallRule -DisplayName "Redis" -Direction Inbound -Protocol TCP -LocalPort 6379 -Action Allow
```

### Step 2: Install PostgreSQL Database

#### 2.1 Download and Install PostgreSQL
1. **Download PostgreSQL 15** from https://www.postgresql.org/download/windows/
2. **Run the installer** as Administrator
3. **Installation Settings**:
   - Installation Directory: `C:\Program Files\PostgreSQL\15`
   - Data Directory: `C:\Program Files\PostgreSQL\15\data`
   - Port: `5432`
   - Superuser Password: `Create a strong password` (save this!)
   - Locale: `Default locale`

#### 2.2 Configure PostgreSQL for NoctisPro
```powershell
# Open PostgreSQL Command Line (psql)
# Navigate to: Start Menu > PostgreSQL 15 > SQL Shell (psql)
# Or run from command line:
cd "C:\Program Files\PostgreSQL\15\bin"
.\psql.exe -U postgres
```

```sql
-- Create NoctisPro database and user
CREATE DATABASE noctispro;
CREATE USER noctispro_user WITH PASSWORD 'NoctisPro2024!';
GRANT ALL PRIVILEGES ON DATABASE noctispro TO noctispro_user;
ALTER USER noctispro_user CREATEDB;
\q
```

#### 2.3 Configure PostgreSQL Service
```powershell
# Ensure PostgreSQL starts automatically
Set-Service -Name postgresql-x64-15 -StartupType Automatic
Start-Service -Name postgresql-x64-15
```

### Step 3: Install Python and Dependencies

#### 3.1 Install Python 3.11
1. **Download Python 3.11** from https://www.python.org/downloads/windows/
2. **Run installer** with these options:
   - ✅ Add Python to PATH
   - ✅ Install for all users
   - ✅ Install pip
   - Installation path: `C:\Python311`

#### 3.2 Verify Python Installation
```powershell
# Open new PowerShell as Administrator
python --version
pip --version
```

### Step 4: Install Redis

#### 4.1 Download and Install Redis
1. **Download Redis for Windows** from https://github.com/microsoftarchive/redis/releases
2. **Extract to**: `C:\Redis`
3. **Install as Windows Service**:

```powershell
cd C:\Redis
.\redis-server.exe --service-install --service-name Redis --port 6379
.\redis-server.exe --service-start
```

#### 4.2 Configure Redis Service
```powershell
# Set Redis to start automatically
Set-Service -Name Redis -StartupType Automatic
Start-Service -Name Redis
```

### Step 5: Install and Configure NoctisPro

#### 5.1 Copy NoctisPro Files
1. **Create installation directory**:
```powershell
New-Item -ItemType Directory -Path "C:\noctis" -Force
```

2. **Copy all NoctisPro files** to `C:\noctis`
   - Extract/copy the entire NoctisPro project to this directory
   - Ensure `manage.py` is in `C:\noctis\manage.py`

#### 5.2 Install Python Dependencies
```powershell
cd C:\noctis

# Create virtual environment
python -m venv .venv

# Activate virtual environment
.\.venv\Scripts\activate.bat

# Upgrade pip
python -m pip install --upgrade pip

# Install PostgreSQL adapter
pip install psycopg2-binary

# Install Windows-specific requirements
pip install -r requirements-windows.txt
```

#### 5.3 Configure Environment Variables
Create `C:\noctis\.env` file:

```env
# Database Configuration
DB_ENGINE=django.db.backends.postgresql
DB_NAME=noctispro
DB_USER=noctispro_user
DB_PASSWORD=NoctisPro2024!
DB_HOST=localhost
DB_PORT=5432

# Django Configuration
SECRET_KEY=your-super-secret-key-here-change-this-in-production
DEBUG=False
ALLOWED_HOSTS=*

# Redis Configuration
REDIS_URL=redis://localhost:6379/0

# DICOM Configuration
DICOM_AE_TITLE=NOCTISPRO
DICOM_PORT=11112

# Production Settings
ENVIRONMENT=production
```

#### 5.4 Initialize Database
```powershell
cd C:\noctis
.\.venv\Scripts\activate.bat

# Run database migrations
python manage.py makemigrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser --username admin --email admin@noctispro.com

# Collect static files
python manage.py collectstatic --noinput
```

### Step 6: Install Cloudflare Tunnel

#### 6.1 Download Cloudflare Tunnel
```powershell
# Download cloudflared for Windows
Invoke-WebRequest -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile "C:\noctis\cloudflared.exe"
```

#### 6.2 Create Tunnel Configuration
Create `C:\noctis\tunnel.yml`:

```yaml
tunnel: noctispro-tunnel
credentials-file: C:\noctis\tunnel-credentials.json

ingress:
  - hostname: "*.trycloudflare.com"
    service: http://localhost:8000
  - service: http_status:404
```

### Step 7: Create Windows Services

#### 7.1 Install NSSM (Non-Sucking Service Manager)
```powershell
# Download NSSM
Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile "C:\nssm.zip"
Expand-Archive -Path "C:\nssm.zip" -DestinationPath "C:\"
Copy-Item "C:\nssm-2.24\win64\nssm.exe" -Destination "C:\Windows\System32\"
```

#### 7.2 Create NoctisPro Django Service
```powershell
# Create Django service
nssm install "NoctisPro-Django" "C:\noctis\.venv\Scripts\python.exe"
nssm set "NoctisPro-Django" AppParameters "manage.py runserver 0.0.0.0:8000"
nssm set "NoctisPro-Django" AppDirectory "C:\noctis"
nssm set "NoctisPro-Django" DisplayName "NoctisPro Django Web Server"
nssm set "NoctisPro-Django" Description "NoctisPro DICOM PACS Web Interface"
nssm set "NoctisPro-Django" Start SERVICE_AUTO_START
```

#### 7.3 Create Celery Worker Service
```powershell
# Create Celery service
nssm install "NoctisPro-Celery" "C:\noctis\.venv\Scripts\python.exe"
nssm set "NoctisPro-Celery" AppParameters "-m celery -A noctis_pro worker --loglevel=info"
nssm set "NoctisPro-Celery" AppDirectory "C:\noctis"
nssm set "NoctisPro-Celery" DisplayName "NoctisPro Celery Worker"
nssm set "NoctisPro-Celery" Description "NoctisPro Background Task Worker"
nssm set "NoctisPro-Celery" Start SERVICE_AUTO_START
```

#### 7.4 Create DICOM SCP Service
```powershell
# Create DICOM SCP service
nssm install "NoctisPro-DICOM" "C:\noctis\.venv\Scripts\python.exe"
nssm set "NoctisPro-DICOM" AppParameters "dicom_receiver.py"
nssm set "NoctisPro-DICOM" AppDirectory "C:\noctis"
nssm set "NoctisPro-DICOM" DisplayName "NoctisPro DICOM SCP Receiver"
nssm set "NoctisPro-DICOM" Description "NoctisPro DICOM Image Receiver"
nssm set "NoctisPro-DICOM" Start SERVICE_AUTO_START
```

#### 7.5 Create Cloudflare Tunnel Service
```powershell
# Create Cloudflare tunnel service
nssm install "NoctisPro-Tunnel" "C:\noctis\cloudflared.exe"
nssm set "NoctisPro-Tunnel" AppParameters "tunnel --url http://localhost:8000"
nssm set "NoctisPro-Tunnel" AppDirectory "C:\noctis"
nssm set "NoctisPro-Tunnel" DisplayName "NoctisPro HTTPS Tunnel"
nssm set "NoctisPro-Tunnel" Description "NoctisPro Universal HTTPS Access Tunnel"
nssm set "NoctisPro-Tunnel" Start SERVICE_AUTO_START
```

### Step 8: Configure Security and Hardening

#### 8.1 Set File Permissions
```powershell
# Set secure permissions on NoctisPro directory
icacls "C:\noctis" /grant "Administrators:(OI)(CI)F" /T
icacls "C:\noctis" /grant "SYSTEM:(OI)(CI)F" /T
icacls "C:\noctis" /remove "Users" /T
icacls "C:\noctis" /remove "Everyone" /T

# Protect sensitive files
icacls "C:\noctis\.env" /grant "Administrators:F" /inheritance:r
icacls "C:\noctis\db.sqlite3" /grant "Administrators:F" /inheritance:r
```

#### 8.2 Configure Windows Defender Exclusions
```powershell
# Add Windows Defender exclusions for performance
Add-MpPreference -ExclusionPath "C:\noctis"
Add-MpPreference -ExclusionPath "C:\Program Files\PostgreSQL"
Add-MpPreference -ExclusionProcess "python.exe"
Add-MpPreference -ExclusionProcess "postgres.exe"
Add-MpPreference -ExclusionProcess "cloudflared.exe"
```

### Step 9: Start All Services

#### 9.1 Start Services in Order
```powershell
# Start PostgreSQL (should already be running)
Start-Service -Name postgresql-x64-15

# Start Redis
Start-Service -Name Redis

# Start NoctisPro services
Start-Service -Name "NoctisPro-Django"
Start-Service -Name "NoctisPro-Celery" 
Start-Service -Name "NoctisPro-DICOM"
Start-Service -Name "NoctisPro-Tunnel"
```

#### 9.2 Verify Services
```powershell
# Check service status
Get-Service -Name "postgresql-x64-15", "Redis", "NoctisPro-*"

# Check if ports are listening
netstat -an | findstr ":8000"
netstat -an | findstr ":11112"
netstat -an | findstr ":5432"
netstat -an | findstr ":6379"
```

### Step 10: Get Your Universal HTTPS URL

#### 10.1 Find Your Cloudflare Tunnel URL
```powershell
# Check tunnel logs to get your URL
Get-EventLog -LogName Application -Source "NoctisPro-Tunnel" -Newest 10

# Or check tunnel output directly
nssm status "NoctisPro-Tunnel"
```

The tunnel will provide a URL like: `https://random-string.trycloudflare.com`

#### 10.2 Alternative: Check Tunnel Output
1. **Open Services**: `services.msc`
2. **Find**: "NoctisPro HTTPS Tunnel"
3. **Right-click** → Properties → Recovery → View logs
4. **Look for**: URL starting with `https://`

---

## 🔧 Management and Monitoring

### Daily Operations

#### Start System
```batch
# Create C:\noctis\START_NOCTISPRO.bat
@echo off
echo Starting NoctisPro DICOM System...
net start "NoctisPro-Django"
net start "NoctisPro-Celery"
net start "NoctisPro-DICOM"
net start "NoctisPro-Tunnel"
echo System started successfully!
pause
```

#### Stop System
```batch
# Create C:\noctis\STOP_NOCTISPRO.bat
@echo off
echo Stopping NoctisPro DICOM System...
net stop "NoctisPro-Tunnel"
net stop "NoctisPro-DICOM"
net stop "NoctisPro-Celery"
net stop "NoctisPro-Django"
echo System stopped successfully!
pause
```

#### Check System Status
```batch
# Create C:\noctis\STATUS_NOCTISPRO.bat
@echo off
echo NoctisPro System Status:
echo ========================
sc query "postgresql-x64-15"
sc query "Redis"
sc query "NoctisPro-Django"
sc query "NoctisPro-Celery"
sc query "NoctisPro-DICOM"
sc query "NoctisPro-Tunnel"
pause
```

### Backup Script
```batch
# Create C:\noctis\BACKUP_NOCTISPRO.bat
@echo off
set BACKUP_DIR=C:\noctis_backups\%date:~-4,4%-%date:~-10,2%-%date:~-7,2%
mkdir "%BACKUP_DIR%"

echo Creating PostgreSQL backup...
"C:\Program Files\PostgreSQL\15\bin\pg_dump.exe" -U noctispro_user -h localhost noctispro > "%BACKUP_DIR%\noctispro_db.sql"

echo Creating media files backup...
xcopy "C:\noctis\media" "%BACKUP_DIR%\media\" /E /I /Y

echo Backup completed: %BACKUP_DIR%
pause
```

---

## 🌐 Universal Access Configuration

### Your System URLs

After installation, your system will be accessible via:

1. **Local Access**: `http://localhost:8000`
2. **Universal HTTPS**: `https://random-string.trycloudflare.com` (check tunnel logs)
3. **DICOM SCP**: `[YOUR-PUBLIC-IP]:11112` with AE Title: `NOCTISPRO`

### DICOM Device Configuration

To send DICOM images to your system from any modality:

```
DICOM Settings:
- Host: [Your Server's Public IP]
- Port: 11112
- AE Title: NOCTISPRO
- Protocol: DICOM C-STORE
```

---

## 🛡️ Security Hardening

### Step 11: Production Security

#### 11.1 Update Environment Variables
Edit `C:\noctis\.env`:

```env
# Generate a new secret key
SECRET_KEY=your-new-super-secret-key-minimum-50-characters-long
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1,*.trycloudflare.com

# Database with strong password
DB_PASSWORD=YourStrongDatabasePassword2024!

# Additional security
SECURE_SSL_REDIRECT=True
SECURE_BROWSER_XSS_FILTER=True
SECURE_CONTENT_TYPE_NOSNIFF=True
```

#### 11.2 Configure HTTPS Redirect
```powershell
# Update Django settings for HTTPS
cd C:\noctis
.\.venv\Scripts\activate.bat
python manage.py shell
```

```python
# In Django shell
from django.conf import settings
# Verify HTTPS settings are applied
exit()
```

#### 11.3 Set Up SSL Certificate (Optional)
For custom domain with proper SSL:

```powershell
# Install Certbot for Windows
# Download from: https://certbot.eff.org/instructions?ws=other&os=windows
# Follow domain verification process
```

---

## 🧪 Testing and Validation

### Step 12: Comprehensive Testing

#### 12.1 Run System Validation
```powershell
cd C:\noctis
.\.venv\Scripts\activate.bat

# Run comprehensive tests
python validate_all_buttons.py

# Run Windows-specific tests
powershell -ExecutionPolicy Bypass -File "test_all_buttons_windows.ps1"
```

#### 12.2 Test DICOM Reception
```powershell
# Test DICOM echo (C-ECHO)
cd C:\noctis
.\.venv\Scripts\activate.bat
python -c "
from pynetdicom import AE
from pynetdicom.sop_class import Verification
ae = AE()
ae.add_requested_context(Verification)
assoc = ae.associate('localhost', 11112, ae_title='NOCTISPRO')
if assoc.is_established:
    print('✅ DICOM SCP is responding')
    assoc.release()
else:
    print('❌ DICOM SCP connection failed')
"
```

#### 12.3 Test Web Interface
1. **Open browser** to `http://localhost:8000`
2. **Login** with admin credentials
3. **Test all major functions**:
   - Patient list
   - DICOM upload
   - Image viewer
   - Reports generation

---

## 🚀 Final Deployment Steps

### Step 13: Create Desktop Shortcuts

#### 13.1 NoctisPro Launcher Shortcut
Create `C:\Users\Public\Desktop\NoctisPro DICOM System.lnk`:
- Target: `C:\noctis\START_NOCTISPRO.bat`
- Icon: Choose appropriate icon

#### 13.2 System Monitor Shortcut
Create `C:\Users\Public\Desktop\NoctisPro Status.lnk`:
- Target: `C:\noctis\STATUS_NOCTISPRO.bat`

### Step 14: Get Your Universal HTTPS URL

#### 14.1 Find Tunnel URL
```powershell
# Method 1: Check service logs
Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='NoctisPro-Tunnel'} -MaxEvents 5

# Method 2: Run tunnel manually to see URL
cd C:\noctis
.\cloudflared.exe tunnel --url http://localhost:8000
# Look for output like: "https://abc-def-123.trycloudflare.com"
```

#### 14.2 Document Your URLs
Create `C:\noctis\ACCESS_URLS.txt`:

```
NoctisPro DICOM System Access Information
========================================

Local Access:
- Web Interface: http://localhost:8000
- Admin Panel: http://localhost:8000/admin

Universal HTTPS Access:
- Public URL: https://[your-tunnel-url].trycloudflare.com
- Admin Panel: https://[your-tunnel-url].trycloudflare.com/admin

DICOM Reception:
- Host: [Your Server Public IP]
- Port: 11112
- AE Title: NOCTISPRO

Database Access:
- PostgreSQL: localhost:5432
- Database: noctispro
- User: noctispro_user

Admin Credentials:
- Username: admin
- Password: [set during installation]

Last Updated: [Current Date]
```

---

## 🎯 Post-Installation Checklist

### ✅ Verification Steps

1. **Services Running**:
   - [ ] PostgreSQL Service
   - [ ] Redis Service  
   - [ ] NoctisPro-Django Service
   - [ ] NoctisPro-Celery Service
   - [ ] NoctisPro-DICOM Service
   - [ ] NoctisPro-Tunnel Service

2. **Network Access**:
   - [ ] Local web access: `http://localhost:8000`
   - [ ] Universal HTTPS access: `https://[tunnel-url].trycloudflare.com`
   - [ ] DICOM port open: `[public-ip]:11112`

3. **Database Connection**:
   - [ ] PostgreSQL accessible
   - [ ] Django migrations applied
   - [ ] Admin user created

4. **Security**:
   - [ ] Firewall rules configured
   - [ ] File permissions set
   - [ ] Strong passwords used
   - [ ] Debug mode disabled

5. **Functionality**:
   - [ ] Web interface loads
   - [ ] Admin panel accessible
   - [ ] DICOM receiver responding
   - [ ] File uploads working

---

## 🆘 Troubleshooting

### Common Issues and Solutions

#### Database Connection Issues
```powershell
# Test PostgreSQL connection
cd "C:\Program Files\PostgreSQL\15\bin"
.\psql.exe -U noctispro_user -h localhost -d noctispro
```

#### Service Start Failures
```powershell
# Check service logs
Get-EventLog -LogName Application -Source "NoctisPro-Django" -Newest 10
```

#### Tunnel Connection Issues
```powershell
# Test tunnel manually
cd C:\noctis
.\cloudflared.exe tunnel --url http://localhost:8000
```

#### Port Conflicts
```powershell
# Check what's using ports
netstat -ano | findstr ":8000"
netstat -ano | findstr ":11112"
```

---

## 📞 Support and Maintenance

### Regular Maintenance Tasks

1. **Weekly**:
   - Check service status
   - Review system logs
   - Test HTTPS access

2. **Monthly**:
   - Update system patches
   - Backup database
   - Review security logs

3. **Quarterly**:
   - Update Python packages
   - Review access logs
   - Performance optimization

### Log Locations

- **Django Logs**: `C:\noctis\noctis_pro.log`
- **PostgreSQL Logs**: `C:\Program Files\PostgreSQL\15\data\log\`
- **Windows Event Logs**: Event Viewer → Application
- **Service Logs**: Event Viewer → System

---

## 🎉 Congratulations!

Your NoctisPro DICOM system is now fully deployed on Windows Server 2019 with:

✅ **PostgreSQL Database** - Professional database backend  
✅ **Universal HTTPS Access** - Accessible from anywhere  
✅ **DICOM SCP Receiver** - Receives medical images globally  
✅ **Professional Security** - Enterprise-grade hardening  
✅ **Automatic Services** - Starts with Windows  

Your system is ready for production use!

### Your Access Information:
- **Universal HTTPS URL**: Check tunnel service logs
- **DICOM Reception**: `[Your-Public-IP]:11112`
- **Admin Interface**: `https://[tunnel-url]/admin`

Remember to:
1. Change default passwords
2. Configure your DICOM devices
3. Test with real DICOM images
4. Set up regular backups