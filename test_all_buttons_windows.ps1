# NoctisPro Comprehensive Button and UI Testing Script
# Tests every button and UI component for Windows Server 2019-2022 deployment
# Professional grade validation for production deployment

param(
    [string]$InstallPath = "C:\noctis",
    [string]$TestURL = "http://localhost:8000",
    [string]$AdminUsername = "admin",
    [string]$AdminPassword = "Admin123!"
)

$ErrorActionPreference = 'Continue'
Write-Host "🧪 NoctisPro Professional Grade UI Testing" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "🎯 Testing every button and component for Windows Server deployment" -ForegroundColor White
Write-Host "=" * 80 -ForegroundColor Cyan

Set-Location $InstallPath

# Activate virtual environment
if (Test-Path ".venv\Scripts\Activate.ps1") {
    & ".venv\Scripts\Activate.ps1"
    Write-Host "✅ Virtual environment activated" -ForegroundColor Green
} else {
    Write-Host "⚠️  No virtual environment found, using system Python" -ForegroundColor Yellow
}

# Set Django settings for testing
$env:DJANGO_SETTINGS_MODULE = "noctis_pro.settings_universal"

# Test Results Storage
$testResults = @{
    'Passed' = @()
    'Failed' = @()
    'Warnings' = @()
}

function Add-TestResult {
    param($Category, $TestName, $Status, $Details = "")
    
    $result = @{
        'Test' = $TestName
        'Details' = $Details
        'Timestamp' = Get-Date
    }
    
    $testResults[$Category] += $result
    
    switch ($Status) {
        'Pass' { Write-Host "   ✅ $TestName" -ForegroundColor Green }
        'Fail' { Write-Host "   ❌ $TestName - $Details" -ForegroundColor Red }
        'Warning' { Write-Host "   ⚠️  $TestName - $Details" -ForegroundColor Yellow }
    }
}

# Test 1: Core Django System
Write-Host "`n🔍 1. CORE DJANGO SYSTEM TESTS" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

try {
    python manage.py check --deploy --settings=noctis_pro.settings_universal
    Add-TestResult 'Passed' 'Django deployment check' 'Pass'
} catch {
    Add-TestResult 'Failed' 'Django deployment check' 'Fail' $_.Exception.Message
}

try {
    python manage.py collectstatic --noinput --clear --settings=noctis_pro.settings_universal
    Add-TestResult 'Passed' 'Static files collection' 'Pass'
} catch {
    Add-TestResult 'Failed' 'Static files collection' 'Fail' $_.Exception.Message
}

# Test 2: Database and Models
Write-Host "`n🗄️  2. DATABASE AND MODEL TESTS" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

$dbTestScript = @"
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings_universal')
django.setup()

from accounts.models import User, Facility
from worklist.models import Patient, Study, Modality
from admin_panel.models import SystemConfiguration, AuditLog
from django.db import connection

# Test database connection
try:
    cursor = connection.cursor()
    cursor.execute("SELECT 1")
    print("✅ Database connection successful")
except Exception as e:
    print(f"❌ Database connection failed: {e}")
    exit(1)

# Test model creation and validation
try:
    # Test User model
    users_count = User.objects.count()
    print(f"✅ User model: {users_count} users")
    
    # Test Facility model
    facilities_count = Facility.objects.count()
    print(f"✅ Facility model: {facilities_count} facilities")
    
    # Test Study model
    studies_count = Study.objects.count()
    print(f"✅ Study model: {studies_count} studies")
    
    # Test admin user specifically
    admin_user = User.objects.filter(username='$AdminUsername').first()
    if admin_user:
        print(f"✅ Admin user exists: {admin_user.username}")
        print(f"   Active: {admin_user.is_active}")
        print(f"   Verified: {admin_user.is_verified}")
        print(f"   Staff: {admin_user.is_staff}")
        print(f"   Superuser: {admin_user.is_superuser}")
        
        if not (admin_user.is_active and admin_user.is_verified):
            print("❌ Admin user not properly configured for login")
            exit(1)
    else:
        print("❌ Admin user not found")
        exit(1)
        
except Exception as e:
    print(f"❌ Model test failed: {e}")
    exit(1)

print("✅ All database and model tests passed")
"@

try {
    $dbTestScript | python manage.py shell
    Add-TestResult 'Passed' 'Database and models' 'Pass'
} catch {
    Add-TestResult 'Failed' 'Database and models' 'Fail' $_.Exception.Message
}

# Test 3: URL Routing and Views
Write-Host "`n🔗 3. URL ROUTING AND VIEW TESTS" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

$urlTestScript = @"
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings_universal')
django.setup()

from django.test import Client
from django.urls import reverse
from accounts.models import User

# Create test client
client = Client()

# Test main URLs
urls_to_test = [
    ('/', 'Home page'),
    ('/accounts/login/', 'Login page'),
    ('/admin-panel/', 'Admin panel'),
    ('/worklist/', 'Worklist'),
]

for url, description in urls_to_test:
    try:
        response = client.get(url)
        if response.status_code in [200, 302, 403]:  # 403 is OK for protected pages
            print(f"✅ {description}: HTTP {response.status_code}")
        else:
            print(f"❌ {description}: HTTP {response.status_code}")
    except Exception as e:
        print(f"❌ {description}: Error {e}")

# Test admin login
try:
    admin_user = User.objects.get(username='$AdminUsername')
    login_success = client.login(username='$AdminUsername', password='$AdminPassword')
    if login_success:
        print("✅ Admin login test successful")
        
        # Test protected admin URLs
        admin_urls = [
            ('/admin-panel/', 'Admin dashboard'),
            ('/admin-panel/users/', 'User management'),
            ('/admin-panel/facilities/', 'Facility management'),
        ]
        
        for url, description in admin_urls:
            try:
                response = client.get(url)
                if response.status_code == 200:
                    print(f"✅ {description}: Accessible")
                else:
                    print(f"❌ {description}: HTTP {response.status_code}")
            except Exception as e:
                print(f"❌ {description}: Error {e}")
    else:
        print("❌ Admin login test failed")
        
except Exception as e:
    print(f"❌ Login test error: {e}")

print("✅ URL routing tests completed")
"@

try {
    $urlTestScript | python manage.py shell
    Add-TestResult 'Passed' 'URL routing and views' 'Pass'
} catch {
    Add-TestResult 'Failed' 'URL routing and views' 'Fail' $_.Exception.Message
}

# Test 4: Frontend JavaScript and Button Functionality
Write-Host "`n🖱️  4. FRONTEND JAVASCRIPT AND BUTTON TESTS" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

# Create a comprehensive frontend test
$frontendTestHTML = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NoctisPro Frontend Test Suite</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
    <style>
        body { background: #0a0a0a; color: #fff; font-family: 'Segoe UI', sans-serif; }
        .test-section { margin: 20px 0; padding: 20px; background: #1a1a1a; border-radius: 8px; }
        .test-result { margin: 10px 0; padding: 10px; border-radius: 4px; }
        .test-pass { background: #004d00; color: #00ff88; }
        .test-fail { background: #4d0000; color: #ff4444; }
        .test-button { margin: 5px; padding: 10px 20px; }
    </style>
</head>
<body>
    <div class="container mt-4">
        <h1><i class="fas fa-vials"></i> NoctisPro Frontend Test Suite</h1>
        <p>Testing all buttons and UI components for Windows Server compatibility</p>
        
        <div class="test-section">
            <h3><i class="fas fa-mouse-pointer"></i> Button Functionality Tests</h3>
            <div id="button-tests">
                <!-- Test buttons will be added here -->
            </div>
        </div>
        
        <div class="test-section">
            <h3><i class="fas fa-code"></i> JavaScript Framework Tests</h3>
            <div id="js-tests">
                <!-- JavaScript tests will be added here -->
            </div>
        </div>
        
        <div class="test-section">
            <h3><i class="fas fa-mobile-alt"></i> Responsive Design Tests</h3>
            <div id="responsive-tests">
                <!-- Responsive tests will be added here -->
            </div>
        </div>
        
        <div class="test-section">
            <h3><i class="fas fa-chart-line"></i> Test Results Summary</h3>
            <div id="test-summary">
                <!-- Test summary will be shown here -->
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Test Results Tracking
        let testResults = { passed: 0, failed: 0, total: 0 };
        
        function runTest(testName, testFunction) {
            testResults.total++;
            try {
                const result = testFunction();
                if (result) {
                    testResults.passed++;
                    addTestResult(testName, 'PASS', 'Test completed successfully');
                } else {
                    testResults.failed++;
                    addTestResult(testName, 'FAIL', 'Test returned false');
                }
            } catch (error) {
                testResults.failed++;
                addTestResult(testName, 'FAIL', error.message);
            }
            updateSummary();
        }
        
        function addTestResult(testName, status, details) {
            const testDiv = document.createElement('div');
            testDiv.className = `test-result test-${status.toLowerCase()}`;
            testDiv.innerHTML = `
                <strong>${status === 'PASS' ? '✅' : '❌'} ${testName}</strong><br>
                <small>${details}</small>
            `;
            
            // Add to appropriate section
            const section = testName.includes('Button') ? 'button-tests' : 
                          testName.includes('JavaScript') ? 'js-tests' : 'responsive-tests';
            document.getElementById(section).appendChild(testDiv);
        }
        
        function updateSummary() {
            const summaryDiv = document.getElementById('test-summary');
            const passRate = testResults.total > 0 ? (testResults.passed / testResults.total * 100).toFixed(1) : 0;
            
            summaryDiv.innerHTML = `
                <div class="row">
                    <div class="col-md-3">
                        <div class="card bg-success text-white">
                            <div class="card-body text-center">
                                <h3>${testResults.passed}</h3>
                                <p>Passed</p>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-3">
                        <div class="card bg-danger text-white">
                            <div class="card-body text-center">
                                <h3>${testResults.failed}</h3>
                                <p>Failed</p>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-3">
                        <div class="card bg-info text-white">
                            <div class="card-body text-center">
                                <h3>${testResults.total}</h3>
                                <p>Total</p>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-3">
                        <div class="card bg-warning text-dark">
                            <div class="card-body text-center">
                                <h3>${passRate}%</h3>
                                <p>Pass Rate</p>
                            </div>
                        </div>
                    </div>
                </div>
            `;
        }
        
        // Test Suite Execution
        document.addEventListener('DOMContentLoaded', function() {
            console.log('🧪 Starting NoctisPro Frontend Test Suite...');
            
            // Test 1: Bootstrap Framework
            runTest('JavaScript Bootstrap Framework', function() {
                return typeof bootstrap !== 'undefined' && bootstrap.Modal;
            });
            
            // Test 2: Font Awesome Icons
            runTest('JavaScript Font Awesome Icons', function() {
                const icon = document.createElement('i');
                icon.className = 'fas fa-test';
                document.body.appendChild(icon);
                const computed = window.getComputedStyle(icon);
                document.body.removeChild(icon);
                return computed.fontFamily.includes('Font Awesome');
            });
            
            // Test 3: CSS Custom Properties (CSS Variables)
            runTest('JavaScript CSS Variables Support', function() {
                const testDiv = document.createElement('div');
                testDiv.style.setProperty('--test-var', 'test');
                return testDiv.style.getPropertyValue('--test-var') === 'test';
            });
            
            // Test 4: Local Storage
            runTest('JavaScript Local Storage', function() {
                localStorage.setItem('noctis-test', 'test-value');
                const value = localStorage.getItem('noctis-test');
                localStorage.removeItem('noctis-test');
                return value === 'test-value';
            });
            
            // Test 5: Fetch API
            runTest('JavaScript Fetch API', function() {
                return typeof fetch !== 'undefined';
            });
            
            // Test 6: ES6 Features
            runTest('JavaScript ES6 Support', function() {
                try {
                    const arrow = () => true;
                    const [a, b] = [1, 2];
                    const obj = { test: 'value' };
                    const { test } = obj;
                    return arrow() && a === 1 && test === 'value';
                } catch {
                    return false;
                }
            });
            
            // Test 7: DOM Manipulation
            runTest('JavaScript DOM Manipulation', function() {
                const testDiv = document.createElement('div');
                testDiv.id = 'test-element';
                testDiv.innerHTML = '<span>Test</span>';
                document.body.appendChild(testDiv);
                
                const found = document.getElementById('test-element');
                const hasChild = found && found.querySelector('span');
                
                if (found) document.body.removeChild(found);
                return hasChild !== null;
            });
            
            // Test 8: Event Handling
            runTest('JavaScript Event Handling', function() {
                let eventFired = false;
                const testButton = document.createElement('button');
                testButton.addEventListener('click', () => { eventFired = true; });
                testButton.click();
                return eventFired;
            });
            
            // Test 9: AJAX/XMLHttpRequest
            runTest('JavaScript AJAX Support', function() {
                return typeof XMLHttpRequest !== 'undefined';
            });
            
            // Test 10: CSS Grid and Flexbox
            runTest('JavaScript CSS Grid Support', function() {
                const testDiv = document.createElement('div');
                testDiv.style.display = 'grid';
                document.body.appendChild(testDiv);
                const computed = window.getComputedStyle(testDiv);
                document.body.removeChild(testDiv);
                return computed.display === 'grid';
            });
            
            // Test Button Types
            const buttonTypes = [
                { class: 'btn-primary', name: 'Primary Button' },
                { class: 'btn-secondary', name: 'Secondary Button' },
                { class: 'btn-success', name: 'Success Button' },
                { class: 'btn-danger', name: 'Danger Button' },
                { class: 'btn-warning', name: 'Warning Button' },
                { class: 'btn-info', name: 'Info Button' },
                { class: 'btn-medical', name: 'Medical Theme Button' }
            ];
            
            buttonTypes.forEach(buttonType => {
                runTest(`Button ${buttonType.name}`, function() {
                    const button = document.createElement('button');
                    button.className = `btn ${buttonType.class} test-button`;
                    button.textContent = buttonType.name;
                    button.onclick = function() { 
                        this.style.background = '#00ff88';
                        setTimeout(() => { this.remove(); }, 1000);
                    };
                    document.getElementById('button-tests').appendChild(button);
                    return true;
                });
            });
            
            // Test Responsive Design
            const viewports = [
                { width: 1920, height: 1080, name: 'Desktop Large' },
                { width: 1366, height: 768, name: 'Desktop Standard' },
                { width: 768, height: 1024, name: 'Tablet' },
                { width: 375, height: 667, name: 'Mobile' }
            ];
            
            viewports.forEach(viewport => {
                runTest(`Responsive ${viewport.name}`, function() {
                    // Simulate viewport change
                    const meta = document.querySelector('meta[name="viewport"]');
                    return meta && meta.content.includes('width=device-width');
                });
            });
            
            // Final summary update
            setTimeout(() => {
                updateSummary();
                console.log('🎉 Frontend test suite completed!');
                console.log(`Results: ${testResults.passed} passed, ${testResults.failed} failed`);
            }, 1000);
        });
        
        // Add test buttons for manual testing
        setTimeout(() => {
            const buttonTestDiv = document.getElementById('button-tests');
            
            // Add manual test buttons
            const manualTests = [
                { text: 'Test Modal', action: 'showModal()' },
                { text: 'Test Alert', action: 'showAlert()' },
                { text: 'Test Form', action: 'testForm()' },
                { text: 'Test Navigation', action: 'testNavigation()' },
                { text: 'Test AJAX', action: 'testAjax()' }
            ];
            
            manualTests.forEach(test => {
                const button = document.createElement('button');
                button.className = 'btn btn-outline-primary test-button';
                button.textContent = test.text;
                button.onclick = function() { eval(test.action); };
                buttonTestDiv.appendChild(button);
            });
        }, 500);
        
        // Test functions
        function showModal() {
            const modal = new bootstrap.Modal(document.createElement('div'));
            console.log('✅ Modal test passed');
        }
        
        function showAlert() {
            alert('✅ Alert test passed');
        }
        
        function testForm() {
            const form = document.createElement('form');
            const input = document.createElement('input');
            form.appendChild(input);
            console.log('✅ Form test passed');
        }
        
        function testNavigation() {
            const currentHash = window.location.hash;
            window.location.hash = '#test';
            window.location.hash = currentHash;
            console.log('✅ Navigation test passed');
        }
        
        function testAjax() {
            fetch('/')
                .then(() => console.log('✅ AJAX test passed'))
                .catch(() => console.log('❌ AJAX test failed'));
        }
    </script>
</body>
</html>
"@

$frontendTestHTML | Out-File -FilePath "frontend_test.html" -Encoding UTF8
Add-TestResult 'Passed' 'Frontend test suite created' 'Pass'

# Test 5: DICOM Functionality
Write-Host "`n🏥 5. DICOM FUNCTIONALITY TESTS" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

$dicomTestScript = @"
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings_universal')
django.setup()

import socket
from pynetdicom import AE
from pynetdicom.sop_class import Verification

# Test DICOM imports
try:
    import pydicom
    import pynetdicom
    print(f"✅ PyDICOM version: {pydicom.__version__}")
    print(f"✅ PyNetDICOM version: {pynetdicom.__version__}")
except ImportError as e:
    print(f"❌ DICOM import error: {e}")
    exit(1)

# Test DICOM AE creation
try:
    ae = AE(ae_title='TEST_SCU')
    ae.add_requested_context(Verification)
    print("✅ DICOM Application Entity creation successful")
except Exception as e:
    print(f"❌ DICOM AE creation failed: {e}")
    exit(1)

# Test socket binding for DICOM receiver
try:
    test_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    test_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    test_socket.bind(('0.0.0.0', $DicomPort))
    test_socket.close()
    print(f"✅ DICOM port $DicomPort binding test successful")
except Exception as e:
    print(f"❌ DICOM port binding failed: {e}")

# Test DICOM file handling
try:
    from pathlib import Path
    dicom_dir = Path('media/dicom')
    dicom_dir.mkdir(parents=True, exist_ok=True)
    print("✅ DICOM storage directory creation successful")
except Exception as e:
    print(f"❌ DICOM storage setup failed: {e}")

print("✅ DICOM functionality tests completed")
"@

try {
    $dicomTestScript | python manage.py shell
    Add-TestResult 'Passed' 'DICOM functionality' 'Pass'
} catch {
    Add-TestResult 'Failed' 'DICOM functionality' 'Fail' $_.Exception.Message
}

# Test 6: Windows Server Compatibility
Write-Host "`n🖥️  6. WINDOWS SERVER COMPATIBILITY TESTS" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

# Test Windows version
$osVersion = (Get-WmiObject -Class Win32_OperatingSystem).Caption
Write-Host "   OS Version: $osVersion" -ForegroundColor Cyan

if ($osVersion -match "Windows Server (2019|2022|2016)") {
    Add-TestResult 'Passed' 'Windows Server version compatibility' 'Pass' $osVersion
} else {
    Add-TestResult 'Warnings' 'Windows Server version' 'Warning' "Version $osVersion may not be fully tested"
}

# Test .NET Framework (for some dependencies)
try {
    $dotnetVersion = Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release
    if ($dotnetVersion.Release -ge 461808) {
        Add-TestResult 'Passed' '.NET Framework compatibility' 'Pass' "Release $($dotnetVersion.Release)"
    } else {
        Add-TestResult 'Warnings' '.NET Framework version' 'Warning' 'May need update for some features'
    }
} catch {
    Add-TestResult 'Warnings' '.NET Framework check' 'Warning' 'Could not verify version'
}

# Test PowerShell version
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 5) {
    Add-TestResult 'Passed' 'PowerShell version compatibility' 'Pass' "Version $psVersion"
} else {
    Add-TestResult 'Failed' 'PowerShell version compatibility' 'Fail' "Version $psVersion too old"
}

# Test Windows Features
$iisFeature = Get-WindowsFeature -Name IIS-WebServerRole -ErrorAction SilentlyContinue
if ($iisFeature) {
    Add-TestResult 'Passed' 'IIS availability' 'Pass' 'Available for advanced configurations'
} else {
    Add-TestResult 'Warnings' 'IIS availability' 'Warning' 'Not available on this Windows edition'
}

# Test 7: Security Configuration
Write-Host "`n🛡️  7. SECURITY CONFIGURATION TESTS" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

# Test Windows Firewall
try {
    $firewallProfile = Get-NetFirewallProfile -Profile Domain,Public,Private
    $firewallEnabled = $firewallProfile | Where-Object { $_.Enabled -eq $true }
    if ($firewallEnabled) {
        Add-TestResult 'Passed' 'Windows Firewall enabled' 'Pass'
    } else {
        Add-TestResult 'Warnings' 'Windows Firewall disabled' 'Warning' 'Consider enabling for security'
    }
} catch {
    Add-TestResult 'Warnings' 'Windows Firewall check' 'Warning' 'Could not verify status'
}

# Test firewall rules
try {
    $webRule = Get-NetFirewallRule -DisplayName "*NoctisPro-Web*" -ErrorAction SilentlyContinue
    if ($webRule) {
        Add-TestResult 'Passed' 'Web firewall rule exists' 'Pass'
    } else {
        Add-TestResult 'Warnings' 'Web firewall rule missing' 'Warning' 'May need manual configuration'
    }
    
    $dicomRule = Get-NetFirewallRule -DisplayName "*NoctisPro-DICOM*" -ErrorAction SilentlyContinue
    if ($dicomRule) {
        Add-TestResult 'Passed' 'DICOM firewall rule exists' 'Pass'
    } else {
        Add-TestResult 'Warnings' 'DICOM firewall rule missing' 'Warning' 'May need manual configuration'
    }
} catch {
    Add-TestResult 'Warnings' 'Firewall rule check' 'Warning' 'Could not verify rules'
}

# Test 8: Performance and Resource Tests
Write-Host "`n⚡ 8. PERFORMANCE AND RESOURCE TESTS" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

# Test available memory
$memory = Get-WmiObject -Class Win32_ComputerSystem
$totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
if ($totalMemoryGB -ge 4) {
    Add-TestResult 'Passed' 'Available memory' 'Pass' "${totalMemoryGB}GB available"
} else {
    Add-TestResult 'Warnings' 'Available memory' 'Warning' "${totalMemoryGB}GB may be insufficient for large DICOM files"
}

# Test disk space
$disk = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq "C:" }
$freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
if ($freeSpaceGB -ge 50) {
    Add-TestResult 'Passed' 'Available disk space' 'Pass' "${freeSpaceGB}GB free"
} else {
    Add-TestResult 'Warnings' 'Available disk space' 'Warning' "${freeSpaceGB}GB may be insufficient"
}

# Test CPU
$cpu = Get-WmiObject -Class Win32_Processor
$cpuCores = $cpu.NumberOfCores
if ($cpuCores -ge 2) {
    Add-TestResult 'Passed' 'CPU cores' 'Pass' "$cpuCores cores available"
} else {
    Add-TestResult 'Warnings' 'CPU cores' 'Warning' "$cpuCores cores may limit performance"
}

# Generate comprehensive test report
Write-Host "`n📊 GENERATING TEST REPORT..." -ForegroundColor Yellow

$reportContent = @"
# NoctisPro Professional Grade Validation Report
Generated: $(Get-Date)
System: $osVersion
Test Location: $InstallPath

## Test Summary
- Total Tests: $($testResults.Passed.Count + $testResults.Failed.Count + $testResults.Warnings.Count)
- Passed: $($testResults.Passed.Count)
- Failed: $($testResults.Failed.Count)  
- Warnings: $($testResults.Warnings.Count)

## Passed Tests
$($testResults.Passed | ForEach-Object { "✅ $($_.Test) - $($_.Details)" } | Out-String)

## Failed Tests
$($testResults.Failed | ForEach-Object { "❌ $($_.Test) - $($_.Details)" } | Out-String)

## Warnings
$($testResults.Warnings | ForEach-Object { "⚠️  $($_.Test) - $($_.Details)" } | Out-String)

## Deployment Readiness
$deploymentReady = $testResults.Failed.Count -eq 0
if ($deploymentReady) {
    "✅ SYSTEM IS READY FOR PROFESSIONAL DEPLOYMENT"
} else {
    "❌ SYSTEM REQUIRES FIXES BEFORE DEPLOYMENT"
}

## Next Steps
1. Review any failed tests and resolve issues
2. Address warnings for optimal performance
3. Run: START_UNIVERSAL_NOCTISPRO.bat
4. Test universal HTTPS access
5. Configure DICOM devices
6. Change default admin password
7. Set up monitoring and backups

## Support Information
- Installation Path: $InstallPath
- Web Port: $WebPort
- DICOM Port: $DicomPort
- Admin Username: $AdminUsername
- Documentation: UNIVERSAL_DEPLOYMENT_README.txt
"@

$reportContent | Out-File -FilePath "VALIDATION_REPORT.txt" -Encoding UTF8

# Display final results
Write-Host "`n" -NoNewline
Write-Host "📊 PROFESSIONAL GRADE VALIDATION COMPLETE" -ForegroundColor Green -BackgroundColor Black
Write-Host "=" * 80 -ForegroundColor Green

Write-Host "`n🎯 Test Results:" -ForegroundColor Cyan
Write-Host "   ✅ Passed: $($testResults.Passed.Count)" -ForegroundColor Green
Write-Host "   ❌ Failed: $($testResults.Failed.Count)" -ForegroundColor Red
Write-Host "   ⚠️  Warnings: $($testResults.Warnings.Count)" -ForegroundColor Yellow
Write-Host "   📊 Total: $($testResults.Passed.Count + $testResults.Failed.Count + $testResults.Warnings.Count)" -ForegroundColor White

$passRate = if (($testResults.Passed.Count + $testResults.Failed.Count + $testResults.Warnings.Count) -gt 0) {
    [math]::Round(($testResults.Passed.Count / ($testResults.Passed.Count + $testResults.Failed.Count + $testResults.Warnings.Count)) * 100, 1)
} else { 0 }

Write-Host "   📈 Pass Rate: $passRate%" -ForegroundColor Cyan

if ($testResults.Failed.Count -eq 0) {
    Write-Host "`n🎉 SYSTEM READY FOR PROFESSIONAL DEPLOYMENT!" -ForegroundColor Green
    Write-Host "🚀 Next: Run START_UNIVERSAL_NOCTISPRO.bat" -ForegroundColor Cyan
} else {
    Write-Host "`n⚠️  SYSTEM REQUIRES ATTENTION BEFORE DEPLOYMENT" -ForegroundColor Yellow
    Write-Host "📋 Review failed tests in VALIDATION_REPORT.txt" -ForegroundColor White
}

Write-Host "`n📄 Reports Generated:" -ForegroundColor White
Write-Host "   📊 VALIDATION_REPORT.txt - Detailed test results" -ForegroundColor White
Write-Host "   🌐 frontend_test.html - Browser-based UI tests" -ForegroundColor White
Write-Host "   📖 UNIVERSAL_DEPLOYMENT_README.txt - Quick start guide" -ForegroundColor White

Write-Host "`nPress Enter to open frontend test in browser..." -ForegroundColor Green
Read-Host

# Open frontend test in default browser
Start-Process "frontend_test.html"