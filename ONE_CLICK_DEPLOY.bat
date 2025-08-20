@echo off
REM NoctisPro ONE-CLICK AUTO-DEPLOYMENT for Windows Server 2019
REM Handles EVERYTHING automatically until universal HTTPS access
REM NO USER INTERACTION REQUIRED

title NoctisPro One-Click Auto-Deployment

echo.
echo ████████████████████████████████████████████████████████████████
echo ██                                                            ██
echo ██    🚀 NOCTISPRO ONE-CLICK AUTO-DEPLOYMENT 🚀               ██
echo ██                                                            ██
echo ██    Windows Server 2019 + Python 3 + PostgreSQL 17        ██
echo ██    Universal HTTPS + Global DICOM Reception              ██
echo ██                                                            ██
echo ████████████████████████████████████████████████████████████████
echo.

echo 🔧 Checking administrator privileges...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ❌ This script must be run as Administrator!
    echo Right-click this file and select "Run as administrator"
    pause
    exit /b 1
)
echo ✅ Administrator privileges confirmed

echo.
echo 🚀 Starting complete auto-deployment...
echo    This will take 10-15 minutes to complete everything
echo    NO USER INTERACTION REQUIRED - just wait!
echo.

REM Set execution policy for PowerShell scripts
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force"

REM Run the complete auto-deployment
powershell -ExecutionPolicy Bypass -File "FULL_AUTO_DEPLOY_WINDOWS2019.ps1"

echo.
echo 🎉 AUTO-DEPLOYMENT COMPLETE!
echo.
echo Your system is now running with universal HTTPS access!
echo Check the tunnel window for your secure HTTPS URL.
echo.
pause