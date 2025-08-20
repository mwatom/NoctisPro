# NoctisPro Windows Server 2019 Readiness Checker
# Verifies system is ready for auto-deployment
# Run as Administrator

Write-Host "🔍 NOCTISPRO WINDOWS SERVER 2019 READINESS CHECK" -ForegroundColor Green -BackgroundColor Black
Write-Host "=" * 70 -ForegroundColor Green

$allGood = $true

# Check 1: Administrator privileges
Write-Host "`n👑 Checking Administrator Privileges..." -ForegroundColor Yellow
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "✅ Running as Administrator" -ForegroundColor Green
} else {
    Write-Host "❌ NOT running as Administrator" -ForegroundColor Red
    Write-Host "💡 Right-click PowerShell and 'Run as Administrator'" -ForegroundColor Yellow
    $allGood = $false
}

# Check 2: Windows Server 2019
Write-Host "`n🖥️  Checking Windows Version..." -ForegroundColor Yellow
$osVersion = (Get-WmiObject -Class Win32_OperatingSystem).Caption
Write-Host "   OS: $osVersion" -ForegroundColor White

if ($osVersion -match "Server 2019" -or $osVersion -match "Server 2022" -or $osVersion -match "Windows 10" -or $osVersion -match "Windows 11") {
    Write-Host "✅ Compatible Windows version" -ForegroundColor Green
} else {
    Write-Host "⚠️  Untested Windows version (may still work)" -ForegroundColor Yellow
}

# Check 3: Internet connectivity
Write-Host "`n🌐 Checking Internet Connectivity..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "https://www.google.com" -UseBasicParsing -TimeoutSec 10
    Write-Host "✅ Internet connection available" -ForegroundColor Green
} catch {
    Write-Host "❌ No internet connection" -ForegroundColor Red
    Write-Host "💡 Internet required for downloading dependencies" -ForegroundColor Yellow
    $allGood = $false
}

# Check 4: Python 3 installation
Write-Host "`n🐍 Checking Python Installation..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "   Found: $pythonVersion" -ForegroundColor White
    
    if ($pythonVersion -match "Python 3\.[8-9]|Python 3\.1[0-9]") {
        Write-Host "✅ Compatible Python version" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Python version may need upgrade (3.8+ recommended)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Python not found or not in PATH" -ForegroundColor Red
    Write-Host "💡 Auto-deployment will install Python 3.11" -ForegroundColor Yellow
}

# Check 5: PostgreSQL installation
Write-Host "`n🐘 Checking PostgreSQL Installation..." -ForegroundColor Yellow
$pgServices = Get-Service -Name "postgresql*" -ErrorAction SilentlyContinue
if ($pgServices) {
    foreach ($service in $pgServices) {
        Write-Host "   Found: $($service.Name) - $($service.Status)" -ForegroundColor White
    }
    
    # Check specifically for PostgreSQL 17
    $pg17Service = Get-Service -Name "postgresql-x64-17" -ErrorAction SilentlyContinue
    if ($pg17Service) {
        Write-Host "✅ PostgreSQL 17 detected" -ForegroundColor Green
    } else {
        Write-Host "⚠️  PostgreSQL 17 not found (other version detected)" -ForegroundColor Yellow
        Write-Host "💡 Auto-deployment will configure existing PostgreSQL" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ PostgreSQL not found" -ForegroundColor Red
    Write-Host "💡 Auto-deployment will install PostgreSQL 17" -ForegroundColor Yellow
}

# Check 6: Available disk space
Write-Host "`n💾 Checking Disk Space..." -ForegroundColor Yellow
$disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
$freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
Write-Host "   Free space on C: drive: $freeSpaceGB GB" -ForegroundColor White

if ($freeSpaceGB -gt 10) {
    Write-Host "✅ Sufficient disk space" -ForegroundColor Green
} else {
    Write-Host "❌ Low disk space (need at least 10GB)" -ForegroundColor Red
    $allGood = $false
}

# Check 7: Required ports availability
Write-Host "`n🔌 Checking Port Availability..." -ForegroundColor Yellow
$requiredPorts = @(8000, 11112, 5432, 6379)
foreach ($port in $requiredPorts) {
    $portInUse = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($portInUse) {
        Write-Host "   Port $port: ❌ In use" -ForegroundColor Red
        if ($port -eq 5432) {
            Write-Host "     💡 Port 5432 in use is normal (PostgreSQL)" -ForegroundColor Yellow
        } else {
            $allGood = $false
        }
    } else {
        Write-Host "   Port $port: ✅ Available" -ForegroundColor Green
    }
}

# Check 8: PowerShell execution policy
Write-Host "`n🔒 Checking PowerShell Execution Policy..." -ForegroundColor Yellow
$policy = Get-ExecutionPolicy
Write-Host "   Current policy: $policy" -ForegroundColor White

if ($policy -eq "Restricted") {
    Write-Host "⚠️  Execution policy is restricted" -ForegroundColor Yellow
    Write-Host "💡 Auto-deployment will fix this automatically" -ForegroundColor Yellow
} else {
    Write-Host "✅ PowerShell execution policy allows scripts" -ForegroundColor Green
}

# Check 9: NoctisPro files
Write-Host "`n📁 Checking NoctisPro Files..." -ForegroundColor Yellow
$currentDir = Get-Location
if (Test-Path "manage.py") {
    Write-Host "✅ NoctisPro files found in current directory" -ForegroundColor Green
    Write-Host "   Location: $currentDir" -ForegroundColor White
} else {
    Write-Host "❌ NoctisPro files not found in current directory" -ForegroundColor Red
    Write-Host "💡 Please run this script from the NoctisPro project directory" -ForegroundColor Yellow
    $allGood = $false
}

# Final assessment
Write-Host "`n" -NoNewline
if ($allGood) {
    Write-Host "🎉 SYSTEM READY FOR AUTO-DEPLOYMENT! 🎉" -ForegroundColor Green -BackgroundColor Black
    Write-Host "=" * 70 -ForegroundColor Green
    Write-Host "`n🚀 TO START AUTO-DEPLOYMENT:" -ForegroundColor Yellow
    Write-Host "   Run: .\ONE_CLICK_DEPLOY.bat" -ForegroundColor White
    Write-Host "   Or: .\FULL_AUTO_DEPLOY_WINDOWS2019.ps1" -ForegroundColor White
    Write-Host "`n⏱️  Estimated time: 10-15 minutes" -ForegroundColor Cyan
    Write-Host "🔄 No user interaction required!" -ForegroundColor Cyan
} else {
    Write-Host "⚠️  SYSTEM NEEDS PREPARATION" -ForegroundColor Yellow -BackgroundColor Black
    Write-Host "=" * 70 -ForegroundColor Yellow
    Write-Host "`n💡 REQUIRED ACTIONS:" -ForegroundColor Yellow
    Write-Host "   1. Run PowerShell as Administrator" -ForegroundColor White
    Write-Host "   2. Ensure internet connectivity" -ForegroundColor White
    Write-Host "   3. Free up disk space if needed" -ForegroundColor White
    Write-Host "   4. Run from NoctisPro project directory" -ForegroundColor White
    Write-Host "`n🔄 Run this check again after fixing issues" -ForegroundColor Cyan
}

Write-Host "`n📞 SUPPORT INFORMATION:" -ForegroundColor Cyan
Write-Host "   📧 Email: support@noctispro.com" -ForegroundColor White
Write-Host "   📖 Docs: Check deployment guides in project" -ForegroundColor White
Write-Host "   🐛 Issues: Create GitHub issue for problems" -ForegroundColor White

Write-Host "`nPress any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")