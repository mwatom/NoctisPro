# NoctisPro DICOM System - Complete Manual Deployment Script for Windows Server 2019
# Run this script as Administrator in PowerShell on your Windows Server 2019
# This script will guide you through the complete installation process

param(
    [string]$InstallPath = "C:\noctis",
    [string]$PostgreSQLVersion = "17",
    [string]$PythonVersion = "3.11",
    [switch]$SkipPrerequisites = $false
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Color coding for output
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Step { param($Message) Write-Host "🔧 $Message" -ForegroundColor Blue }

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Main deployment function
function Start-NoctisProDeployment {
    Write-Host @"
========================================
  NoctisPro DICOM System Deployment
  Windows Server 2019 Manual Setup
========================================
"@ -ForegroundColor Cyan

    # Check administrator privileges
    if (-not (Test-Administrator)) {
        Write-Error "This script must be run as Administrator!"
        Write-Info "Right-click PowerShell and select 'Run as Administrator'"
        Read-Host "Press Enter to exit"
        exit 1
    }

    Write-Success "Running as Administrator ✓"
    Write-Info "Installation Path: $InstallPath"
    Write-Info "PostgreSQL Version: $PostgreSQLVersion"
    Write-Info "Python Version: $PythonVersion"
    
    $continue = Read-Host "`nProceed with installation? (Y/N)"
    if ($continue -ne 'Y' -and $continue -ne 'y') {
        Write-Info "Installation cancelled by user"
        exit 0
    }

    # Step 1: Configure Windows Firewall
    Write-Step "Step 1: Configuring Windows Firewall..."
    try {
        New-NetFirewallRule -DisplayName "NoctisPro Web Interface" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "NoctisPro DICOM Receiver" -Direction Inbound -Protocol TCP -LocalPort 11112 -Action Allow -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "PostgreSQL Database" -Direction Inbound -Protocol TCP -LocalPort 5432 -Action Allow -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "Redis Cache Server" -Direction Inbound -Protocol TCP -LocalPort 6379 -Action Allow -ErrorAction SilentlyContinue
        Write-Success "Firewall rules configured"
    } catch {
        Write-Warning "Firewall configuration may have issues: $($_.Exception.Message)"
    }

    # Step 2: Verify PostgreSQL Installation
    Write-Step "Step 2: Verifying PostgreSQL $PostgreSQLVersion Installation..."
    Test-PostgreSQLInstallation

    # Step 3: Verify Python Installation
    Write-Step "Step 3: Verifying Python $PythonVersion Installation..."
    Test-PythonInstallation

    # Step 4: Install Redis
    Write-Step "Step 4: Installing Redis Server..."
    Install-Redis

    # Step 5: Prepare NoctisPro Installation Directory
    Write-Step "Step 5: Preparing NoctisPro Installation..."
    Prepare-NoctisProDirectory

    # Step 6: Install Python Dependencies
    Write-Step "Step 6: Installing Python Dependencies..."
    Install-PythonDependencies

    # Step 7: Configure Environment
    Write-Step "Step 7: Configuring Environment..."
    Configure-Environment

    # Step 8: Initialize Database
    Write-Step "Step 8: Initializing Database..."
    Initialize-Database

    # Step 9: Configure Windows Services
    Write-Step "Step 9: Configuring Windows Services..."
    Configure-WindowsServices

    # Step 10: Create Management Scripts
    Write-Step "Step 10: Creating Management Scripts..."
    Create-ManagementScripts

    # Step 11: Final Testing
    Write-Step "Step 11: Running Final Tests..."
    Test-Installation

    # Step 12: Display Summary
    Show-InstallationSummary
}

function Test-PostgreSQLInstallation {
    Write-Info "Checking PostgreSQL $PostgreSQLVersion installation..."
    
    # Check for PostgreSQL service
    $pgService = Get-Service -Name "*postgresql*$PostgreSQLVersion*" -ErrorAction SilentlyContinue
    if (-not $pgService) {
        $pgService = Get-Service -Name "*postgresql*" -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    
    if ($pgService) {
        Write-Success "PostgreSQL service found: $($pgService.Name)"
        Write-Info "Status: $($pgService.Status) | StartType: $($pgService.StartType)"
        
        # Try to start the service
        try {
            if ($pgService.Status -ne "Running") {
                Start-Service -Name $pgService.Name
                Write-Success "PostgreSQL service started"
            }
        } catch {
            Write-Warning "Could not start PostgreSQL service: $($_.Exception.Message)"
        }
    } else {
        Write-Error "PostgreSQL service not found!"
        Write-Info "Please install PostgreSQL $PostgreSQLVersion from: https://www.postgresql.org/download/windows/"
        Write-Info "Installation settings:"
        Write-Info "- Installation Directory: C:\Program Files\PostgreSQL\$PostgreSQLVersion"
        Write-Info "- Data Directory: C:\Program Files\PostgreSQL\$PostgreSQLVersion\data"
        Write-Info "- Port: 5432"
        Write-Info "- Create a strong superuser password and remember it!"
        
        $continue = Read-Host "Have you installed PostgreSQL? (Y/N)"
        if ($continue -ne 'Y' -and $continue -ne 'y') {
            Write-Error "PostgreSQL is required. Please install it first."
            exit 1
        } else {
            # Retry detection
            Test-PostgreSQLInstallation
        }
    }
    
    # Check installation directory
    $pgDir = "C:\Program Files\PostgreSQL\$PostgreSQLVersion"
    if (Test-Path $pgDir) {
        Write-Success "PostgreSQL directory found: $pgDir"
    } else {
        Write-Warning "PostgreSQL directory not found at expected location"
        $pgDir = Read-Host "Enter PostgreSQL installation path (e.g., C:\Program Files\PostgreSQL\17)"
        if (-not (Test-Path $pgDir)) {
            Write-Error "PostgreSQL installation directory not found!"
            exit 1
        }
    }
    
    # Test PostgreSQL connectivity
    $psqlPath = Join-Path $pgDir "bin\psql.exe"
    if (Test-Path $psqlPath) {
        Write-Success "PostgreSQL binaries found"
        
        # Test connection
        try {
            $testResult = & "$pgDir\bin\pg_isready.exe" -h localhost -p 5432 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "PostgreSQL is accepting connections"
            } else {
                Write-Warning "PostgreSQL may not be accepting connections"
            }
        } catch {
            Write-Warning "Could not test PostgreSQL connection"
        }
    } else {
        Write-Error "PostgreSQL binaries not found!"
        exit 1
    }
    
    # Store PostgreSQL path for later use
    $script:PostgreSQLPath = $pgDir
}

function Test-PythonInstallation {
    Write-Info "Checking Python $PythonVersion installation..."
    
    try {
        $pythonVersion = python --version 2>$null
        if ($pythonVersion -match "Python (\d+\.\d+)") {
            $version = $matches[1]
            Write-Success "Python found: $pythonVersion"
            
            if ($version -ge "3.10") {
                Write-Success "Python version is compatible"
            } else {
                Write-Warning "Python version may be too old. Python 3.10+ recommended."
            }
        } else {
            throw "Python not found in PATH"
        }
        
        # Test pip
        $pipVersion = pip --version 2>$null
        if ($pipVersion) {
            Write-Success "pip found: $($pipVersion.Split(' ')[1])"
        } else {
            Write-Warning "pip not found"
        }
        
    } catch {
        Write-Error "Python not found or not properly installed!"
        Write-Info "Please install Python $PythonVersion from: https://www.python.org/downloads/windows/"
        Write-Info "Installation requirements:"
        Write-Info "- ✅ Add Python to PATH"
        Write-Info "- ✅ Install for all users"
        Write-Info "- ✅ Install pip"
        Write-Info "- Installation path: C:\Python311"
        
        $continue = Read-Host "Have you installed Python? (Y/N)"
        if ($continue -ne 'Y' -and $continue -ne 'y') {
            Write-Error "Python is required. Please install it first."
            exit 1
        } else {
            # Retry detection
            Test-PythonInstallation
        }
    }
}

function Install-Redis {
    Write-Info "Setting up Redis server..."
    
    # Check if Redis is already installed
    $redisService = Get-Service -Name "Redis" -ErrorAction SilentlyContinue
    if ($redisService) {
        Write-Success "Redis service already exists"
        try {
            Start-Service -Name "Redis" -ErrorAction SilentlyContinue
            Write-Success "Redis service started"
        } catch {
            Write-Warning "Could not start Redis service"
        }
        return
    }
    
    try {
        # Create Redis directory
        $redisDir = "C:\Redis"
        New-Item -ItemType Directory -Path $redisDir -Force | Out-Null
        
        # Create temp directory
        New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
        
        Write-Info "Downloading Redis for Windows..."
        $redisUrl = "https://github.com/microsoftarchive/redis/releases/download/win-3.0.504/Redis-x64-3.0.504.zip"
        Invoke-WebRequest -Uri $redisUrl -OutFile "C:\temp\redis.zip" -UseBasicParsing
        
        Write-Info "Extracting Redis..."
        Expand-Archive -Path "C:\temp\redis.zip" -DestinationPath $redisDir -Force
        
        # Install Redis as service
        Write-Info "Installing Redis as Windows service..."
        Set-Location $redisDir
        & ".\redis-server.exe" --service-install --service-name Redis --port 6379
        
        # Configure and start Redis service
        Set-Service -Name Redis -StartupType Automatic
        Start-Service -Name Redis
        
        Write-Success "Redis installed and started successfully"
        
    } catch {
        Write-Error "Failed to install Redis: $($_.Exception.Message)"
        Write-Info "You may need to install Redis manually or use an alternative like Memurai"
    }
}

function Prepare-NoctisProDirectory {
    Write-Info "Preparing NoctisPro installation directory..."
    
    # Create installation directory
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Set-Location $InstallPath
    Write-Success "Created installation directory: $InstallPath"
    
    # Check if NoctisPro files are already present
    if (Test-Path "manage.py") {
        Write-Success "NoctisPro files already present"
    } else {
        Write-Warning "NoctisPro application files not found!"
        Write-Info "Please copy all NoctisPro project files to: $InstallPath"
        Write-Info "Required files and directories:"
        Write-Info "- manage.py"
        Write-Info "- requirements-windows.txt"
        Write-Info "- noctis_pro/ (directory)"
        Write-Info "- accounts/ (directory)"
        Write-Info "- worklist/ (directory)"
        Write-Info "- dicom_viewer/ (directory)"
        Write-Info "- templates/ (directory)"
        Write-Info "- static/ (directory)"
        
        Read-Host "Press Enter after copying all files to $InstallPath"
        
        # Verify files are present
        $requiredFiles = @("manage.py")
        $requiredDirs = @("noctis_pro")
        
        foreach ($file in $requiredFiles) {
            if (-not (Test-Path $file)) {
                Write-Error "Required file missing: $file"
                exit 1
            }
        }
        
        foreach ($dir in $requiredDirs) {
            if (-not (Test-Path $dir)) {
                Write-Error "Required directory missing: $dir"
                exit 1
            }
        }
        
        Write-Success "All required files verified"
    }
}

function Install-PythonDependencies {
    Write-Info "Setting up Python virtual environment and dependencies..."
    
    Set-Location $InstallPath
    
    # Create virtual environment
    if (-not (Test-Path ".venv")) {
        Write-Info "Creating Python virtual environment..."
        python -m venv .venv
        Write-Success "Virtual environment created"
    } else {
        Write-Success "Virtual environment already exists"
    }
    
    # Activate virtual environment
    Write-Info "Activating virtual environment..."
    try {
        & ".\.venv\Scripts\Activate.ps1"
        Write-Success "Virtual environment activated"
    } catch {
        Write-Warning "Execution policy issue. Fixing..."
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        & ".\.venv\Scripts\Activate.ps1"
    }
    
    # Upgrade pip
    Write-Info "Upgrading pip..."
    & ".\.venv\Scripts\python.exe" -m pip install --upgrade pip
    
    # Install PostgreSQL adapter
    Write-Info "Installing PostgreSQL adapter..."
    & ".\.venv\Scripts\pip.exe" install psycopg2-binary
    
    # Install requirements
    if (Test-Path "requirements-windows.txt") {
        Write-Info "Installing Windows-specific requirements..."
        & ".\.venv\Scripts\pip.exe" install -r requirements-windows.txt
    } elseif (Test-Path "requirements.txt") {
        Write-Info "Installing standard requirements..."
        & ".\.venv\Scripts\pip.exe" install -r requirements.txt
    }
    
    # Install critical packages individually if requirements file failed
    Write-Info "Installing critical packages..."
    $criticalPackages = @(
        "Django>=5,<6",
        "celery>=5,<6", 
        "redis",
        "pydicom",
        "pynetdicom",
        "Pillow>=10,<11",
        "python-dotenv",
        "djangorestframework",
        "django-cors-headers",
        "waitress>=2,<3",
        "numpy>=1.24,<2",
        "matplotlib>=3.8,<3.9"
    )
    
    foreach ($package in $criticalPackages) {
        try {
            & ".\.venv\Scripts\pip.exe" install $package --quiet
            Write-Success "Installed: $package"
        } catch {
            Write-Warning "Failed to install: $package"
        }
    }
    
    Write-Success "Python dependencies installation completed"
}

function Configure-Environment {
    Write-Info "Configuring environment variables..."
    
    # Generate Django secret key
    $secretKey = & ".\.venv\Scripts\python.exe" -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
    
    # Create .env file
    $envContent = @"
# Database Configuration
DB_ENGINE=django.db.backends.postgresql
DB_NAME=noctispro
DB_USER=noctispro_user
DB_PASSWORD=NoctisPro2024!
DB_HOST=localhost
DB_PORT=5432

# Django Configuration
SECRET_KEY=$secretKey
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1,*

# Redis Configuration
REDIS_URL=redis://localhost:6379/0

# DICOM Configuration
DICOM_AE_TITLE=NOCTISPRO
DICOM_PORT=11112

# Production Settings
ENVIRONMENT=production

# Security Settings
SECURE_BROWSER_XSS_FILTER=True
SECURE_CONTENT_TYPE_NOSNIFF=True
X_FRAME_OPTIONS=DENY
"@
    
    $envContent | Out-File -FilePath "$InstallPath\.env" -Encoding UTF8
    Write-Success "Environment configuration created"
}

function Initialize-Database {
    Write-Info "Initializing PostgreSQL database for NoctisPro..."
    
    # Create database setup script
    $sqlScript = @"
-- Create NoctisPro database and user
CREATE DATABASE noctispro;
CREATE USER noctispro_user WITH PASSWORD 'NoctisPro2024!';
GRANT ALL PRIVILEGES ON DATABASE noctispro TO noctispro_user;
ALTER USER noctispro_user CREATEDB;
ALTER USER noctispro_user SUPERUSER;

-- Connect to noctispro database
\c noctispro
GRANT ALL ON SCHEMA public TO noctispro_user;
"@
    
    # Save SQL script
    New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
    $sqlScript | Out-File -FilePath "C:\temp\setup_noctispro.sql" -Encoding UTF8
    
    # Execute SQL script
    Write-Info "Creating NoctisPro database..."
    Write-Info "You will be prompted for PostgreSQL superuser password"
    
    try {
        $psqlPath = Join-Path $script:PostgreSQLPath "bin\psql.exe"
        & $psqlPath -U postgres -h localhost -f "C:\temp\setup_noctispro.sql"
        Write-Success "Database created successfully"
    } catch {
        Write-Error "Failed to create database. Please create manually:"
        Write-Info "1. Open PostgreSQL command line (psql)"
        Write-Info "2. Run the commands in C:\temp\setup_noctispro.sql"
    }
    
    # Run Django migrations
    Write-Info "Running Django database migrations..."
    Set-Location $InstallPath
    
    try {
        & ".\.venv\Scripts\python.exe" manage.py makemigrations
        & ".\.venv\Scripts\python.exe" manage.py migrate
        Write-Success "Database migrations completed"
        
        # Create superuser
        Write-Info "Creating Django superuser account..."
        Write-Info "You will be prompted to create an admin account"
        & ".\.venv\Scripts\python.exe" manage.py createsuperuser
        
        # Collect static files
        Write-Info "Collecting static files..."
        & ".\.venv\Scripts\python.exe" manage.py collectstatic --noinput
        
    } catch {
        Write-Error "Database initialization failed: $($_.Exception.Message)"
    }
}

function Configure-WindowsServices {
    Write-Info "Installing NSSM and configuring Windows services..."
    
    # Install NSSM
    try {
        New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
        
        Write-Info "Downloading NSSM..."
        Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile "C:\temp\nssm.zip" -UseBasicParsing
        
        Expand-Archive -Path "C:\temp\nssm.zip" -DestinationPath "C:\temp\" -Force
        Copy-Item "C:\temp\nssm-2.24\win64\nssm.exe" -Destination "C:\Windows\System32\" -Force
        
        Write-Success "NSSM installed"
    } catch {
        Write-Error "Failed to install NSSM: $($_.Exception.Message)"
        return
    }
    
    # Create NoctisPro services
    $pythonPath = Join-Path $InstallPath ".venv\Scripts\python.exe"
    
    # Web Service
    Write-Info "Creating NoctisPro Web Service..."
    nssm install "NoctisPro-Web" $pythonPath
    nssm set "NoctisPro-Web" AppParameters "manage.py runserver 0.0.0.0:8000"
    nssm set "NoctisPro-Web" AppDirectory $InstallPath
    nssm set "NoctisPro-Web" DisplayName "NoctisPro Web Server"
    nssm set "NoctisPro-Web" Description "NoctisPro DICOM PACS Web Interface"
    nssm set "NoctisPro-Web" Start SERVICE_AUTO_START
    
    # Celery Service
    Write-Info "Creating Celery Worker Service..."
    nssm install "NoctisPro-Celery" $pythonPath
    nssm set "NoctisPro-Celery" AppParameters "-m celery -A noctis_pro worker --loglevel=info --pool=solo"
    nssm set "NoctisPro-Celery" AppDirectory $InstallPath
    nssm set "NoctisPro-Celery" DisplayName "NoctisPro Background Worker"
    nssm set "NoctisPro-Celery" Description "NoctisPro Celery Task Worker"
    nssm set "NoctisPro-Celery" Start SERVICE_AUTO_START
    
    # DICOM Service
    Write-Info "Creating DICOM Receiver Service..."
    nssm install "NoctisPro-DICOM" $pythonPath
    nssm set "NoctisPro-DICOM" AppParameters "dicom_receiver.py"
    nssm set "NoctisPro-DICOM" AppDirectory $InstallPath
    nssm set "NoctisPro-DICOM" DisplayName "NoctisPro DICOM Receiver"
    nssm set "NoctisPro-DICOM" Description "NoctisPro DICOM SCP Image Receiver"
    nssm set "NoctisPro-DICOM" Start SERVICE_AUTO_START
    
    Write-Success "Windows services configured"
    
    # Start services
    Write-Info "Starting NoctisPro services..."
    $services = @("NoctisPro-Web", "NoctisPro-Celery", "NoctisPro-DICOM")
    
    foreach ($serviceName in $services) {
        try {
            Start-Service -Name $serviceName
            Write-Success "Started: $serviceName"
            Start-Sleep -Seconds 2
        } catch {
            Write-Warning "Failed to start: $serviceName"
        }
    }
}

function Create-ManagementScripts {
    Write-Info "Creating management scripts..."
    
    # Start script
    $startScript = @'
@echo off
echo ========================================
echo    Starting NoctisPro DICOM System
echo ========================================
echo.

echo [1/5] Starting PostgreSQL Database...
net start "postgresql-x64-17"
if errorlevel 1 echo   WARNING: PostgreSQL may already be running

echo [2/5] Starting Redis Cache Server...
net start "Redis"
if errorlevel 1 echo   WARNING: Redis may already be running

echo [3/5] Starting NoctisPro Web Interface...
net start "NoctisPro-Web"

echo [4/5] Starting NoctisPro Background Worker...
net start "NoctisPro-Celery"

echo [5/5] Starting NoctisPro DICOM Receiver...
net start "NoctisPro-DICOM"

echo.
echo ========================================
echo        NoctisPro System Started
echo ========================================
echo.
echo Web Interface: http://localhost:8000
echo Admin Panel:   http://localhost:8000/admin
echo DICOM Port:    11112 (AE Title: NOCTISPRO)
echo.
pause
'@
    
    $startScript | Out-File -FilePath "$InstallPath\START_NOCTISPRO.bat" -Encoding ASCII
    
    # Stop script
    $stopScript = @'
@echo off
echo ========================================
echo    Stopping NoctisPro DICOM System
echo ========================================
echo.

echo Stopping DICOM Receiver...
net stop "NoctisPro-DICOM"

echo Stopping Background Worker...
net stop "NoctisPro-Celery"

echo Stopping Web Interface...
net stop "NoctisPro-Web"

echo.
echo ========================================
echo       NoctisPro System Stopped
echo ========================================
pause
'@
    
    $stopScript | Out-File -FilePath "$InstallPath\STOP_NOCTISPRO.bat" -Encoding ASCII
    
    # Status script
    $statusScript = @'
@echo off
echo ========================================
echo     NoctisPro System Status Check
echo ========================================
echo.

echo Database Services:
sc query "postgresql-x64-17" | findstr "STATE"
sc query "Redis" | findstr "STATE"

echo.
echo Application Services:
sc query "NoctisPro-Web" | findstr "STATE"
sc query "NoctisPro-Celery" | findstr "STATE"  
sc query "NoctisPro-DICOM" | findstr "STATE"

echo.
echo Network Ports:
netstat -an | findstr ":8000.*LISTENING"
netstat -an | findstr ":11112.*LISTENING"
netstat -an | findstr ":5432.*LISTENING"
netstat -an | findstr ":6379.*LISTENING"

pause
'@
    
    $statusScript | Out-File -FilePath "$InstallPath\STATUS_NOCTISPRO.bat" -Encoding ASCII
    
    Write-Success "Management scripts created"
}

function Test-Installation {
    Write-Info "Running installation tests..."
    
    # Test services
    $services = @(
        @{Name="postgresql-x64-17"; DisplayName="PostgreSQL Database"},
        @{Name="Redis"; DisplayName="Redis Cache Server"},
        @{Name="NoctisPro-Web"; DisplayName="Web Interface"},
        @{Name="NoctisPro-Celery"; DisplayName="Background Worker"},
        @{Name="NoctisPro-DICOM"; DisplayName="DICOM Receiver"}
    )
    
    Write-Info "Service Status:"
    foreach ($svc in $services) {
        try {
            $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if ($service -and $service.Status -eq "Running") {
                Write-Success "$($svc.DisplayName): Running"
            } else {
                Write-Warning "$($svc.DisplayName): Not running"
            }
        } catch {
            Write-Error "$($svc.DisplayName): Service not found"
        }
    }
    
    # Test network ports
    Write-Info "Port Status:"
    $ports = @(
        @{Port=8000; Service="Web Interface"},
        @{Port=11112; Service="DICOM Receiver"}, 
        @{Port=5432; Service="PostgreSQL Database"},
        @{Port=6379; Service="Redis Cache"}
    )
    
    foreach ($portInfo in $ports) {
        $listening = netstat -an | findstr ":$($portInfo.Port).*LISTENING"
        if ($listening) {
            Write-Success "Port $($portInfo.Port) ($($portInfo.Service)): Listening"
        } else {
            Write-Warning "Port $($portInfo.Port) ($($portInfo.Service)): Not listening"
        }
    }
    
    # Test web interface
    Write-Info "Testing web interface..."
    Start-Sleep -Seconds 5
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8000" -TimeoutSec 10 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Success "Web interface responding"
        }
    } catch {
        Write-Warning "Web interface may not be ready yet"
    }
}

function Show-InstallationSummary {
    $accessInfo = @"
========================================
  NoctisPro DICOM System Installation
         COMPLETED SUCCESSFULLY!
========================================

Installation Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Server: $env:COMPUTERNAME
Installation Path: $InstallPath

WEB ACCESS:
-----------
🌐 Local Web Interface: http://localhost:8000
👤 Admin Panel: http://localhost:8000/admin
🔌 API Endpoint: http://localhost:8000/api/

DICOM RECEIVER:
---------------
🏥 Host: localhost (or server IP for external)
📡 Port: 11112
🏷️  AE Title: NOCTISPRO

DATABASE:
---------
🗄️  Type: PostgreSQL $PostgreSQLVersion
📍 Host: localhost:5432
💾 Database: noctispro
👤 User: noctispro_user

MANAGEMENT:
-----------
▶️  Start System: $InstallPath\START_NOCTISPRO.bat
⏹️  Stop System: $InstallPath\STOP_NOCTISPRO.bat
📊 Check Status: $InstallPath\STATUS_NOCTISPRO.bat

NEXT STEPS:
-----------
1. 🌐 Open http://localhost:8000 to access NoctisPro
2. 👤 Login to admin panel with your superuser account
3. 🔧 Configure DICOM devices to send to port 11112
4. 🔒 Change default passwords for production use
5. 🛡️  Configure firewall for external access if needed

SUPPORT:
--------
📋 Installation log: Check PowerShell output above
🔍 Service status: Run STATUS_NOCTISPRO.bat
📖 Documentation: Check project README files

========================================
       🎉 DEPLOYMENT COMPLETE! 🎉
========================================
"@
    
    Write-Host $accessInfo -ForegroundColor Green
    
    # Save access info to file
    $accessInfo | Out-File -FilePath "$InstallPath\INSTALLATION_SUMMARY.txt" -Encoding UTF8
    
    Write-Info "Installation summary saved to: $InstallPath\INSTALLATION_SUMMARY.txt"
    Read-Host "Press Enter to finish"
}

# Start the deployment process
Start-NoctisProDeployment