@echo off
echo ========================================
echo   NoctisPro DICOM System Deployment
echo   Windows Server 2019 Auto-Installer
echo ========================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo Right-click this file and select "Run as administrator"
    pause
    exit /b 1
)

echo ✅ Running as Administrator
echo.

REM Check if PowerShell is available
powershell -Command "Write-Host 'PowerShell is available'" >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: PowerShell is not available!
    echo Please ensure PowerShell is installed on this system.
    pause
    exit /b 1
)

echo ✅ PowerShell is available
echo.

REM Set execution policy for PowerShell scripts
echo 🔧 Setting PowerShell execution policy...
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"

REM Check if deployment script exists locally
if exist "WINDOWS_2019_MANUAL_DEPLOY.ps1" (
    echo ✅ Found local deployment script
    echo 🚀 Starting NoctisPro deployment...
    echo.
    powershell -ExecutionPolicy Bypass -File "WINDOWS_2019_MANUAL_DEPLOY.ps1"
) else (
    echo ⚠️  Local deployment script not found
    echo.
    echo MANUAL INSTRUCTIONS:
    echo 1. Download WINDOWS_2019_MANUAL_DEPLOY.ps1 from the repository
    echo 2. Place it in the same directory as this batch file
    echo 3. Run this batch file again
    echo.
    echo OR copy the PowerShell script content directly into PowerShell
    echo.
)

echo.
echo Deployment process completed.
pause