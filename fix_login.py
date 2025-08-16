#!/usr/bin/env python
"""
Script to fix login issues by creating a properly verified admin user
"""
import os
import sys
import django

# Add the project root to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from django.contrib.auth import get_user_model
from accounts.models import User, Facility

def fix_login_issues():
    """Fix common login issues"""
    print("🔧 Fixing NoctisPro Login Issues...")
    
    # 1. Create or fix admin user
    username = 'admin'
    password = 'Admin123!'
    email = 'admin@noctispro.com'
    
    try:
        # Try to get existing user
        user = User.objects.get(username=username)
        print(f"✅ Found existing user: {username}")
        
        # Fix verification status
        user.is_active = True
        user.is_verified = True
        user.role = 'admin'
        user.is_staff = True
        user.is_superuser = True
        user.set_password(password)
        user.save()
        
        print(f"✅ Fixed user verification: Active={user.is_active}, Verified={user.is_verified}")
        
    except User.DoesNotExist:
        # Create new admin user
        user = User.objects.create_user(
            username=username,
            email=email,
            password=password,
            first_name='System',
            last_name='Administrator',
            role='admin',
            is_active=True,
            is_verified=True,
            is_staff=True,
            is_superuser=True
        )
        print(f"✅ Created new admin user: {username}")
    
    # 2. Create default facility if none exists
    if not Facility.objects.exists():
        facility = Facility.objects.create(
            name='Default Medical Center',
            address='123 Healthcare Ave, Medical City',
            phone='+1-555-0123',
            email='contact@medicalcenter.com',
            license_number='MC-2024-001',
            ae_title='NOCTISPRO',
            is_active=True
        )
        print(f"✅ Created default facility: {facility.name}")
        
        # Assign facility to admin user
        user.facility = facility
        user.save()
        print(f"✅ Assigned facility to admin user")
    
    # 3. Verify all users have correct status
    unverified_users = User.objects.filter(is_verified=False)
    if unverified_users.exists():
        print(f"⚠️  Found {unverified_users.count()} unverified users:")
        for u in unverified_users:
            print(f"   - {u.username} (Active: {u.is_active}, Verified: {u.is_verified})")
            # Fix verification for all users
            u.is_verified = True
            u.is_active = True
            u.save()
            print(f"   ✅ Fixed verification for {u.username}")
    
    print("\n🎉 Login Issues Fixed!")
    print(f"   Username: {username}")
    print(f"   Password: {password}")
    print(f"   Email: {email}")
    print(f"   Role: admin")
    print(f"   Verified: ✅")
    print(f"   Active: ✅")
    
    return user

def check_database_health():
    """Check database and migrations"""
    print("\n🔍 Checking Database Health...")
    
    # Check if tables exist
    try:
        user_count = User.objects.count()
        facility_count = Facility.objects.count()
        print(f"✅ Database accessible - Users: {user_count}, Facilities: {facility_count}")
    except Exception as e:
        print(f"❌ Database error: {e}")
        print("💡 Try running: python manage.py migrate")
        return False
    
    return True

if __name__ == "__main__":
    print("🚀 NoctisPro Login Repair Tool")
    print("=" * 50)
    
    # Check database first
    if not check_database_health():
        sys.exit(1)
    
    # Fix login issues
    try:
        admin_user = fix_login_issues()
        print("\n✅ All fixes applied successfully!")
        print("\n🌐 You can now login at: http://localhost:8000/login/")
        
    except Exception as e:
        print(f"❌ Error during fix: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)