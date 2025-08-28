#!/usr/bin/env python
"""
Comprehensive health check script for NoctisPro
Verifies all system components are working correctly
"""

import os
import sys
import json
import time
import socket
import requests
import subprocess
from urllib.parse import urlparse

def check_service(name, host, port, timeout=5):
    """Check if a service is running on the specified host:port"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        if result == 0:
            return True, f"{name} service is running on {host}:{port}"
        else:
            return False, f"{name} service is not responding on {host}:{port}"
    except Exception as e:
        return False, f"Error checking {name} service: {str(e)}"

def check_http_endpoint(name, url, timeout=10):
    """Check if an HTTP endpoint is responding"""
    try:
        response = requests.get(url, timeout=timeout)
        if response.status_code == 200:
            return True, f"{name} endpoint is healthy (status: {response.status_code})"
        else:
            return False, f"{name} endpoint returned status: {response.status_code}"
    except requests.exceptions.RequestException as e:
        return False, f"{name} endpoint error: {str(e)}"

def check_database():
    """Check database connectivity"""
    try:
        import django
        from django.conf import settings
        from django.db import connection
        
        # Configure Django settings
        os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
        django.setup()
        
        # Test database connection
        cursor = connection.cursor()
        cursor.execute("SELECT 1")
        return True, "Database connection successful"
    except Exception as e:
        return False, f"Database connection failed: {str(e)}"

def check_redis():
    """Check Redis connectivity"""
    try:
        import redis
        redis_url = os.environ.get('REDIS_URL', 'redis://localhost:6379/0')
        r = redis.from_url(redis_url)
        r.ping()
        return True, "Redis connection successful"
    except Exception as e:
        return False, f"Redis connection failed: {str(e)}"

def check_disk_space():
    """Check available disk space"""
    try:
        import shutil
        total, used, free = shutil.disk_usage('/')
        free_gb = free // (1024**3)
        used_percent = (used / total) * 100
        
        if free_gb < 5:
            return False, f"Low disk space: {free_gb}GB free ({used_percent:.1f}% used)"
        elif free_gb < 10:
            return True, f"Warning: {free_gb}GB free ({used_percent:.1f}% used)"
        else:
            return True, f"Disk space OK: {free_gb}GB free ({used_percent:.1f}% used)"
    except Exception as e:
        return False, f"Disk space check failed: {str(e)}"

def check_memory():
    """Check available memory"""
    try:
        with open('/proc/meminfo', 'r') as f:
            meminfo = {}
            for line in f:
                key, value = line.split(':')
                meminfo[key] = int(value.split()[0]) * 1024  # Convert to bytes
        
        total_mem = meminfo['MemTotal']
        available_mem = meminfo['MemAvailable']
        used_percent = ((total_mem - available_mem) / total_mem) * 100
        available_gb = available_mem // (1024**3)
        
        if used_percent > 90:
            return False, f"High memory usage: {used_percent:.1f}% used ({available_gb}GB available)"
        elif used_percent > 80:
            return True, f"Warning: {used_percent:.1f}% memory used ({available_gb}GB available)"
        else:
            return True, f"Memory OK: {used_percent:.1f}% used ({available_gb}GB available)"
    except Exception as e:
        return False, f"Memory check failed: {str(e)}"

def check_docker_containers():
    """Check Docker container status"""
    try:
        result = subprocess.run(['docker', 'ps', '--format', 'json'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            containers = []
            for line in result.stdout.strip().split('\n'):
                if line:
                    containers.append(json.loads(line))
            
            if len(containers) > 0:
                running_containers = [c['Names'] for c in containers]
                return True, f"Docker containers running: {', '.join(running_containers)}"
            else:
                return False, "No Docker containers are running"
        else:
            return False, f"Docker command failed: {result.stderr}"
    except Exception as e:
        return False, f"Docker check failed: {str(e)}"

def main():
    """Run comprehensive health checks"""
    print("🏥 NoctisPro System Health Check")
    print("=" * 50)
    
    checks = []
    
    # Infrastructure checks
    print("\n📋 Infrastructure Checks:")
    
    # Disk space
    status, message = check_disk_space()
    checks.append(('Disk Space', status, message))
    print(f"  {'✅' if status else '❌'} {message}")
    
    # Memory
    status, message = check_memory()
    checks.append(('Memory', status, message))
    print(f"  {'✅' if status else '❌'} {message}")
    
    # Docker containers
    status, message = check_docker_containers()
    checks.append(('Docker Containers', status, message))
    print(f"  {'✅' if status else '❌'} {message}")
    
    # Service checks
    print("\n🔧 Service Checks:")
    
    # PostgreSQL
    status, message = check_service('PostgreSQL', 'localhost', 5432)
    checks.append(('PostgreSQL', status, message))
    print(f"  {'✅' if status else '❌'} {message}")
    
    # Redis
    status, message = check_service('Redis', 'localhost', 6379)
    checks.append(('Redis Port', status, message))
    print(f"  {'✅' if status else '❌'} {message}")
    
    # Redis connectivity
    status, message = check_redis()
    checks.append(('Redis Connection', status, message))
    print(f"  {'✅' if status else '❌'} {message}")
    
    # Django application
    status, message = check_service('Django', 'localhost', 8000)
    checks.append(('Django Port', status, message))
    print(f"  {'✅' if status else '❌'} {message}")
    
    # DICOM receiver
    status, message = check_service('DICOM Receiver', 'localhost', 11112)
    checks.append(('DICOM Receiver', status, message))
    print(f"  {'✅' if status else '❌'} {message}")
    
    # Application checks
    print("\n🌐 Application Checks:")
    
    # Database connectivity
    status, message = check_database()
    checks.append(('Database Connection', status, message))
    print(f"  {'✅' if status else '❌'} {message}")
    
    # Django health endpoint
    status, message = check_http_endpoint('Django Health', 'http://localhost:8000/health/')
    checks.append(('Django Health Endpoint', status, message))
    print(f"  {'✅' if status else '❌'} {message}")
    
    # Main application
    status, message = check_http_endpoint('Main Application', 'http://localhost:8000/')
    checks.append(('Main Application', status, message))
    print(f"  {'✅' if status else '❌'} {message}")
    
    # Ngrok (if running)
    status, message = check_service('Ngrok', 'localhost', 4040)
    checks.append(('Ngrok Web Interface', status, message))
    print(f"  {'✅' if status else '❌'} {message}")
    
    # Summary
    print("\n📊 Health Check Summary:")
    total_checks = len(checks)
    passed_checks = sum(1 for _, status, _ in checks if status)
    failed_checks = total_checks - passed_checks
    
    print(f"  Total Checks: {total_checks}")
    print(f"  Passed: {passed_checks}")
    print(f"  Failed: {failed_checks}")
    print(f"  Success Rate: {(passed_checks/total_checks)*100:.1f}%")
    
    if failed_checks == 0:
        print("\n🎉 All systems are healthy and ready for demo!")
        return 0
    elif failed_checks <= 2:
        print("\n⚠️  System mostly healthy with minor issues")
        return 1
    else:
        print("\n❌ System has significant issues that need attention")
        return 2

if __name__ == '__main__':
    exit_code = main()
    sys.exit(exit_code)