# NoctisPro DICOM System - Windows Server 2019 Manual Deployment

## 🚀 Quick Start - Copy & Paste Deployment

This repository contains a complete automated deployment script for NoctisPro DICOM system on Windows Server 2019. Follow these simple steps to deploy the entire system.

## 📋 Prerequisites

Before running the deployment script, ensure you have:

### Required Software (Download First)
1. **PostgreSQL 17**: Download from https://www.postgresql.org/download/windows/
   - Use the interactive installer
   - Remember the superuser password you set!
   
2. **Python 3.11**: Download from https://www.python.org/downloads/windows/
   - ✅ **IMPORTANT**: Check "Add Python to PATH" during installation
   - ✅ Install for all users
   - ✅ Install pip

### System Requirements
- Windows Server 2019 (Standard or Datacenter)
- Administrator privileges
- 8 GB RAM minimum (16 GB recommended)
- 100 GB+ free disk space
- Internet connection for downloads

## 🎯 One-Command Deployment

### Step 1: Copy the Deployment Script

1. **Open PowerShell as Administrator** on your Windows Server 2019
2. **Copy the entire content** of `WINDOWS_2019_MANUAL_DEPLOY.ps1` from this repository
3. **Paste it directly** into PowerShell and press Enter

### Step 2: Copy NoctisPro Files

When prompted by the script:
1. **Copy all NoctisPro project files** to `C:\noctis`
2. Ensure these files/directories are present:
   - `manage.py`
   - `requirements-windows.txt` (or `requirements.txt`)
   - `noctis_pro/` directory
   - `accounts/` directory  
   - `worklist/` directory
   - `dicom_viewer/` directory
   - `templates/` directory
   - `static/` directory

### Step 3: Follow the Prompts

The script will automatically:
- ✅ Configure Windows Firewall
- ✅ Verify PostgreSQL installation
- ✅ Verify Python installation  
- ✅ Install and configure Redis
- ✅ Set up Python virtual environment
- ✅ Install all dependencies
- ✅ Configure environment variables
- ✅ Initialize PostgreSQL database
- ✅ Run Django migrations
- ✅ Create Windows services
- ✅ Create management scripts
- ✅ Test the installation

## 🔧 What the Script Does

### Automatic Configuration
- **Firewall Rules**: Opens ports 8000, 11112, 5432, 6379
- **Redis Installation**: Downloads and installs Redis as Windows service
- **Python Environment**: Creates virtual environment and installs dependencies
- **Database Setup**: Creates PostgreSQL database and user for NoctisPro
- **Windows Services**: Configures NoctisPro as auto-starting Windows services
- **Management Scripts**: Creates start/stop/status batch files

### Services Created
- `NoctisPro-Web`: Django web interface (port 8000)
- `NoctisPro-Celery`: Background task worker
- `NoctisPro-DICOM`: DICOM SCP receiver (port 11112)

## 🎉 After Deployment

### Access Your System
- **Web Interface**: http://localhost:8000
- **Admin Panel**: http://localhost:8000/admin
- **DICOM Receiver**: localhost:11112 (AE Title: NOCTISPRO)

### Management Scripts
Located in `C:\noctis\`:
- `START_NOCTISPRO.bat` - Start all services
- `STOP_NOCTISPRO.bat` - Stop all services  
- `STATUS_NOCTISPRO.bat` - Check system status

### Configuration Files
- `C:\noctis\.env` - Environment configuration
- `C:\noctis\INSTALLATION_SUMMARY.txt` - Installation details

## 🔒 Security Notes

### Default Passwords (CHANGE THESE!)
- **PostgreSQL User**: `noctispro_user` / `NoctisPro2024!`
- **Django Admin**: Created during installation

### Production Hardening
1. **Change database password** in `C:\noctis\.env`
2. **Update Django SECRET_KEY** (already auto-generated)
3. **Configure ALLOWED_HOSTS** for your domain/IP
4. **Set up SSL/HTTPS** for production use
5. **Configure regular backups**

## 🌐 External Access Setup

### For Internet Access
1. **Configure router port forwarding**:
   - Port 8000 → Server IP:8000 (Web interface)
   - Port 11112 → Server IP:11112 (DICOM receiver)

2. **Update firewall rules** for external access:
   ```powershell
   New-NetFirewallRule -DisplayName "NoctisPro External Web" -Direction Inbound -Protocol TCP -LocalPort 8000 -RemoteAddress Any -Action Allow
   New-NetFirewallRule -DisplayName "NoctisPro External DICOM" -Direction Inbound -Protocol TCP -LocalPort 11112 -RemoteAddress Any -Action Allow
   ```

3. **Update ALLOWED_HOSTS** in `C:\noctis\.env`:
   ```
   ALLOWED_HOSTS=localhost,127.0.0.1,your-domain.com,your-external-ip
   ```

## 🆘 Troubleshooting

### Common Issues

#### Script Execution Policy Error
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

#### PostgreSQL Connection Issues
1. Verify PostgreSQL service is running:
   ```powershell
   Get-Service -Name "*postgresql*"
   ```
2. Test connection:
   ```powershell
   cd "C:\Program Files\PostgreSQL\17\bin"
   .\pg_isready.exe -h localhost -p 5432
   ```

#### Python Not Found
- Reinstall Python with "Add to PATH" checked
- Or use full path: `C:\Python311\python.exe`

#### Services Won't Start
1. Check Event Viewer → Windows Logs → Application
2. Run services manually to see errors:
   ```powershell
   cd C:\noctis
   .\.venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
   ```

#### Port Already in Use
```powershell
# Find what's using the port
netstat -ano | findstr ":8000"

# Kill the process if needed
taskkill /PID [process_id] /F
```

### Getting Help

1. **Check installation summary**: `C:\noctis\INSTALLATION_SUMMARY.txt`
2. **Run status check**: `C:\noctis\STATUS_NOCTISPRO.bat`
3. **Check service logs**: Event Viewer → Application logs
4. **Verify file permissions**: Ensure `C:\noctis` is accessible

## 📊 System Monitoring

### Health Checks
```powershell
# Check all services
Get-Service -Name "postgresql-x64-17", "Redis", "NoctisPro-*"

# Check listening ports
netstat -an | findstr ":8000\|:11112\|:5432\|:6379"

# Test web interface
Invoke-WebRequest -Uri "http://localhost:8000" -UseBasicParsing
```

### Log Locations
- **Django Logs**: `C:\noctis\noctis_pro.log`
- **PostgreSQL Logs**: `C:\Program Files\PostgreSQL\17\data\log\`
- **Windows Event Logs**: Event Viewer → Application
- **Service Logs**: Event Viewer → System

## 🔄 Maintenance

### Regular Tasks
- **Daily**: Check service status with `STATUS_NOCTISPRO.bat`
- **Weekly**: Review system logs
- **Monthly**: Update Python packages, backup database
- **Quarterly**: Security review, performance optimization

### Backup Script
```batch
# Save as C:\noctis\BACKUP_SYSTEM.bat
@echo off
set BACKUP_DIR=C:\noctis_backups\%date:~-4,4%-%date:~-10,2%-%date:~-7,2%
mkdir "%BACKUP_DIR%"
"C:\Program Files\PostgreSQL\17\bin\pg_dump.exe" -U noctispro_user -h localhost noctispro > "%BACKUP_DIR%\database.sql"
xcopy "C:\noctis\media" "%BACKUP_DIR%\media\" /E /I /Y
echo Backup completed: %BACKUP_DIR%
```

## 🎯 DICOM Device Configuration

To send DICOM images to your NoctisPro system:

### Modality Settings
- **Host**: Your server's IP address
- **Port**: 11112
- **AE Title**: NOCTISPRO
- **Protocol**: DICOM C-STORE

### Test DICOM Connection
```powershell
cd C:\noctis
.\.venv\Scripts\python.exe -c "
from pynetdicom import AE
from pynetdicom.sop_class import Verification
ae = AE()
ae.add_requested_context(Verification)
assoc = ae.associate('localhost', 11112, ae_title='NOCTISPRO')
if assoc.is_established:
    print('✅ DICOM connection successful')
    assoc.release()
else:
    print('❌ DICOM connection failed')
"
```

---

## 📞 Support

For issues or questions:
1. Check this README first
2. Review installation logs
3. Check Windows Event Viewer
4. Verify all prerequisites are met
5. Ensure all files are copied correctly to `C:\noctis`

**Your NoctisPro DICOM system should now be fully operational on Windows Server 2019!** 🎉