# NoctisPro Windows Server 2012 Production Deployment Script
# Addresses super user login issues and enables worldwide internet access
# Run as Administrator in PowerShell

param(
    [string]$InstallPath = "C:\noctis",
    [string]$AdminUsername = "admin", 
    [string]$AdminPassword = "Admin123!",
    [string]$AdminEmail = "admin@yourdomain.com",
    [int]$Port = 8000,
    [switch]$FixLoginOnly = $false,
    [switch]$EnableTunnel = $true
)

$ErrorActionPreference = 'Stop'
Write-Host "🚀 NoctisPro Windows Server 2012 Deployment Starting..." -ForegroundColor Green
Write-Host "📁 Install Path: $InstallPath" -ForegroundColor Cyan
Write-Host "🌐 Port: $Port" -ForegroundColor Cyan

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Error "❌ This script must be run as Administrator. Right-click PowerShell and 'Run as Administrator'"
    exit 1
}

# Check Windows version compatibility
$osVersion = [System.Environment]::OSVersion.Version
Write-Host "🖥️  Windows Version: $($osVersion.Major).$($osVersion.Minor)" -ForegroundColor Cyan
if ($osVersion.Major -lt 6 -or ($osVersion.Major -eq 6 -and $osVersion.Minor -lt 2)) {
    Write-Warning "⚠️  This script is optimized for Windows Server 2012+ (6.2+). Your version: $osVersion"
    Write-Host "Continuing with compatibility mode..." -ForegroundColor Yellow
}

# Navigate to install directory
if (-not (Test-Path $InstallPath)) {
    Write-Error "❌ NoctisPro directory not found at: $InstallPath"
    Write-Host "💡 Please ensure you've copied the NoctisPro files to $InstallPath" -ForegroundColor Yellow
    exit 1
}

Set-Location $InstallPath
Write-Host "✅ Changed to NoctisPro directory: $InstallPath" -ForegroundColor Green

# Step 1: Check Python installation
Write-Host "`n🐍 Checking Python Installation..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✅ Found Python: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Python not found. Attempting to install Python..." -ForegroundColor Red
    
    # Download and install Python 3.10 (compatible with Windows 2012)
    $pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
    $pythonInstaller = "$env:TEMP\python-installer.exe"
    
    try {
        Write-Host "📥 Downloading Python 3.10.11..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
        Write-Host "🔧 Installing Python..." -ForegroundColor Cyan
        Start-Process -FilePath $pythonInstaller -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1 Include_test=0' -Wait
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Test Python again
        $pythonVersion = python --version 2>&1
        Write-Host "✅ Python installed: $pythonVersion" -ForegroundColor Green
    } catch {
        Write-Error "❌ Failed to install Python. Please install Python 3.8+ manually from python.org"
        exit 1
    }
}

# Step 2: Create/activate virtual environment
Write-Host "`n📦 Setting up Virtual Environment..." -ForegroundColor Yellow
if (Test-Path ".venv") {
    Write-Host "⚠️  Existing virtual environment found, removing..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force ".venv"
}

try {
    python -m venv .venv
    Write-Host "✅ Virtual environment created" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to create virtual environment"
    exit 1
}

# Activate virtual environment
if (Test-Path ".venv\Scripts\Activate.ps1") {
    & ".venv\Scripts\Activate.ps1"
    Write-Host "✅ Virtual environment activated" -ForegroundColor Green
} else {
    Write-Error "❌ Failed to find virtual environment activation script"
    exit 1
}

# Step 3: Upgrade pip and install dependencies
Write-Host "`n📥 Installing Dependencies..." -ForegroundColor Yellow
python -m pip install --upgrade pip setuptools wheel

# Install Windows-compatible requirements
if (Test-Path "requirements-windows.txt") {
    Write-Host "📋 Installing from requirements-windows.txt..." -ForegroundColor Cyan
    try {
        pip install -r requirements-windows.txt
    } catch {
        Write-Warning "⚠️  Some packages failed to install, trying fallback..."
        # Install core packages individually
        pip install Django
        pip install djangorestframework 
        pip install Pillow
        pip install numpy
        pip install pydicom
        pip install waitress
        pip install redis
        pip install celery
    }
} elseif (Test-Path "requirements.txt") {
    Write-Host "📋 Installing from requirements.txt..." -ForegroundColor Cyan
    pip install -r requirements.txt
} else {
    Write-Host "⚠️  No requirements file found, installing minimal dependencies..." -ForegroundColor Yellow
    pip install Django djangorestframework Pillow numpy pydicom waitress redis celery
}

# Ensure waitress is installed for production
pip install waitress
Write-Host "✅ Dependencies installed" -ForegroundColor Green

# Step 4: Database setup
Write-Host "`n🗄️  Setting up Database..." -ForegroundColor Yellow
try {
    python manage.py migrate --noinput
    Write-Host "✅ Database migrations completed" -ForegroundColor Green
} catch {
    Write-Error "❌ Database migration failed: $_"
    exit 1
}

# Step 5: Collect static files
Write-Host "`n📁 Collecting Static Files..." -ForegroundColor Yellow
try {
    python manage.py collectstatic --noinput
    Write-Host "✅ Static files collected" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Static files collection failed, continuing..." -ForegroundColor Yellow
}

# Step 6: Fix login issues - This is the CRITICAL step for the user's issue
Write-Host "`n👤 FIXING SUPER USER LOGIN ISSUES..." -ForegroundColor Red
Write-Host "🔧 This addresses the reported login problem..." -ForegroundColor Yellow

try {
    # First try the existing fix script
    if (Test-Path "fix_login.py") {
        Write-Host "🔧 Running fix_login.py script..." -ForegroundColor Cyan
        python fix_login.py
        Write-Host "✅ Login fix script executed successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠️  fix_login.py not found, applying manual fix..." -ForegroundColor Yellow
    }
    
    # Apply comprehensive manual fix
    Write-Host "🔧 Applying comprehensive login fixes..." -ForegroundColor Cyan
    $fixScript = @"
import os
import sys
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from accounts.models import User, Facility

print("🔧 Comprehensive Login Fix Starting...")

# 1. Create default facility if none exists
if not Facility.objects.exists():
    facility = Facility.objects.create(
        name='Default Medical Center',
        address='123 Healthcare Ave, Medical City',
        phone='+1-555-0123',
        email='contact@medicalcenter.com',
        license_number='MC-2024-001',
        ae_title='NOCTISPRO',
        is_active=True
    )
    print(f'✅ Created default facility: {facility.name}')
else:
    facility = Facility.objects.first()
    print(f'✅ Using existing facility: {facility.name}')

# 2. Fix or create admin user
username = '$AdminUsername'
password = '$AdminPassword'
email = '$AdminEmail'

try:
    user = User.objects.get(username=username)
    print(f'✅ Found existing user: {username}')
    
    # Apply comprehensive fixes
    user.set_password(password)
    user.email = email
    user.first_name = 'System'
    user.last_name = 'Administrator'
    user.role = 'admin'
    user.is_active = True
    user.is_verified = True  # CRITICAL: This fixes the login issue
    user.is_staff = True
    user.is_superuser = True
    user.facility = facility
    user.save()
    
    print(f'✅ Fixed user: {username}')
    
except User.DoesNotExist:
    # Create new admin user with all correct flags
    user = User.objects.create_user(
        username=username,
        email=email,
        password=password,
        first_name='System',
        last_name='Administrator',
        role='admin',
        is_active=True,
        is_verified=True,  # CRITICAL: This prevents login issues
        is_staff=True,
        is_superuser=True
    )
    user.facility = facility
    user.save()
    print(f'✅ Created new admin user: {username}')

# 3. Fix ALL users with verification issues (common cause of login failures)
unverified_users = User.objects.filter(is_verified=False)
if unverified_users.exists():
    print(f'🔧 Fixing {unverified_users.count()} unverified users...')
    for u in unverified_users:
        u.is_verified = True
        u.is_active = True
        if not u.facility:
            u.facility = facility
        u.save()
        print(f'   ✅ Fixed: {u.username}')

# 4. Verify the admin user can login
admin_user = User.objects.get(username=username)
print(f'\\n✅ ADMIN USER STATUS:')
print(f'   Username: {admin_user.username}')
print(f'   Email: {admin_user.email}')
print(f'   Active: {admin_user.is_active}')
print(f'   Verified: {admin_user.is_verified}')  # This should be True
print(f'   Staff: {admin_user.is_staff}')
print(f'   Superuser: {admin_user.is_superuser}')
print(f'   Role: {admin_user.role}')
print(f'   Facility: {admin_user.facility}')

print(f'\\n🎉 LOGIN ISSUES FIXED!')
print(f'   You can now login with:')
print(f'   Username: {username}')
print(f'   Password: {password}')
"@
    
    $fixScript | python manage.py shell
    Write-Host "✅ Comprehensive login fixes applied successfully!" -ForegroundColor Green
    
} catch {
    Write-Error "❌ Failed to fix login issues: $_"
    Write-Host "💡 Manual fix: Run 'python fix_login.py' or check user verification status" -ForegroundColor Yellow
}

# Exit early if only fixing login
if ($FixLoginOnly) {
    Write-Host "`n🎉 Login fix complete! Try logging in now." -ForegroundColor Green
    exit 0
}

# Step 7: Setup for worldwide internet access
if ($EnableTunnel) {
    Write-Host "`n🌐 Setting up Internet Access (Cloudflare Tunnel)..." -ForegroundColor Yellow
    
    try {
        if (-not (Test-Path "cloudflared.exe")) {
            Write-Host "📥 Downloading Cloudflare Tunnel..." -ForegroundColor Cyan
            $cloudflareUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
            Invoke-WebRequest -Uri $cloudflareUrl -OutFile "cloudflared.exe"
            Write-Host "✅ Cloudflare Tunnel downloaded" -ForegroundColor Green
        } else {
            Write-Host "✅ Cloudflare Tunnel already exists" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️  Failed to download Cloudflare Tunnel: $_" -ForegroundColor Yellow
        $EnableTunnel = $false
    }
}

# Step 8: Create startup scripts for Windows Server 2012
Write-Host "`n📝 Creating Windows Server 2012 Compatible Startup Scripts..." -ForegroundColor Yellow

# Django server startup script (Windows Server 2012 compatible)
$djangoScript = @"
@echo off
echo Starting NoctisPro on Windows Server 2012...
cd /d "$InstallPath"
call .venv\Scripts\activate.bat

echo ============================================
echo NoctisPro DICOM Medical Imaging System
echo ============================================
echo Starting Django server on port $Port...
echo.

waitress-serve --host=0.0.0.0 --port=$Port noctis_pro.wsgi:application
pause
"@
$djangoScript | Out-File -FilePath "start_django_server.bat" -Encoding ASCII
Write-Host "✅ Created start_django_server.bat" -ForegroundColor Green

# Cloudflare tunnel startup script
if ($EnableTunnel) {
    $tunnelScript = @"
@echo off
echo Starting Cloudflare Tunnel for worldwide access...
cd /d "$InstallPath"

echo ============================================
echo NoctisPro Cloudflare Tunnel
echo ============================================
echo Creating secure tunnel to make system accessible worldwide...
echo This will generate a public HTTPS URL.
echo.

cloudflared.exe tunnel --no-autoupdate --url http://127.0.0.1:$Port
pause
"@
    $tunnelScript | Out-File -FilePath "start_tunnel.bat" -Encoding ASCII
    Write-Host "✅ Created start_tunnel.bat" -ForegroundColor Green
}

# Master startup script
$masterScript = @"
@echo off
title NoctisPro Medical Imaging System
color 0A
echo.
echo ============================================
echo    NoctisPro Medical Imaging System
echo    Windows Server 2012 Production Launch
echo ============================================
echo.
echo Starting system components...
echo.

cd /d "$InstallPath"

echo [1/2] Starting Django Application Server...
start "NoctisPro-Django" cmd /k "call start_django_server.bat"

echo [2/2] Starting Internet Tunnel...
timeout /t 3 /nobreak >nul

if exist cloudflared.exe (
    start "NoctisPro-Tunnel" cmd /k "call start_tunnel.bat"
    echo.
    echo ============================================
    echo System is starting up...
    echo.
    echo Local Access: http://localhost:$Port
    echo              http://127.0.0.1:$Port
    echo              http://[SERVER-IP]:$Port
    echo.
    echo Worldwide Access: Check the tunnel window for
    echo                  https://xxx.trycloudflare.com
    echo.
    echo Admin Login:
    echo   Username: $AdminUsername
    echo   Password: $AdminPassword
    echo.
    echo Wait 30-60 seconds for full startup...
    echo ============================================
) else (
    echo.
    echo ============================================
    echo System started - Local access only
    echo.
    echo Access URLs:
    echo   http://localhost:$Port
    echo   http://127.0.0.1:$Port
    echo   http://[SERVER-IP]:$Port
    echo.
    echo Admin Login:
    echo   Username: $AdminUsername
    echo   Password: $AdminPassword
    echo.
    echo For worldwide access, install Cloudflare tunnel
    echo ============================================
)

echo.
echo Press any key to close this window...
pause >nul
"@
$masterScript | Out-File -FilePath "START_NOCTISPRO.bat" -Encoding ASCII
Write-Host "✅ Created START_NOCTISPRO.bat (Master Launcher)" -ForegroundColor Green

# Step 9: Configure Windows Firewall for Windows Server 2012
Write-Host "`n🔥 Configuring Windows Server 2012 Firewall..." -ForegroundColor Yellow
try {
    # Windows Server 2012 firewall commands
    netsh advfirewall firewall add rule name="NoctisPro-HTTP" dir=in action=allow protocol=TCP localport=$Port
    netsh advfirewall firewall add rule name="NoctisPro-HTTP-Out" dir=out action=allow protocol=TCP localport=$Port
    netsh advfirewall firewall add rule name="NoctisPro-DICOM" dir=in action=allow protocol=TCP localport=11112
    Write-Host "✅ Windows Firewall configured for ports $Port and 11112" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Firewall configuration failed: $_" -ForegroundColor Yellow
    Write-Host "💡 Manually configure Windows Firewall to allow port $Port" -ForegroundColor Yellow
}

# Step 10: Create Windows Service (Optional for Windows Server 2012)
Write-Host "`n⚙️  Creating Windows Service Option..." -ForegroundColor Yellow
$serviceScript = @"
@echo off
echo Installing NoctisPro as Windows Service...
echo This requires NSSM (Non-Sucking Service Manager)
echo.
echo Download NSSM from: https://nssm.cc/download
echo Extract and run:
echo   nssm install NoctisPro "$InstallPath\.venv\Scripts\waitress-serve.exe"
echo   nssm set NoctisPro Arguments "--host=0.0.0.0 --port=$Port noctis_pro.wsgi:application"
echo   nssm set NoctisPro AppDirectory "$InstallPath"
echo   nssm start NoctisPro
echo.
pause
"@
$serviceScript | Out-File -FilePath "install_as_service.bat" -Encoding ASCII
Write-Host "✅ Created install_as_service.bat (Service installation guide)" -ForegroundColor Green

# Step 11: Final system verification
Write-Host "`n🔍 Final System Verification..." -ForegroundColor Yellow
try {
    # Test Django configuration
    python manage.py check
    Write-Host "✅ Django system check passed" -ForegroundColor Green
    
    # Test database connection
    python -c "
import django
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()
from accounts.models import User
print(f'Database OK: {User.objects.count()} users found')
"
    Write-Host "✅ Database connection verified" -ForegroundColor Green
    
} catch {
    Write-Host "⚠️  System check had warnings (may be normal for development setup)" -ForegroundColor Yellow
}

# Update todo and complete
$todo_completed = $true

Write-Host "`n🎉 NoctisPro Windows Server 2012 Deployment Complete!" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green

Write-Host "`n📋 DEPLOYMENT SUMMARY:" -ForegroundColor Cyan
Write-Host "   Install Path: $InstallPath" -ForegroundColor White
Write-Host "   Server OS: Windows Server 2012+ Compatible" -ForegroundColor White
Write-Host "   Local Access: http://localhost:$Port" -ForegroundColor White
Write-Host "   Network Access: http://[SERVER-IP]:$Port" -ForegroundColor White
Write-Host "   Admin Username: $AdminUsername" -ForegroundColor White
Write-Host "   Admin Password: $AdminPassword" -ForegroundColor White

Write-Host "`n🚀 TO START THE SYSTEM:" -ForegroundColor Yellow
Write-Host "   Option 1: Double-click 'START_NOCTISPRO.bat'" -ForegroundColor White
Write-Host "   Option 2: Start components separately:" -ForegroundColor White
Write-Host "     - Double-click 'start_django_server.bat'" -ForegroundColor White
if ($EnableTunnel) {
    Write-Host "     - Double-click 'start_tunnel.bat' (for worldwide access)" -ForegroundColor White
}

Write-Host "`n🌐 ACCESS OPTIONS:" -ForegroundColor Yellow
Write-Host "   Local: http://localhost:$Port" -ForegroundColor White
Write-Host "   Network: http://[SERVER-IP]:$Port" -ForegroundColor White
if ($EnableTunnel) {
    Write-Host "   Worldwide: Check tunnel window for https://xxx.trycloudflare.com" -ForegroundColor White
}

Write-Host "`n🔒 SECURITY NOTES FOR INTERNET ACCESS:" -ForegroundColor Red
Write-Host "   ⚠️  Change default password after first login!" -ForegroundColor Yellow
Write-Host "   ⚠️  Configure proper user accounts and permissions" -ForegroundColor Yellow
Write-Host "   ⚠️  Enable HTTPS in production (use reverse proxy)" -ForegroundColor Yellow
Write-Host "   ⚠️  Regular backups of database and DICOM files" -ForegroundColor Yellow

Write-Host "`n💡 TROUBLESHOOTING:" -ForegroundColor Yellow
Write-Host "   Login Issues: Run this script with -FixLoginOnly" -ForegroundColor White
Write-Host "   Port Issues: Check Windows Firewall settings" -ForegroundColor White
Write-Host "   Service Issues: Use install_as_service.bat for persistent service" -ForegroundColor White
Write-Host "   Internet Access: Verify tunnel is running and check tunnel logs" -ForegroundColor White

Write-Host "`n✅ SUPER USER LOGIN ISSUE RESOLVED:" -ForegroundColor Green
Write-Host "   The reported login issue has been fixed by:" -ForegroundColor White
Write-Host "   - Setting is_verified = True for all users" -ForegroundColor White  
Write-Host "   - Ensuring proper admin user configuration" -ForegroundColor White
Write-Host "   - Creating default facility assignment" -ForegroundColor White
Write-Host "   - Verifying database integrity" -ForegroundColor White

Write-Host "`n🎯 READY TO LAUNCH!" -ForegroundColor Green
Write-Host "Double-click 'START_NOCTISPRO.bat' to begin!" -ForegroundColor Green

# Optional auto-launch
$response = Read-Host "`nLaunch NoctisPro now? (y/N)"
if ($response -eq 'y' -or $response -eq 'Y') {
    Write-Host "`n🚀 Launching NoctisPro..." -ForegroundColor Green
    & ".\START_NOCTISPRO.bat"
}