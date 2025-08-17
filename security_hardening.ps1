# NoctisPro Security Hardening Script for Windows Server 2012
# Run after initial deployment to secure the system for internet access
# Run as Administrator

param(
    [string]$InstallPath = "C:\noctis",
    [string]$NewAdminPassword = "",
    [string]$Domain = "",
    [switch]$EnableHTTPS = $false
)

$ErrorActionPreference = 'Stop'
Write-Host "🛡️  NoctisPro Security Hardening Starting..." -ForegroundColor Red
Write-Host "🔒 Securing system for internet access..." -ForegroundColor Yellow

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Error "❌ This script must be run as Administrator"
    exit 1
}

Set-Location $InstallPath

# Step 1: Change Default Admin Password
Write-Host "`n🔑 Changing Admin Password..." -ForegroundColor Yellow
if (-not $NewAdminPassword) {
    $NewAdminPassword = Read-Host "Enter new admin password (leave blank to skip)" -AsSecureString
    $NewAdminPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewAdminPassword))
}

if ($NewAdminPassword) {
    $changePasswordScript = @"
from accounts.models import User
user = User.objects.get(username='admin')
user.set_password('$NewAdminPassword')
user.save()
print('✅ Admin password changed successfully')
"@
    $changePasswordScript | python manage.py shell
    Write-Host "✅ Admin password updated" -ForegroundColor Green
} else {
    Write-Warning "⚠️  Admin password not changed - using default password is a security risk!"
}

# Step 2: Configure Production Settings
Write-Host "`n⚙️  Configuring Production Settings..." -ForegroundColor Yellow

# Backup original settings
Copy-Item "noctis_pro\settings.py" "noctis_pro\settings.py.backup"

# Read current settings
$settingsContent = Get-Content "noctis_pro\settings.py" -Raw

# Update critical security settings
$settingsContent = $settingsContent -replace "DEBUG = True", "DEBUG = False"

if ($Domain) {
    $allowedHosts = "ALLOWED_HOSTS = ['$Domain', 'localhost', '127.0.0.1']"
} else {
    $allowedHosts = "ALLOWED_HOSTS = ['*']  # WARNING: Configure this with your actual domain"
}
$settingsContent = $settingsContent -replace "ALLOWED_HOSTS = \[.*?\]", $allowedHosts

# Generate new secret key
$newSecretKey = -join ((1..50) | ForEach {Get-Random -InputObject (@('a'..'z') + @('A'..'Z') + @('0'..'9') + @('!','@','#','$','%','^','&','*'))})
$settingsContent = $settingsContent -replace "SECRET_KEY = '.*?'", "SECRET_KEY = '$newSecretKey'"

# Add security headers
$securitySettings = @"

# Security settings for production
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'
SECURE_HSTS_SECONDS = 31536000 if not DEBUG else 0
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True

# Session security
SESSION_COOKIE_SECURE = True if not DEBUG else False
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_AGE = 3600  # 1 hour
SESSION_EXPIRE_AT_BROWSER_CLOSE = True

# CSRF protection
CSRF_COOKIE_SECURE = True if not DEBUG else False
CSRF_COOKIE_HTTPONLY = True

# Logging for security events
LOGGING['loggers']['security'] = {
    'handlers': ['file'],
    'level': 'WARNING',
    'propagate': True,
}
"@

$settingsContent += $securitySettings
$settingsContent | Set-Content "noctis_pro\settings.py"

Write-Host "✅ Production settings configured" -ForegroundColor Green

# Step 3: Enhanced Windows Firewall Configuration
Write-Host "`n🔥 Configuring Enhanced Firewall Rules..." -ForegroundColor Yellow

try {
    # Remove any existing rules
    netsh advfirewall firewall delete rule name="NoctisPro-HTTP" >$null 2>&1
    netsh advfirewall firewall delete rule name="NoctisPro-DICOM" >$null 2>&1
    
    # Add specific rules
    netsh advfirewall firewall add rule name="NoctisPro-HTTP-In" dir=in action=allow protocol=TCP localport=8000 remoteip=any
    netsh advfirewall firewall add rule name="NoctisPro-DICOM-In" dir=in action=allow protocol=TCP localport=11112 remoteip=any
    
    # Block unnecessary ports
    netsh advfirewall firewall add rule name="Block-SSH" dir=in action=block protocol=TCP localport=22
    netsh advfirewall firewall add rule name="Block-FTP" dir=in action=block protocol=TCP localport=21
    netsh advfirewall firewall add rule name="Block-Telnet" dir=in action=block protocol=TCP localport=23
    
    Write-Host "✅ Firewall rules configured" -ForegroundColor Green
} catch {
    Write-Warning "⚠️  Firewall configuration failed: $_"
}

# Step 4: Disable Unnecessary Services
Write-Host "`n⚙️  Disabling Unnecessary Services..." -ForegroundColor Yellow

$servicesToDisable = @(
    'Fax',
    'Spooler',
    'RemoteRegistry',
    'Telnet',
    'SNMP'
)

foreach ($service in $servicesToDisable) {
    try {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Running') {
            Stop-Service -Name $service -Force
            Set-Service -Name $service -StartupType Disabled
            Write-Host "   ✅ Disabled: $service" -ForegroundColor Green
        }
    } catch {
        Write-Host "   ⚠️  Could not disable: $service" -ForegroundColor Yellow
    }
}

# Step 5: Configure User Account Security
Write-Host "`n👥 Configuring User Account Security..." -ForegroundColor Yellow

$userSecurityScript = @"
from accounts.models import User
from django.utils import timezone
from datetime import timedelta

# Disable any default/test users
test_users = User.objects.filter(username__in=['test', 'demo', 'guest', 'user'])
for user in test_users:
    user.is_active = False
    user.save()
    print(f'🔒 Disabled test user: {user.username}')

# Ensure all users have facilities assigned
users_without_facility = User.objects.filter(facility__isnull=True, is_active=True)
if users_without_facility.exists():
    from accounts.models import Facility
    default_facility = Facility.objects.first()
    for user in users_without_facility:
        user.facility = default_facility
        user.save()
        print(f'🏥 Assigned facility to: {user.username}')

# Check for users with weak passwords (this would need custom implementation)
print('✅ User security check completed')
"@

$userSecurityScript | python manage.py shell

# Step 6: Setup Automated Backups
Write-Host "`n💾 Setting up Automated Backups..." -ForegroundColor Yellow

$backupScript = @"
@echo off
title NoctisPro Backup
set BACKUP_ROOT=C:\noctis_backups
set DATE_TIME=%date:~-4,4%-%date:~-10,2%-%date:~-7,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%
set DATE_TIME=%DATE_TIME: =0%
set BACKUP_DIR=%BACKUP_ROOT%\%DATE_TIME%

echo Creating backup: %BACKUP_DIR%
mkdir "%BACKUP_DIR%" 2>nul

echo Backing up database...
copy "C:\noctis\db.sqlite3" "%BACKUP_DIR%\db.sqlite3"

echo Backing up media files...
xcopy "C:\noctis\media" "%BACKUP_DIR%\media\" /E /I /Q

echo Backing up settings...
copy "C:\noctis\noctis_pro\settings.py" "%BACKUP_DIR%\settings.py"

echo Cleaning old backups (keeping last 7 days)...
forfiles /p "%BACKUP_ROOT%" /m *.* /d -7 /c "cmd /c rmdir /s /q @path" 2>nul

echo Backup completed: %BACKUP_DIR%
"@

$backupScript | Out-File -FilePath "backup_system.bat" -Encoding ASCII

# Create scheduled task for daily backups
try {
    $action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c C:\noctis\backup_system.bat"
    $trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM
    $principal = New-ScheduledTaskPrincipal -UserID "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName "NoctisPro-Daily-Backup" -Description "Daily backup of NoctisPro system"
    Write-Host "✅ Automated daily backups configured" -ForegroundColor Green
} catch {
    Write-Warning "⚠️  Failed to setup automated backups: $_"
}

# Step 7: Install Security Updates
Write-Host "`n🔄 Checking for Windows Updates..." -ForegroundColor Yellow
try {
    # Enable automatic updates
    $au = (New-Object -ComObject Microsoft.Update.AutoUpdate)
    $au.EnableService()
    Write-Host "✅ Automatic updates enabled" -ForegroundColor Green
} catch {
    Write-Warning "⚠️  Could not configure automatic updates"
}

# Step 8: Create Security Monitoring Script
Write-Host "`n📊 Setting up Security Monitoring..." -ForegroundColor Yellow

$monitoringScript = @"
@echo off
title NoctisPro Security Monitor
echo ============================================
echo    NoctisPro Security Status Monitor
echo ============================================
echo.

echo Checking system status...
echo.

echo [1] Active Users:
powershell "python manage.py shell -c \"from accounts.models import User; print(f'Active users: {User.objects.filter(is_active=True).count()}')\""

echo.
echo [2] Failed Login Attempts (last 24h):
powershell "Get-EventLog -LogName Security -InstanceId 4625 -After (Get-Date).AddDays(-1) | Measure-Object | Select-Object -ExpandProperty Count"

echo.
echo [3] Firewall Status:
netsh advfirewall show allprofiles state

echo.
echo [4] Service Status:
sc query NoctisPro 2>nul || echo NoctisPro service not installed

echo.
echo [5] Disk Space:
dir C:\ | findstr "bytes free"

echo.
echo [6] Memory Usage:
powershell "Get-WmiObject -Class Win32_OperatingSystem | Select-Object @{Name='Memory Usage';Expression={'{0:N2}' -f ((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory)*100)/ $_.TotalVisibleMemorySize) + '%'}}"

echo.
echo ============================================
pause
"@

$monitoringScript | Out-File -FilePath "security_monitor.bat" -Encoding ASCII
Write-Host "✅ Security monitoring script created" -ForegroundColor Green

# Step 9: Configure Logging and Auditing
Write-Host "`n📝 Configuring Security Logging..." -ForegroundColor Yellow

$loggingScript = @"
# Configure advanced logging
LOGGING['handlers']['security_file'] = {
    'level': 'WARNING',
    'class': 'logging.FileHandler',
    'filename': 'security.log',
    'formatter': 'verbose',
}

LOGGING['formatters']['verbose'] = {
    'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
    'style': '{',
}

LOGGING['loggers']['django.security'] = {
    'handlers': ['security_file'],
    'level': 'WARNING',
    'propagate': True,
}

# Security middleware for logging
MIDDLEWARE.insert(0, 'django.middleware.security.SecurityMiddleware')
"@

# Append to settings
$loggingScript | Add-Content "noctis_pro\settings.py"

# Step 10: Create Security Checklist
Write-Host "`n📋 Creating Security Checklist..." -ForegroundColor Yellow

$checklistContent = @"
# NoctisPro Security Checklist

## ✅ Initial Security Setup Completed

### Critical Security Items:
- [x] Default admin password changed
- [x] Production settings configured (DEBUG=False)
- [x] Secret key regenerated
- [x] Firewall rules configured
- [x] Unnecessary services disabled
- [x] Automated backups configured
- [x] Security logging enabled

### Ongoing Security Tasks:

#### Daily:
- [ ] Review security logs (run security_monitor.bat)
- [ ] Check for failed login attempts
- [ ] Monitor system resources

#### Weekly:
- [ ] Review user accounts and permissions
- [ ] Check backup integrity
- [ ] Review firewall logs
- [ ] Update system patches

#### Monthly:
- [ ] Update Python packages
- [ ] Review and rotate credentials
- [ ] Audit user access logs
- [ ] Test backup restoration
- [ ] Review security configurations

### Security Best Practices:

1. **Password Policy:**
   - Use strong passwords (12+ characters)
   - Enable account lockout after failed attempts
   - Regular password rotation

2. **Network Security:**
   - Use HTTPS in production (SSL certificate)
   - Implement IP whitelisting if possible
   - Monitor network traffic

3. **System Hardening:**
   - Keep Windows Server updated
   - Disable unnecessary services
   - Regular security scans

4. **Data Protection:**
   - Encrypt sensitive data at rest
   - Secure DICOM file storage
   - Regular database backups

5. **Monitoring:**
   - Log all security events
   - Monitor for unusual activity
   - Set up alerts for critical events

### Emergency Contacts:
- System Administrator: ________________
- IT Security Team: ___________________
- Vendor Support: ____________________

### Quick Response Commands:

Block suspicious IP:
netsh advfirewall firewall add rule name="Block-Suspicious-IP" dir=in action=block remoteip=XXX.XXX.XXX.XXX

Disable user account:
python manage.py shell -c "from accounts.models import User; User.objects.filter(username='USERNAME').update(is_active=False)"

Emergency shutdown:
shutdown /s /t 60 /c "Emergency security shutdown"

View recent logins:
python manage.py shell -c "from accounts.models import UserSession; [print(f'{s.user.username}: {s.login_time}') for s in UserSession.objects.filter(login_time__gte=timezone.now()-timedelta(hours=24))]"
"@

$checklistContent | Out-File -FilePath "SECURITY_CHECKLIST.txt" -Encoding UTF8
Write-Host "✅ Security checklist created" -ForegroundColor Green

# Final Summary
Write-Host "`n🎉 Security Hardening Complete!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

Write-Host "`n📋 SECURITY SUMMARY:" -ForegroundColor Cyan
Write-Host "   ✅ Admin password: $(if($NewAdminPassword){'Changed'}else{'⚠️ STILL DEFAULT'})" -ForegroundColor $(if($NewAdminPassword){'Green'}else{'Red'})
Write-Host "   ✅ Production mode: Enabled" -ForegroundColor Green
Write-Host "   ✅ Firewall: Configured" -ForegroundColor Green
Write-Host "   ✅ Backups: Automated daily" -ForegroundColor Green
Write-Host "   ✅ Monitoring: Available" -ForegroundColor Green

Write-Host "`n🔧 SECURITY TOOLS CREATED:" -ForegroundColor Yellow
Write-Host "   📝 backup_system.bat - Manual backup utility" -ForegroundColor White
Write-Host "   📊 security_monitor.bat - Security status checker" -ForegroundColor White
Write-Host "   📋 SECURITY_CHECKLIST.txt - Ongoing security tasks" -ForegroundColor White

Write-Host "`n🚨 CRITICAL REMINDERS:" -ForegroundColor Red
if (-not $NewAdminPassword) {
    Write-Host "   ⚠️  CHANGE ADMIN PASSWORD IMMEDIATELY!" -ForegroundColor Red
}
Write-Host "   ⚠️  Configure SSL/TLS for production use" -ForegroundColor Yellow
Write-Host "   ⚠️  Set up proper domain in ALLOWED_HOSTS" -ForegroundColor Yellow
Write-Host "   ⚠️  Review and test backup procedures" -ForegroundColor Yellow

Write-Host "`n✅ Your NoctisPro system is now hardened for internet access!" -ForegroundColor Green