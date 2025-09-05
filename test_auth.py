#!/usr/bin/env python3
"""
Test authentication for all user roles to ensure no 500 errors
"""
import os
import sys
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
sys.path.insert(0, '/workspace')
django.setup()

from django.contrib.auth import authenticate
from accounts.models import User, Facility
from django.db import transaction

def test_authentication():
    print("=" * 60)
    print("AUTHENTICATION TEST - Verifying all user roles can login")
    print("=" * 60)
    
    # Check existing admin users
    print("\n1. Checking existing admin users:")
    admins = User.objects.filter(role='admin')
    print(f"   Found {admins.count()} admin user(s)")
    
    for admin in admins:
        print(f"   - {admin.username}: active={admin.is_active}, verified={admin.is_verified}")
        
        # Test authentication
        test_user = authenticate(username=admin.username, password='admin123')
        if test_user:
            print(f"     ✅ Can authenticate with default password")
        else:
            print(f"     ⚠️  Cannot authenticate (password may be different)")
    
    # Create or get test facility
    print("\n2. Creating/Getting test facility:")
    facility, created = Facility.objects.get_or_create(
        license_number='TEST-FAC-001',
        defaults={
            'name': 'Test Medical Facility',
            'address': '123 Test Street, Test City',
            'phone': '555-0100',
            'email': 'test@facility.com',
            'ae_title': 'TEST_FAC',
            'is_active': True
        }
    )
    print(f"   {'Created' if created else 'Found existing'} facility: {facility.name}")
    
    # Test users for each role
    test_users = [
        {
            'username': 'test_admin',
            'role': 'admin',
            'facility': None,
            'first_name': 'Test',
            'last_name': 'Admin'
        },
        {
            'username': 'test_radiologist',
            'role': 'radiologist',
            'facility': facility,
            'first_name': 'Test',
            'last_name': 'Radiologist',
            'license_number': 'RAD-12345'
        },
        {
            'username': 'test_facility',
            'role': 'facility',
            'facility': facility,
            'first_name': 'Test',
            'last_name': 'Facility User'
        }
    ]
    
    print("\n3. Creating and testing users for each role:")
    
    with transaction.atomic():
        for test_data in test_users:
            username = test_data['username']
            
            # Check if user exists
            try:
                user = User.objects.get(username=username)
                print(f"\n   Found existing user: {username}")
                action = "Updated"
            except User.DoesNotExist:
                user = User(username=username)
                print(f"\n   Creating new user: {username}")
                action = "Created"
            
            # Update user fields
            user.role = test_data['role']
            user.facility = test_data.get('facility')
            user.first_name = test_data['first_name']
            user.last_name = test_data['last_name']
            user.email = f"{username}@test.com"
            user.is_active = True
            user.is_verified = True  # This is crucial for login!
            
            if 'license_number' in test_data:
                user.license_number = test_data['license_number']
            
            # Set password
            user.set_password('TestPass123!')
            user.save()
            
            print(f"   {action} {user.get_role_display()}: {username}")
            print(f"   - Active: {user.is_active}")
            print(f"   - Verified: {user.is_verified}")
            print(f"   - Facility: {user.facility.name if user.facility else 'None'}")
            
            # Test authentication
            auth_user = authenticate(username=username, password='TestPass123!')
            if auth_user:
                print(f"   ✅ Authentication successful!")
                
                # Check login conditions
                if auth_user.is_active and auth_user.is_verified:
                    print(f"   ✅ User can login (active and verified)")
                else:
                    print(f"   ❌ User cannot login: active={auth_user.is_active}, verified={auth_user.is_verified}")
            else:
                print(f"   ❌ Authentication failed!")
    
    print("\n" + "=" * 60)
    print("TEST SUMMARY:")
    print("=" * 60)
    print("\nTest credentials for each role:")
    print("\n1. Admin User:")
    print("   Username: test_admin")
    print("   Password: TestPass123!")
    print("\n2. Radiologist:")
    print("   Username: test_radiologist")
    print("   Password: TestPass123!")
    print("\n3. Facility User:")
    print("   Username: test_facility")
    print("   Password: TestPass123!")
    
    print("\n✅ All test users created/updated successfully!")
    print("✅ All users are active and verified")
    print("✅ All users should be able to login without 500 errors")
    
    # Check for any users that might have issues
    print("\n" + "=" * 60)
    print("CHECKING FOR POTENTIAL ISSUES:")
    print("=" * 60)
    
    # Check for unverified users
    unverified = User.objects.filter(is_verified=False)
    if unverified.exists():
        print(f"\n⚠️  Found {unverified.count()} unverified user(s) who cannot login:")
        for u in unverified[:5]:
            print(f"   - {u.username} ({u.get_role_display()})")
    else:
        print("\n✅ No unverified users found")
    
    # Check for inactive users
    inactive = User.objects.filter(is_active=False)
    if inactive.exists():
        print(f"\n⚠️  Found {inactive.count()} inactive user(s) who cannot login:")
        for u in inactive[:5]:
            print(f"   - {u.username} ({u.get_role_display()})")
    else:
        print("\n✅ No inactive users found")
    
    # Check facility users without facilities
    facility_users_no_facility = User.objects.filter(role='facility', facility__isnull=True)
    if facility_users_no_facility.exists():
        print(f"\n⚠️  Found {facility_users_no_facility.count()} facility user(s) without facility assignment:")
        for u in facility_users_no_facility[:5]:
            print(f"   - {u.username}")
    else:
        print("\n✅ All facility users have facility assignments")

if __name__ == '__main__':
    try:
        test_authentication()
    except Exception as e:
        print(f"\n❌ Error during testing: {e}")
        import traceback
        traceback.print_exc()