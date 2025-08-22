#!/usr/bin/env python3

"""
NoctisPro Demo Deployment Validation Script
Validates complete system functionality for customer demonstration
"""

import subprocess
import requests
import sys
import os
import json
import time
from urllib.parse import urlparse

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    END = '\033[0m'

def print_status(message, status="INFO"):
    color = Colors.BLUE
    if status == "SUCCESS":
        color = Colors.GREEN
    elif status == "ERROR":
        color = Colors.RED
    elif status == "WARNING":
        color = Colors.YELLOW
    
    print(f"{color}[{status}]{Colors.END} {message}")

def run_command(command, capture_output=True):
    """Run a shell command and return result"""
    try:
        result = subprocess.run(command, shell=True, capture_output=capture_output, text=True)
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        return False, "", str(e)

def check_service_status(service_name):
    """Check if a systemd service is active"""
    success, stdout, stderr = run_command(f"systemctl is-active {service_name}")
    return success and "active" in stdout

def check_port_open(port):
    """Check if a port is open and listening"""
    success, stdout, stderr = run_command(f"netstat -tlnp | grep :{port}")
    return success and f":{port}" in stdout

def check_url_accessible(url, timeout=10):
    """Check if URL is accessible"""
    try:
        response = requests.get(url, timeout=timeout, verify=False)
        return response.status_code == 200, response.status_code
    except Exception as e:
        return False, str(e)

def check_https_redirect(domain):
    """Check if HTTP redirects to HTTPS"""
    try:
        response = requests.get(f"http://{domain}", allow_redirects=False, timeout=10)
        return response.status_code in [301, 302] and 'https' in response.headers.get('Location', '').lower()
    except Exception as e:
        return False

def get_domain_from_config():
    """Extract domain from deployment configuration"""
    try:
        with open('/opt/noctis_pro/SECURE_ACCESS_INFO.txt', 'r') as f:
            content = f.read()
            for line in content.split('\n'):
                if 'https://' in line:
                    url = line.split('https://')[1].split()[0].strip()
                    return url
    except:
        pass
    
    # Fallback: check deployment script
    try:
        with open('deploy_noctis_production.sh', 'r') as f:
            content = f.read()
            for line in content.split('\n'):
                if 'DOMAIN_NAME=' in line and not line.strip().startswith('#'):
                    domain = line.split('=')[1].strip().strip('"').strip("'")
                    if domain != "noctis-server.local":
                        return domain
    except:
        pass
    
    return None

def main():
    print(f"{Colors.BOLD}🚀 NoctisPro Demo Deployment Validation{Colors.END}")
    print(f"{Colors.BOLD}Ubuntu 24.04 Customer Demo Readiness Check{Colors.END}")
    print("=" * 60)
    
    validation_results = []
    
    # 1. System Information
    print_status("Checking system information...")
    success, stdout, stderr = run_command("lsb_release -a")
    if success and "24.04" in stdout:
        print_status("Ubuntu 24.04 LTS detected", "SUCCESS")
        validation_results.append(("Ubuntu 24.04", True))
    else:
        print_status("Ubuntu 24.04 not detected - may cause compatibility issues", "WARNING")
        validation_results.append(("Ubuntu 24.04", False))
    
    # 2. Check Core Services
    print_status("Checking core services...")
    
    services = [
        "noctis-django",
        "noctis-daphne", 
        "noctis-celery",
        "postgresql",
        "redis",
        "nginx",
        "docker"
    ]
    
    for service in services:
        if check_service_status(service):
            print_status(f"{service}: active", "SUCCESS")
            validation_results.append((f"Service {service}", True))
        else:
            print_status(f"{service}: inactive or failed", "ERROR")
            validation_results.append((f"Service {service}", False))
    
    # 3. Check Docker
    print_status("Checking Docker installation...")
    success, stdout, stderr = run_command("docker --version")
    if success:
        print_status(f"Docker version: {stdout.strip()}", "SUCCESS")
        validation_results.append(("Docker installed", True))
        
        # Check Docker containers
        success, stdout, stderr = run_command("docker ps")
        if success:
            container_count = len(stdout.strip().split('\n')) - 1
            print_status(f"Docker containers running: {container_count}", "SUCCESS")
            validation_results.append(("Docker containers", True))
        else:
            print_status("Docker containers not running", "ERROR")
            validation_results.append(("Docker containers", False))
    else:
        print_status("Docker not installed or not working", "ERROR")
        validation_results.append(("Docker installed", False))
    
    # 4. Check Network Ports
    print_status("Checking network ports...")
    
    ports = [80, 443, 5432, 6379]
    port_names = ["HTTP", "HTTPS", "PostgreSQL", "Redis"]
    
    for port, name in zip(ports, port_names):
        if check_port_open(port):
            print_status(f"Port {port} ({name}): open", "SUCCESS")
            validation_results.append((f"Port {port}", True))
        else:
            print_status(f"Port {port} ({name}): closed", "ERROR")
            validation_results.append((f"Port {port}", False))
    
    # 5. Check Local Web Access
    print_status("Checking local web access...")
    
    local_urls = [
        "http://localhost",
        "http://192.168.100.15",
        "http://localhost/admin"
    ]
    
    for url in local_urls:
        accessible, status = check_url_accessible(url)
        if accessible:
            print_status(f"Local access {url}: working", "SUCCESS")
            validation_results.append((f"Local access", True))
        else:
            print_status(f"Local access {url}: failed ({status})", "ERROR")
            validation_results.append((f"Local access", False))
        break  # Only test first working URL
    
    # 6. Check HTTPS Configuration
    print_status("Checking HTTPS configuration...")
    
    domain = get_domain_from_config()
    if domain:
        print_status(f"Detected domain: {domain}")
        
        # Check HTTPS access
        https_url = f"https://{domain}"
        accessible, status = check_url_accessible(https_url)
        if accessible:
            print_status(f"HTTPS access: working", "SUCCESS")
            validation_results.append(("HTTPS access", True))
            
            # Check HTTP to HTTPS redirect
            if check_https_redirect(domain):
                print_status("HTTP to HTTPS redirect: working", "SUCCESS")
                validation_results.append(("HTTPS redirect", True))
            else:
                print_status("HTTP to HTTPS redirect: not configured", "WARNING")
                validation_results.append(("HTTPS redirect", False))
        else:
            print_status(f"HTTPS access: failed ({status})", "ERROR")
            validation_results.append(("HTTPS access", False))
    else:
        print_status("No domain configured - HTTPS not available", "WARNING")
        validation_results.append(("Domain configured", False))
    
    # 7. Check SSL Certificate
    if domain:
        print_status("Checking SSL certificate...")
        success, stdout, stderr = run_command(f"echo | openssl s_client -connect {domain}:443 -servername {domain} 2>/dev/null | openssl x509 -noout -dates")
        if success and "notAfter" in stdout:
            print_status("SSL certificate: valid", "SUCCESS")
            validation_results.append(("SSL certificate", True))
        else:
            print_status("SSL certificate: invalid or missing", "ERROR")
            validation_results.append(("SSL certificate", False))
    
    # 8. Check Database Connection
    print_status("Checking database connection...")
    success, stdout, stderr = run_command("sudo -u postgres psql -d noctis_pro -c 'SELECT 1;'")
    if success and "1" in stdout:
        print_status("Database connection: working", "SUCCESS")
        validation_results.append(("Database connection", True))
    else:
        print_status("Database connection: failed", "ERROR")
        validation_results.append(("Database connection", False))
    
    # 9. Check Application Files
    print_status("Checking application files...")
    
    critical_files = [
        "/opt/noctis_pro/manage.py",
        "/opt/noctis_pro/.env",
        "/opt/noctis_pro/static/",
        "/etc/nginx/sites-available/noctis_pro"
    ]
    
    for file_path in critical_files:
        if os.path.exists(file_path):
            print_status(f"Critical file {file_path}: exists", "SUCCESS")
            validation_results.append((f"File {os.path.basename(file_path)}", True))
        else:
            print_status(f"Critical file {file_path}: missing", "ERROR")
            validation_results.append((f"File {os.path.basename(file_path)}", False))
    
    # 10. Check Security Configuration
    print_status("Checking security configuration...")
    
    # Check firewall
    success, stdout, stderr = run_command("ufw status")
    if success and "active" in stdout.lower():
        print_status("Firewall: active", "SUCCESS")
        validation_results.append(("Firewall", True))
    else:
        print_status("Firewall: inactive", "WARNING")
        validation_results.append(("Firewall", False))
    
    # Check fail2ban
    success, stdout, stderr = run_command("fail2ban-client status")
    if success:
        print_status("Fail2ban: active", "SUCCESS")
        validation_results.append(("Fail2ban", True))
    else:
        print_status("Fail2ban: inactive", "WARNING")
        validation_results.append(("Fail2ban", False))
    
    # 11. Performance Check
    print_status("Checking system performance...")
    
    # Check memory usage
    success, stdout, stderr = run_command("free -m")
    if success:
        lines = stdout.strip().split('\n')
        for line in lines:
            if line.startswith('Mem:'):
                parts = line.split()
                total_mem = int(parts[1])
                used_mem = int(parts[2])
                usage_percent = (used_mem / total_mem) * 100
                
                if usage_percent < 80:
                    print_status(f"Memory usage: {usage_percent:.1f}% - good", "SUCCESS")
                    validation_results.append(("Memory usage", True))
                else:
                    print_status(f"Memory usage: {usage_percent:.1f}% - high", "WARNING")
                    validation_results.append(("Memory usage", False))
                break
    
    # Check disk space
    success, stdout, stderr = run_command("df -h /")
    if success:
        lines = stdout.strip().split('\n')
        for line in lines:
            if '/' in line and not line.startswith('Filesystem'):
                parts = line.split()
                usage = parts[4].replace('%', '')
                if int(usage) < 90:
                    print_status(f"Disk usage: {usage}% - good", "SUCCESS")
                    validation_results.append(("Disk usage", True))
                else:
                    print_status(f"Disk usage: {usage}% - high", "WARNING")
                    validation_results.append(("Disk usage", False))
                break
    
    # 12. Final Summary
    print("\n" + "=" * 60)
    print_status("DEMO DEPLOYMENT VALIDATION SUMMARY", "INFO")
    print("=" * 60)
    
    passed = sum(1 for _, status in validation_results if status)
    total = len(validation_results)
    success_rate = (passed / total) * 100
    
    print(f"\n{Colors.BOLD}Results: {passed}/{total} checks passed ({success_rate:.1f}%){Colors.END}")
    
    if success_rate >= 90:
        print_status("🎉 DEMO READY - System is ready for customer demonstration!", "SUCCESS")
        demo_ready = True
    elif success_rate >= 75:
        print_status("⚠️ MOSTLY READY - Minor issues detected, demo possible with caution", "WARNING")
        demo_ready = True
    else:
        print_status("❌ NOT READY - Critical issues detected, fix before demo", "ERROR")
        demo_ready = False
    
    # Detailed results
    print(f"\n{Colors.BOLD}Detailed Results:{Colors.END}")
    for check, status in validation_results:
        status_icon = "✅" if status else "❌"
        print(f"  {status_icon} {check}")
    
    # Customer access information
    if demo_ready:
        print(f"\n{Colors.BOLD}🌐 CUSTOMER ACCESS INFORMATION:{Colors.END}")
        
        # Get access URL
        if domain:
            print(f"  🔗 Demo URL: https://{domain}")
            print(f"  🔐 Admin Panel: https://{domain}/admin")
        
        print(f"  👤 Demo Login: admin / admin123")
        print(f"  ⚠️ Change password immediately after first login!")
        
        # Print access info file if exists
        if os.path.exists('/opt/noctis_pro/SECURE_ACCESS_INFO.txt'):
            print(f"\n{Colors.BOLD}📋 Complete Access Information:{Colors.END}")
            with open('/opt/noctis_pro/SECURE_ACCESS_INFO.txt', 'r') as f:
                print(f.read())
    
    # Recommendations
    print(f"\n{Colors.BOLD}🔧 RECOMMENDATIONS:{Colors.END}")
    
    failed_checks = [check for check, status in validation_results if not status]
    if failed_checks:
        print("  Fix these issues before customer demo:")
        for check in failed_checks:
            print(f"    - {check}")
    
    print("\n  Pre-demo checklist:")
    print("    - Test login with admin credentials")
    print("    - Verify DICOM viewer loads")
    print("    - Check all main navigation links")
    print("    - Test admin panel access")
    print("    - Verify no JavaScript errors in browser console")
    
    if demo_ready:
        print(f"\n{Colors.GREEN}{Colors.BOLD}✅ SYSTEM READY FOR CUSTOMER DEMONSTRATION{Colors.END}")
        return 0
    else:
        print(f"\n{Colors.RED}{Colors.BOLD}❌ SYSTEM NOT READY - FIX ISSUES BEFORE DEMO{Colors.END}")
        return 1

if __name__ == "__main__":
    try:
        # Check if running with proper permissions
        if os.geteuid() != 0:
            print_status("This script should be run with sudo for complete validation", "WARNING")
        
        exit_code = main()
        sys.exit(exit_code)
        
    except KeyboardInterrupt:
        print_status("\nValidation interrupted by user", "WARNING")
        sys.exit(1)
    except Exception as e:
        print_status(f"Validation failed with error: {e}", "ERROR")
        sys.exit(1)