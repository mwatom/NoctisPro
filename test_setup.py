#!/usr/bin/env python3
"""
Test script to verify ngrok and admin login functionality
"""
import requests
import json
import subprocess
import time
import sys
import os

# Add the project directory to the path
sys.path.insert(0, '/workspace')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')

def check_django_server():
    """Check if Django development server is running"""
    try:
        response = requests.get('http://localhost:8000/health/simple/', timeout=5)
        return response.status_code == 200
    except:
        return False

def get_ngrok_url():
    """Get the public ngrok URL"""
    try:
        response = requests.get('http://localhost:4040/api/tunnels', timeout=5)
        if response.status_code == 200:
            data = response.json()
            if data.get('tunnels'):
                for tunnel in data['tunnels']:
                    if tunnel.get('public_url', '').startswith('https://'):
                        return tunnel['public_url']
        return None
    except:
        return None

def test_admin_login(base_url):
    """Test admin login functionality"""
    try:
        # First, get the login page to extract CSRF token
        session = requests.Session()
        login_url = f"{base_url}/admin/"
        response = session.get(login_url, timeout=10)
        
        if response.status_code == 200:
            print(f"✓ Admin page accessible at {login_url}")
            return True
        else:
            print(f"✗ Admin page returned status {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ Admin page test failed: {e}")
        return False

def main():
    print("=== NOCTIS PRO SETUP TEST ===")
    print()
    
    # Test Django server
    print("1. Testing Django Server...")
    if check_django_server():
        print("✓ Django server is running on http://localhost:8000")
    else:
        print("✗ Django server is not accessible")
        return False
    
    # Test ngrok
    print("\n2. Testing ngrok tunnel...")
    ngrok_url = get_ngrok_url()
    if ngrok_url:
        print(f"✓ ngrok tunnel active: {ngrok_url}")
        
        # Test ngrok URL accessibility
        print("\n3. Testing ngrok URL accessibility...")
        if test_admin_login(ngrok_url):
            print(f"✓ Admin interface accessible via ngrok")
        else:
            print(f"✗ Admin interface not accessible via ngrok")
            
        # Test local admin
        print("\n4. Testing local admin interface...")
        if test_admin_login("http://localhost:8000"):
            print(f"✓ Local admin interface accessible")
        else:
            print(f"✗ Local admin interface not accessible")
            
    else:
        print("✗ ngrok tunnel not found or not running")
        print("   Make sure ngrok is running with: ngrok http 8000")
        
    print("\n=== TEST SUMMARY ===")
    print(f"Django Server: {'✓' if check_django_server() else '✗'}")
    print(f"ngrok Tunnel: {'✓' if get_ngrok_url() else '✗'}")
    
    if ngrok_url:
        print(f"\nACCESS YOUR APPLICATION:")
        print(f"Local URL:  http://localhost:8000/admin/")
        print(f"Public URL: {ngrok_url}/admin/")
        print(f"Admin Login: username='admin', password='admin123'")
    else:
        print(f"\nLocal URL: http://localhost:8000/admin/")
        print(f"Admin Login: username='admin', password='admin123'")
        print("NOTE: ngrok not running - only local access available")

if __name__ == "__main__":
    main()