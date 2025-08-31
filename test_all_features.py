#!/usr/bin/env python3
"""
Comprehensive test script for NoctisPro DICOM viewer
Tests all major functionality to ensure everything works properly
"""

import os
import sys
import django
import time
import json
from datetime import datetime

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from django.test import Client
from django.contrib.auth import get_user_model
from accounts.models import Facility
from worklist.models import Study, Patient, Modality
from notifications.models import Notification, NotificationType

User = get_user_model()

class TestResults:
    def __init__(self):
        self.passed = []
        self.failed = []
        self.warnings = []
    
    def add_success(self, test_name, details=""):
        self.passed.append(f"✓ {test_name}: {details}")
        print(f"\033[92m✓ {test_name}\033[0m: {details}")
    
    def add_failure(self, test_name, error):
        self.failed.append(f"✗ {test_name}: {error}")
        print(f"\033[91m✗ {test_name}\033[0m: {error}")
    
    def add_warning(self, test_name, warning):
        self.warnings.append(f"⚠ {test_name}: {warning}")
        print(f"\033[93m⚠ {test_name}\033[0m: {warning}")
    
    def summary(self):
        print("\n" + "="*60)
        print("TEST SUMMARY")
        print("="*60)
        print(f"Total tests: {len(self.passed) + len(self.failed)}")
        print(f"\033[92mPassed: {len(self.passed)}\033[0m")
        print(f"\033[91mFailed: {len(self.failed)}\033[0m")
        print(f"\033[93mWarnings: {len(self.warnings)}\033[0m")
        
        if self.failed:
            print("\nFailed tests:")
            for fail in self.failed:
                print(f"  {fail}")
        
        if self.warnings:
            print("\nWarnings:")
            for warn in self.warnings:
                print(f"  {warn}")
        
        return len(self.failed) == 0

def test_user_creation_and_login(results):
    """Test user creation and login functionality"""
    client = Client()
    
    try:
        # Create test facility first
        facility = Facility.objects.create(
            name="Test Facility",
            address="123 Test St",
            phone="555-0123",
            email="test@facility.com",
            license_number="TEST123",
            is_active=True
        )
        results.add_success("Facility Creation", f"Created facility: {facility.name}")
        
        # Create different user types
        users_data = [
            {'username': 'admin_test', 'role': 'admin', 'password': 'admin123!'},
            {'username': 'radiologist_test', 'role': 'radiologist', 'password': 'radio123!'},
            {'username': 'facility_test', 'role': 'facility', 'password': 'facility123!', 'facility': facility}
        ]
        
        for user_data in users_data:
            user = User.objects.create_user(
                username=user_data['username'],
                password=user_data['password'],
                role=user_data.get('role', 'facility'),
                facility=user_data.get('facility'),
                first_name=f"Test {user_data['role'].title()}",
                last_name="User",
                email=f"{user_data['username']}@test.com"
            )
            results.add_success(f"User Creation ({user_data['role']})", f"Created user: {user.username}")
            
            # Test login
            response = client.post('/accounts/login/', {
                'username': user_data['username'],
                'password': user_data['password']
            })
            
            if response.status_code == 302:  # Redirect after successful login
                results.add_success(f"User Login ({user_data['role']})", f"Successfully logged in as {user.username}")
            else:
                results.add_failure(f"User Login ({user_data['role']})", f"Login failed with status {response.status_code}")
            
            client.logout()
        
    except Exception as e:
        results.add_failure("User/Facility Creation", str(e))

def test_study_upload(results):
    """Test study upload functionality"""
    client = Client()
    
    try:
        # Login as admin
        admin = User.objects.filter(role='admin').first()
        if not admin:
            admin = User.objects.create_superuser('admin', 'admin@test.com', 'admin123!')
        
        client.force_login(admin)
        
        # Test upload endpoint
        response = client.get('/worklist/upload/')
        if response.status_code == 200:
            results.add_success("Upload Page Access", "Upload page accessible")
        else:
            results.add_failure("Upload Page Access", f"Status code: {response.status_code}")
        
        # Note: Actual file upload would require DICOM files
        results.add_warning("DICOM Upload", "Skipping actual file upload test (requires DICOM files)")
        
    except Exception as e:
        results.add_failure("Study Upload", str(e))

def test_admin_delete_study(results):
    """Test admin study deletion"""
    client = Client()
    
    try:
        # Create test study
        patient = Patient.objects.create(
            patient_id="TEST001",
            first_name="Test",
            last_name="Patient",
            date_of_birth="1990-01-01"
        )
        
        modality = Modality.objects.get_or_create(code="CT", defaults={'name': 'CT'})[0]
        facility = Facility.objects.first()
        
        study = Study.objects.create(
            study_instance_uid=f"1.2.3.{int(time.time())}",
            accession_number=f"TEST{int(time.time())}",
            patient=patient,
            facility=facility,
            modality=modality,
            study_description="Test Study for Deletion",
            status='scheduled'
        )
        results.add_success("Test Study Creation", f"Created study: {study.accession_number}")
        
        # Login as admin
        admin = User.objects.filter(role='admin').first()
        client.force_login(admin)
        
        # Test delete endpoint
        response = client.post(f'/worklist/api/study/{study.id}/delete/')
        
        if response.status_code == 200:
            data = json.loads(response.content)
            if data.get('success'):
                results.add_success("Study Deletion", f"Successfully deleted study {study.accession_number}")
            else:
                results.add_failure("Study Deletion", f"Delete failed: {data.get('error', 'Unknown error')}")
        else:
            results.add_failure("Study Deletion", f"Status code: {response.status_code}")
        
    except Exception as e:
        results.add_failure("Admin Delete Study", str(e))

def test_dicom_viewer_endpoints(results):
    """Test DICOM viewer endpoints"""
    client = Client()
    
    try:
        # Login as radiologist
        radiologist = User.objects.filter(role='radiologist').first()
        if radiologist:
            client.force_login(radiologist)
        
        # Test viewer page
        response = client.get('/dicom_viewer/')
        if response.status_code == 200:
            results.add_success("DICOM Viewer Access", "Viewer page accessible")
        else:
            results.add_failure("DICOM Viewer Access", f"Status code: {response.status_code}")
        
        # Test upload endpoint
        response = client.get('/dicom_viewer/upload/')
        if response.status_code in [200, 405]:  # 405 if GET not allowed
            results.add_success("DICOM Upload Endpoint", "Upload endpoint exists")
        else:
            results.add_failure("DICOM Upload Endpoint", f"Status code: {response.status_code}")
        
    except Exception as e:
        results.add_failure("DICOM Viewer", str(e))

def test_session_timeout(results):
    """Test session timeout functionality"""
    try:
        from django.conf import settings
        
        timeout = getattr(settings, 'SESSION_COOKIE_AGE', None)
        if timeout:
            timeout_minutes = timeout / 60
            if timeout_minutes == 10:
                results.add_success("Session Timeout", f"Configured for {timeout_minutes} minutes")
            else:
                results.add_warning("Session Timeout", f"Set to {timeout_minutes} minutes (expected 10)")
        else:
            results.add_failure("Session Timeout", "SESSION_COOKIE_AGE not configured")
        
        # Check if middleware is enabled
        if 'noctis_pro.middleware.SessionTimeoutMiddleware' in settings.MIDDLEWARE:
            results.add_success("Session Timeout Middleware", "Middleware is enabled")
        else:
            results.add_failure("Session Timeout Middleware", "Middleware not enabled")
        
    except Exception as e:
        results.add_failure("Session Timeout Configuration", str(e))

def test_notifications(results):
    """Test notification system"""
    try:
        # Check notification types
        notif_types = NotificationType.objects.all()
        if notif_types.exists():
            results.add_success("Notification Types", f"Found {notif_types.count()} notification types")
        else:
            results.add_warning("Notification Types", "No notification types configured")
        
        # Test creating a notification
        user = User.objects.first()
        if user:
            notif_type, _ = NotificationType.objects.get_or_create(
                code='test',
                defaults={'name': 'Test Notification', 'description': 'Test'}
            )
            
            notif = Notification.objects.create(
                notification_type=notif_type,
                recipient=user,
                title="Test Notification",
                message="This is a test notification",
                priority='normal'
            )
            results.add_success("Notification Creation", f"Created notification ID: {notif.id}")
        
    except Exception as e:
        results.add_failure("Notifications", str(e))

def test_admin_panel(results):
    """Test admin panel functionality"""
    client = Client()
    
    try:
        # Login as admin
        admin = User.objects.filter(role='admin').first()
        if admin:
            client.force_login(admin)
            
            # Test admin panel pages
            endpoints = [
                ('/admin-panel/', 'Admin Dashboard'),
                ('/admin-panel/users/', 'User Management'),
                ('/admin-panel/facilities/', 'Facility Management'),
                ('/admin-panel/users/create/', 'User Creation Page'),
                ('/admin-panel/facilities/create/', 'Facility Creation Page'),
            ]
            
            for endpoint, name in endpoints:
                response = client.get(endpoint)
                if response.status_code == 200:
                    results.add_success(f"Admin Panel - {name}", f"Accessible at {endpoint}")
                else:
                    results.add_failure(f"Admin Panel - {name}", f"Status code: {response.status_code}")
        else:
            results.add_failure("Admin Panel", "No admin user found")
            
    except Exception as e:
        results.add_failure("Admin Panel", str(e))

def main():
    print("="*60)
    print("NOCTISPRO COMPREHENSIVE FUNCTIONALITY TEST")
    print("="*60)
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60 + "\n")
    
    results = TestResults()
    
    # Run all tests
    test_user_creation_and_login(results)
    test_study_upload(results)
    test_admin_delete_study(results)
    test_dicom_viewer_endpoints(results)
    test_session_timeout(results)
    test_notifications(results)
    test_admin_panel(results)
    
    # Print summary
    success = results.summary()
    
    print("\n" + "="*60)
    if success:
        print("\033[92mALL CRITICAL TESTS PASSED!\033[0m")
    else:
        print("\033[91mSOME TESTS FAILED - PLEASE REVIEW\033[0m")
    print("="*60)
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())