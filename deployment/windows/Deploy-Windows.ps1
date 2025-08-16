param(
  [string]$RepoRoot,
  [string]$AppName = 'NoctisPro',
  [int]$Port = 8000,
  [string]$PythonVersion = '3.10.11',
  [string]$SuperuserUsername = 'admin',
  [string]$SuperuserPassword = 'Admin123!',
  [string]$SuperuserEmail = 'admin@example.com'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Assert-Admin {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) { throw 'Run this script in an elevated PowerShell (Run as Administrator).' }
}

function Resolve-RepoRoot {
  param([string]$InputPath)
  if ($InputPath -and (Test-Path $InputPath)) { return (Resolve-Path $InputPath).Path }
  # default: assume script is in repo\deployment\windows
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  $repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
  if (-not (Test-Path (Join-Path $repoRoot 'manage.py'))) {
    throw "Could not locate repo root. Pass -RepoRoot C:\\path\\to\\repo or place script in repo\\deployment\\windows."
  }
  return $repoRoot
}

function New-Folder { param([string[]]$Paths) foreach ($p in $Paths) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null } } }

function Invoke-Download {
  param([string[]]$Uris, [string]$OutFile)
  foreach ($uri in $Uris) {
    try { Invoke-WebRequest -Uri $uri -OutFile $OutFile -UseBasicParsing; return } catch { }
  }
  throw "Failed to download to $OutFile from: $($Uris -join ', ')"
}

function Expand-Zip {
  param([string]$ZipPath, [string]$Dest)
  try { Expand-Archive -Path $ZipPath -DestinationPath $Dest -Force }
  catch {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $Dest)
  }
}

function Get-Python310Path {
  $candidates = @(
    'C:\\Program Files\\Python310\\python.exe',
    'C:\\Python310\\python.exe'
  )
  foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
  foreach ($key in @('HKLM:\\SOFTWARE\\Python\\PythonCore\\3.10\\InstallPath','HKLM:\\SOFTWARE\\WOW6432Node\\Python\\PythonCore\\3.10\\InstallPath')) {
    try {
      $reg = Get-Item $key -ErrorAction Stop
      $path = $reg.GetValue('')
      if ($path) {
        $exe = Join-Path $path 'python.exe'
        if (Test-Path $exe) { return $exe }
      }
    } catch {}
  }
  return $null
}

# --- Begin ---
Assert-Admin
$RepoRoot = Resolve-RepoRoot -InputPath $RepoRoot
$AppNameSafe = ($AppName -replace '[^A-Za-z0-9_-]', '')
if (-not $AppNameSafe) { $AppNameSafe = 'App' }

$LogsDir = "C:\\logs\\$AppNameSafe"
$TempDir = "C:\\temp\\$AppNameSafe"
$VenvDir = Join-Path $RepoRoot '.venv'
$VenvPython = Join-Path $VenvDir 'Scripts\\python.exe'
$WaitressExe = Join-Path $VenvDir 'Scripts\\waitress-serve.exe'
$NssmSvc = "$AppNameSafe-App"
$TunnelSvc = "$AppNameSafe-Tunnel"

New-Folder @($LogsDir,$TempDir)

# --- Python 3.10 ---
$pythonExe = Get-Python310Path
if (-not $pythonExe) {
  $pyInstaller = Join-Path $TempDir "python-$PythonVersion-amd64.exe"
  $pyUris = @(
    "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe"
  )
  Write-Host "Downloading Python $PythonVersion..."
  Invoke-Download -Uris $pyUris -OutFile $pyInstaller
  Unblock-File $pyInstaller
  Write-Host "Installing Python $PythonVersion..."
  Start-Process -FilePath $pyInstaller -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1 Include_test=0' -Wait
  $pythonExe = Get-Python310Path
  if (-not $pythonExe) { throw 'Python 3.10 installation failed.' }
}
Write-Host "Python: $pythonExe"

# --- Virtualenv ---
if (-not (Test-Path $VenvPython)) { & $pythonExe -m venv $VenvDir }
& $VenvPython -m pip install --upgrade pip setuptools wheel

# --- Dependencies (Windows-friendly) ---
$reqWindows = Join-Path $RepoRoot 'requirements-windows.txt'
$reqTxt = Join-Path $RepoRoot 'requirements.txt'
$installed = $false
try {
  if (Test-Path $reqWindows) {
    Write-Host 'Installing Windows requirements...'
    & $VenvPython -m pip install -r $reqWindows
    $installed = $true
  } elseif (Test-Path $reqTxt) {
    Write-Warning 'requirements-windows.txt not found; installing from requirements.txt (may fail on Windows).'
    & $VenvPython -m pip install -r $reqTxt
    $installed = $true
  }
} catch {
  Write-Warning "Dependency install failed: $($_.Exception.Message)"
  $installed = $false
}
if (-not $installed) {
  Write-Warning 'Falling back to minimal dependencies...'
  & $VenvPython -m pip install Django djangorestframework Pillow numpy pydicom waitress
}
# Ensure waitress present
& $VenvPython -m pip install waitress --upgrade

# --- Django setup ---
Push-Location $RepoRoot
try {
  & $VenvPython manage.py migrate --noinput
  $env:DJANGO_SUPERUSER_USERNAME = $SuperuserUsername
  $env:DJANGO_SUPERUSER_EMAIL = $SuperuserEmail
  $env:DJANGO_SUPERUSER_PASSWORD = $SuperuserPassword
  $suScript = @'
from django.contrib.auth import get_user_model
import os
User = get_user_model()
u = os.environ.get("DJANGO_SUPERUSER_USERNAME","admin")
e = os.environ.get("DJANGO_SUPERUSER_EMAIL","admin@example.com")
p = os.environ.get("DJANGO_SUPERUSER_PASSWORD","Admin123!")
exists = User.objects.filter(username=u).exists()
print(f"Superuser '{u}' exists? {exists}")
if not exists:
    User.objects.create_superuser(username=u, email=e, password=p)
    print("Superuser created.")
'@
  $suPath = Join-Path $TempDir 'create_superuser.py'
  $suScript | Set-Content -Path $suPath -Encoding UTF8
  & $VenvPython manage.py shell < $suPath
  & $VenvPython manage.py collectstatic --noinput
} finally {
  Pop-Location
}

# --- Download NSSM ---
Write-Host 'Fetching NSSM...'
$nssmZip = Join-Path $TempDir 'nssm.zip'
Invoke-Download -Uris @(
  'https://nssm.cc/release/nssm-2.24.zip',
  'https://github.com/kohsuke/nssm/releases/download/nssm-2.24/nssm-2.24.zip',
  'https://github.com/ejsmont-artur/nssm-mirror/releases/download/v2.24-101-g897c7ad/nssm-2.24-101-g897c7ad.zip'
) -OutFile $nssmZip
Expand-Zip -ZipPath $nssmZip -Dest $TempDir
$nssmExe = Get-ChildItem -Path $TempDir -Recurse -Filter 'nssm.exe' | Where-Object { $_.FullName -match '\\win64\\' } | Select-Object -First 1
if (-not $nssmExe) { throw 'nssm.exe (win64) not found after extraction.' }
$nssm = $nssmExe.FullName

# --- App service (Waitress) ---
try { Get-Service -Name $NssmSvc -ErrorAction Stop | Out-Null; Stop-Service $NssmSvc -Force -ErrorAction SilentlyContinue; sc.exe delete $NssmSvc | Out-Null } catch {}
& $nssm install $NssmSvc $WaitressExe "--listen=127.0.0.1:$Port noctis_pro.wsgi:application" | Out-Null
& $nssm set $NssmSvc AppDirectory $RepoRoot | Out-Null
& $nssm set $NssmSvc AppStdout (Join-Path $LogsDir 'app-out.log') | Out-Null
& $nssm set $NssmSvc AppStderr (Join-Path $LogsDir 'app-err.log') | Out-Null
& $nssm set $NssmSvc AppEnvironmentExtra "DJANGO_SETTINGS_MODULE=noctis_pro.settings" | Out-Null
& $nssm set $NssmSvc AppEnvironmentExtra "PYTHONUNBUFFERED=1" | Out-Null
sc.exe config $NssmSvc start= delayed-auto | Out-Null
& $nssm start $NssmSvc | Out-Null

# --- Cloudflared quick tunnel ---
Write-Host 'Fetching cloudflared...'
$cloudflaredPath = Join-Path $RepoRoot 'cloudflared.exe'
Invoke-Download -Uris @('https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe') -OutFile $cloudflaredPath
Unblock-File $cloudflaredPath

try { Get-Service -Name $TunnelSvc -ErrorAction Stop | Out-Null; Stop-Service $TunnelSvc -Force -ErrorAction SilentlyContinue; sc.exe delete $TunnelSvc | Out-Null } catch {}
& $nssm install $TunnelSvc $cloudflaredPath "tunnel --no-autoupdate --url http://127.0.0.1:$Port" | Out-Null
& $nssm set $TunnelSvc AppDirectory $RepoRoot | Out-Null
& $nssm set $TunnelSvc AppStdout (Join-Path $LogsDir 'cloudflared-out.log') | Out-Null
& $nssm set $TunnelSvc AppStderr (Join-Path $LogsDir 'cloudflared-err.log') | Out-Null
sc.exe config $TunnelSvc start= delayed-auto | Out-Null
& $nssm start $TunnelSvc | Out-Null

# --- Wait for public HTTPS URL ---
Write-Host 'Waiting for public HTTPS link (Cloudflare Quick Tunnel)...'
$deadline = (Get-Date).AddMinutes(4)
$publicUrl = $null
$regex = 'https://[a-z0-9-]+\.trycloudflare\.com'

function Try-ExtractLink {
  param([string]$path)
  if (Test-Path $path) {
    $lines = Get-Content $path -Encoding UTF8 -Tail 600
    foreach ($l in $lines) { if ($l -match $regex) { return $matches[0] } }
  }
  return $null
}

while ((Get-Date) -lt $deadline -and -not $publicUrl) {
  $publicUrl = Try-ExtractLink (Join-Path $LogsDir 'cloudflared-out.log')
  if (-not $publicUrl) { $publicUrl = Try-ExtractLink (Join-Path $LogsDir 'cloudflared-err.log') }
  if (-not $publicUrl) { Start-Sleep -Seconds 2 }
}

# --- Output status ---
if ($publicUrl) {
  Write-Host "`nPublic HTTPS URL: $publicUrl`n"
  Write-Host "Credentials: $SuperuserUsername / $SuperuserPassword"
} else {
  Write-Warning "Could not detect the Quick Tunnel URL. Check logs:
  $(Join-Path $LogsDir 'cloudflared-out.log')
  $(Join-Path $LogsDir 'cloudflared-err.log')"
  if (Test-Path (Join-Path $LogsDir 'cloudflared-err.log')) {
    Write-Host '--- Last 60 lines (cloudflared-err.log) ---'
    Get-Content (Join-Path $LogsDir 'cloudflared-err.log') -Tail 60
  }
}

Write-Host "Services installed: $NssmSvc (app), $TunnelSvc (tunnel). Use 'services.msc' to manage."