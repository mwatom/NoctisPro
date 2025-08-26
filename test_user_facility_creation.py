#!/usr/bin/env python3
"""
Test script for User and Facility Creation
This script tests the enhanced user and facility creation functionality
"""

import os
import sys
import django
from django.core.management import setup_environ

# Setup Django environment
sys.path.append('/workspace')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from accounts.models import User, Facility
from admin_panel.forms import CustomUserCreationForm, FacilityForm
from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile


def test_facility_creation():
    """Test facility creation with validation"""
    print("🏥 Testing Facility Creation...")
    
    # Test 1: Valid facility creation
    facility_data = {
        'name': 'Test Medical Center',
        'address': '123 Healthcare Ave\nMedical District\nCity, State 12345',
        'phone': '+1 (555) 123-4567',
        'email': 'info@testmedical.com',
        'license_number': 'MED-2024-001',
        'ae_title': 'TESTMED',
        'is_active': True,
    }
    
    form = FacilityForm(data=facility_data)
    if form.is_valid():
        facility = form.save()
        print(f"✅ Facility created successfully: {facility.name}")
        print(f"   - AE Title: {facility.ae_title}")
        print(f"   - License: {facility.license_number}")
        print(f"   - Active: {facility.is_active}")
    else:
        print("❌ Facility creation failed:")
        for field, errors in form.errors.items():
            print(f"   - {field}: {errors}")
    
    # Test 2: Facility with auto-generated AE Title
    facility_data2 = {
        'name': 'Advanced Imaging Solutions',
        'address': '456 Radiology Blvd\nImaging Center\nCity, State 12345',
        'phone': '+1 (555) 987-6543',
        'email': 'contact@advancedimaging.com',
        'license_number': 'IMG-2024-002',
        'ae_title': '',  # Should auto-generate
        'is_active': True,
    }
    
    form2 = FacilityForm(data=facility_data2)
    if form2.is_valid():
        facility2 = form2.save()
        print(f"✅ Facility with auto-generated AE Title: {facility2.name}")
        print(f"   - Auto-generated AE Title: {facility2.ae_title}")
    else:
        print("❌ Facility with auto-generated AE Title failed:")
        for field, errors in form2.errors.items():
            print(f"   - {field}: {errors}")
    
    # Test 3: Invalid facility (duplicate license)
    facility_data3 = {
        'name': 'Duplicate License Center',
        'address': '789 Copy St',
        'license_number': 'MED-2024-001',  # Duplicate
        'is_active': True,
    }
    
    form3 = FacilityForm(data=facility_data3)
    if not form3.is_valid():
        print("✅ Duplicate license validation working:")
        for field, errors in form3.errors.items():
            print(f"   - {field}: {errors}")
    else:
        print("❌ Duplicate license should have been rejected")
    
    return facility, facility2 if 'facility2' in locals() else None


def test_user_creation(facilities):
    """Test user creation with validation"""
    print("\n👤 Testing User Creation...")
    
    # Test 1: Valid admin user creation
    user_data = {
        'username': 'admin_test',
        'email': 'admin@testmedical.com',
        'first_name': 'Test',
        'last_name': 'Administrator',
        'password1': 'SecurePass123!',
        'password2': 'SecurePass123!',
        'role': 'admin',
        'phone': '+1 (555) 111-1111',
        'license_number': 'ADMIN-001',
        'specialization': 'System Administration',
    }
    
    form = CustomUserCreationForm(data=user_data)
    if form.is_valid():
        user = form.save()
        print(f"✅ Admin user created successfully: {user.username}")
        print(f"   - Role: {user.get_role_display()}")
        print(f"   - Active: {user.is_active}")
        print(f"   - Verified: {user.is_verified}")
    else:
        print("❌ Admin user creation failed:")
        for field, errors in form.errors.items():
            print(f"   - {field}: {errors}")
    
    # Test 2: Valid radiologist user creation
    user_data2 = {
        'username': 'radiologist_test',
        'email': 'radiologist@testmedical.com',
        'first_name': 'Dr. Sarah',
        'last_name': 'Johnson',
        'password1': 'SecurePass456!',
        'password2': 'SecurePass456!',
        'role': 'radiologist',
        'facility': facilities[0].id if facilities and facilities[0] else None,
        'phone': '+1 (555) 222-2222',
        'license_number': 'RAD-12345',
        'specialization': 'Neuroradiology',
    }
    
    form2 = CustomUserCreationForm(data=user_data2)
    if form2.is_valid():
        user2 = form2.save()
        print(f"✅ Radiologist user created successfully: {user2.username}")
        print(f"   - Role: {user2.get_role_display()}")
        print(f"   - Facility: {user2.facility.name if user2.facility else 'None'}")
        print(f"   - Specialization: {user2.specialization}")
    else:
        print("❌ Radiologist user creation failed:")
        for field, errors in form2.errors.items():
            print(f"   - {field}: {errors}")
    
    # Test 3: Valid facility user creation
    user_data3 = {
        'username': 'facility_test',
        'email': 'facility@testmedical.com',
        'first_name': 'John',
        'last_name': 'Tech',
        'password1': 'SecurePass789!',
        'password2': 'SecurePass789!',
        'role': 'facility',
        'facility': facilities[0].id if facilities and facilities[0] else None,
        'phone': '+1 (555) 333-3333',
    }
    
    form3 = CustomUserCreationForm(data=user_data3)
    if form3.is_valid():
        user3 = form3.save()
        print(f"✅ Facility user created successfully: {user3.username}")
        print(f"   - Role: {user3.get_role_display()}")
        print(f"   - Facility: {user3.facility.name if user3.facility else 'None'}")
    else:
        print("❌ Facility user creation failed:")
        for field, errors in form3.errors.items():
            print(f"   - {field}: {errors}")
    
    # Test 4: Invalid facility user (no facility assigned)
    user_data4 = {
        'username': 'facility_invalid',
        'email': 'invalid@testmedical.com',
        'password1': 'SecurePass000!',
        'password2': 'SecurePass000!',
        'role': 'facility',
        'facility': None,  # Should fail validation
    }
    
    form4 = CustomUserCreationForm(data=user_data4)
    if not form4.is_valid():
        print("✅ Facility user without facility validation working:")
        for field, errors in form4.errors.items():
            print(f"   - {field}: {errors}")
    else:
        print("❌ Facility user without facility should have been rejected")
    
    # Test 5: Invalid user (duplicate username)
    user_data5 = {
        'username': 'admin_test',  # Duplicate
        'email': 'duplicate@testmedical.com',
        'password1': 'SecurePass111!',
        'password2': 'SecurePass111!',
        'role': 'admin',
    }
    
    form5 = CustomUserCreationForm(data=user_data5)
    if not form5.is_valid():
        print("✅ Duplicate username validation working:")
        for field, errors in form5.errors.items():
            print(f"   - {field}: {errors}")
    else:
        print("❌ Duplicate username should have been rejected")
    
    # Test 6: Invalid user (password mismatch)
    user_data6 = {
        'username': 'password_test',
        'email': 'password@testmedical.com',
        'password1': 'SecurePass123!',
        'password2': 'DifferentPass456!',  # Mismatch
        'role': 'admin',
    }
    
    form6 = CustomUserCreationForm(data=user_data6)
    if not form6.is_valid():
        print("✅ Password mismatch validation working:")
        for field, errors in form6.errors.items():
            print(f"   - {field}: {errors}")
    else:
        print("❌ Password mismatch should have been rejected")


def test_facility_with_user_creation():
    """Test facility creation with automatic user creation"""
    print("\n🏥👤 Testing Facility with User Creation...")
    
    facility_data = {
        'name': 'Integrated Medical Center',
        'address': '999 Integration Blvd\nSuite 100\nCity, State 12345',
        'phone': '+1 (555) 999-0000',
        'email': 'info@integrated.com',
        'license_number': 'INTEG-2024-001',
        'is_active': True,
        'create_facility_user': True,
        'facility_username': 'integrated_user',
        'facility_email': 'user@integrated.com',
        'facility_password': 'IntegratedPass123!',
    }
    
    form = FacilityForm(data=facility_data)
    if form.is_valid():
        facility = form.save()
        print(f"✅ Facility created for integrated test: {facility.name}")
        
        # Check if facility user creation data is valid
        if form.cleaned_data.get('create_facility_user'):
            print("   - Facility user creation requested")
            print(f"   - Username: {form.cleaned_data.get('facility_username')}")
            print(f"   - Email: {form.cleaned_data.get('facility_email')}")
    else:
        print("❌ Facility with user creation failed:")
        for field, errors in form.errors.items():
            print(f"   - {field}: {errors}")


def display_current_state():
    """Display current state of users and facilities"""
    print("\n📊 Current Database State:")
    
    print(f"\n🏥 Facilities ({Facility.objects.count()}):")
    for facility in Facility.objects.all():
        print(f"   - {facility.name} (AE: {facility.ae_title}, License: {facility.license_number})")
        users_count = facility.user_set.count()
        print(f"     Users: {users_count}")
    
    print(f"\n👤 Users ({User.objects.count()}):")
    for user in User.objects.all():
        facility_name = user.facility.name if user.facility else "No Facility"
        print(f"   - {user.username} ({user.get_role_display()}) - {facility_name}")
        print(f"     Active: {user.is_active}, Verified: {user.is_verified}")


def cleanup_test_data():
    """Clean up test data"""
    print("\n🧹 Cleaning up test data...")
    
    # Delete test users
    test_users = User.objects.filter(username__contains='test')
    deleted_users = test_users.count()
    test_users.delete()
    
    # Delete test facilities
    test_facilities = Facility.objects.filter(name__contains='Test')
    test_facilities = test_facilities.union(
        Facility.objects.filter(name__contains='Advanced'),
        Facility.objects.filter(name__contains='Duplicate'),
        Facility.objects.filter(name__contains='Integrated')
    )
    deleted_facilities = test_facilities.count()
    test_facilities.delete()
    
    print(f"   - Deleted {deleted_users} test users")
    print(f"   - Deleted {deleted_facilities} test facilities")


def main():
    """Main test function"""
    print("🧪 Starting User and Facility Creation Tests")
    print("=" * 50)
    
    try:
        # Test facility creation
        facilities = test_facility_creation()
        
        # Test user creation
        test_user_creation([facilities[0]] if facilities[0] else [])
        
        # Test integrated facility and user creation
        test_facility_with_user_creation()
        
        # Display current state
        display_current_state()
        
        print("\n✅ All tests completed successfully!")
        
        # Ask for cleanup
        response = input("\n🧹 Would you like to clean up test data? (y/N): ")
        if response.lower() == 'y':
            cleanup_test_data()
            print("✅ Cleanup completed!")
        
    except Exception as e:
        print(f"\n❌ Test failed with error: {str(e)}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    main()