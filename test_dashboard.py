#!/usr/bin/env python3
"""
Test script to simulate dashboard access and check worklist display
"""

import os
import sys
import django
from pathlib import Path

# Add the project root to Python path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from django.test import Client
from django.contrib.auth import get_user_model
from worklist.models import Study

User = get_user_model()

def test_dashboard_access():
    """Test dashboard access and worklist display"""
    print("Testing dashboard access...")
    
    # Create client
    client = Client()
    
    # Get or create a test user
    user = User.objects.first()
    if not user:
        print("No users found in database")
        return
    
    print(f"Using user: {user.username}")
    
    # Test login
    print("\n1. Testing login...")
    login_response = client.post('/accounts/login/', {
        'username': user.username,
        'password': 'admin123'  # Try common password
    })
    print(f"Login status: {login_response.status_code}")
    
    if login_response.status_code == 302:
        print("Login successful (redirect)")
    else:
        print("Login failed, trying to force login...")
        client.force_login(user)
    
    # Test dashboard access
    print("\n2. Testing dashboard access...")
    dashboard_response = client.get('/worklist/')
    print(f"Dashboard status: {dashboard_response.status_code}")
    
    if dashboard_response.status_code == 200:
        content = dashboard_response.content.decode('utf-8')
        
        # Check if the dashboard contains expected elements
        if 'studiesTableBody' in content:
            print("✓ Dashboard contains studies table")
        else:
            print("✗ Dashboard missing studies table")
        
        if 'loadStudiesData' in content:
            print("✓ Dashboard contains loadStudiesData function")
        else:
            print("✗ Dashboard missing loadStudiesData function")
        
        if 'api/studies' in content:
            print("✓ Dashboard contains API endpoint reference")
        else:
            print("✗ Dashboard missing API endpoint reference")
        
        # Check for JavaScript errors
        if 'console.log' in content:
            print("✓ Debug logging is enabled")
        
        # Check if there are any obvious JavaScript issues
        if 'error' in content.lower():
            print("⚠ Dashboard contains error references")
        
    else:
        print(f"Dashboard access failed: {dashboard_response.content}")
    
    # Test API access after login
    print("\n3. Testing API access after login...")
    api_response = client.get('/worklist/api/studies/')
    print(f"API status: {api_response.status_code}")
    
    if api_response.status_code == 200:
        data = api_response.json()
        print(f"API success: {data.get('success')}")
        print(f"Studies returned: {len(data.get('studies', []))}")
    else:
        print(f"API failed: {api_response.content}")
    
    # Check database
    print("\n4. Database check:")
    total_studies = Study.objects.count()
    print(f"Total studies in database: {total_studies}")
    
    if total_studies > 0:
        studies = Study.objects.all()[:3]
        for study in studies:
            print(f"  - {study.accession_number}: {study.patient.full_name} ({study.modality.code})")

if __name__ == "__main__":
    test_dashboard_access()