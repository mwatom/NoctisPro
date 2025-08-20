@echo off
REM NoctisPro ULTIMATE AUTO-DEPLOYMENT
REM Double-click this file to deploy everything automatically
REM NO SETUP REQUIRED - handles everything from scratch

title NoctisPro Ultimate Auto-Deployment

echo.
echo ████████████████████████████████████████████████████████████████
echo ██                                                            ██
echo ██    🚀 NOCTISPRO ULTIMATE AUTO-DEPLOYMENT 🚀               ██
echo ██                                                            ██
echo ██         🎯 EVERYTHING AUTOMATED 🎯                        ██
echo ██                                                            ██
echo ██    ✅ Python 3 Auto-Install                               ██
echo ██    ✅ PostgreSQL 17 Auto-Setup                            ██
echo ██    ✅ Universal HTTPS Auto-Config                         ██
echo ██    ✅ Global DICOM Reception                              ██
echo ██    ✅ AE Title "MAE" Auto-Setup                           ██
echo ██                                                            ██
echo ████████████████████████████████████████████████████████████████
echo.

echo 🔍 Checking system readiness...

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ❌ ADMINISTRATOR PRIVILEGES REQUIRED
    echo.
    echo 💡 TO FIX:
    echo    1. Right-click this file
    echo    2. Select "Run as administrator"
    echo    3. Click "Yes" when prompted
    echo.
    pause
    exit /b 1
)

echo ✅ Administrator privileges confirmed
echo.

echo 🔧 Setting PowerShell execution policy...
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force" >nul 2>&1
echo ✅ PowerShell configured

echo.
echo 🚀 STARTING COMPLETE AUTO-DEPLOYMENT...
echo.
echo ⏱️  Estimated time: 10-15 minutes
echo 🔄 No user interaction required
echo 📺 Watch progress in the windows that open
echo.
echo Starting in 5 seconds...
timeout /t 5 /nobreak >nul

REM Run the complete auto-deployment
powershell -ExecutionPolicy Bypass -File "FULL_AUTO_DEPLOY_WINDOWS2019.ps1" -AETitle "MAE"

echo.
echo 🎉 AUTO-DEPLOYMENT COMPLETED!
echo.
echo Your NoctisPro system is now running with:
echo    ✅ Universal HTTPS access
echo    ✅ Global DICOM reception (AE Title: MAE)
echo    ✅ PostgreSQL 17 database
echo    ✅ Auto-start services
echo.
echo 🌐 Check the tunnel window for your HTTPS URL!
echo.
pause