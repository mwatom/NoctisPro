# 🌍 NoctisPro Internet Deployment Guide

Make your NoctisPro medical imaging system accessible from anywhere on the internet with a single command!

## 🚀 Quick Start

### For Windows Server

1. **Open PowerShell as Administrator**
2. **Navigate to your NoctisPro directory**
3. **Run the deployment script:**
   ```powershell
   .\deploy_internet_windows.ps1
   ```

### For Linux (Ubuntu/Debian/CentOS/RHEL/Fedora)

1. **Open terminal**
2. **Navigate to your NoctisPro directory** 
3. **Run the deployment script:**
   ```bash
   chmod +x deploy_internet_linux.sh
   ./deploy_internet_linux.sh
   ```

## 🎯 What These Scripts Do

### ✅ **Automatic Setup**
- ✅ Fixes all login issues (sets `is_verified=True` for users)
- ✅ Installs Python and all required dependencies
- ✅ Creates production-ready Django settings
- ✅ Sets up Cloudflare tunnel for internet access
- ✅ Creates startup scripts and system services
- ✅ Configures firewall rules
- ✅ Provides a public HTTPS URL (e.g., `https://xxxx.trycloudflare.com`)

### 🔑 **Default Login Credentials**
- **Username:** `admin`
- **Password:** `Admin123!`
- **Role:** Administrator
- **Status:** Active & Verified ✅

## 🌍 How Internet Access Works

Your NoctisPro system becomes accessible worldwide through:

1. **Cloudflare Tunnel** (Recommended - Free HTTPS)
   - Automatically provides secure HTTPS URLs
   - No port forwarding needed
   - Works behind any firewall/NAT
   - Example URL: `https://xyz123.trycloudflare.com`

2. **ngrok Tunnel** (Alternative)
   - Quick setup for testing
   - Requires ngrok account for persistence
   - Example URL: `https://abc123.ngrok.io`

## 📋 Usage Instructions

### Windows

After running `deploy_internet_windows.ps1`:

```powershell
# Start everything (Django + Internet tunnel)
.\start_noctispro_internet.bat

# Or start components separately
.\start_django.bat        # Django server only
.\start_tunnel.bat        # Internet tunnel only

# Windows Service management
.\manage_service.ps1 -Action install   # Install as service
.\manage_service.ps1 -Action start     # Start service
.\manage_service.ps1 -Action stop      # Stop service
.\manage_service.ps1 -Action remove    # Remove service
```

### Linux

After running `deploy_internet_linux.sh`:

```bash
# Start everything (Django + Internet tunnel)
./start_noctispro_internet.sh

# Or start components separately
./start_django.sh         # Django server only
./start_tunnel.sh          # Internet tunnel only

# Systemd service management
sudo systemctl start noctispro    # Start service
sudo systemctl stop noctispro     # Stop service
sudo systemctl status noctispro   # Check status
sudo journalctl -u noctispro -f   # View logs
```

## 🔧 Advanced Configuration

### Custom Parameters

**Windows:**
```powershell
.\deploy_internet_windows.ps1 -ProjectPath "C:\MyNoctis" -AdminUsername "doctor" -AdminPassword "MySecurePass" -Port 8080 -TunnelType "ngrok"
```

**Linux:**
```bash
./deploy_internet_linux.sh /opt/noctispro doctor MySecurePass doctor@hospital.com 8080 ngrok
```

### Parameters:
- `ProjectPath` / `$1`: NoctisPro project directory
- `AdminUsername` / `$2`: Admin username (default: admin)
- `AdminPassword` / `$3`: Admin password (default: Admin123!)
- `AdminEmail` / `$4`: Admin email (default: admin@noctispro.com)
- `Port` / `$5`: Local port (default: 8000)
- `TunnelType` / `$6`: Tunnel type - `cloudflare` or `ngrok` (default: cloudflare)

## 🔐 Security Considerations

### ⚠️ **Important Security Notes**

1. **Change Default Passwords**
   ```python
   # Run this after deployment to change admin password
   python fix_login_and_deploy_internet.py
   ```

2. **Monitor Access Logs**
   - Windows: Check `noctis_pro.log`
   - Linux: `sudo journalctl -u noctispro -f`

3. **Regular Updates**
   - Keep your system updated
   - Monitor for security patches
   - Review access logs regularly

4. **HTTPS Only**
   - Both Cloudflare and ngrok provide HTTPS
   - Never use HTTP for production

### 🛡️ **Firewall & Network**

- **Windows:** Script automatically configures Windows Firewall
- **Linux:** Script configures UFW/firewalld
- **Cloud:** If using cloud servers, configure security groups to allow the chosen port

## 🐛 Troubleshooting

### Common Issues

#### 1. **Login Still Not Working**
```bash
# Re-run the login fix
python fix_login_and_deploy_internet.py
```

#### 2. **Tunnel URL Not Appearing**
```bash
# Check if tunnel service is running
# Windows: Check Task Manager for cloudflared.exe
# Linux: ps aux | grep cloudflared
```

#### 3. **Dependencies Missing**
```bash
# Windows
pip install django djangorestframework pillow pydicom numpy scipy waitress

# Linux  
pip install django djangorestframework pillow pydicom numpy scipy gunicorn
```

#### 4. **Permission Errors (Linux)**
```bash
# Make scripts executable
chmod +x *.sh
chmod +x fix_login_and_deploy_internet.py
```

#### 5. **Port Already in Use**
```bash
# Find what's using the port
# Windows: netstat -ano | findstr :8000
# Linux: sudo lsof -i :8000

# Kill the process or choose a different port
```

### Getting Help

1. **Check Logs:**
   - Windows: `noctis_pro.log`
   - Linux: `sudo journalctl -u noctispro -f`

2. **Verify Services:**
   - Windows: `services.msc` → Look for "NoctisPro"
   - Linux: `sudo systemctl status noctispro`

3. **Test Local Access First:**
   - Visit `http://localhost:8000` before testing internet URL

## 📁 Files Created

After running the deployment scripts, you'll have:

### Core Files
- `fix_login_and_deploy_internet.py` - Login fix and setup script
- `noctis_pro/settings_internet.py` - Production settings for internet access

### Windows Files
- `start_django.bat` - Start Django server
- `start_tunnel.bat` - Start internet tunnel
- `start_noctispro_internet.bat` - Start everything
- `manage_service.ps1` - Windows service management

### Linux Files  
- `start_django.sh` - Start Django server
- `start_tunnel.sh` - Start internet tunnel
- `start_noctispro_internet.sh` - Start everything
- `/etc/systemd/system/noctispro.service` - Systemd service

## 🎉 Success!

Once deployed, you'll have:

✅ **A fully functional NoctisPro system**  
✅ **Accessible from anywhere on the internet**  
✅ **Secure HTTPS connection**  
✅ **Fixed login issues**  
✅ **Production-ready configuration**  
✅ **Automatic startup scripts**  
✅ **System service integration**

Your medical imaging system is now ready for global access! 🌍

---

## 📞 Support

If you encounter any issues:

1. Check this troubleshooting guide
2. Review the logs (mentioned above)
3. Ensure all dependencies are installed
4. Verify firewall settings
5. Test local access before internet access

**Remember:** Your system will be accessible from the internet, so make sure to:
- Use strong passwords
- Monitor access logs
- Keep the system updated
- Follow security best practices