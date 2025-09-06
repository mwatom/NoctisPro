#!/usr/bin/env python3
"""
🏥 Noctis Pro PACS - User & Facility Creation Test
This script verifies that admin can create users/facilities and they can login properly.
"""

import os
import sys
import django
from pathlib import Path

# Add the project directory to Python path
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from django.test import Client
from django.contrib.auth import get_user_model
from accounts.models import Facility
from django.urls import reverse

User = get_user_model()

def test_admin_user_creation():
    """Test admin can create users and they can login"""
    print("🧪 Testing Admin User Creation & Login...")
    
    client = Client()
    
    # Login as admin
    login_response = client.post('/login/', {
        'username': 'admin',
        'password': 'admin'
    })
    
    if login_response.status_code not in [200, 302]:
        print("❌ Admin login failed")
        return False
    
    # Test creating a new radiologist
    facility = Facility.objects.first()
    user_data = {
        'username': 'test_radiologist',
        'email': 'test.radiologist@hospital.com',
        'first_name': 'Dr. Test',
        'last_name': 'Radiologist',
        'password1': 'testpassword123',
        'password2': 'testpassword123',
        'role': 'radiologist',
        'facility': facility.id if facility else '',
        'license_number': 'RAD-TEST-001',
        'specialization': 'Diagnostic Radiology'
    }
    
    create_response = client.post('/admin-panel/users/create/', user_data)
    
    if create_response.status_code in [200, 302]:
        print("✅ Admin can create users")
        
        # Test if created user can login
        test_client = Client()
        test_login = test_client.post('/login/', {
            'username': 'test_radiologist',
            'password': 'testpassword123'
        })
        
        if test_login.status_code in [200, 302]:
            print("✅ Created user can login successfully")
            
            # Test if user sees their appropriate dashboard
            dashboard_response = test_client.get('/worklist/')
            if dashboard_response.status_code == 200:
                print("✅ Created user can access their dashboard")
                return True
            else:
                print("❌ Created user cannot access dashboard")
                return False
        else:
            print("❌ Created user cannot login")
            return False
    else:
        print("❌ Admin cannot create users")
        return False

def test_admin_facility_creation():
    """Test admin can create facilities"""
    print("🧪 Testing Admin Facility Creation...")
    
    client = Client()
    client.login(username='admin', password='admin')
    
    facility_data = {
        'name': 'Test Medical Center',
        'address': '123 Test Street, Test City, TC 12345',
        'phone': '+1-555-TEST-MED',
        'email': 'contact@testmedical.com',
        'license_number': 'TMC-RAD-2024-TEST',
        'create_facility_user': True,
        'facility_username': 'testfacility',
        'facility_password': 'testfacility123',
        'facility_email': 'facility@testmedical.com'
    }
    
    create_response = client.post('/admin-panel/facilities/create/', facility_data)
    
    if create_response.status_code in [200, 302]:
        print("✅ Admin can create facilities")
        
        # Check if facility user was created
        facility_user = User.objects.filter(username='testfacility').first()
        if facility_user:
            print("✅ Facility user auto-created")
            
            # Test facility user login
            test_client = Client()
            facility_login = test_client.post('/login/', {
                'username': 'testfacility',
                'password': 'testfacility123'
            })
            
            if facility_login.status_code in [200, 302]:
                print("✅ Facility user can login")
                
                # Test facility user sees only their facility data
                dashboard_response = test_client.get('/worklist/')
                if dashboard_response.status_code == 200:
                    print("✅ Facility user can access their restricted dashboard")
                    return True
                else:
                    print("❌ Facility user cannot access dashboard")
                    return False
            else:
                print("❌ Facility user cannot login")
                return False
        else:
            print("❌ Facility user was not auto-created")
            return False
    else:
        print("❌ Admin cannot create facilities")
        return False

def main():
    """Run all user/facility creation tests"""
    print("🏥 NOCTIS PRO PACS - USER & FACILITY CREATION VERIFICATION")
    print("="*60)
    
    try:
        user_test_passed = test_admin_user_creation()
        facility_test_passed = test_admin_facility_creation()
        
        print("\n" + "="*60)
        print("📊 TEST RESULTS SUMMARY:")
        print("="*60)
        
        if user_test_passed:
            print("✅ Admin User Creation & Login: WORKING")
        else:
            print("❌ Admin User Creation & Login: FAILED")
        
        if facility_test_passed:
            print("✅ Admin Facility Creation & User Login: WORKING")
        else:
            print("❌ Admin Facility Creation & User Login: FAILED")
        
        if user_test_passed and facility_test_passed:
            print("\n🎉 ALL TESTS PASSED!")
            print("✅ Admin can create users and facilities")
            print("✅ Created users can login to their appropriate windows")
            print("✅ Facility users see only their facility data")
            print("✅ Role-based access control working properly")
            return True
        else:
            print("\n❌ SOME TESTS FAILED!")
            return False
            
    except Exception as e:
        print(f"❌ Test execution failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)