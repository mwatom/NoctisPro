#!/usr/bin/env python3
"""
NoctisPro Deployment Validation Script with Printing Support
This script validates that the deployment was successful and all features work correctly.
"""

import os
import sys
import subprocess
import requests
import json
import time
from pathlib import Path

class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    PURPLE = '\033[0;35m'
    NC = '\033[0m'  # No Color

def log_info(message):
    print(f"{Colors.BLUE}[INFO]{Colors.NC} {message}")

def log_success(message):
    print(f"{Colors.GREEN}[SUCCESS]{Colors.NC} {message}")

def log_warning(message):
    print(f"{Colors.YELLOW}[WARNING]{Colors.NC} {message}")

def log_error(message):
    print(f"{Colors.RED}[ERROR]{Colors.NC} {message}")

def log_header(message):
    print(f"{Colors.PURPLE}{message}{Colors.NC}")

class DeploymentValidator:
    def __init__(self):
        self.base_url = "http://localhost:8000"
        self.errors = []
        self.warnings = []
        
    def run_command(self, command, check_return=True):
        """Run a shell command and return output"""
        try:
            result = subprocess.run(
                command, shell=True, capture_output=True, text=True, timeout=30
            )
            if check_return and result.returncode != 0:
                raise subprocess.CalledProcessError(result.returncode, command, result.stderr)
            return result.stdout.strip(), result.stderr.strip(), result.returncode
        except subprocess.TimeoutExpired:
            raise Exception(f"Command timed out: {command}")
        except subprocess.CalledProcessError as e:
            raise Exception(f"Command failed: {command}\nError: {e.stderr}")

    def check_system_services(self):
        """Check that all required system services are running"""
        log_header("🔧 Checking System Services")
        
        required_services = [
            'noctis-django',
            'noctis-daphne', 
            'noctis-celery',
            'postgresql',
            'redis-server',
            'nginx',
            'cups'
        ]
        
        for service in required_services:
            try:
                stdout, stderr, returncode = self.run_command(f"systemctl is-active {service}")
                if returncode == 0 and stdout.strip() == 'active':
                    log_success(f"{service}: Running")
                else:
                    log_error(f"{service}: Not running")
                    self.errors.append(f"Service {service} is not running")
            except Exception as e:
                log_error(f"{service}: Error checking status - {str(e)}")
                self.errors.append(f"Error checking {service}: {str(e)}")

    def check_web_interface(self):
        """Check that the web interface is accessible"""
        log_header("🌐 Checking Web Interface")
        
        try:
            response = requests.get(f"{self.base_url}/", timeout=10)
            if response.status_code == 200:
                log_success("Web interface accessible")
            else:
                log_error(f"Web interface returned status {response.status_code}")
                self.errors.append(f"Web interface status: {response.status_code}")
        except requests.exceptions.RequestException as e:
            log_error(f"Cannot access web interface: {str(e)}")
            self.errors.append(f"Web interface error: {str(e)}")

    def check_dicom_viewer(self):
        """Check DICOM viewer functionality"""
        log_header("🏥 Checking DICOM Viewer")
        
        try:
            response = requests.get(f"{self.base_url}/dicom-viewer/", timeout=10)
            if response.status_code == 200:
                log_success("DICOM viewer accessible")
                
                # Check if print functionality is available
                if 'btnPrint' in response.text:
                    log_success("Print button found in DICOM viewer")
                else:
                    log_warning("Print button not found in DICOM viewer")
                    self.warnings.append("Print button missing from DICOM viewer")
                    
            else:
                log_error(f"DICOM viewer returned status {response.status_code}")
                self.errors.append(f"DICOM viewer status: {response.status_code}")
        except requests.exceptions.RequestException as e:
            log_error(f"Cannot access DICOM viewer: {str(e)}")
            self.errors.append(f"DICOM viewer error: {str(e)}")

    def check_printing_system(self):
        """Check CUPS printing system and printer availability"""
        log_header("🖨️ Checking Printing System")
        
        # Check CUPS service
        try:
            stdout, stderr, returncode = self.run_command("systemctl is-active cups")
            if returncode == 0 and stdout.strip() == 'active':
                log_success("CUPS service is running")
            else:
                log_error("CUPS service is not running")
                self.errors.append("CUPS service not running")
                return
        except Exception as e:
            log_error(f"Error checking CUPS service: {str(e)}")
            self.errors.append(f"CUPS service check failed: {str(e)}")
            return

        # Check for available printers
        try:
            stdout, stderr, returncode = self.run_command("lpstat -p", check_return=False)
            if returncode == 0 and stdout.strip():
                log_success("Printers configured:")
                for line in stdout.strip().split('\n'):
                    if line.strip():
                        print(f"  {line}")
                        
                                 # Test printer API endpoint
                 try:
                     response = requests.get(f"{self.base_url}/dicom-viewer/print/printers/", timeout=10)
                     if response.status_code == 200:
                         data = response.json()
                         if data.get('success') and data.get('printers'):
                             log_success(f"Printer API working - {len(data['printers'])} printer(s) available")
                         else:
                             log_warning("Printer API working but no printers available")
                             self.warnings.append("No printers available via API")
                     else:
                         log_error(f"Printer API returned status {response.status_code}")
                         self.errors.append(f"Printer API status: {response.status_code}")
                         
                     # Test layout API endpoint
                     layout_response = requests.get(f"{self.base_url}/dicom-viewer/print/layouts/?modality=CT", timeout=10)
                     if layout_response.status_code == 200:
                         layout_data = layout_response.json()
                         if layout_data.get('success') and layout_data.get('layouts'):
                             log_success(f"Print layouts API working - {len(layout_data['layouts'])} layout(s) available for CT")
                         else:
                             log_warning("Print layouts API working but no layouts available")
                             self.warnings.append("No print layouts available")
                     else:
                         log_error(f"Print layouts API returned status {layout_response.status_code}")
                         self.errors.append(f"Print layouts API status: {layout_response.status_code}")
                         
                 except requests.exceptions.RequestException as e:
                     log_error(f"Cannot access printer API: {str(e)}")
                     self.errors.append(f"Printer API error: {str(e)}")
                    
            else:
                log_warning("No printers configured")
                self.warnings.append("No printers configured - printing will not work")
                
        except Exception as e:
            log_error(f"Error checking printers: {str(e)}")
            self.errors.append(f"Printer check failed: {str(e)}")

    def check_database_connection(self):
        """Check database connectivity"""
        log_header("🗄️ Checking Database")
        
        try:
            stdout, stderr, returncode = self.run_command(
                'sudo -u postgres psql -d noctis_pro -c "SELECT version();" -t'
            )
            if returncode == 0:
                log_success("Database connection successful")
                version = stdout.strip().split('\n')[0].strip()
                log_info(f"PostgreSQL version: {version}")
            else:
                log_error("Database connection failed")
                self.errors.append("Database connection failed")
        except Exception as e:
            log_error(f"Database check error: {str(e)}")
            self.errors.append(f"Database error: {str(e)}")

    def check_redis_connection(self):
        """Check Redis connectivity"""
        log_header("📦 Checking Redis Cache")
        
        try:
            # Check if Redis is running
            stdout, stderr, returncode = self.run_command("systemctl is-active redis-server")
            if returncode == 0 and stdout.strip() == 'active':
                log_success("Redis service is running")
                
                # Test Redis connection
                stdout, stderr, returncode = self.run_command("redis-cli ping", check_return=False)
                if returncode == 0 and 'PONG' in stdout:
                    log_success("Redis connection successful")
                else:
                    log_warning("Redis connection test failed")
                    self.warnings.append("Redis connection issue")
            else:
                log_error("Redis service is not running")
                self.errors.append("Redis service not running")
        except Exception as e:
            log_error(f"Redis check error: {str(e)}")
            self.errors.append(f"Redis error: {str(e)}")

    def check_file_permissions(self):
        """Check file permissions and ownership"""
        log_header("🔐 Checking File Permissions")
        
        critical_paths = [
            '/opt/noctis_pro',
            '/opt/noctis_pro/.env',
            '/opt/noctis_pro/media',
            '/opt/noctis_pro/static',
        ]
        
        for path in critical_paths:
            if os.path.exists(path):
                try:
                    stat_info = os.stat(path)
                    # Check if noctis user owns the files
                    stdout, stderr, returncode = self.run_command(f"ls -la {path}")
                    if 'noctis' in stdout:
                        log_success(f"Correct ownership: {path}")
                    else:
                        log_warning(f"Incorrect ownership: {path}")
                        self.warnings.append(f"Ownership issue: {path}")
                except Exception as e:
                    log_error(f"Error checking {path}: {str(e)}")
                    self.errors.append(f"Permission check failed: {path}")
            else:
                log_error(f"Missing path: {path}")
                self.errors.append(f"Missing required path: {path}")

    def check_dependencies(self):
        """Check that all Python dependencies are installed"""
        log_header("📦 Checking Python Dependencies")
        
        critical_packages = [
            'django',
            'pydicom',
            'pillow',
            'reportlab',  # For printing
            'cups',       # For printing (optional)
        ]
        
        try:
            for package in critical_packages:
                stdout, stderr, returncode = self.run_command(
                    f'sudo -u noctis /opt/noctis_pro/venv/bin/python -c "import {package}; print(f\\"{package}: OK\\")"',
                    check_return=False
                )
                if returncode == 0:
                    log_success(f"Package {package}: Available")
                else:
                    if package == 'cups':
                        log_warning(f"Package {package}: Not available (printing may use fallback)")
                        self.warnings.append(f"Optional package {package} not available")
                    else:
                        log_error(f"Package {package}: Missing")
                        self.errors.append(f"Required package {package} missing")
        except Exception as e:
            log_error(f"Error checking dependencies: {str(e)}")
            self.errors.append(f"Dependency check failed: {str(e)}")

    def check_security_configuration(self):
        """Check security configuration"""
        log_header("🛡️ Checking Security Configuration")
        
        # Check firewall
        try:
            stdout, stderr, returncode = self.run_command("ufw status", check_return=False)
            if 'Status: active' in stdout:
                log_success("UFW firewall is active")
            else:
                log_warning("UFW firewall is not active")
                self.warnings.append("Firewall not active")
        except Exception as e:
            log_warning(f"Could not check firewall: {str(e)}")

        # Check fail2ban
        try:
            stdout, stderr, returncode = self.run_command("systemctl is-active fail2ban")
            if returncode == 0 and stdout.strip() == 'active':
                log_success("Fail2ban is running")
            else:
                log_warning("Fail2ban is not running")
                self.warnings.append("Fail2ban not running")
        except Exception as e:
            log_warning(f"Could not check fail2ban: {str(e)}")

    def check_ubuntu_version(self):
        """Check Ubuntu version and compatibility"""
        log_header("🐧 Checking Ubuntu Version")
        
        try:
            stdout, stderr, returncode = self.run_command("lsb_release -rs")
            if returncode == 0:
                version = stdout.strip()
                log_success(f"Ubuntu version: {version}")
                
                # Check if it's a supported version
                major_version = float(version.split('.')[0])
                if major_version >= 20:
                    log_success("Ubuntu version is supported")
                    
                    if major_version >= 24:
                        log_success("Ubuntu 24.04+ detected - enhanced features available")
                        # Check Ubuntu 24.04 specific fixes
                        stdout, stderr, returncode = self.run_command("update-alternatives --display iptables | grep legacy", check_return=False)
                        if returncode == 0:
                            log_success("Ubuntu 24.04 iptables compatibility configured")
                        else:
                            log_warning("Ubuntu 24.04 iptables compatibility may need configuration")
                            self.warnings.append("Ubuntu 24.04 iptables legacy not configured")
                else:
                    log_warning(f"Ubuntu {version} is older than recommended (20.04+)")
                    self.warnings.append(f"Ubuntu version {version} is older than recommended")
            else:
                log_error("Could not determine Ubuntu version")
                self.errors.append("Ubuntu version check failed")
        except Exception as e:
            log_error(f"Ubuntu version check error: {str(e)}")
            self.errors.append(f"Ubuntu version error: {str(e)}")

    def run_validation(self):
        """Run complete validation"""
        log_header("🚀 NoctisPro Deployment Validation with Enhanced Printing Support")
        print()
        
        self.check_ubuntu_version()
        print()
        self.check_system_services()
        print()
        self.check_web_interface()
        print()
        self.check_dicom_viewer()
        print()
        self.check_printing_system()
        print()
        self.check_database_connection()
        print()
        self.check_redis_connection()
        print()
        self.check_file_permissions()
        print()
        self.check_dependencies()
        print()
        self.check_security_configuration()
        print()
        
        # Summary
        log_header("📋 Validation Summary")
        print()
        
        if not self.errors and not self.warnings:
            log_success("🎉 All checks passed! Deployment is successful.")
            log_success("✅ NoctisPro is ready for production use with DICOM printing support")
            print()
                         print("🖨️ To test enhanced printing:")
             print("1. Open the DICOM viewer")
             print("2. Load a DICOM study") 
             print("3. Click the Print button")
             print("4. Select print medium (Paper/Film)")
             print("5. Choose modality-specific layout")
             print("6. Select glossy paper or medical film")
             print("7. Print test image with selected layout")
            return True
            
        elif self.errors:
            log_error("❌ Deployment validation failed!")
            print()
            log_error("Critical errors found:")
            for error in self.errors:
                print(f"  • {error}")
            
            if self.warnings:
                print()
                log_warning("Warnings found:")
                for warning in self.warnings:
                    print(f"  • {warning}")
            
            print()
            log_error("Please fix these issues before using the system in production.")
            return False
            
        else:
            log_warning("⚠️ Deployment completed with warnings")
            print()
            log_warning("Warnings found:")
            for warning in self.warnings:
                print(f"  • {warning}")
            print()
            log_info("System is functional but some features may not work optimally.")
            log_info("Consider addressing the warnings for best performance.")
            return True

def main():
    if os.geteuid() != 0:
        log_error("This script must be run as root (sudo)")
        sys.exit(1)
    
    validator = DeploymentValidator()
    success = validator.run_validation()
    
    if success:
        print()
        log_header("🎯 Next Steps")
        print()
        print("1. Access NoctisPro: http://localhost:8000")
        print("2. Login with admin/admin123 (change password immediately)")
        print("3. Configure printer settings: /dicom-viewer/print/settings/")
        print("4. Test DICOM printing with glossy paper")
        print("5. Set up GitHub webhook for auto-deployment")
        print()
        log_success("NoctisPro deployment validation completed successfully!")
        sys.exit(0)
    else:
        print()
        log_error("Deployment validation failed. Please check the errors above.")
        sys.exit(1)

if __name__ == "__main__":
    main()