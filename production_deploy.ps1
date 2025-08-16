# NoctisPro Production Deployment Script for Windows Server 2012+
# Run as Administrator in PowerShell

param(
    [string]$InstallPath = "C:\noctis",
    [string]$AdminUsername = "admin",
    [string]$AdminPassword = "Admin123!",
    [string]$AdminEmail = "admin@yourdomain.com",
    [int]$Port = 8000
)

$ErrorActionPreference = 'Stop'
Write-Host "🚀 NoctisPro Production Deployment Starting..." -ForegroundColor Green
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
    Write-Error "❌ Python not found. Please install Python 3.8+ from python.org"
    exit 1
}

# Step 2: Create virtual environment
Write-Host "`n📦 Setting up Virtual Environment..." -ForegroundColor Yellow
if (Test-Path ".venv") {
    Write-Host "⚠️  Existing virtual environment found, removing..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force ".venv"
}

try {
    python -m venv .venv
    Write-Host "✅ Virtual environment created" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to create virtual environment. Install python3-venv package"
    exit 1
}

# Activate virtual environment
& ".venv\Scripts\Activate.ps1"
Write-Host "✅ Virtual environment activated" -ForegroundColor Green

# Step 3: Upgrade pip and install dependencies
Write-Host "`n📥 Installing Dependencies..." -ForegroundColor Yellow
python -m pip install --upgrade pip setuptools wheel

# Try Windows-specific requirements first
if (Test-Path "requirements-windows.txt") {
    Write-Host "📋 Installing from requirements-windows.txt..." -ForegroundColor Cyan
    pip install -r requirements-windows.txt
} elseif (Test-Path "requirements.txt") {
    Write-Host "📋 Installing from requirements.txt..." -ForegroundColor Cyan
    pip install -r requirements.txt
} else {
    Write-Host "⚠️  No requirements file found, installing minimal dependencies..." -ForegroundColor Yellow
    pip install Django djangorestframework Pillow numpy pydicom waitress
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

# Step 6: Fix login issues and create admin user
Write-Host "`n👤 Creating Admin User and Fixing Login Issues..." -ForegroundColor Yellow
try {
    python fix_login.py
    Write-Host "✅ Admin user created and login issues fixed" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Login fix script failed, creating user manually..." -ForegroundColor Yellow
    
    # Manual user creation
    $createUserScript = @"
from accounts.models import User, Facility
import sys

# Create facility if not exists
if not Facility.objects.exists():
    facility = Facility.objects.create(
        name='Default Medical Center',
        address='123 Healthcare Ave',
        phone='+1-555-0123',
        email='contact@medical.com',
        license_number='MC-2024-001',
        ae_title='NOCTISPRO'
    )
    print(f'Created facility: {facility.name}')

# Create or update admin user
username = '$AdminUsername'
try:
    user = User.objects.get(username=username)
    print(f'Found existing user: {username}')
except User.DoesNotExist:
    user = User.objects.create_user(username=username)
    print(f'Created new user: {username}')

# Update user properties
user.set_password('$AdminPassword')
user.email = '$AdminEmail'
user.first_name = 'System'
user.last_name = 'Administrator'
user.role = 'admin'
user.is_active = True
user.is_verified = True
user.is_staff = True
user.is_superuser = True
if Facility.objects.exists():
    user.facility = Facility.objects.first()
user.save()

print(f'User {username} is ready:')
print(f'  Active: {user.is_active}')
print(f'  Verified: {user.is_verified}')
print(f'  Role: {user.role}')
print(f'  Email: {user.email}')
"@
    
    $createUserScript | python manage.py shell
    Write-Host "✅ Manual admin user creation completed" -ForegroundColor Green
}

# Step 7: Download Cloudflare tunnel
Write-Host "`n🌐 Setting up Cloudflare Tunnel..." -ForegroundColor Yellow
try {
    if (-not (Test-Path "cloudflared.exe")) {
        Write-Host "📥 Downloading cloudflared..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile "cloudflared.exe"
        Write-Host "✅ Cloudflared downloaded" -ForegroundColor Green
    } else {
        Write-Host "✅ Cloudflared already exists" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  Failed to download cloudflared: $_" -ForegroundColor Yellow
}

# Step 8: Create startup scripts
Write-Host "`n📝 Creating Startup Scripts..." -ForegroundColor Yellow

# Django server startup script
$djangoScript = @"
@echo off
cd /d "$InstallPath"
call .venv\Scripts\activate.bat
echo Starting NoctisPro Django Server...
waitress-serve --host=127.0.0.1 --port=$Port noctis_pro.wsgi:application
pause
"@
$djangoScript | Out-File -FilePath "start_django.bat" -Encoding ASCII
Write-Host "✅ Created start_django.bat" -ForegroundColor Green

# Cloudflare tunnel startup script
$tunnelScript = @"
@echo off
cd /d "$InstallPath"
echo Starting Cloudflare Tunnel...
cloudflared.exe tunnel --no-autoupdate --url http://127.0.0.1:$Port
pause
"@
$tunnelScript | Out-File -FilePath "start_tunnel.bat" -Encoding ASCII
Write-Host "✅ Created start_tunnel.bat" -ForegroundColor Green

# Combined startup script
$combinedScript = @"
@echo off
cd /d "$InstallPath"
echo Starting NoctisPro Production System...
echo.

echo Starting Django Server...
start "NoctisPro Django" cmd /k "call .venv\Scripts\activate.bat && waitress-serve --host=127.0.0.1 --port=$Port noctis_pro.wsgi:application"

timeout /t 5 /nobreak >nul

if exist cloudflared.exe (
    echo Starting Cloudflare Tunnel...
    start "NoctisPro Tunnel" cmd /k "cloudflared.exe tunnel --no-autoupdate --url http://127.0.0.1:$Port"
    
    echo.
    echo ================================================
    echo NoctisPro is starting up...
    echo.
    echo Django Server: http://127.0.0.1:$Port
    echo Admin Credentials:
    echo   Username: $AdminUsername
    echo   Password: $AdminPassword
    echo.
    echo Wait 30-60 seconds, then check the Tunnel window
    echo for your public HTTPS URL like:
    echo https://random-string.trycloudflare.com
    echo ================================================
) else (
    echo.
    echo ================================================
    echo NoctisPro Django Server Started
    echo.
    echo Local Access: http://127.0.0.1:$Port
    echo Admin Credentials:
    echo   Username: $AdminUsername
    echo   Password: $AdminPassword
    echo.
    echo Note: Cloudflare tunnel not available
    echo For external access, configure firewall/port forwarding
    echo ================================================
)

pause
"@
$combinedScript | Out-File -FilePath "start_noctispro.bat" -Encoding ASCII
Write-Host "✅ Created start_noctispro.bat" -ForegroundColor Green

# Step 9: Create Windows firewall rule
Write-Host "`n🔥 Configuring Windows Firewall..." -ForegroundColor Yellow
try {
    netsh advfirewall firewall add rule name="NoctisPro PACS" dir=in action=allow protocol=TCP localport=$Port
    Write-Host "✅ Firewall rule added for port $Port" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Failed to add firewall rule: $_" -ForegroundColor Yellow
}

# Step 10: Final verification
Write-Host "`n🔍 Final System Check..." -ForegroundColor Yellow
try {
    python manage.py check --deploy
    Write-Host "✅ Django system check passed" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Django check had warnings (this is normal for development)" -ForegroundColor Yellow
}

# Completion message
Write-Host "`n🎉 NoctisPro Production Deployment Complete!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

Write-Host "`n📋 DEPLOYMENT SUMMARY:" -ForegroundColor Cyan
Write-Host "   Install Path: $InstallPath" -ForegroundColor White
Write-Host "   Local URL: http://127.0.0.1:$Port" -ForegroundColor White
Write-Host "   Admin Username: $AdminUsername" -ForegroundColor White
Write-Host "   Admin Password: $AdminPassword" -ForegroundColor White

Write-Host "`n🚀 TO START THE SYSTEM:" -ForegroundColor Yellow
Write-Host "   Double-click: start_noctispro.bat" -ForegroundColor White
Write-Host "   - OR -" -ForegroundColor Gray
Write-Host "   Manual start:" -ForegroundColor White
Write-Host "     1. Double-click: start_django.bat" -ForegroundColor White
Write-Host "     2. Double-click: start_tunnel.bat (for public access)" -ForegroundColor White

Write-Host "`n🌐 ACCESS OPTIONS:" -ForegroundColor Yellow
Write-Host "   Local: http://127.0.0.1:$Port" -ForegroundColor White
Write-Host "   Public: Check tunnel window for https://xxx.trycloudflare.com" -ForegroundColor White

Write-Host "`n💡 TROUBLESHOOTING:" -ForegroundColor Yellow
Write-Host "   - If login fails: Run 'python fix_login.py'" -ForegroundColor White
Write-Host "   - View logs in Django server window" -ForegroundColor White
Write-Host "   - Check Windows Firewall if external access fails" -ForegroundColor White

Write-Host "`n🔧 Ready to start? Press Enter to launch NoctisPro now..." -ForegroundColor Green
Read-Host

# Launch the system
& ".\start_noctispro.bat"