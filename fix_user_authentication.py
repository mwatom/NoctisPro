#!/usr/bin/env python3
"""
Fix user authentication issues - ensure users created by admin can login
"""
import os
import sys
import django

# Add the project directory to Python path
sys.path.append('/workspace')

# Set up Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from django.contrib.auth import authenticate
from django.contrib.auth.hashers import make_password, check_password
from accounts.models import User, Facility

def test_user_authentication():
    """Test user authentication and fix issues"""
    print("🔍 Testing User Authentication System")
    print("=" * 50)
    
    # Test admin user
    print("\n1. Testing Admin User:")
    admin_user = User.objects.get(username='admin')
    print(f"   Username: {admin_user.username}")
    print(f"   Role: {admin_user.role}")
    print(f"   Active: {admin_user.is_active}")
    print(f"   Verified: {admin_user.is_verified}")
    print(f"   Has usable password: {admin_user.has_usable_password()}")
    
    # Test admin authentication
    auth_result = authenticate(username='admin', password='admin123')
    print(f"   Authentication test: {'✅ SUCCESS' if auth_result else '❌ FAILED'}")
    
    # Create a test facility user
    print("\n2. Creating Test Facility User:")
    try:
        # Create or get test facility
        facility, created = Facility.objects.get_or_create(
            name='Test Facility',
            defaults={
                'address': 'Test Address',
                'phone': '123-456-7890',
                'email': 'test@facility.com',
                'license_number': 'TEST123',
                'ae_title': 'TEST_FACILITY',
                'is_active': True
            }
        )
        print(f"   Facility: {facility.name} ({'created' if created else 'exists'})")
        
        # Create test facility user
        test_username = 'testfacility'
        test_password = 'test123'
        
        # Delete existing test user if exists
        User.objects.filter(username=test_username).delete()
        
        # Create user using the same method as admin panel
        test_user = User.objects.create_user(
            username=test_username,
            email='test@facility.com',
            password=test_password,
            first_name='Test',
            last_name='User',
            role='facility'
        )
        test_user.facility = facility
        test_user.is_verified = True
        test_user.is_active = True
        test_user.save()
        
        print(f"   Created user: {test_user.username}")
        print(f"   Role: {test_user.role}")
        print(f"   Active: {test_user.is_active}")
        print(f"   Verified: {test_user.is_verified}")
        print(f"   Has usable password: {test_user.has_usable_password()}")
        print(f"   Facility: {test_user.facility.name if test_user.facility else 'None'}")
        
        # Test authentication
        auth_result = authenticate(username=test_username, password=test_password)
        print(f"   Authentication test: {'✅ SUCCESS' if auth_result else '❌ FAILED'}")
        
        if not auth_result:
            print("   🔧 Attempting to fix password...")
            test_user.set_password(test_password)
            test_user.save()
            auth_result = authenticate(username=test_username, password=test_password)
            print(f"   Authentication after fix: {'✅ SUCCESS' if auth_result else '❌ STILL FAILED'}")
            
    except Exception as e:
        print(f"   ❌ Error creating test user: {e}")
    
    # Create a test standalone user
    print("\n3. Creating Test Standalone User:")
    try:
        test_username = 'testuser'
        test_password = 'test123'
        
        # Delete existing test user if exists
        User.objects.filter(username=test_username).delete()
        
        # Create standalone user
        test_user = User.objects.create_user(
            username=test_username,
            email='testuser@example.com',
            password=test_password,
            first_name='Test',
            last_name='Standalone',
            role='radiologist'  # or any role except facility
        )
        test_user.is_verified = True
        test_user.is_active = True
        test_user.save()
        
        print(f"   Created user: {test_user.username}")
        print(f"   Role: {test_user.role}")
        print(f"   Active: {test_user.is_active}")
        print(f"   Verified: {test_user.is_verified}")
        print(f"   Has usable password: {test_user.has_usable_password()}")
        
        # Test authentication
        auth_result = authenticate(username=test_username, password=test_password)
        print(f"   Authentication test: {'✅ SUCCESS' if auth_result else '❌ FAILED'}")
        
        if not auth_result:
            print("   🔧 Attempting to fix password...")
            test_user.set_password(test_password)
            test_user.save()
            auth_result = authenticate(username=test_username, password=test_password)
            print(f"   Authentication after fix: {'✅ SUCCESS' if auth_result else '❌ STILL FAILED'}")
            
    except Exception as e:
        print(f"   ❌ Error creating test standalone user: {e}")
    
    # Check all users and their authentication status
    print("\n4. All Users Summary:")
    print("-" * 30)
    for user in User.objects.all():
        has_password = user.has_usable_password()
        print(f"   {user.username} ({user.role}): Active={user.is_active}, Verified={user.is_verified}, Password={'✅' if has_password else '❌'}")
    
    print("\n" + "=" * 50)
    print("✅ User Authentication Test Complete!")
    print("\nTest Credentials:")
    print("   Admin: admin / admin123")
    print("   Facility User: testfacility / test123") 
    print("   Standalone User: testuser / test123")

if __name__ == '__main__':
    test_user_authentication()