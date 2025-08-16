# NoctisPro Internet Deployment Script for Windows
# Makes your NoctisPro system accessible from anywhere on the internet
# Run as Administrator in PowerShell

param(
    [string]$ProjectPath = (Get-Location),
    [string]$AdminUsername = "admin",
    [string]$AdminPassword = "Admin123!",
    [string]$AdminEmail = "admin@noctispro.com",
    [int]$Port = 8000,
    [string]$TunnelType = "cloudflare"  # cloudflare or ngrok
)

$ErrorActionPreference = 'Stop'
Write-Host "🚀 NoctisPro Internet Deployment Starting..." -ForegroundColor Green
Write-Host "📁 Project Path: $ProjectPath" -ForegroundColor Cyan
Write-Host "🌐 Local Port: $Port" -ForegroundColor Cyan
Write-Host "🌍 Tunnel Type: $TunnelType" -ForegroundColor Cyan

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

# Navigate to project directory
Set-Location $ProjectPath
Write-Host "✅ Working in directory: $ProjectPath" -ForegroundColor Green

# Step 1: Check Python installation
Write-Host "`n🐍 Checking Python Installation..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    if ($pythonVersion -match "Python") {
        Write-Host "✅ Found Python: $pythonVersion" -ForegroundColor Green
    } else {
        throw "Python not found"
    }
} catch {
    Write-Host "❌ Python not found. Installing Python..." -ForegroundColor Red
    
    # Download and install Python
    $pythonInstaller = "python-3.11.0-amd64.exe"
    $pythonUrl = "https://www.python.org/ftp/python/3.11.0/$pythonInstaller"
    
    Write-Host "📥 Downloading Python installer..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
    
    Write-Host "🔧 Installing Python..." -ForegroundColor Yellow
    Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1" -Wait
    
    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Remove-Item $pythonInstaller
    Write-Host "✅ Python installed successfully" -ForegroundColor Green
}

# Step 2: Install required dependencies
Write-Host "`n📦 Installing Required Dependencies..." -ForegroundColor Yellow

$requiredPackages = @(
    "django>=4.2.0",
    "djangorestframework",
    "pillow",
    "pydicom",
    "pynetdicom", 
    "numpy",
    "scipy",
    "waitress"
)

foreach ($package in $requiredPackages) {
    try {
        Write-Host "Installing $package..." -ForegroundColor Cyan
        python -m pip install $package --quiet
        Write-Host "✅ Installed $package" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Warning: Failed to install $package" -ForegroundColor Yellow
    }
}

# Step 3: Run the login fix script
Write-Host "`n🔧 Running Login Fix Script..." -ForegroundColor Yellow
try {
    python fix_login_and_deploy_internet.py
    Write-Host "✅ Login fix completed" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Login fix had issues, but continuing..." -ForegroundColor Yellow
}

# Step 4: Setup Cloudflare Tunnel
Write-Host "`n🌍 Setting up Internet Access..." -ForegroundColor Yellow

if ($TunnelType -eq "cloudflare") {
    # Download Cloudflared
    $cloudflaredPath = "$env:TEMP\cloudflared.exe"
    $cloudflaredUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
    
    Write-Host "📥 Downloading Cloudflare Tunnel..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $cloudflaredUrl -OutFile $cloudflaredPath
        Write-Host "✅ Cloudflare Tunnel downloaded" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to download Cloudflare Tunnel" -ForegroundColor Red
        exit 1
    }
    
    # Copy to system directory
    $systemCloudflared = "C:\Windows\System32\cloudflared.exe"
    Copy-Item $cloudflaredPath $systemCloudflared -Force
    Write-Host "✅ Cloudflare Tunnel installed to system" -ForegroundColor Green
    
} elseif ($TunnelType -eq "ngrok") {
    # Download ngrok
    $ngrokZip = "$env:TEMP\ngrok.zip"
    $ngrokPath = "$env:TEMP\ngrok.exe"
    $ngrokUrl = "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip"
    
    Write-Host "📥 Downloading ngrok..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $ngrokUrl -OutFile $ngrokZip
        Expand-Archive $ngrokZip -DestinationPath $env:TEMP -Force
        
        # Copy to system directory
        $systemNgrok = "C:\Windows\System32\ngrok.exe"
        Copy-Item $ngrokPath $systemNgrok -Force
        Write-Host "✅ ngrok installed to system" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to download ngrok" -ForegroundColor Red
        exit 1
    }
}

# Step 5: Create startup scripts
Write-Host "`n📝 Creating Startup Scripts..." -ForegroundColor Yellow

# Django startup script
$djangoScript = @"
@echo off
cd /d "$ProjectPath"
echo Starting NoctisPro Django Server...
python -m waitress --host=0.0.0.0 --port=$Port noctis_pro.wsgi:application
"@

$djangoScript | Out-File -FilePath "start_django.bat" -Encoding ASCII
Write-Host "✅ Created start_django.bat" -ForegroundColor Green

# Tunnel startup script
if ($TunnelType -eq "cloudflare") {
    $tunnelScript = @"
@echo off
echo Starting Cloudflare Tunnel...
cloudflared tunnel --url http://localhost:$Port
"@
} else {
    $tunnelScript = @"
@echo off
echo Starting ngrok Tunnel...
ngrok http $Port
"@
}

$tunnelScript | Out-File -FilePath "start_tunnel.bat" -Encoding ASCII
Write-Host "✅ Created start_tunnel.bat" -ForegroundColor Green

# Combined startup script
$combinedScript = @"
@echo off
title NoctisPro Internet Deployment
echo ================================
echo  NoctisPro Internet Deployment
echo ================================
echo.

echo Starting Django server...
start "Django Server" /min cmd /c "start_django.bat"

echo Waiting for Django to start...
timeout /t 10 /nobreak > nul

echo Starting internet tunnel...
start "Internet Tunnel" cmd /c "start_tunnel.bat"

echo.
echo ================================
echo  NoctisPro is now accessible!
echo ================================
echo.
echo Login Credentials:
echo Username: $AdminUsername
echo Password: $AdminPassword
echo.
echo The tunnel URL will appear in the tunnel window.
echo Look for a URL like: https://xxxx.trycloudflare.com
echo.
echo Press any key to open the tunnel window...
pause > nul

echo Opening tunnel status...
start cmd /c "start_tunnel.bat"
"@

$combinedScript | Out-File -FilePath "start_noctispro_internet.bat" -Encoding ASCII
Write-Host "✅ Created start_noctispro_internet.bat" -ForegroundColor Green

# Step 6: Create Windows Service (optional)
Write-Host "`n🔧 Creating Windows Service..." -ForegroundColor Yellow

$serviceScript = @"
# NoctisPro Service Management Script
param([string]`$Action = "install")

`$serviceName = "NoctisPro"
`$serviceDisplayName = "NoctisPro Medical Imaging System"
`$servicePath = "`"$ProjectPath\start_django.bat`""

switch (`$Action.ToLower()) {
    "install" {
        Write-Host "Installing NoctisPro service..." -ForegroundColor Green
        New-Service -Name `$serviceName -DisplayName `$serviceDisplayName -BinaryPathName `$servicePath -StartupType Automatic
        Write-Host "✅ Service installed. Use 'Start-Service NoctisPro' to start" -ForegroundColor Green
    }
    "remove" {
        Write-Host "Removing NoctisPro service..." -ForegroundColor Yellow
        Stop-Service `$serviceName -ErrorAction SilentlyContinue
        sc.exe delete `$serviceName
        Write-Host "✅ Service removed" -ForegroundColor Green
    }
    "start" {
        Start-Service `$serviceName
        Write-Host "✅ Service started" -ForegroundColor Green
    }
    "stop" {
        Stop-Service `$serviceName
        Write-Host "✅ Service stopped" -ForegroundColor Green
    }
}
"@

$serviceScript | Out-File -FilePath "manage_service.ps1" -Encoding UTF8
Write-Host "✅ Created manage_service.ps1" -ForegroundColor Green

# Step 7: Final instructions
Write-Host "`n🎉 NoctisPro Internet Deployment Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

Write-Host "`n📋 How to Start Your Internet-Accessible NoctisPro:" -ForegroundColor Yellow
Write-Host "1. Double-click: start_noctispro_internet.bat" -ForegroundColor Cyan
Write-Host "2. Wait for the tunnel URL to appear (e.g., https://xxxx.trycloudflare.com)" -ForegroundColor Cyan
Write-Host "3. Access your system from anywhere using that URL!" -ForegroundColor Cyan

Write-Host "`n🔑 Login Credentials:" -ForegroundColor Yellow
Write-Host "   Username: $AdminUsername" -ForegroundColor White
Write-Host "   Password: $AdminPassword" -ForegroundColor White
Write-Host "   Role: Administrator" -ForegroundColor White

Write-Host "`n🛠️  Manual Commands:" -ForegroundColor Yellow
Write-Host "   Start Django only: start_django.bat" -ForegroundColor Cyan
Write-Host "   Start tunnel only: start_tunnel.bat" -ForegroundColor Cyan
Write-Host "   Install as service: .\manage_service.ps1 -Action install" -ForegroundColor Cyan

Write-Host "`n🔐 Security Notes:" -ForegroundColor Red
Write-Host "- Your system will be accessible from the internet" -ForegroundColor Yellow
Write-Host "- Make sure to change default passwords in production" -ForegroundColor Yellow
Write-Host "- Monitor access logs regularly" -ForegroundColor Yellow

Write-Host "`n🚀 Ready to launch? Run: .\start_noctispro_internet.bat" -ForegroundColor Green

# Ask if user wants to start immediately
$response = Read-Host "`nStart NoctisPro now? (y/n)"
if ($response -eq "y" -or $response -eq "Y") {
    Write-Host "`n🚀 Starting NoctisPro..." -ForegroundColor Green
    .\start_noctispro_internet.bat
}