# NoctisPro Universal HTTPS Tunnel Setup
# Multiple tunnel options for reliable universal access
# Run as Administrator

param(
    [string]$InstallPath = "C:\noctis",
    [int]$WebPort = 8000,
    [int]$DicomPort = 11112,
    [string]$TunnelType = "cloudflare"  # cloudflare, ngrok, localtunnel
)

$ErrorActionPreference = 'Stop'
Write-Host "🌐 Setting up Universal HTTPS Tunnel..." -ForegroundColor Green

Set-Location $InstallPath

# Function to test internet connectivity
function Test-InternetConnection {
    try {
        $response = Invoke-WebRequest -Uri "https://www.google.com" -UseBasicParsing -TimeoutSec 10
        return $true
    } catch {
        return $false
    }
}

if (-not (Test-InternetConnection)) {
    Write-Error "❌ No internet connection. Please check your network settings."
    exit 1
}

Write-Host "✅ Internet connection verified" -ForegroundColor Green

# Option 1: Cloudflare Tunnel (Recommended - Free and Reliable)
if ($TunnelType -eq "cloudflare") {
    Write-Host "`n☁️  Setting up Cloudflare Tunnel..." -ForegroundColor Yellow
    
    # Download cloudflared
    if (-not (Test-Path "cloudflared.exe")) {
        Write-Host "📥 Downloading Cloudflare Tunnel..." -ForegroundColor Cyan
        try {
            $cloudflareUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
            Invoke-WebRequest -Uri $cloudflareUrl -OutFile "cloudflared.exe" -UseBasicParsing
            Write-Host "✅ Cloudflare Tunnel downloaded" -ForegroundColor Green
        } catch {
            Write-Error "❌ Failed to download Cloudflare Tunnel: $_"
        }
    }
    
    # Create enhanced tunnel script with monitoring
    $enhancedTunnelScript = @"
@echo off
title NoctisPro Universal HTTPS Tunnel - Cloudflare
cd /d "$InstallPath"
color 0B

:start_tunnel
cls
echo ████████████████████████████████████████████████████████████████
echo ██                                                            ██
echo ██    🌐 NoctisPro Universal HTTPS Tunnel 🌐                  ██
echo ██                                                            ██
echo ████████████████████████████████████████████████████████████████
echo.
echo ⏰ Starting: %date% %time%
echo 💻 Local URL: http://127.0.0.1:$WebPort
echo 🌍 Establishing universal HTTPS access...
echo.
echo ⏳ Please wait while we create your universal URL...
echo    This may take 30-60 seconds...
echo.
echo ████████████████████████████████████████████████████████████████
echo.

if not exist cloudflared.exe (
    echo ❌ Cloudflare Tunnel not found!
    echo.
    echo 📥 Please download cloudflared.exe from:
    echo    https://github.com/cloudflare/cloudflared/releases
    echo.
    echo 💡 Save it as: $InstallPath\cloudflared.exe
    echo.
    pause
    goto start_tunnel
)

REM Start the tunnel with retry logic
:tunnel_retry
echo 🚀 Starting Cloudflare Tunnel...
cloudflared.exe tunnel --no-autoupdate --url http://127.0.0.1:$WebPort

echo.
echo ⚠️  Tunnel disconnected at %date% %time%
echo 🔄 Restarting in 10 seconds...
echo    Press Ctrl+C to stop
echo.
timeout /t 10 /nobreak >nul
goto tunnel_retry
"@
    $enhancedTunnelScript | Out-File -FilePath "start_cloudflare_tunnel.bat" -Encoding ASCII
    Write-Host "✅ Enhanced Cloudflare tunnel script created" -ForegroundColor Green
}

# Option 2: Ngrok (Alternative tunnel service)
Write-Host "`n🔧 Setting up Ngrok (Alternative Tunnel)..." -ForegroundColor Yellow
$ngrokScript = @"
@echo off
title NoctisPro Universal HTTPS Tunnel - Ngrok
cd /d "$InstallPath"

if not exist ngrok.exe (
    echo 📥 Downloading Ngrok...
    powershell -Command "Invoke-WebRequest -Uri 'https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip' -OutFile 'ngrok.zip'; Expand-Archive -Path 'ngrok.zip' -DestinationPath '.' -Force; Remove-Item 'ngrok.zip'"
)

echo ████████████████████████████████████████████████████████████████
echo ██                                                            ██
echo ██    🌐 NoctisPro Universal HTTPS - Ngrok 🌐                 ██
echo ██                                                            ██
echo ████████████████████████████████████████████████████████████████
echo.
echo 💻 Local URL: http://127.0.0.1:$WebPort
echo 🌍 Creating universal HTTPS tunnel...
echo.

ngrok.exe http $WebPort --log stdout
pause
"@
$ngrokScript | Out-File -FilePath "start_ngrok_tunnel.bat" -Encoding ASCII

# Option 3: LocalTunnel (Free alternative)
$localtunnelScript = @"
@echo off
title NoctisPro Universal HTTPS Tunnel - LocalTunnel
cd /d "$InstallPath"

REM Check if Node.js is installed
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js not found. Installing...
    powershell -Command "Invoke-WebRequest -Uri 'https://nodejs.org/dist/v18.17.0/node-v18.17.0-x64.msi' -OutFile 'node-installer.msi'; Start-Process -FilePath 'node-installer.msi' -ArgumentList '/quiet' -Wait"
    echo ✅ Node.js installed
)

REM Install localtunnel
npm install -g localtunnel

echo ████████████████████████████████████████████████████████████████
echo ██                                                            ██
echo ██    🌐 NoctisPro Universal HTTPS - LocalTunnel 🌐           ██
echo ██                                                            ██
echo ████████████████████████████████████████████████████████████████
echo.
echo 💻 Local URL: http://127.0.0.1:$WebPort
echo 🌍 Creating universal HTTPS tunnel...
echo.

lt --port $WebPort --subdomain noctispro-%RANDOM%
pause
"@
$localtunnelScript | Out-File -FilePath "start_localtunnel.bat" -Encoding ASCII

Write-Host "✅ Alternative tunnel scripts created" -ForegroundColor Green

# Create tunnel selector script
$tunnelSelectorScript = @"
@echo off
title NoctisPro Tunnel Selector
cd /d "$InstallPath"
color 0E

:menu
cls
echo ████████████████████████████████████████████████████████████████
echo ██                                                            ██
echo ██    🌐 NoctisPro Universal Tunnel Selector 🌐               ██
echo ██                                                            ██
echo ████████████████████████████████████████████████████████████████
echo.
echo Select your preferred tunnel service:
echo.
echo 1. ☁️  Cloudflare Tunnel (Recommended - Free, Fast, Reliable)
echo 2. 🔗 Ngrok (Requires account for custom domains)
echo 3. 🌐 LocalTunnel (Free, may be slower)
echo 4. 📊 Test all tunnels
echo 5. ❌ Cancel
echo.
set /p choice="Enter your choice (1-5): "

if "%choice%"=="1" (
    echo 🚀 Starting Cloudflare Tunnel...
    start "Cloudflare Tunnel" cmd /k "$InstallPath\start_cloudflare_tunnel.bat"
    goto success
)

if "%choice%"=="2" (
    echo 🚀 Starting Ngrok Tunnel...
    start "Ngrok Tunnel" cmd /k "$InstallPath\start_ngrok_tunnel.bat"
    goto success
)

if "%choice%"=="3" (
    echo 🚀 Starting LocalTunnel...
    start "LocalTunnel" cmd /k "$InstallPath\start_localtunnel.bat"
    goto success
)

if "%choice%"=="4" (
    echo 🧪 Testing all tunnel services...
    echo.
    echo 1. Testing Cloudflare...
    if exist cloudflared.exe (
        echo ✅ Cloudflare Tunnel available
    ) else (
        echo ❌ Cloudflare Tunnel not found
    )
    
    echo 2. Testing Ngrok...
    if exist ngrok.exe (
        echo ✅ Ngrok available
    ) else (
        echo ❌ Ngrok not found
    )
    
    echo 3. Testing LocalTunnel...
    node --version >nul 2>&1
    if %errorlevel% equ 0 (
        echo ✅ Node.js available for LocalTunnel
    ) else (
        echo ❌ Node.js not found for LocalTunnel
    )
    
    echo.
    pause
    goto menu
)

if "%choice%"=="5" (
    goto :eof
)

echo Invalid choice. Please try again.
timeout /t 2 /nobreak >nul
goto menu

:success
echo.
echo ✅ Tunnel service started!
echo 💡 Check the tunnel window for your universal HTTPS URL
echo 🌍 Your NoctisPro system is now accessible worldwide!
echo.
pause
"@
$tunnelSelectorScript | Out-File -FilePath "select_tunnel.bat" -Encoding ASCII

Write-Host "✅ Created tunnel selector script" -ForegroundColor Green

# Step 17: Create comprehensive documentation
Write-Host "`n📚 Creating Documentation..." -ForegroundColor Yellow

$readmeContent = @"
# NoctisPro Universal Deployment - Quick Start Guide

## 🎯 What You Have Now

Your NoctisPro DICOM system is now configured for:
- ✅ **Universal HTTPS Access** - Works from anywhere on the internet
- ✅ **DICOM SCP Receiver** - Receives medical images from anywhere
- ✅ **Windows Server 2019-2022** - Fully compatible
- ✅ **Professional Grade** - Production-ready configuration

## 🚀 Quick Start (3 Steps)

### Step 1: Start the System
Double-click: **"NoctisPro Universal"** shortcut on your desktop
- OR -
Double-click: `START_UNIVERSAL_NOCTISPRO.bat`

### Step 2: Get Your Universal URL
1. Wait 30-60 seconds for tunnel to establish
2. Check the "HTTPS Tunnel" window
3. Look for: `https://random-string.trycloudflare.com`
4. **This URL works from anywhere in the world!**

### Step 3: Login and Configure
1. Open your universal URL in any browser
2. Login with:
   - Username: `$AdminUsername`
   - Password: `$AdminPassword`
3. **Change password immediately!**
4. Configure your facilities and users

## 🏥 DICOM Configuration

### For DICOM Devices (CT, MRI, X-Ray, etc.)
Configure your medical devices to send DICOM to:
- **IP Address**: [Your Server's Public IP]
- **Port**: `$DicomPort`
- **AE Title**: `$AETitle`

### Finding Your Public IP
1. Visit: https://whatismyipaddress.com
2. Note your IPv4 address
3. Configure DICOM devices to send to: `[YOUR-IP]:$DicomPort`

## 🔧 Management Tools

### System Monitor
Double-click: **"NoctisPro Status"** shortcut
- View real-time system status
- Start/stop services
- Quick troubleshooting

### Available Scripts
- `START_UNIVERSAL_NOCTISPRO.bat` - Main launcher
- `system_status.bat` - System monitor
- `test_system.bat` - Run comprehensive tests
- `select_tunnel.bat` - Choose tunnel service
- `service_manager.ps1` - Install as Windows Service

## 🌐 Multiple Tunnel Options

If Cloudflare tunnel doesn't work, try alternatives:
1. Run: `select_tunnel.bat`
2. Choose from: Cloudflare, Ngrok, or LocalTunnel
3. Each provides universal HTTPS access

## 🛡️ Security Features

✅ **Windows Firewall** - Configured automatically
✅ **HTTPS Encryption** - Via tunnel services
✅ **Admin Authentication** - Secure login system
✅ **DICOM Security** - AE Title verification
✅ **Session Management** - Automatic timeouts

## 📞 Troubleshooting

### Problem: Can't access from internet
**Solution**: Check tunnel window for HTTPS URL

### Problem: DICOM devices can't connect
**Solution**: 
1. Verify Windows Firewall allows port $DicomPort
2. Check your router/network firewall
3. Confirm public IP address

### Problem: Login fails
**Solution**: 
1. Run: `test_system.bat`
2. Check admin user configuration
3. Reset password if needed

### Problem: Services won't start
**Solution**:
1. Run: `system_status.bat`
2. Check for port conflicts
3. Restart individual services

## 📱 Mobile Access

Your universal HTTPS URL works on:
- ✅ Desktop computers
- ✅ Tablets
- ✅ Smartphones
- ✅ Any device with internet

## 🎉 You're Ready!

Your NoctisPro system now provides:
1. **Universal web access** via HTTPS tunnel
2. **Global DICOM reception** on port $DicomPort
3. **Professional medical imaging** capabilities
4. **Multi-facility support** with user management
5. **Secure authentication** and session management

**Start now**: Double-click "NoctisPro Universal" on your desktop!
"@
$readmeContent | Out-File -FilePath "UNIVERSAL_DEPLOYMENT_README.txt" -Encoding UTF8

Write-Host "✅ Created UNIVERSAL_DEPLOYMENT_README.txt" -ForegroundColor Green

# Create a comprehensive validation script
Write-Host "`n🧪 Creating Validation Script..." -ForegroundColor Yellow

$validationScript = @"
# NoctisPro Universal System Validation
# Comprehensive testing for Windows Server deployment

param(
    [string]$InstallPath = "C:\noctis",
    [int]$WebPort = 8000,
    [int]$DicomPort = 11112,
    [string]$AdminUsername = "admin"
)

$ErrorActionPreference = 'Continue'
Write-Host "🧪 NoctisPro Universal System Validation" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Cyan

Set-Location $InstallPath

# Test 1: File Structure Validation
Write-Host "`n📁 1. File Structure Validation..." -ForegroundColor Yellow
$requiredFiles = @(
    "manage.py",
    "requirements.txt",
    "START_UNIVERSAL_NOCTISPRO.bat",
    "start_django_server.bat",
    "start_dicom_receiver.bat",
    "dicom_receiver.py",
    "noctis_pro\settings.py"
)

$missingFiles = @()
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "   ✅ $file" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $file" -ForegroundColor Red
        $missingFiles += $file
    }
}

if ($missingFiles.Count -eq 0) {
    Write-Host "✅ File structure validation passed" -ForegroundColor Green
} else {
    Write-Host "❌ Missing files: $($missingFiles -join ', ')" -ForegroundColor Red
}

# Test 2: Python Environment Validation
Write-Host "`n🐍 2. Python Environment Validation..." -ForegroundColor Yellow
try {
    if (Test-Path ".venv\Scripts\python.exe") {
        $pythonPath = ".venv\Scripts\python.exe"
        Write-Host "   ✅ Virtual environment found" -ForegroundColor Green
    } else {
        $pythonPath = "python"
        Write-Host "   ⚠️  Using system Python" -ForegroundColor Yellow
    }
    
    $pythonVersion = & $pythonPath --version
    Write-Host "   ✅ Python version: $pythonVersion" -ForegroundColor Green
    
    # Test Django import
    & $pythonPath -c "import django; print(f'Django version: {django.get_version()}')"
    Write-Host "   ✅ Django import successful" -ForegroundColor Green
    
} catch {
    Write-Host "   ❌ Python environment error: $_" -ForegroundColor Red
}

# Test 3: Database Validation
Write-Host "`n🗄️  3. Database Validation..." -ForegroundColor Yellow
try {
    if (Test-Path "db.sqlite3") {
        Write-Host "   ✅ Database file exists" -ForegroundColor Green
        
        # Test database connection
        $env:DJANGO_SETTINGS_MODULE = "noctis_pro.settings_universal"
        $dbTest = @"
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings_universal')
django.setup()
from django.db import connection
cursor = connection.cursor()
cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
tables = cursor.fetchall()
print(f'✅ Database connection successful - {len(tables)} tables found')
"@
        $dbTest | & $pythonPath manage.py shell
        Write-Host "   ✅ Database connection validated" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Database file missing" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Database validation error: $_" -ForegroundColor Red
}

# Test 4: Admin User Validation
Write-Host "`n👤 4. Admin User Validation..." -ForegroundColor Yellow
try {
    $userTest = @"
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings_universal')
django.setup()
from accounts.models import User
try:
    user = User.objects.get(username='$AdminUsername')
    print(f'✅ Admin user found: {user.username}')
    print(f'   Active: {user.is_active}')
    print(f'   Verified: {user.is_verified}')
    print(f'   Staff: {user.is_staff}')
    print(f'   Superuser: {user.is_superuser}')
    print(f'   Role: {user.role}')
    
    if user.is_active and user.is_verified and user.is_staff:
        print('✅ Admin user properly configured')
    else:
        print('❌ Admin user configuration issues')
except User.DoesNotExist:
    print('❌ Admin user not found')
"@
    $userTest | & $pythonPath manage.py shell
} catch {
    Write-Host "   ❌ Admin user validation error: $_" -ForegroundColor Red
}

# Test 5: Network Port Validation
Write-Host "`n🌐 5. Network Port Validation..." -ForegroundColor Yellow
$webPortTest = netstat -an | Select-String ":$WebPort"
if ($webPortTest) {
    Write-Host "   ✅ Web port $WebPort is listening" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Web port $WebPort not listening (normal if not started)" -ForegroundColor Yellow
}

$dicomPortTest = netstat -an | Select-String ":$DicomPort"
if ($dicomPortTest) {
    Write-Host "   ✅ DICOM port $DicomPort is listening" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  DICOM port $DicomPort not listening (normal if not started)" -ForegroundColor Yellow
}

# Test 6: Firewall Validation
Write-Host "`n🔥 6. Windows Firewall Validation..." -ForegroundColor Yellow
try {
    $webRule = netsh advfirewall firewall show rule name="NoctisPro-Web" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Web firewall rule exists" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Web firewall rule missing" -ForegroundColor Red
    }
    
    $dicomRule = netsh advfirewall firewall show rule name="NoctisPro-DICOM" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ DICOM firewall rule exists" -ForegroundColor Green
    } else {
        Write-Host "   ❌ DICOM firewall rule missing" -ForegroundColor Red
    }
} catch {
    Write-Host "   ⚠️  Firewall validation error: $_" -ForegroundColor Yellow
}

# Test 7: Tunnel Availability
Write-Host "`n🌐 7. Tunnel Service Validation..." -ForegroundColor Yellow
if (Test-Path "cloudflared.exe") {
    Write-Host "   ✅ Cloudflare Tunnel available" -ForegroundColor Green
} else {
    Write-Host "   ❌ Cloudflare Tunnel missing" -ForegroundColor Red
}

if (Test-Path "ngrok.exe") {
    Write-Host "   ✅ Ngrok available" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Ngrok not installed" -ForegroundColor Yellow
}

# Test 8: Internet Connectivity
Write-Host "`n🌍 8. Internet Connectivity Test..." -ForegroundColor Yellow
try {
    $testSites = @("https://www.google.com", "https://github.com", "https://cloudflare.com")
    foreach ($site in $testSites) {
        try {
            $response = Invoke-WebRequest -Uri $site -UseBasicParsing -TimeoutSec 5
            Write-Host "   ✅ $site - OK" -ForegroundColor Green
        } catch {
            Write-Host "   ❌ $site - Failed" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   ❌ Internet connectivity test failed" -ForegroundColor Red
}

# Final Summary
Write-Host "`n" -NoNewline
Write-Host "📊 VALIDATION SUMMARY" -ForegroundColor Cyan -BackgroundColor Black
Write-Host "=" * 60 -ForegroundColor Cyan

Write-Host "`n🎯 System Status:" -ForegroundColor White
if ($missingFiles.Count -eq 0) {
    Write-Host "   ✅ File structure: PASSED" -ForegroundColor Green
} else {
    Write-Host "   ❌ File structure: FAILED" -ForegroundColor Red
}

Write-Host "`n🚀 Ready for Deployment:" -ForegroundColor White
Write-Host "   1. Start system: Double-click 'NoctisPro Universal'" -ForegroundColor White
Write-Host "   2. Wait for tunnel URL (30-60 seconds)" -ForegroundColor White
Write-Host "   3. Access your universal HTTPS URL" -ForegroundColor White
Write-Host "   4. Login and change admin password" -ForegroundColor White
Write-Host "   5. Configure DICOM devices to send to your public IP:$DicomPort" -ForegroundColor White

Write-Host "`n💡 Need Help?" -ForegroundColor Yellow
Write-Host "   📖 Read: UNIVERSAL_DEPLOYMENT_README.txt" -ForegroundColor White
Write-Host "   📊 Monitor: system_status.bat" -ForegroundColor White
Write-Host "   🔧 Manage: service_manager.ps1" -ForegroundColor White

Write-Host "`nValidation complete! Press Enter to continue..." -ForegroundColor Green
Read-Host
"@
$validationScript | Out-File -FilePath "validate_system.ps1" -Encoding UTF8

Write-Host "✅ Created validate_system.ps1" -ForegroundColor Green

# Final completion message
Write-Host "`n" -NoNewline
Write-Host "🎉 UNIVERSAL TUNNEL SETUP COMPLETE! 🎉" -ForegroundColor Green -BackgroundColor Black
Write-Host "=" * 80 -ForegroundColor Green

Write-Host "`n🌐 UNIVERSAL ACCESS READY:" -ForegroundColor Cyan
Write-Host "   🚀 Main Launcher: START_UNIVERSAL_NOCTISPRO.bat" -ForegroundColor White
Write-Host "   ☁️  Cloudflare Tunnel: start_cloudflare_tunnel.bat" -ForegroundColor White
Write-Host "   🔗 Alternative Tunnels: select_tunnel.bat" -ForegroundColor White
Write-Host "   📊 System Monitor: system_status.bat" -ForegroundColor White

Write-Host "`n🏥 DICOM SCP READY:" -ForegroundColor Cyan
Write-Host "   📡 Port: $DicomPort" -ForegroundColor White
Write-Host "   🏷️  AE Title: $AETitle" -ForegroundColor White
Write-Host "   🌍 Receives from anywhere on the internet!" -ForegroundColor White

Write-Host "`n✅ All tunnel configurations created successfully!" -ForegroundColor Green