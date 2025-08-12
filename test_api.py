#!/usr/bin/env python3
"""
Simple test script to verify API endpoints
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

def test_api_endpoints():
    """Test the API endpoints"""
    print("Testing API endpoints...")
    
    # Create client and login
    client = Client()
    user = User.objects.first()
    if not user:
        print("No users found in database")
        return
    
    client.force_login(user)
    print(f"Logged in as: {user.username}")
    
    # Test main studies API
    print("\n1. Testing /worklist/api/studies/")
    response = client.get('/worklist/api/studies/')
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        print(f"Success: {data.get('success')}")
        print(f"Number of studies: {len(data.get('studies', []))}")
        if data.get('studies'):
            study = data['studies'][0]
            print(f"First study: {study.get('accession_number')} - {study.get('patient_name')}")
    else:
        print(f"Error: {response.content}")
    
    # Test refresh worklist API
    print("\n2. Testing /worklist/api/refresh-worklist/")
    response = client.get('/worklist/api/refresh-worklist/')
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        print(f"Success: {data.get('success')}")
        print(f"Total recent: {data.get('total_recent')}")
        print(f"Number of studies: {len(data.get('studies', []))}")
    else:
        print(f"Error: {response.content}")
    
    # Test upload stats API
    print("\n3. Testing /worklist/api/upload-stats/")
    response = client.get('/worklist/api/upload-stats/')
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        print(f"Success: {data.get('success')}")
        stats = data.get('stats', {})
        print(f"Total studies: {stats.get('total_studies')}")
        print(f"Total series: {stats.get('total_series')}")
        print(f"Total images: {stats.get('total_images')}")
    else:
        print(f"Error: {response.content}")
    
    # Check database directly
    print("\n4. Database check:")
    total_studies = Study.objects.count()
    print(f"Total studies in database: {total_studies}")
    
    if total_studies > 0:
        studies = Study.objects.all()[:3]
        for study in studies:
            print(f"  - {study.accession_number}: {study.patient.full_name} ({study.modality.code})")

if __name__ == "__main__":
    test_api_endpoints()