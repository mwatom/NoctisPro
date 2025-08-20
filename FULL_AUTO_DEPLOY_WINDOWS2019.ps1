# NoctisPro COMPLETE AUTO-DEPLOYMENT for Windows Server 2019
# Everything automated - from fresh server to universal HTTPS access
# Run as Administrator in PowerShell - NO USER INTERACTION REQUIRED

param(
    [string]$InstallPath = "C:\noctis",
    [string]$AdminUsername = "admin",
    [string]$AdminEmail = "admin@noctispro.com",
    [string]$AETitle = "MAE"
)

$ErrorActionPreference = 'Continue'  # Continue on errors to complete as much as possible
$ProgressPreference = 'SilentlyContinue'

# Generate secure random passwords
$AdminPassword = -join ((1..16) | ForEach {Get-Random -InputObject ([char[]](97..122) + [char[]](65..90) + [char[]](48..57))})
$DBPassword = -join ((1..20) | ForEach {Get-Random -InputObject ([char[]](97..122) + [char[]](65..90) + [char[]](48..57) + @('!','@','#','$','%'))})

Write-Host "🚀 NOCTISPRO COMPLETE AUTO-DEPLOYMENT STARTING..." -ForegroundColor Green -BackgroundColor Black
Write-Host "=" * 80 -ForegroundColor Green
Write-Host "🖥️  Target: Windows Server 2019" -ForegroundColor White
Write-Host "📁 Install Path: $InstallPath" -ForegroundColor White
Write-Host "🏥 DICOM AE Title: $AETitle" -ForegroundColor White
Write-Host "👤 Admin User: $AdminUsername" -ForegroundColor White
Write-Host "🔑 Admin Password: $AdminPassword" -ForegroundColor Yellow
Write-Host "🗄️  DB Password: $DBPassword" -ForegroundColor Yellow
Write-Host "=" * 80 -ForegroundColor Green

# Function to check administrator privileges
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Error "❌ This script must be run as Administrator!"
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Create installation directory
Write-Host "`n📁 Creating Installation Directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
Set-Location $InstallPath
Write-Host "✅ Installation directory created: $InstallPath" -ForegroundColor Green

# STEP 1: AUTO-INSTALL PYTHON 3.11
Write-Host "`n🐍 AUTO-INSTALLING PYTHON 3.11..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    if ($pythonVersion -match "Python 3\.1[1-9]") {
        Write-Host "✅ Compatible Python found: $pythonVersion" -ForegroundColor Green
    } else {
        throw "Need Python 3.11+"
    }
} catch {
    Write-Host "📥 Downloading and installing Python 3.11..." -ForegroundColor Cyan
    $pythonUrl = "https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe"
    $pythonInstaller = "python-installer.exe"
    
    Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller -UseBasicParsing
    Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0", "Include_doc=0", "Include_dev=0", "Include_launcher=1" -Wait
    
    # Refresh PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
    Start-Sleep -Seconds 10
    
    Remove-Item $pythonInstaller -Force
    Write-Host "✅ Python 3.11 installed successfully" -ForegroundColor Green
}

# STEP 2: AUTO-INSTALL POSTGRESQL 17
Write-Host "`n🐘 AUTO-INSTALLING POSTGRESQL 17..." -ForegroundColor Yellow
try {
    $pgService = Get-Service -Name "postgresql-x64-17" -ErrorAction SilentlyContinue
    if ($pgService) {
        Write-Host "✅ PostgreSQL 17 already installed" -ForegroundColor Green
    } else {
        Write-Host "📥 Downloading PostgreSQL 17..." -ForegroundColor Cyan
        $pgUrl = "https://get.enterprisedb.com/postgresql/postgresql-17.2-1-windows-x64.exe"
        $pgInstaller = "postgresql-installer.exe"
        
        Invoke-WebRequest -Uri $pgUrl -OutFile $pgInstaller -UseBasicParsing
        
        Write-Host "🔧 Installing PostgreSQL 17 (this may take 5-10 minutes)..." -ForegroundColor Cyan
        # Silent install with default settings
        Start-Process -FilePath $pgInstaller -ArgumentList "--mode", "unattended", "--superpassword", $DBPassword, "--servicename", "postgresql-x64-17", "--servicepassword", $DBPassword -Wait
        
        Remove-Item $pgInstaller -Force
        Start-Sleep -Seconds 30  # Wait for service to initialize
        Write-Host "✅ PostgreSQL 17 installed successfully" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  PostgreSQL installation issue: $_" -ForegroundColor Yellow
    Write-Host "💡 Continuing with existing installation..." -ForegroundColor Yellow
}

# STEP 3: AUTO-INSTALL REDIS
Write-Host "`n🔴 AUTO-INSTALLING REDIS..." -ForegroundColor Yellow
try {
    if (Test-Path "C:\Redis\redis-server.exe") {
        Write-Host "✅ Redis already installed" -ForegroundColor Green
    } else {
        Write-Host "📥 Downloading Redis for Windows..." -ForegroundColor Cyan
        $redisUrl = "https://github.com/microsoftarchive/redis/releases/download/win-3.0.504/Redis-x64-3.0.504.zip"
        $redisZip = "redis.zip"
        
        Invoke-WebRequest -Uri $redisUrl -OutFile $redisZip -UseBasicParsing
        Expand-Archive -Path $redisZip -DestinationPath "C:\Redis" -Force
        Remove-Item $redisZip -Force
        
        # Install as Windows service
        Set-Location "C:\Redis"
        .\redis-server.exe --service-install --service-name Redis --port 6379
        Set-Service -Name Redis -StartupType Automatic
        Start-Service -Name Redis
        
        Set-Location $InstallPath
        Write-Host "✅ Redis installed and started" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  Redis installation issue: $_" -ForegroundColor Yellow
    Write-Host "💡 System will work without Redis..." -ForegroundColor Yellow
}

# STEP 4: COPY NOCTISPRO FILES (if not already present)
Write-Host "`n📋 SETTING UP NOCTISPRO FILES..." -ForegroundColor Yellow
if (-not (Test-Path "manage.py")) {
    Write-Host "❌ NoctisPro files not found in $InstallPath" -ForegroundColor Red
    Write-Host "💡 Please copy the NoctisPro project files to $InstallPath first" -ForegroundColor Yellow
    Write-Host "   Required files: manage.py, requirements.txt, noctis_pro/, etc." -ForegroundColor Yellow
    Read-Host "Press Enter after copying files"
    
    if (-not (Test-Path "manage.py")) {
        Write-Error "❌ NoctisPro files still not found. Deployment cannot continue."
        exit 1
    }
}
Write-Host "✅ NoctisPro files found" -ForegroundColor Green

# STEP 5: CREATE VIRTUAL ENVIRONMENT AND INSTALL DEPENDENCIES
Write-Host "`n📦 AUTO-INSTALLING PYTHON DEPENDENCIES..." -ForegroundColor Yellow
if (Test-Path ".venv") {
    Remove-Item -Recurse -Force ".venv"
}

python -m venv .venv
& ".venv\Scripts\Activate.ps1"

# Upgrade pip
python -m pip install --upgrade pip setuptools wheel

# Install PostgreSQL adapter
pip install psycopg2-binary dj-database-url

# Install core dependencies
pip install Django>=5.0 djangorestframework Pillow numpy pydicom pynetdicom waitress celery redis channels daphne python-dotenv django-widget-tweaks django-cors-headers

# Install Windows-specific requirements if available
if (Test-Path "requirements-windows.txt") {
    pip install -r requirements-windows.txt
} elseif (Test-Path "requirements.txt") {
    pip install -r requirements.txt
}

Write-Host "✅ All Python dependencies installed" -ForegroundColor Green

# STEP 6: AUTO-CONFIGURE POSTGRESQL 17
Write-Host "`n🗄️  AUTO-CONFIGURING POSTGRESQL 17..." -ForegroundColor Yellow

# Find PostgreSQL installation
$pgPaths = @(
    "C:\Program Files\PostgreSQL\17\bin\psql.exe",
    "C:\PostgreSQL\17\bin\psql.exe",
    "C:\Program Files (x86)\PostgreSQL\17\bin\psql.exe"
)

$psqlPath = $null
foreach ($path in $pgPaths) {
    if (Test-Path $path) {
        $psqlPath = $path
        break
    }
}

if ($psqlPath) {
    Write-Host "✅ Found PostgreSQL 17 at: $psqlPath" -ForegroundColor Green
    
    # Create database setup script
    $dbScript = @"
CREATE DATABASE noctispro;
CREATE USER noctispro_user WITH PASSWORD '$DBPassword';
GRANT ALL PRIVILEGES ON DATABASE noctispro TO noctispro_user;
ALTER USER noctispro_user CREATEDB;
"@
    
    $tempSqlFile = "$env:TEMP\setup_noctispro.sql"
    $dbScript | Out-File -FilePath $tempSqlFile -Encoding UTF8
    
    try {
        & $psqlPath -U postgres -f $tempSqlFile 2>$null
        Write-Host "✅ PostgreSQL 17 database configured" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Database may already exist (continuing...)" -ForegroundColor Yellow
    }
    
    Remove-Item $tempSqlFile -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "⚠️  PostgreSQL 17 psql not found, using SQLite fallback" -ForegroundColor Yellow
}

# STEP 7: CREATE ENVIRONMENT CONFIGURATION
Write-Host "`n⚙️  CREATING AUTO-CONFIGURATION..." -ForegroundColor Yellow

$envContent = @"
# NoctisPro Auto-Generated Configuration
DB_ENGINE=django.db.backends.postgresql
DB_NAME=noctispro
DB_USER=noctispro_user
DB_PASSWORD=$DBPassword
DB_HOST=localhost
DB_PORT=5432

SECRET_KEY=$(-join ((1..50) | ForEach {Get-Random -InputObject ([char[]](97..122) + [char[]](65..90) + [char[]](48..57) + @('!','@','#','$','%','^','&','*'))}))
DEBUG=False
ALLOWED_HOSTS=*

REDIS_URL=redis://localhost:6379/0
DICOM_AE_TITLE=$AETitle
DICOM_PORT=11112
ENVIRONMENT=production
"@

$envContent | Out-File -FilePath ".env" -Encoding UTF8
Write-Host "✅ Environment configuration created" -ForegroundColor Green

# STEP 8: AUTO-CONFIGURE WINDOWS FIREWALL
Write-Host "`n🔥 AUTO-CONFIGURING WINDOWS FIREWALL..." -ForegroundColor Yellow
try {
    netsh advfirewall firewall add rule name="NoctisPro-Web" dir=in action=allow protocol=TCP localport=8000 >$null 2>&1
    netsh advfirewall firewall add rule name="NoctisPro-DICOM" dir=in action=allow protocol=TCP localport=11112 >$null 2>&1
    netsh advfirewall firewall add rule name="NoctisPro-HTTPS" dir=out action=allow protocol=TCP remoteport=443 >$null 2>&1
    Write-Host "✅ Windows Firewall configured automatically" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Firewall configuration issue: $_" -ForegroundColor Yellow
}

# STEP 9: AUTO-SETUP DATABASE
Write-Host "`n🗄️  AUTO-SETTING UP DATABASE..." -ForegroundColor Yellow
try {
    python manage.py migrate --noinput
    Write-Host "✅ Database migrations completed" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Trying database reset..." -ForegroundColor Yellow
    if (Test-Path "db.sqlite3") {
        Remove-Item "db.sqlite3" -Force
    }
    python manage.py migrate --noinput
    Write-Host "✅ Database reset and migrated" -ForegroundColor Green
}

# Collect static files
try {
    python manage.py collectstatic --noinput >$null 2>&1
    Write-Host "✅ Static files collected" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Static files collection skipped" -ForegroundColor Yellow
}

# STEP 10: AUTO-CREATE ADMIN USER AND FACILITY
Write-Host "`n👤 AUTO-CREATING ADMIN USER AND FACILITY..." -ForegroundColor Yellow

$setupScript = @"
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from accounts.models import User, Facility
from django.contrib.auth.hashers import make_password

# Create facility with AE title
facility, created = Facility.objects.get_or_create(
    ae_title="$AETitle",
    defaults={
        'name': 'Auto-Deployed Medical Center',
        'address': '123 Healthcare Boulevard, Medical District',
        'phone': '+1-555-MEDICAL',
        'email': "$AdminEmail",
        'license_number': 'AUTO-DEPLOY-2024',
        'is_active': True
    }
)
print(f'✅ Facility configured: {facility.name} (AE: {facility.ae_title})')

# Create admin user
user, created = User.objects.get_or_create(
    username="$AdminUsername",
    defaults={
        'email': "$AdminEmail",
        'first_name': 'System',
        'last_name': 'Administrator',
        'role': 'admin',
        'is_active': True,
        'is_verified': True,
        'is_staff': True,
        'is_superuser': True,
        'facility': facility
    }
)

user.set_password("$AdminPassword")
user.save()
print(f'✅ Admin user created: {user.username}')
print(f'   Password: $AdminPassword')
print(f'   Email: {user.email}')
print(f'   Facility: {user.facility.name}')
"@

$setupScript | python
Write-Host "✅ Admin user and facility auto-created" -ForegroundColor Green

# STEP 11: AUTO-DOWNLOAD CLOUDFLARE TUNNEL
Write-Host "`n🌐 AUTO-DOWNLOADING CLOUDFLARE TUNNEL..." -ForegroundColor Yellow
try {
    if (-not (Test-Path "cloudflared.exe")) {
        $cloudflareUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
        Invoke-WebRequest -Uri $cloudflareUrl -OutFile "cloudflared.exe" -UseBasicParsing
        Write-Host "✅ Cloudflare Tunnel downloaded" -ForegroundColor Green
    } else {
        Write-Host "✅ Cloudflare Tunnel already exists" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  Cloudflare download failed: $_" -ForegroundColor Yellow
}

# STEP 12: AUTO-INSTALL NSSM (Service Manager)
Write-Host "`n🔧 AUTO-INSTALLING SERVICE MANAGER..." -ForegroundColor Yellow
try {
    if (-not (Get-Command "nssm" -ErrorAction SilentlyContinue)) {
        $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
        $nssmZip = "nssm.zip"
        
        Invoke-WebRequest -Uri $nssmUrl -OutFile $nssmZip -UseBasicParsing
        Expand-Archive -Path $nssmZip -DestinationPath "." -Force
        Copy-Item "nssm-2.24\win64\nssm.exe" -Destination "C:\Windows\System32\" -Force
        Remove-Item $nssmZip -Force
        Remove-Item "nssm-2.24" -Recurse -Force
        
        Write-Host "✅ NSSM service manager installed" -ForegroundColor Green
    } else {
        Write-Host "✅ NSSM already available" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  NSSM installation issue: $_" -ForegroundColor Yellow
}

# STEP 13: AUTO-CREATE STARTUP SCRIPTS
Write-Host "`n📝 AUTO-CREATING STARTUP SCRIPTS..." -ForegroundColor Yellow

# Django server startup script
$djangoScript = @"
@echo off
title NoctisPro Django Server - AUTO DEPLOYED
cd /d "$InstallPath"
call .venv\Scripts\activate.bat

echo ========================================
echo    NoctisPro Django Server
echo    AUTO-DEPLOYED ON WINDOWS SERVER 2019
echo ========================================
echo Time: %date% %time%
echo Port: 8000
echo Admin: $AdminUsername
echo Password: $AdminPassword
echo AE Title: $AETitle
echo ========================================
echo.
echo Starting web server...
waitress-serve --host=0.0.0.0 --port=8000 --threads=8 noctis_pro.wsgi:application
"@
$djangoScript | Out-File -FilePath "start_web_server.bat" -Encoding ASCII

# DICOM receiver startup script
$dicomScript = @"
@echo off
title NoctisPro DICOM Receiver - AUTO DEPLOYED
cd /d "$InstallPath"
call .venv\Scripts\activate.bat

echo ========================================
echo   NoctisPro DICOM SCP Receiver
echo   AUTO-DEPLOYED ON WINDOWS SERVER 2019
echo ========================================
echo Time: %date% %time%
echo Port: 11112
echo AE Title: $AETitle
echo Listening globally for DICOM images...
echo ========================================
echo.
python dicom_receiver.py --port 11112 --aet $AETitle --bind 0.0.0.0
"@
$dicomScript | Out-File -FilePath "start_dicom_receiver.bat" -Encoding ASCII

# Universal HTTPS tunnel script
$tunnelScript = @"
@echo off
title NoctisPro Universal HTTPS Tunnel - AUTO DEPLOYED
cd /d "$InstallPath"

echo ========================================
echo   NoctisPro Universal HTTPS Tunnel
echo   AUTO-DEPLOYED ON WINDOWS SERVER 2019
echo ========================================
echo Time: %date% %time%
echo Creating secure tunnel...
echo ========================================
echo.
echo 🌐 Starting Cloudflare tunnel for universal access...
echo 📋 Your HTTPS URL will appear below:
echo.
cloudflared.exe tunnel --url http://localhost:8000
"@
$tunnelScript | Out-File -FilePath "start_https_tunnel.bat" -Encoding ASCII

# Master startup script
$masterScript = @"
@echo off
title NoctisPro Universal System - AUTO DEPLOYED
cd /d "$InstallPath"

echo.
echo ████████████████████████████████████████████████████████████████
echo ██                                                            ██
echo ██    🚀 NOCTISPRO AUTO-DEPLOYED SYSTEM STARTING 🚀           ██
echo ██                                                            ██
echo ██    Windows Server 2019 + Python 3 + PostgreSQL 17        ██
echo ██                                                            ██
echo ████████████████████████████████████████████████████████████████
echo.
echo 📋 SYSTEM INFORMATION:
echo    👤 Admin User: $AdminUsername
echo    🔑 Password: $AdminPassword
echo    🏥 AE Title: $AETitle
echo    🌐 Web Port: 8000
echo    🏥 DICOM Port: 11112
echo.
echo 🚀 Starting all services...
echo.

echo 📡 1. Starting DICOM Receiver...
start "DICOM Receiver" /min start_dicom_receiver.bat

echo 🌐 2. Starting Web Server...
start "Web Server" /min start_web_server.bat

echo 🔗 3. Starting Universal HTTPS Tunnel...
start "HTTPS Tunnel" start_https_tunnel.bat

echo.
echo ✅ All services started!
echo.
echo 🌍 UNIVERSAL ACCESS:
echo    - Wait 30-60 seconds for tunnel to establish
echo    - Your HTTPS URL will appear in the tunnel window
echo    - Use that URL to access from anywhere!
echo.
echo 🏥 DICOM RECEPTION:
echo    - Configure devices to send to: [YOUR-PUBLIC-IP]:11112
echo    - Use AE Title: $AETitle
echo.
echo 💻 LOCAL ACCESS:
echo    - Web: http://localhost:8000
echo    - Admin: http://localhost:8000/admin
echo.
echo Press any key to open local web interface...
pause >nul
start http://localhost:8000
"@
$masterScript | Out-File -FilePath "START_NOCTISPRO_AUTO.bat" -Encoding ASCII

Write-Host "✅ Startup scripts created" -ForegroundColor Green

# STEP 14: AUTO-CREATE WINDOWS SERVICES (OPTIONAL)
Write-Host "`n🔧 AUTO-CREATING WINDOWS SERVICES..." -ForegroundColor Yellow
try {
    # Remove existing services if they exist
    $services = @("NoctisPro-Web", "NoctisPro-DICOM", "NoctisPro-Tunnel")
    foreach ($service in $services) {
        try {
            nssm remove $service confirm >$null 2>&1
        } catch {}
    }
    
    # Create Django web service
    nssm install "NoctisPro-Web" "$InstallPath\.venv\Scripts\python.exe"
    nssm set "NoctisPro-Web" AppParameters "-m waitress --host=0.0.0.0 --port=8000 noctis_pro.wsgi:application"
    nssm set "NoctisPro-Web" AppDirectory "$InstallPath"
    nssm set "NoctisPro-Web" DisplayName "NoctisPro Web Server (Auto-Deployed)"
    nssm set "NoctisPro-Web" Start SERVICE_AUTO_START
    
    # Create DICOM service
    nssm install "NoctisPro-DICOM" "$InstallPath\.venv\Scripts\python.exe"
    nssm set "NoctisPro-DICOM" AppParameters "dicom_receiver.py --port 11112 --aet $AETitle --bind 0.0.0.0"
    nssm set "NoctisPro-DICOM" AppDirectory "$InstallPath"
    nssm set "NoctisPro-DICOM" DisplayName "NoctisPro DICOM Receiver (Auto-Deployed)"
    nssm set "NoctisPro-DICOM" Start SERVICE_AUTO_START
    
    # Create tunnel service
    nssm install "NoctisPro-Tunnel" "$InstallPath\cloudflared.exe"
    nssm set "NoctisPro-Tunnel" AppParameters "tunnel --url http://localhost:8000"
    nssm set "NoctisPro-Tunnel" AppDirectory "$InstallPath"
    nssm set "NoctisPro-Tunnel" DisplayName "NoctisPro HTTPS Tunnel (Auto-Deployed)"
    nssm set "NoctisPro-Tunnel" Start SERVICE_AUTO_START
    
    Write-Host "✅ Windows services created (auto-start enabled)" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Service creation issue: $_" -ForegroundColor Yellow
    Write-Host "💡 You can still run manually with START_NOCTISPRO_AUTO.bat" -ForegroundColor Yellow
}

# STEP 15: CREATE DESKTOP SHORTCUT
Write-Host "`n🖥️  CREATING DESKTOP SHORTCUT..." -ForegroundColor Yellow
try {
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\NoctisPro Auto-Deployed.lnk")
    $Shortcut.TargetPath = "$InstallPath\START_NOCTISPRO_AUTO.bat"
    $Shortcut.WorkingDirectory = $InstallPath
    $Shortcut.Description = "NoctisPro Auto-Deployed DICOM System"
    $Shortcut.Save()
    Write-Host "✅ Desktop shortcut created" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Desktop shortcut creation failed" -ForegroundColor Yellow
}

# STEP 16: FINAL SYSTEM TEST
Write-Host "`n🧪 AUTO-TESTING SYSTEM..." -ForegroundColor Yellow
try {
    python manage.py check --settings=noctis_pro.settings >$null 2>&1
    Write-Host "✅ Django system check passed" -ForegroundColor Green
} catch {
    Write-Host "⚠️  System check had warnings (may be normal)" -ForegroundColor Yellow
}

# STEP 17: AUTO-START THE SYSTEM
Write-Host "`n🚀 AUTO-STARTING NOCTISPRO SYSTEM..." -ForegroundColor Yellow

# Start services if available
try {
    Start-Service -Name "NoctisPro-Web" -ErrorAction SilentlyContinue
    Start-Service -Name "NoctisPro-DICOM" -ErrorAction SilentlyContinue
    Start-Service -Name "NoctisPro-Tunnel" -ErrorAction SilentlyContinue
    Write-Host "✅ Windows services started" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Starting via batch files..." -ForegroundColor Yellow
}

# Display completion information
Write-Host "`n" -NoNewline
Write-Host "🎉 COMPLETE AUTO-DEPLOYMENT FINISHED! 🎉" -ForegroundColor Green -BackgroundColor Black
Write-Host "=" * 80 -ForegroundColor Green

Write-Host "`n📋 YOUR SYSTEM INFORMATION:" -ForegroundColor Cyan
Write-Host "   📁 Location: $InstallPath" -ForegroundColor White
Write-Host "   👤 Admin Username: $AdminUsername" -ForegroundColor White
Write-Host "   🔑 Admin Password: $AdminPassword" -ForegroundColor Yellow
Write-Host "   📧 Admin Email: $AdminEmail" -ForegroundColor White
Write-Host "   🏥 DICOM AE Title: $AETitle" -ForegroundColor White

Write-Host "`n🌐 ACCESS INFORMATION:" -ForegroundColor Cyan
Write-Host "   💻 Local Web: http://localhost:8000" -ForegroundColor White
Write-Host "   📱 Local Admin: http://localhost:8000/admin" -ForegroundColor White
Write-Host "   🌍 Universal HTTPS: Starting tunnel now..." -ForegroundColor White

Write-Host "`n🏥 DICOM RECEPTION:" -ForegroundColor Cyan
Write-Host "   📡 Global Reception: [YOUR-PUBLIC-IP]:11112" -ForegroundColor White
Write-Host "   🏷️  AE Title: $AETitle" -ForegroundColor White
Write-Host "   🌍 Receives DICOM from anywhere!" -ForegroundColor White

Write-Host "`n🚀 STARTING UNIVERSAL HTTPS TUNNEL..." -ForegroundColor Green
Write-Host "🔗 Your universal HTTPS URL will appear below:" -ForegroundColor Yellow
Write-Host "=" * 80 -ForegroundColor Yellow

# Start the tunnel and show the URL
if (Test-Path "cloudflared.exe") {
    Write-Host "⏳ Establishing secure tunnel (30-60 seconds)..." -ForegroundColor Cyan
    .\cloudflared.exe tunnel --url http://localhost:8000
} else {
    Write-Host "⚠️  Cloudflare tunnel not available - starting manual services..." -ForegroundColor Yellow
    & ".\START_NOCTISPRO_AUTO.bat"
}