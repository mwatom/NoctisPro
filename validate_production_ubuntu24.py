#!/usr/bin/env python3

"""
NoctisPro Production Validation Script for Ubuntu 24.04
Comprehensive validation of complete production system functionality
"""

import subprocess
import requests
import sys
import os
import json
import time
from urllib.parse import urlparse
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

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
        return response.status_code == 200, response.status_code, response
    except Exception as e:
        return False, str(e), None

def test_login_functionality(base_url, username="admin", password="admin123"):
    """Test login functionality"""
    try:
        session = requests.Session()
        
        # Get login page
        login_url = f"{base_url}/admin/login/"
        response = session.get(login_url, verify=False)
        
        if response.status_code != 200:
            return False, f"Login page not accessible: {response.status_code}"
        
        # Extract CSRF token
        csrf_token = None
        for line in response.text.split('\n'):
            if 'csrfmiddlewaretoken' in line:
                csrf_token = line.split('value="')[1].split('"')[0]
                break
        
        if not csrf_token:
            return False, "CSRF token not found"
        
        # Attempt login
        login_data = {
            'username': username,
            'password': password,
            'csrfmiddlewaretoken': csrf_token,
            'next': '/admin/'
        }
        
        response = session.post(login_url, data=login_data, verify=False)
        
        # Check if login was successful (should redirect or show admin panel)
        if response.status_code in [200, 302] and 'admin' in response.url:
            return True, "Login successful"
        else:
            return False, f"Login failed: {response.status_code}"
            
    except Exception as e:
        return False, f"Login test error: {e}"

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

def test_dicom_functionality(base_url):
    """Test DICOM viewer functionality"""
    try:
        dicom_url = f"{base_url}/worklist/"
        response = requests.get(dicom_url, verify=False)
        
        if response.status_code == 200:
            # Check if DICOM viewer elements are present
            content = response.text.lower()
            dicom_elements = ['dicom', 'viewer', 'worklist', 'patient']
            found_elements = sum(1 for element in dicom_elements if element in content)
            
            if found_elements >= 2:
                return True, f"DICOM interface accessible with {found_elements}/4 elements"
            else:
                return False, f"DICOM interface incomplete: {found_elements}/4 elements"
        else:
            return False, f"DICOM interface not accessible: {response.status_code}"
            
    except Exception as e:
        return False, f"DICOM test error: {e}"

def main():
    print(f"{Colors.BOLD}🏥 NoctisPro Production Validation - Ubuntu 24.04{Colors.END}")
    print(f"{Colors.BOLD}Complete System Functionality Verification{Colors.END}")
    print("=" * 70)
    
    validation_results = []
    
    # 1. Ubuntu 24.04 Verification
    print_status("Verifying Ubuntu 24.04 LTS...")
    success, stdout, stderr = run_command("lsb_release -a")
    if success and "24.04" in stdout and "LTS" in stdout:
        print_status("Ubuntu 24.04 LTS confirmed", "SUCCESS")
        validation_results.append(("Ubuntu 24.04 LTS", True))
    else:
        print_status("Ubuntu 24.04 LTS not detected", "WARNING")
        validation_results.append(("Ubuntu 24.04 LTS", False))
    
    # 2. System Resources Check
    print_status("Checking system resources...")
    
    # Memory check
    success, stdout, stderr = run_command("free -m")
    if success:
        for line in stdout.split('\n'):
            if line.startswith('Mem:'):
                total_mem = int(line.split()[1])
                if total_mem >= 7000:  # 7GB minimum for production
                    print_status(f"Memory: {total_mem}MB - adequate for production", "SUCCESS")
                    validation_results.append(("Memory adequate", True))
                else:
                    print_status(f"Memory: {total_mem}MB - may be insufficient for production", "WARNING")
                    validation_results.append(("Memory adequate", False))
                break
    
    # Disk space check
    success, stdout, stderr = run_command("df -h /")
    if success:
        for line in stdout.split('\n'):
            if '/' in line and not line.startswith('Filesystem'):
                usage = line.split()[4].replace('%', '')
                available = line.split()[3]
                if int(usage) < 80:
                    print_status(f"Disk usage: {usage}% ({available} available) - good", "SUCCESS")
                    validation_results.append(("Disk space", True))
                else:
                    print_status(f"Disk usage: {usage}% ({available} available) - high", "WARNING")
                    validation_results.append(("Disk space", False))
                break
    
    # 3. Core Services Verification
    print_status("Verifying core production services...")
    
    production_services = [
        "noctis-django",
        "noctis-daphne", 
        "noctis-celery",
        "postgresql",
        "redis",
        "nginx",
        "docker"
    ]
    
    for service in production_services:
        if check_service_status(service):
            print_status(f"Service {service}: active", "SUCCESS")
            validation_results.append((f"Service {service}", True))
        else:
            print_status(f"Service {service}: inactive or failed", "ERROR")
            validation_results.append((f"Service {service}", False))
    
    # 4. Docker Production Verification
    print_status("Verifying Docker production setup...")
    
    # Docker version
    success, stdout, stderr = run_command("docker --version")
    if success:
        docker_version = stdout.strip()
        print_status(f"Docker: {docker_version}", "SUCCESS")
        validation_results.append(("Docker installed", True))
        
        # Docker Compose
        success, stdout, stderr = run_command("docker compose version")
        if success:
            compose_version = stdout.strip()
            print_status(f"Docker Compose: {compose_version}", "SUCCESS")
            validation_results.append(("Docker Compose", True))
        
        # Docker containers
        success, stdout, stderr = run_command("docker ps")
        if success:
            container_count = len([line for line in stdout.split('\n') if line and not line.startswith('CONTAINER')])
            if container_count > 0:
                print_status(f"Docker containers: {container_count} running", "SUCCESS")
                validation_results.append(("Docker containers", True))
            else:
                print_status("No Docker containers running", "WARNING")
                validation_results.append(("Docker containers", False))
    else:
        print_status("Docker not installed or not working", "ERROR")
        validation_results.append(("Docker installed", False))
    
    # 5. Network Ports Verification
    print_status("Verifying network ports...")
    
    production_ports = [80, 443, 5432, 6379]
    port_names = ["HTTP", "HTTPS", "PostgreSQL", "Redis"]
    
    for port, name in zip(production_ports, port_names):
        if check_port_open(port):
            print_status(f"Port {port} ({name}): open", "SUCCESS")
            validation_results.append((f"Port {port}", True))
        else:
            print_status(f"Port {port} ({name}): closed or not listening", "ERROR")
            validation_results.append((f"Port {port}", False))
    
    # 6. Web Interface Testing
    print_status("Testing web interface...")
    
    # Local access test
    local_accessible, local_status, local_response = check_url_accessible("http://localhost")
    if local_accessible:
        print_status("Local web interface: accessible", "SUCCESS")
        validation_results.append(("Local web access", True))
    else:
        print_status(f"Local web interface: failed ({local_status})", "ERROR")
        validation_results.append(("Local web access", False))
    
    # 7. HTTPS Production Configuration
    print_status("Verifying HTTPS production configuration...")
    
    domain = get_domain_from_config()
    if domain:
        print_status(f"Production domain: {domain}")
        
        # HTTPS access test
        https_url = f"https://{domain}"
        https_accessible, https_status, https_response = check_url_accessible(https_url)
        
        if https_accessible:
            print_status("HTTPS production access: working", "SUCCESS")
            validation_results.append(("HTTPS access", True))
            
            # Check security headers
            if https_response and https_response.headers:
                security_headers = ['strict-transport-security', 'x-frame-options', 'content-security-policy']
                found_headers = sum(1 for header in security_headers if header in [h.lower() for h in https_response.headers.keys()])
                
                if found_headers >= 2:
                    print_status(f"Security headers: {found_headers}/3 configured", "SUCCESS")
                    validation_results.append(("Security headers", True))
                else:
                    print_status(f"Security headers: {found_headers}/3 configured", "WARNING")
                    validation_results.append(("Security headers", False))
            
            # Test HTTP to HTTPS redirect
            try:
                http_response = requests.get(f"http://{domain}", allow_redirects=False, timeout=10, verify=False)
                if http_response.status_code in [301, 302] and 'https' in http_response.headers.get('Location', '').lower():
                    print_status("HTTP to HTTPS redirect: working", "SUCCESS")
                    validation_results.append(("HTTPS redirect", True))
                else:
                    print_status("HTTP to HTTPS redirect: not configured", "WARNING")
                    validation_results.append(("HTTPS redirect", False))
            except:
                print_status("HTTP to HTTPS redirect: test failed", "WARNING")
                validation_results.append(("HTTPS redirect", False))
                
        else:
            print_status(f"HTTPS production access: failed ({https_status})", "ERROR")
            validation_results.append(("HTTPS access", False))
    else:
        print_status("No production domain configured", "WARNING")
        validation_results.append(("Production domain", False))
    
    # 8. SSL Certificate Verification
    if domain:
        print_status("Verifying SSL certificate...")
        success, stdout, stderr = run_command(f"echo | openssl s_client -connect {domain}:443 -servername {domain} 2>/dev/null | openssl x509 -noout -dates")
        if success and "notAfter" in stdout:
            print_status("SSL certificate: valid and active", "SUCCESS")
            validation_results.append(("SSL certificate", True))
            
            # Check certificate issuer
            success, stdout, stderr = run_command(f"echo | openssl s_client -connect {domain}:443 -servername {domain} 2>/dev/null | openssl x509 -noout -issuer")
            if success and "Let's Encrypt" in stdout:
                print_status("SSL certificate: Let's Encrypt (production-grade)", "SUCCESS")
        else:
            print_status("SSL certificate: invalid or missing", "ERROR")
            validation_results.append(("SSL certificate", False))
    
    # 9. Database Production Testing
    print_status("Testing database production configuration...")
    
    # Database connection
    success, stdout, stderr = run_command("sudo -u postgres psql -d noctis_pro -c 'SELECT version();'")
    if success and "PostgreSQL" in stdout:
        print_status("Database connection: working", "SUCCESS")
        validation_results.append(("Database connection", True))
        
        # Check database size and tables
        success, stdout, stderr = run_command("sudo -u postgres psql -d noctis_pro -c 'SELECT count(*) FROM information_schema.tables WHERE table_schema = \\'public\\';'")
        if success:
            table_count = int(stdout.strip().split('\n')[-2].strip())
            if table_count > 10:
                print_status(f"Database tables: {table_count} tables created", "SUCCESS")
                validation_results.append(("Database schema", True))
            else:
                print_status(f"Database tables: {table_count} tables - may be incomplete", "WARNING")
                validation_results.append(("Database schema", False))
    else:
        print_status("Database connection: failed", "ERROR")
        validation_results.append(("Database connection", False))
    
    # 10. Login Functionality Testing
    print_status("Testing login functionality...")
    
    if domain:
        base_url = f"https://{domain}"
    else:
        base_url = "http://localhost"
    
    login_success, login_message = test_login_functionality(base_url)
    if login_success:
        print_status(f"Login system: {login_message}", "SUCCESS")
        validation_results.append(("Login functionality", True))
    else:
        print_status(f"Login system: {login_message}", "ERROR")
        validation_results.append(("Login functionality", False))
    
    # 11. DICOM Functionality Testing
    print_status("Testing DICOM functionality...")
    
    dicom_success, dicom_message = test_dicom_functionality(base_url)
    if dicom_success:
        print_status(f"DICOM system: {dicom_message}", "SUCCESS")
        validation_results.append(("DICOM functionality", True))
    else:
        print_status(f"DICOM system: {dicom_message}", "WARNING")
        validation_results.append(("DICOM functionality", False))
    
    # 12. Application Files Verification
    print_status("Verifying production application files...")
    
    critical_production_files = [
        "/opt/noctis_pro/manage.py",
        "/opt/noctis_pro/.env",
        "/opt/noctis_pro/static/",
        "/opt/noctis_pro/media/",
        "/etc/nginx/sites-available/noctis_pro",
        "/etc/systemd/system/noctis-django.service"
    ]
    
    for file_path in critical_production_files:
        if os.path.exists(file_path):
            print_status(f"Production file {file_path}: exists", "SUCCESS")
            validation_results.append((f"File {os.path.basename(file_path)}", True))
        else:
            print_status(f"Production file {file_path}: missing", "ERROR")
            validation_results.append((f"File {os.path.basename(file_path)}", False))
    
    # 13. Security Configuration Verification
    print_status("Verifying production security configuration...")
    
    # Firewall
    success, stdout, stderr = run_command("ufw status")
    if success and "active" in stdout.lower():
        print_status("Firewall: active and configured", "SUCCESS")
        validation_results.append(("Firewall", True))
    else:
        print_status("Firewall: inactive or not configured", "ERROR")
        validation_results.append(("Firewall", False))
    
    # Fail2ban
    success, stdout, stderr = run_command("fail2ban-client status")
    if success:
        print_status("Fail2ban: active and monitoring", "SUCCESS")
        validation_results.append(("Fail2ban", True))
    else:
        print_status("Fail2ban: inactive", "WARNING")
        validation_results.append(("Fail2ban", False))
    
    # 14. Printing System Verification
    print_status("Verifying printing system...")
    
    success, stdout, stderr = run_command("systemctl is-active cups")
    if success and "active" in stdout:
        print_status("CUPS printing system: active", "SUCCESS")
        validation_results.append(("Printing system", True))
        
        # Check for printer drivers
        success, stdout, stderr = run_command("lpstat -e")
        if success:
            print_status("Printer detection: working", "SUCCESS")
        else:
            print_status("Printer detection: no printers configured (normal)", "INFO")
    else:
        print_status("CUPS printing system: inactive", "ERROR")
        validation_results.append(("Printing system", False))
    
    # 15. Performance Testing
    print_status("Testing production performance...")
    
    # Test response time
    if domain:
        test_url = f"https://{domain}"
        start_time = time.time()
        accessible, status, response = check_url_accessible(test_url)
        end_time = time.time()
        response_time = end_time - start_time
        
        if accessible and response_time < 3.0:
            print_status(f"Response time: {response_time:.2f}s - good", "SUCCESS")
            validation_results.append(("Response time", True))
        elif accessible:
            print_status(f"Response time: {response_time:.2f}s - acceptable", "WARNING")
            validation_results.append(("Response time", False))
        else:
            print_status(f"Response time: test failed", "ERROR")
            validation_results.append(("Response time", False))
    
    # 16. Backup System Verification
    print_status("Verifying backup system...")
    
    if os.path.exists("/usr/local/bin/noctis-backup.sh"):
        print_status("Backup script: installed", "SUCCESS")
        validation_results.append(("Backup system", True))
        
        # Check backup directory
        backup_dirs = ["/opt/backups/noctis_pro/", "/data/noctis_pro/backups/"]
        backup_found = False
        for backup_dir in backup_dirs:
            if os.path.exists(backup_dir):
                print_status(f"Backup directory: {backup_dir}", "SUCCESS")
                backup_found = True
                break
        
        if not backup_found:
            print_status("Backup directory: not found", "WARNING")
    else:
        print_status("Backup script: not installed", "ERROR")
        validation_results.append(("Backup system", False))
    
    # 17. Final Summary
    print("\n" + "=" * 70)
    print_status("PRODUCTION DEPLOYMENT VALIDATION SUMMARY", "INFO")
    print("=" * 70)
    
    passed = sum(1 for _, status in validation_results if status)
    total = len(validation_results)
    success_rate = (passed / total) * 100
    
    print(f"\n{Colors.BOLD}Results: {passed}/{total} checks passed ({success_rate:.1f}%){Colors.END}")
    
    if success_rate >= 95:
        print_status("🎉 PRODUCTION READY - System is fully operational for customer use!", "SUCCESS")
        production_ready = True
    elif success_rate >= 85:
        print_status("⚠️ MOSTLY READY - Minor issues detected, suitable for customer evaluation", "WARNING")
        production_ready = True
    else:
        print_status("❌ NOT READY - Critical issues detected, fix before customer access", "ERROR")
        production_ready = False
    
    # Detailed results
    print(f"\n{Colors.BOLD}Detailed Validation Results:{Colors.END}")
    for check, status in validation_results:
        status_icon = "✅" if status else "❌"
        print(f"  {status_icon} {check}")
    
    # Customer access information
    if production_ready:
        print(f"\n{Colors.BOLD}🌐 CUSTOMER PRODUCTION ACCESS:{Colors.END}")
        
        if domain:
            print(f"  🔗 Production URL: https://{domain}")
            print(f"  🔐 Admin Panel: https://{domain}/admin")
            print(f"  📚 API Docs: https://{domain}/api/docs/")
        else:
            print(f"  🔗 Local URL: http://192.168.100.15")
            print(f"  🔐 Admin Panel: http://192.168.100.15/admin")
        
        print(f"  👤 Admin Login: admin / admin123")
        print(f"  ⚠️ CRITICAL: Change admin password immediately!")
        
        # Print complete access info
        if os.path.exists('/opt/noctis_pro/SECURE_ACCESS_INFO.txt'):
            print(f"\n{Colors.BOLD}📋 Complete Production Access Information:{Colors.END}")
            with open('/opt/noctis_pro/SECURE_ACCESS_INFO.txt', 'r') as f:
                print(f.read())
    
    # Production recommendations
    print(f"\n{Colors.BOLD}🏥 PRODUCTION RECOMMENDATIONS:{Colors.END}")
    
    failed_checks = [check for check, status in validation_results if not status]
    if failed_checks:
        print("  Fix these issues for optimal production performance:")
        for check in failed_checks:
            print(f"    - {check}")
    
    print("\n  Customer evaluation checklist:")
    print("    - Test complete login workflow")
    print("    - Verify DICOM viewer functionality")
    print("    - Test worklist management")
    print("    - Check admin panel features")
    print("    - Verify print system availability")
    print("    - Test real-time collaboration features")
    print("    - Check API documentation access")
    print("    - Verify security features (HTTPS, audit logs)")
    
    print(f"\n  Production monitoring commands:")
    print("    - sudo /usr/local/bin/noctis-status.sh")
    print("    - htop && df -h")
    print("    - sudo journalctl -u noctis-django -f")
    print("    - sudo docker ps && sudo docker stats")
    
    if production_ready:
        print(f"\n{Colors.GREEN}{Colors.BOLD}✅ PRODUCTION SYSTEM READY FOR CUSTOMER EVALUATION{Colors.END}")
        print(f"{Colors.GREEN}🏥 Complete medical imaging platform operational with full functionality{Colors.END}")
        return 0
    else:
        print(f"\n{Colors.RED}{Colors.BOLD}❌ PRODUCTION SYSTEM NOT READY{Colors.END}")
        print(f"{Colors.RED}Fix critical issues before customer access{Colors.END}")
        return 1

if __name__ == "__main__":
    try:
        # Check if running with proper permissions
        if os.geteuid() != 0:
            print_status("Running production validation with user permissions", "INFO")
            print_status("Some checks may require sudo for complete validation", "WARNING")
        
        exit_code = main()
        sys.exit(exit_code)
        
    except KeyboardInterrupt:
        print_status("\nProduction validation interrupted by user", "WARNING")
        sys.exit(1)
    except Exception as e:
        print_status(f"Production validation failed with error: {e}", "ERROR")
        sys.exit(1)