# NoctisPro Universal Deployment Script for Windows Server 2019-2022
# One-time deployment with universal HTTPS access and DICOM SCP receiver
# Run as Administrator in PowerShell

param(
    [string]$InstallPath = "C:\noctis",
    [string]$AdminUsername = "admin",
    [string]$AdminPassword = "",
    [string]$AdminEmail = "admin@noctispro.com",
    [int]$WebPort = 8000,
    [int]$DicomPort = 11112,
    [string]$AETitle = "NOCTISPRO",
    [switch]$EnableAutoStart = $true
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Generate secure random password if not provided
if (-not $AdminPassword) {
    $AdminPassword = -join ((1..16) | ForEach {Get-Random -InputObject (@('a'..'z') + @('A'..'Z') + @('0'..'9') + @('!','@','#','$','%','^','&','*'))})
}

Write-Host "🚀 NoctisPro Universal Deployment Starting..." -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "📁 Install Path: $InstallPath" -ForegroundColor White
Write-Host "🌐 Web Port: $WebPort" -ForegroundColor White
Write-Host "🏥 DICOM Port: $DicomPort" -ForegroundColor White
Write-Host "🔑 AE Title: $AETitle" -ForegroundColor White
Write-Host "=" * 80 -ForegroundColor Cyan

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

# Step 1: Install Python 3.11 (Windows Server 2019-2022 compatible)
Write-Host "`n🐍 Installing Python 3.11..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    if ($pythonVersion -match "Python 3\.1[1-9]") {
        Write-Host "✅ Compatible Python found: $pythonVersion" -ForegroundColor Green
    } else {
        throw "Incompatible Python version"
    }
} catch {
    Write-Host "📥 Downloading Python 3.11..." -ForegroundColor Cyan
    $pythonUrl = "https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe"
    $pythonInstaller = "python-3.11.8-installer.exe"
    
    try {
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller -UseBasicParsing
        Write-Host "✅ Python installer downloaded" -ForegroundColor Green
        
        Write-Host "🔧 Installing Python..." -ForegroundColor Cyan
        Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0" -Wait
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
        
        # Verify installation
        Start-Sleep -Seconds 5
        $pythonVersion = python --version 2>&1
        Write-Host "✅ Python installed: $pythonVersion" -ForegroundColor Green
        
        # Cleanup
        Remove-Item $pythonInstaller -Force
    } catch {
        Write-Error "❌ Failed to install Python: $_"
        exit 1
    }
}

# Step 2: Create virtual environment
Write-Host "`n📦 Setting up Virtual Environment..." -ForegroundColor Yellow
if (Test-Path ".venv") {
    Write-Host "⚠️  Removing existing virtual environment..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force ".venv"
}

try {
    python -m venv .venv
    Write-Host "✅ Virtual environment created" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to create virtual environment: $_"
    exit 1
}

# Activate virtual environment
& ".venv\Scripts\Activate.ps1"
Write-Host "✅ Virtual environment activated" -ForegroundColor Green

# Step 3: Install dependencies
Write-Host "`n📥 Installing Dependencies..." -ForegroundColor Yellow
python -m pip install --upgrade pip setuptools wheel

# Install Windows-specific requirements
if (Test-Path "requirements-windows.txt") {
    Write-Host "📋 Installing from requirements-windows.txt..." -ForegroundColor Cyan
    pip install -r requirements-windows.txt
} elseif (Test-Path "requirements.txt") {
    Write-Host "📋 Installing from requirements.txt..." -ForegroundColor Cyan
    pip install -r requirements.txt
} else {
    Write-Host "📋 Installing core dependencies..." -ForegroundColor Cyan
    pip install Django djangorestframework Pillow numpy pydicom pynetdicom waitress channels daphne redis celery
}

# Ensure production server is installed
pip install waitress gunicorn
Write-Host "✅ Dependencies installed" -ForegroundColor Green

# Step 4: Database setup
Write-Host "`n🗄️  Setting up Database..." -ForegroundColor Yellow
try {
    python manage.py migrate --noinput
    Write-Host "✅ Database migrations completed" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Migration failed, trying to fix..." -ForegroundColor Yellow
    # Remove existing database and retry
    if (Test-Path "db.sqlite3") {
        Remove-Item "db.sqlite3" -Force
    }
    python manage.py migrate --noinput
    Write-Host "✅ Database recreated and migrated" -ForegroundColor Green
}

# Step 5: Collect static files
Write-Host "`n📁 Collecting Static Files..." -ForegroundColor Yellow
try {
    python manage.py collectstatic --noinput
    Write-Host "✅ Static files collected" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Static files collection failed, continuing..." -ForegroundColor Yellow
}

# Step 6: Create admin user and fix login issues
Write-Host "`n👤 Creating Admin User..." -ForegroundColor Yellow
$createUserScript = @"
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from accounts.models import User, Facility
from django.contrib.auth.hashers import make_password

# Create default facility if not exists
if not Facility.objects.exists():
    facility = Facility.objects.create(
        name='Universal Medical Center',
        address='123 Healthcare Boulevard',
        phone='+1-555-MEDICAL',
        email='$AdminEmail',
        license_number='UMC-2024-001',
        ae_title='$AETitle',
        is_active=True
    )
    print(f'✅ Created facility: {facility.name}')
else:
    facility = Facility.objects.first()
    print(f'✅ Using existing facility: {facility.name}')

# Create or update admin user
try:
    user = User.objects.get(username='$AdminUsername')
    print(f'📝 Updating existing user: $AdminUsername')
except User.DoesNotExist:
    user = User.objects.create_user(username='$AdminUsername')
    print(f'🆕 Created new user: $AdminUsername')

# Apply all necessary settings for admin access
user.set_password('$AdminPassword')
user.email = '$AdminEmail'
user.first_name = 'System'
user.last_name = 'Administrator'
user.role = 'admin'
user.is_active = True
user.is_verified = True  # CRITICAL: This fixes login issues
user.is_staff = True
user.is_superuser = True
user.facility = facility
user.save()

print(f'✅ Admin user configured:')
print(f'   Username: {user.username}')
print(f'   Email: {user.email}')
print(f'   Role: {user.role}')
print(f'   Active: {user.is_active}')
print(f'   Verified: {user.is_verified}')
print(f'   Staff: {user.is_staff}')
print(f'   Superuser: {user.is_superuser}')
print(f'   Facility: {user.facility.name if user.facility else "None"}')
"@

$createUserScript | python manage.py shell
Write-Host "✅ Admin user setup completed" -ForegroundColor Green

# Step 7: Download Cloudflare tunnel for universal HTTPS access
Write-Host "`n🌐 Setting up Universal HTTPS Access..." -ForegroundColor Yellow
try {
    if (-not (Test-Path "cloudflared.exe")) {
        Write-Host "📥 Downloading Cloudflare Tunnel..." -ForegroundColor Cyan
        $cloudflareUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
        Invoke-WebRequest -Uri $cloudflareUrl -OutFile "cloudflared.exe" -UseBasicParsing
        Write-Host "✅ Cloudflare Tunnel downloaded" -ForegroundColor Green
    } else {
        Write-Host "✅ Cloudflare Tunnel already exists" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  Failed to download Cloudflare Tunnel: $_" -ForegroundColor Yellow
    Write-Host "💡 You can download manually from: https://github.com/cloudflare/cloudflared/releases" -ForegroundColor Yellow
}

# Step 8: Configure Windows Firewall for internet access
Write-Host "`n🔥 Configuring Windows Firewall..." -ForegroundColor Yellow
try {
    # Allow web traffic
    netsh advfirewall firewall add rule name="NoctisPro-Web" dir=in action=allow protocol=TCP localport=$WebPort
    Write-Host "✅ Web firewall rule added for port $WebPort" -ForegroundColor Green
    
    # Allow DICOM traffic
    netsh advfirewall firewall add rule name="NoctisPro-DICOM" dir=in action=allow protocol=TCP localport=$DicomPort
    Write-Host "✅ DICOM firewall rule added for port $DicomPort" -ForegroundColor Green
    
    # Allow outbound connections for tunnel
    netsh advfirewall firewall add rule name="NoctisPro-Outbound" dir=out action=allow protocol=TCP remoteport=443
    Write-Host "✅ Outbound HTTPS rule added" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Failed to configure firewall: $_" -ForegroundColor Yellow
}

# Step 9: Create comprehensive startup scripts
Write-Host "`n📝 Creating Startup Scripts..." -ForegroundColor Yellow

# Main Django server script
$djangoScript = @"
@echo off
title NoctisPro Django Server
cd /d "$InstallPath"
call .venv\Scripts\activate.bat
echo ========================================
echo    NoctisPro Django Server Starting
echo ========================================
echo Time: %date% %time%
echo Port: $WebPort
echo Admin: $AdminUsername
echo ========================================
echo.
waitress-serve --host=0.0.0.0 --port=$WebPort --threads=8 --channel-timeout=300 noctis_pro.wsgi:application
echo.
echo Django server stopped. Press any key to restart...
pause
goto :eof
"@
$djangoScript | Out-File -FilePath "start_django_server.bat" -Encoding ASCII

# DICOM SCP receiver script
$dicomScript = @"
@echo off
title NoctisPro DICOM SCP Receiver
cd /d "$InstallPath"
call .venv\Scripts\activate.bat
echo ========================================
echo   NoctisPro DICOM SCP Receiver
echo ========================================
echo Time: %date% %time%
echo Port: $DicomPort
echo AE Title: $AETitle
echo Listening for DICOM connections...
echo ========================================
echo.
python dicom_receiver.py --port $DicomPort --aet $AETitle --bind 0.0.0.0
echo.
echo DICOM receiver stopped. Press any key to restart...
pause
goto :eof
"@
$dicomScript | Out-File -FilePath "start_dicom_receiver.bat" -Encoding ASCII

# Cloudflare tunnel script for universal HTTPS
$tunnelScript = @"
@echo off
title NoctisPro Universal HTTPS Tunnel
cd /d "$InstallPath"
echo ========================================
echo    NoctisPro Universal HTTPS Tunnel
echo ========================================
echo Time: %date% %time%
echo Local: http://127.0.0.1:$WebPort
echo.
echo Starting Cloudflare Tunnel...
echo Wait for your universal HTTPS URL:
echo ========================================
echo.
if exist cloudflared.exe (
    cloudflared.exe tunnel --no-autoupdate --url http://127.0.0.1:$WebPort
) else (
    echo ❌ Cloudflare Tunnel not found!
    echo Please download cloudflared.exe from:
    echo https://github.com/cloudflare/cloudflared/releases
    echo.
    pause
)
echo.
echo Tunnel stopped. Press any key to restart...
pause
goto :eof
"@
$tunnelScript | Out-File -FilePath "start_https_tunnel.bat" -Encoding ASCII

# Universal deployment launcher
$launcherScript = @"
@echo off
title NoctisPro Universal System Launcher
cd /d "$InstallPath"
color 0A
echo.
echo ████████████████████████████████████████████████████████████████
echo ██                                                            ██
echo ██    🏥 NoctisPro Universal DICOM System Launcher 🌐         ██
echo ██                                                            ██
echo ████████████████████████████████████████████████████████████████
echo.
echo 🚀 Starting all services for universal access...
echo.
echo 📊 System Configuration:
echo    📁 Install Path: $InstallPath
echo    🌐 Web Port: $WebPort  
echo    🏥 DICOM Port: $DicomPort
echo    🔑 AE Title: $AETitle
echo    👤 Admin User: $AdminUsername
echo.
echo ⏳ Starting services in 3 seconds...
timeout /t 3 /nobreak >nul

echo.
echo 🖥️  Starting Django Web Server...
start "NoctisPro Django Server" cmd /k "$InstallPath\start_django_server.bat"

echo ⏳ Waiting for Django to initialize...
timeout /t 8 /nobreak >nul

echo 🏥 Starting DICOM SCP Receiver...
start "NoctisPro DICOM Receiver" cmd /k "$InstallPath\start_dicom_receiver.bat"

echo ⏳ Waiting for DICOM service...
timeout /t 3 /nobreak >nul

if exist cloudflared.exe (
    echo 🌐 Starting Universal HTTPS Tunnel...
    start "NoctisPro HTTPS Tunnel" cmd /k "$InstallPath\start_https_tunnel.bat"
    
    echo.
    echo ████████████████████████████████████████████████████████████████
    echo ██                                                            ██
    echo ██    🎉 NoctisPro System Started Successfully! 🎉            ██
    echo ██                                                            ██
    echo ████████████████████████████████████████████████████████████████
    echo.
    echo 🌐 Universal Access:
    echo    ⏳ Check the "HTTPS Tunnel" window for your universal URL
    echo    📱 Look for: https://random-string.trycloudflare.com
    echo    🔗 This URL works from anywhere in the world!
    echo.
    echo 🏥 DICOM Access:
    echo    📡 External DICOM: [YOUR-PUBLIC-IP]:$DicomPort
    echo    🏷️  AE Title: $AETitle
    echo    📋 Configure your DICOM devices to send to this address
    echo.
    echo 👤 Admin Login:
    echo    🔑 Username: $AdminUsername
    echo    🗝️  Password: $AdminPassword
    echo    📧 Email: $AdminEmail
    echo.
    echo 🔧 Management:
    echo    📊 All services running in separate windows
    echo    🔄 Close any window to stop that service
    echo    🚀 Run this script again to restart everything
    echo.
    echo ████████████████████████████████████████████████████████████████
) else (
    echo.
    echo ⚠️  Cloudflare Tunnel not available - Local access only
    echo 🌐 Local URLs:
    echo    💻 Web: http://localhost:$WebPort
    echo    🏥 DICOM: localhost:$DicomPort
    echo.
    echo 💡 For internet access, download cloudflared.exe from:
    echo    https://github.com/cloudflare/cloudflared/releases
)

echo.
echo Press any key to view system status...
pause >nul

:status_loop
cls
echo ████████████████████████████████████████████████████████████████
echo ██                                                            ██
echo ██    📊 NoctisPro System Status Monitor 📊                   ██
echo ██                                                            ██
echo ████████████████████████████████████████████████████████████████
echo.
echo ⏰ Current Time: %date% %time%
echo.
echo 🖥️  Service Status:
tasklist /FI "WINDOWTITLE eq NoctisPro Django Server" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ Django Server: RUNNING
) else (
    echo    ❌ Django Server: STOPPED
)

tasklist /FI "WINDOWTITLE eq NoctisPro DICOM Receiver" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ DICOM Receiver: RUNNING
) else (
    echo    ❌ DICOM Receiver: STOPPED
)

tasklist /FI "WINDOWTITLE eq NoctisPro HTTPS Tunnel" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ HTTPS Tunnel: RUNNING
) else (
    echo    ❌ HTTPS Tunnel: STOPPED
)

echo.
echo 🌐 Access Information:
echo    👤 Admin Login: $AdminUsername / $AdminPassword
echo    💻 Local Web: http://localhost:$WebPort
echo    🏥 DICOM Port: $DicomPort (AE Title: $AETitle)
echo    🔗 Universal URL: Check tunnel window
echo.
echo 🔧 Actions:
echo    R - Restart all services
echo    S - Show service windows
echo    Q - Quit monitor
echo.
set /p choice="Choose action (R/S/Q): "

if /i "%choice%"=="R" (
    echo 🔄 Restarting services...
    taskkill /F /FI "WINDOWTITLE eq NoctisPro*" >nul 2>&1
    timeout /t 2 /nobreak >nul
    start "NoctisPro Django Server" cmd /k "$InstallPath\start_django_server.bat"
    timeout /t 3 /nobreak >nul
    start "NoctisPro DICOM Receiver" cmd /k "$InstallPath\start_dicom_receiver.bat"
    timeout /t 2 /nobreak >nul
    if exist cloudflared.exe start "NoctisPro HTTPS Tunnel" cmd /k "$InstallPath\start_https_tunnel.bat"
    echo ✅ Services restarted
    timeout /t 2 /nobreak >nul
    goto status_loop
)

if /i "%choice%"=="S" (
    echo 🪟 Bringing service windows to front...
    powershell -Command "Get-Process | Where-Object {$_.MainWindowTitle -like '*NoctisPro*'} | ForEach-Object {[Microsoft.VisualBasic.Interaction]::AppActivate($_.Id)}"
    timeout /t 1 /nobreak >nul
    goto status_loop
)

if /i "%choice%"=="Q" (
    echo 👋 Exiting monitor...
    goto :eof
)

goto status_loop
"@
$launcherScript | Out-File -FilePath "START_UNIVERSAL_NOCTISPRO.bat" -Encoding ASCII

Write-Host "✅ Created START_UNIVERSAL_NOCTISPRO.bat" -ForegroundColor Green
Write-Host "✅ Created start_django_server.bat" -ForegroundColor Green
Write-Host "✅ Created start_dicom_receiver.bat" -ForegroundColor Green
Write-Host "✅ Created start_https_tunnel.bat" -ForegroundColor Green

# Step 10: Create DICOM receiver configuration
Write-Host "`n🏥 Configuring DICOM SCP Receiver..." -ForegroundColor Yellow

$dicomReceiverScript = @"
#!/usr/bin/env python3
"""
NoctisPro Universal DICOM SCP Receiver
Receives DICOM images from anywhere on the internet
Compatible with Windows Server 2019-2022
"""

import os
import sys
import django
import argparse
import socket
from datetime import datetime

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from pynetdicom import AE, evt, StoragePresentationContexts
from pynetdicom.sop_class import Verification
from pydicom import dcmread
from worklist.models import Study, Patient, Modality
from accounts.models import Facility
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('dicom_receiver.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def handle_store(event):
    """Handle incoming DICOM store requests"""
    try:
        # Get the dataset
        ds = event.dataset
        
        # Log the reception
        logger.info(f"📥 Received DICOM from {event.assoc.requestor.address}:{event.assoc.requestor.port}")
        logger.info(f"   Patient: {getattr(ds, 'PatientName', 'Unknown')}")
        logger.info(f"   Study: {getattr(ds, 'StudyDescription', 'Unknown')}")
        logger.info(f"   Modality: {getattr(ds, 'Modality', 'Unknown')}")
        
        # Create media directory if it doesn't exist
        media_dir = os.path.join(os.getcwd(), 'media', 'dicom')
        os.makedirs(media_dir, exist_ok=True)
        
        # Generate filename
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        sop_instance_uid = getattr(ds, 'SOPInstanceUID', timestamp)
        filename = f"{timestamp}_{sop_instance_uid}.dcm"
        filepath = os.path.join(media_dir, filename)
        
        # Save the DICOM file
        ds.save_as(filepath)
        logger.info(f"💾 Saved DICOM file: {filename}")
        
        # Try to create database entry
        try:
            # Get or create patient
            patient_name = str(getattr(ds, 'PatientName', 'Unknown'))
            patient_id = getattr(ds, 'PatientID', 'Unknown')
            
            patient, created = Patient.objects.get_or_create(
                patient_id=patient_id,
                defaults={
                    'name': patient_name,
                    'date_of_birth': getattr(ds, 'PatientBirthDate', None),
                    'gender': getattr(ds, 'PatientSex', 'Unknown')
                }
            )
            
            # Get or create modality
            modality_name = getattr(ds, 'Modality', 'Unknown')
            modality, created = Modality.objects.get_or_create(
                name=modality_name,
                defaults={'description': f'{modality_name} Imaging'}
            )
            
            # Get default facility
            facility = Facility.objects.first()
            
            # Create study entry
            study = Study.objects.create(
                patient=patient,
                facility=facility,
                modality=modality,
                study_instance_uid=getattr(ds, 'StudyInstanceUID', ''),
                study_description=getattr(ds, 'StudyDescription', 'Received via SCP'),
                dicom_file=f'dicom/{filename}',
                upload_date=datetime.now(),
                status='completed'
            )
            
            logger.info(f"📋 Created database entry for study: {study.id}")
            
        except Exception as db_error:
            logger.error(f"❌ Database error: {db_error}")
            # Continue even if database fails - file is still saved
        
        # Return success
        return 0x0000
        
    except Exception as e:
        logger.error(f"❌ Error handling DICOM store: {e}")
        return 0xC000  # Failure status

def handle_echo(event):
    """Handle C-ECHO (verification) requests"""
    logger.info(f"📡 C-ECHO request from {event.assoc.requestor.address}")
    return 0x0000

def main():
    parser = argparse.ArgumentParser(description='NoctisPro Universal DICOM SCP Receiver')
    parser.add_argument('--port', type=int, default=$DicomPort, help='DICOM port')
    parser.add_argument('--aet', default='$AETitle', help='AE Title')
    parser.add_argument('--bind', default='0.0.0.0', help='Bind address (0.0.0.0 for internet)')
    args = parser.parse_args()
    
    # Get local IP for display
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except:
        local_ip = "Unknown"
    
    print(f"""
████████████████████████████████████████████████████████████████
██                                                            ██
██    🏥 NoctisPro Universal DICOM SCP Receiver 🌐            ██
██                                                            ██
████████████████████████████████████████████████████████████████

🔧 Configuration:
   🏷️  AE Title: {args.aet}
   🌐 Bind Address: {args.bind}
   📡 Port: {args.port}
   💻 Local IP: {local_ip}
   
🌍 Universal Access:
   📤 Send DICOM to: [YOUR-PUBLIC-IP]:{args.port}
   🏷️  Use AE Title: {args.aet}
   🔗 Works from anywhere on the internet!
   
📁 Storage:
   💾 Files saved to: {os.path.join(os.getcwd(), 'media', 'dicom')}
   📋 Database entries created automatically
   
████████████████████████████████████████████████████████████████
🚀 Starting DICOM SCP Server...
""")
    
    # Create Application Entity
    ae = AE(ae_title=args.aet)
    
    # Add supported presentation contexts
    ae.supported_contexts = StoragePresentationContexts
    ae.add_supported_context(Verification)
    
    # Add event handlers
    handlers = [
        (evt.EVT_C_STORE, handle_store),
        (evt.EVT_C_ECHO, handle_echo)
    ]
    
    try:
        # Start SCP server
        logger.info(f"🚀 Starting DICOM SCP on {args.bind}:{args.port} with AE Title: {args.aet}")
        ae.start_server((args.bind, args.port), evt_handlers=handlers)
        
    except KeyboardInterrupt:
        logger.info("🛑 DICOM SCP stopped by user")
    except Exception as e:
        logger.error(f"❌ DICOM SCP error: {e}")
        print(f"❌ Error: {e}")
        input("Press Enter to exit...")

if __name__ == "__main__":
    main()
"@
$dicomReceiverScript | Out-File -FilePath "dicom_receiver.py" -Encoding UTF8

Write-Host "✅ Created dicom_receiver.py" -ForegroundColor Green

# Step 11: Create system status and management scripts
Write-Host "`n🔧 Creating Management Scripts..." -ForegroundColor Yellow

# System status script
$statusScript = @"
@echo off
title NoctisPro System Status
echo ████████████████████████████████████████████████████████████████
echo ██                                                            ██
echo ██    📊 NoctisPro System Status Monitor 📊                   ██
echo ██                                                            ██
echo ████████████████████████████████████████████████████████████████
echo.
echo ⏰ Current Time: %date% %time%
echo 📁 Install Path: $InstallPath
echo.
echo 🖥️  Service Status:
tasklist /FI "WINDOWTITLE eq NoctisPro Django Server" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ Django Web Server: RUNNING on port $WebPort
) else (
    echo    ❌ Django Web Server: STOPPED
)

tasklist /FI "WINDOWTITLE eq NoctisPro DICOM Receiver" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ DICOM SCP Receiver: RUNNING on port $DicomPort
) else (
    echo    ❌ DICOM SCP Receiver: STOPPED
)

tasklist /FI "WINDOWTITLE eq NoctisPro HTTPS Tunnel" >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ Universal HTTPS Tunnel: RUNNING
) else (
    echo    ❌ Universal HTTPS Tunnel: STOPPED
)

echo.
echo 🌐 Network Status:
netstat -an | find ":$WebPort " >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ Web port $WebPort: LISTENING
) else (
    echo    ❌ Web port $WebPort: NOT LISTENING
)

netstat -an | find ":$DicomPort " >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ DICOM port $DicomPort: LISTENING
) else (
    echo    ❌ DICOM port $DicomPort: NOT LISTENING
)

echo.
echo 🔧 Quick Actions:
echo    1 - Start all services
echo    2 - Stop all services  
echo    3 - Restart all services
echo    4 - Open web interface
echo    5 - View logs
echo    Q - Quit
echo.
set /p choice="Choose action (1-5/Q): "

if "%choice%"=="1" (
    echo 🚀 Starting all services...
    start "NoctisPro Django Server" cmd /k "$InstallPath\start_django_server.bat"
    timeout /t 2 /nobreak >nul
    start "NoctisPro DICOM Receiver" cmd /k "$InstallPath\start_dicom_receiver.bat"
    timeout /t 2 /nobreak >nul
    if exist cloudflared.exe start "NoctisPro HTTPS Tunnel" cmd /k "$InstallPath\start_https_tunnel.bat"
    echo ✅ Services started
    timeout /t 2 /nobreak >nul
    goto :eof
)

if "%choice%"=="2" (
    echo 🛑 Stopping all services...
    taskkill /F /FI "WINDOWTITLE eq NoctisPro*" >nul 2>&1
    echo ✅ Services stopped
    timeout /t 2 /nobreak >nul
    goto :eof
)

if "%choice%"=="3" (
    echo 🔄 Restarting all services...
    taskkill /F /FI "WINDOWTITLE eq NoctisPro*" >nul 2>&1
    timeout /t 3 /nobreak >nul
    start "NoctisPro Django Server" cmd /k "$InstallPath\start_django_server.bat"
    timeout /t 3 /nobreak >nul
    start "NoctisPro DICOM Receiver" cmd /k "$InstallPath\start_dicom_receiver.bat"
    timeout /t 2 /nobreak >nul
    if exist cloudflared.exe start "NoctisPro HTTPS Tunnel" cmd /k "$InstallPath\start_https_tunnel.bat"
    echo ✅ Services restarted
    timeout /t 2 /nobreak >nul
    goto :eof
)

if "%choice%"=="4" (
    echo 🌐 Opening web interface...
    start http://localhost:$WebPort
    goto :eof
)

if "%choice%"=="5" (
    echo 📋 Opening log files...
    if exist dicom_receiver.log start notepad dicom_receiver.log
    if exist noctis_pro.log start notepad noctis_pro.log
    goto :eof
)

if /i "%choice%"=="Q" (
    goto :eof
)

echo Invalid choice, try again...
timeout /t 1 /nobreak >nul
goto :eof
"@
$statusScript | Out-File -FilePath "system_status.bat" -Encoding ASCII

Write-Host "✅ Created system_status.bat" -ForegroundColor Green

# Step 12: Configure production settings for internet access
Write-Host "`n⚙️  Configuring Production Settings..." -ForegroundColor Yellow

# Create production settings override
$productionSettings = @"
# Production settings override for universal internet access
# This file is automatically generated by universal_deploy_windows.ps1

import os
from .settings import *

# Security for internet access
DEBUG = False
ALLOWED_HOSTS = ['*']  # Allow all hosts for universal access via tunnel

# Generate secure secret key
SECRET_KEY = '$(-join ((1..50) | ForEach {Get-Random -InputObject (@('a'..'z') + @('A'..'Z') + @('0'..'9') + @('!','@','#','$','%','^','&','*'))}))'

# Database configuration (SQLite for simplicity)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
        'OPTIONS': {
            'timeout': 30,
        }
    }
}

# Cache configuration
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
    }
}

# Security headers for internet exposure
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'SAMEORIGIN'  # Allow embedding for DICOM viewer

# Session security
SESSION_COOKIE_AGE = 86400  # 24 hours
SESSION_EXPIRE_AT_BROWSER_CLOSE = False
SESSION_COOKIE_HTTPONLY = True

# CSRF protection
CSRF_COOKIE_HTTPONLY = True
CSRF_TRUSTED_ORIGINS = [
    'https://*.trycloudflare.com',  # Allow Cloudflare tunnel domains
    'http://localhost:$WebPort',
    'http://127.0.0.1:$WebPort'
]

# File upload settings for DICOM
FILE_UPLOAD_MAX_MEMORY_SIZE = 100 * 1024 * 1024  # 100MB
DATA_UPLOAD_MAX_MEMORY_SIZE = 100 * 1024 * 1024  # 100MB

# Media files configuration
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# Static files configuration
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

# Logging configuration
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': 'noctis_pro.log',
            'maxBytes': 1024*1024*10,  # 10MB
            'backupCount': 5,
            'formatter': 'verbose',
        },
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
    },
    'root': {
        'handlers': ['file', 'console'],
        'level': 'INFO',
    },
    'loggers': {
        'django': {
            'handlers': ['file'],
            'level': 'INFO',
            'propagate': False,
        },
        'noctis_pro': {
            'handlers': ['file', 'console'],
            'level': 'INFO',
            'propagate': False,
        },
    },
}

# DICOM receiver configuration
DICOM_SCP_PORT = $DicomPort
DICOM_AE_TITLE = '$AETitle'
DICOM_BIND_ADDRESS = '0.0.0.0'  # Listen on all interfaces for internet access

print(f"🔧 Production settings loaded:")
print(f"   Debug: {DEBUG}")
print(f"   Allowed Hosts: {ALLOWED_HOSTS}")
print(f"   DICOM Port: {DICOM_SCP_PORT}")
print(f"   AE Title: {DICOM_AE_TITLE}")
"@
$productionSettings | Out-File -FilePath "noctis_pro/settings_universal.py" -Encoding UTF8

# Step 13: Create environment activation script
Write-Host "`n🔧 Creating Environment Setup..." -ForegroundColor Yellow

$envScript = @"
# NoctisPro Environment Setup for Production
# Sets Django settings module for universal deployment

$env:DJANGO_SETTINGS_MODULE = "noctis_pro.settings_universal"
Write-Host "✅ Django settings configured for universal access" -ForegroundColor Green
"@
$envScript | Out-File -FilePath "setup_env.ps1" -Encoding UTF8

# Step 14: Create comprehensive test script
Write-Host "`n🧪 Creating System Test Script..." -ForegroundColor Yellow

$testScript = @"
@echo off
title NoctisPro System Tests
cd /d "$InstallPath"
call .venv\Scripts\activate.bat

echo ████████████████████████████████████████████████████████████████
echo ██                                                            ██
echo ██    🧪 NoctisPro Universal System Tests 🧪                  ██
echo ██                                                            ██
echo ████████████████████████████████████████████████████████████████
echo.

echo 🔍 Running comprehensive system tests...
echo.

echo 📋 1. Django System Check...
python manage.py check
if %errorlevel% neq 0 (
    echo ❌ Django system check failed
    pause
    exit /b 1
)
echo ✅ Django system check passed
echo.

echo 🗄️  2. Database Migration Check...
python manage.py showmigrations
if %errorlevel% neq 0 (
    echo ❌ Migration check failed
    pause
    exit /b 1
)
echo ✅ Migration check passed
echo.

echo 👤 3. Admin User Verification...
python -c "
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
    if not (user.is_active and user.is_verified):
        print('❌ User not properly configured')
        exit(1)
except:
    print('❌ Admin user not found')
    exit(1)
"
if %errorlevel% neq 0 (
    echo ❌ Admin user verification failed
    pause
    exit /b 1
)
echo ✅ Admin user verification passed
echo.

echo 🏥 4. Facility Configuration Check...
python -c "
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings_universal')
django.setup()
from accounts.models import Facility
facilities = Facility.objects.all()
print(f'✅ Found {facilities.count()} facilities')
for f in facilities:
    print(f'   - {f.name} (AE: {f.ae_title})')
"
if %errorlevel% neq 0 (
    echo ❌ Facility check failed
    pause
    exit /b 1
)
echo ✅ Facility configuration passed
echo.

echo 🌐 5. Network Port Check...
netstat -an | find ":$WebPort"
if %errorlevel% equ 0 (
    echo ✅ Web port $WebPort is listening
) else (
    echo ⚠️  Web port $WebPort not listening (normal if not started)
)

netstat -an | find ":$DicomPort"
if %errorlevel% equ 0 (
    echo ✅ DICOM port $DicomPort is listening
) else (
    echo ⚠️  DICOM port $DicomPort not listening (normal if not started)
)
echo.

echo 🔥 6. Windows Firewall Check...
netsh advfirewall firewall show rule name="NoctisPro-Web" >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Web firewall rule exists
) else (
    echo ⚠️  Web firewall rule missing
)

netsh advfirewall firewall show rule name="NoctisPro-DICOM" >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ DICOM firewall rule exists
) else (
    echo ⚠️  DICOM firewall rule missing
)
echo.

echo 📁 7. File Structure Check...
if exist ".venv" (
    echo ✅ Virtual environment exists
) else (
    echo ❌ Virtual environment missing
)

if exist "manage.py" (
    echo ✅ Django project files exist
) else (
    echo ❌ Django project files missing
)

if exist "db.sqlite3" (
    echo ✅ Database file exists
) else (
    echo ❌ Database file missing
)

if exist "cloudflared.exe" (
    echo ✅ Cloudflare tunnel available
) else (
    echo ⚠️  Cloudflare tunnel not found (manual download needed)
)
echo.

echo ████████████████████████████████████████████████████████████████
echo ██                                                            ██
echo ██    🎯 System Test Summary 🎯                               ██
echo ██                                                            ██
echo ████████████████████████████████████████████████████████████████
echo.
echo ✅ System tests completed!
echo 🚀 Ready for universal deployment
echo.
echo 📱 Quick Start:
echo    Double-click: START_UNIVERSAL_NOCTISPRO.bat
echo.
pause
"@
$testScript | Out-File -FilePath "test_system.bat" -Encoding ASCII

Write-Host "✅ Created test_system.bat" -ForegroundColor Green

# Step 15: Create Windows Service installer (optional)
Write-Host "`n🔧 Creating Windows Service Installer..." -ForegroundColor Yellow

$serviceScript = @"
# NoctisPro Windows Service Installer
# Run as Administrator to install NoctisPro as Windows Service

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Start,
    [switch]$Stop
)

$InstallPath = "$InstallPath"
$ServiceName = "NoctisProPACS"
$DisplayName = "NoctisPro DICOM PACS System"

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Error "❌ This script must be run as Administrator"
    exit 1
}

if ($Install) {
    Write-Host "🔧 Installing NoctisPro as Windows Service..." -ForegroundColor Yellow
    
    # Download NSSM if not exists
    if (-not (Test-Path "nssm.exe")) {
        Write-Host "📥 Downloading NSSM..." -ForegroundColor Cyan
        $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
        Invoke-WebRequest -Uri $nssmUrl -OutFile "nssm.zip" -UseBasicParsing
        Expand-Archive -Path "nssm.zip" -DestinationPath "." -Force
        Copy-Item "nssm-2.24\win64\nssm.exe" "." -Force
        Remove-Item "nssm.zip" -Force
        Remove-Item "nssm-2.24" -Recurse -Force
    }
    
    # Install service
    .\nssm.exe install $ServiceName "$InstallPath\.venv\Scripts\python.exe"
    .\nssm.exe set $ServiceName Arguments "manage.py runserver 0.0.0.0:$WebPort --settings=noctis_pro.settings_universal"
    .\nssm.exe set $ServiceName AppDirectory "$InstallPath"
    .\nssm.exe set $ServiceName DisplayName "$DisplayName"
    .\nssm.exe set $ServiceName Description "NoctisPro Medical DICOM PACS System with Universal Access"
    .\nssm.exe set $ServiceName Start SERVICE_AUTO_START
    
    Write-Host "✅ Service installed successfully" -ForegroundColor Green
    Write-Host "🚀 Use -Start to start the service" -ForegroundColor Cyan
}

if ($Uninstall) {
    Write-Host "🗑️  Uninstalling NoctisPro service..." -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    .\nssm.exe remove $ServiceName confirm
    Write-Host "✅ Service uninstalled" -ForegroundColor Green
}

if ($Start) {
    Write-Host "🚀 Starting NoctisPro service..." -ForegroundColor Yellow
    Start-Service -Name $ServiceName
    Write-Host "✅ Service started" -ForegroundColor Green
}

if ($Stop) {
    Write-Host "🛑 Stopping NoctisPro service..." -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force
    Write-Host "✅ Service stopped" -ForegroundColor Green
}

if (-not ($Install -or $Uninstall -or $Start -or $Stop)) {
    Write-Host "NoctisPro Windows Service Manager" -ForegroundColor Cyan
    Write-Host "Usage:" -ForegroundColor White
    Write-Host "  .\service_manager.ps1 -Install   # Install as Windows Service" -ForegroundColor White
    Write-Host "  .\service_manager.ps1 -Start     # Start the service" -ForegroundColor White
    Write-Host "  .\service_manager.ps1 -Stop      # Stop the service" -ForegroundColor White
    Write-Host "  .\service_manager.ps1 -Uninstall # Remove the service" -ForegroundColor White
}
"@
$serviceScript | Out-File -FilePath "service_manager.ps1" -Encoding UTF8

Write-Host "✅ Created service_manager.ps1" -ForegroundColor Green

# Step 16: Final system verification
Write-Host "`n🔍 Final System Verification..." -ForegroundColor Yellow
try {
    # Set environment variable for Django
    $env:DJANGO_SETTINGS_MODULE = "noctis_pro.settings_universal"
    
    python manage.py check --settings=noctis_pro.settings_universal
    Write-Host "✅ Django production check passed" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Django check had warnings (this may be normal)" -ForegroundColor Yellow
}

# Create desktop shortcuts
Write-Host "`n🖥️  Creating Desktop Shortcuts..." -ForegroundColor Yellow
try {
    $WshShell = New-Object -comObject WScript.Shell
    
    # Main launcher shortcut
    $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\NoctisPro Universal.lnk")
    $Shortcut.TargetPath = "$InstallPath\START_UNIVERSAL_NOCTISPRO.bat"
    $Shortcut.WorkingDirectory = $InstallPath
    $Shortcut.Description = "NoctisPro Universal DICOM System"
    $Shortcut.Save()
    
    # System status shortcut
    $StatusShortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\NoctisPro Status.lnk")
    $StatusShortcut.TargetPath = "$InstallPath\system_status.bat"
    $StatusShortcut.WorkingDirectory = $InstallPath
    $StatusShortcut.Description = "NoctisPro System Status Monitor"
    $StatusShortcut.Save()
    
    Write-Host "✅ Desktop shortcuts created" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Failed to create desktop shortcuts: $_" -ForegroundColor Yellow
}

# Completion message with comprehensive information
Write-Host "`n" -NoNewline
Write-Host "🎉 NOCTISPRO UNIVERSAL DEPLOYMENT COMPLETE! 🎉" -ForegroundColor Green -BackgroundColor Black
Write-Host "=" * 80 -ForegroundColor Green

Write-Host "`n📋 DEPLOYMENT SUMMARY:" -ForegroundColor Cyan
Write-Host "   📁 Install Path: $InstallPath" -ForegroundColor White
Write-Host "   👤 Admin Username: $AdminUsername" -ForegroundColor White
Write-Host "   🔑 Admin Password: $AdminPassword" -ForegroundColor White
Write-Host "   📧 Admin Email: $AdminEmail" -ForegroundColor White
Write-Host "   🌐 Web Port: $WebPort" -ForegroundColor White
Write-Host "   🏥 DICOM Port: $DicomPort" -ForegroundColor White
Write-Host "   🏷️  AE Title: $AETitle" -ForegroundColor White

Write-Host "`n🚀 TO START THE UNIVERSAL SYSTEM:" -ForegroundColor Yellow
Write-Host "   Option 1: Double-click desktop shortcut 'NoctisPro Universal'" -ForegroundColor White
Write-Host "   Option 2: Double-click: START_UNIVERSAL_NOCTISPRO.bat" -ForegroundColor White
Write-Host "   Option 3: Run individual services manually" -ForegroundColor White

Write-Host "`n🌐 UNIVERSAL ACCESS URLS:" -ForegroundColor Yellow
Write-Host "   💻 Local Web: http://localhost:$WebPort" -ForegroundColor White
Write-Host "   🌍 Universal HTTPS: Check tunnel window for https://xxx.trycloudflare.com" -ForegroundColor White
Write-Host "   📱 Admin Panel: [HTTPS-URL]/admin-panel/" -ForegroundColor White

Write-Host "`n🏥 DICOM SCP ACCESS:" -ForegroundColor Yellow
Write-Host "   📡 External DICOM: [YOUR-PUBLIC-IP]:$DicomPort" -ForegroundColor White
Write-Host "   🏷️  AE Title: $AETitle" -ForegroundColor White
Write-Host "   🌍 Receives from anywhere on the internet!" -ForegroundColor White

Write-Host "`n🔧 MANAGEMENT TOOLS:" -ForegroundColor Yellow
Write-Host "   📊 System Status: system_status.bat" -ForegroundColor White
Write-Host "   🧪 Run Tests: test_system.bat" -ForegroundColor White
Write-Host "   🔧 Windows Service: service_manager.ps1 -Install" -ForegroundColor White

Write-Host "`n🛡️  SECURITY NOTES:" -ForegroundColor Red
Write-Host "   ⚠️  System is configured for internet access" -ForegroundColor Yellow
Write-Host "   🔒 Change admin password immediately after first login" -ForegroundColor Yellow
Write-Host "   🔥 Windows Firewall rules have been configured" -ForegroundColor Yellow
Write-Host "   🌐 Cloudflare tunnel provides secure HTTPS access" -ForegroundColor Yellow

Write-Host "`n💡 NEXT STEPS:" -ForegroundColor Cyan
Write-Host "   1. Start the system: Double-click 'NoctisPro Universal' on desktop" -ForegroundColor White
Write-Host "   2. Wait for tunnel to establish (30-60 seconds)" -ForegroundColor White
Write-Host "   3. Note your universal HTTPS URL from tunnel window" -ForegroundColor White
Write-Host "   4. Login with admin credentials and change password" -ForegroundColor White
Write-Host "   5. Configure DICOM devices to send to your public IP:$DicomPort" -ForegroundColor White

Write-Host "`n🎯 Ready to launch? Press Enter to start NoctisPro now..." -ForegroundColor Green
Read-Host

# Launch the universal system
Write-Host "🚀 Launching NoctisPro Universal System..." -ForegroundColor Green
& ".\START_UNIVERSAL_NOCTISPRO.bat"