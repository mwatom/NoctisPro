#!/usr/bin/env python3
"""
NoctisPro Login Fix & Internet Deployment Preparation Script
This script fixes login issues and prepares the system for internet access
"""
import os
import sys
import django
import subprocess
import platform

def setup_django():
    """Setup Django environment"""
    # Add the project root to Python path
    project_root = os.path.dirname(os.path.abspath(__file__))
    sys.path.append(project_root)
    
    # Setup Django
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
    django.setup()

def fix_login_issues():
    """Fix login issues by creating/fixing admin user and verifying all users"""
    from django.contrib.auth import get_user_model
    from accounts.models import User, Facility
    
    print("🔧 Fixing NoctisPro Login Issues...")
    
    # Admin user credentials
    username = 'admin'
    password = 'Admin123!'
    email = 'admin@noctispro.com'
    
    try:
        # Get or create admin user
        user, created = User.objects.get_or_create(
            username=username,
            defaults={
                'email': email,
                'first_name': 'System',
                'last_name': 'Administrator',
                'role': 'admin',
                'is_active': True,
                'is_verified': True,
                'is_staff': True,
                'is_superuser': True
            }
        )
        
        if not created:
            # Update existing user
            user.is_active = True
            user.is_verified = True
            user.role = 'admin'
            user.is_staff = True
            user.is_superuser = True
            user.email = email
        
        user.set_password(password)
        user.save()
        
        action = "Created" if created else "Updated"
        print(f"✅ {action} admin user: {username}")
        
        # Create default facility if none exists
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
        
        # Fix verification for all users
        unverified_users = User.objects.filter(is_verified=False)
        if unverified_users.exists():
            print(f"⚠️  Found {unverified_users.count()} unverified users:")
            for u in unverified_users:
                print(f"   - {u.username} (Active: {u.is_active}, Verified: {u.is_verified})")
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
        
    except Exception as e:
        print(f"❌ Error fixing login: {e}")
        import traceback
        traceback.print_exc()
        return None

def check_database_health():
    """Check database and migrations"""
    print("\n🔍 Checking Database Health...")
    
    try:
        from accounts.models import User, Facility
        user_count = User.objects.count()
        facility_count = Facility.objects.count()
        print(f"✅ Database accessible - Users: {user_count}, Facilities: {facility_count}")
        return True
    except Exception as e:
        print(f"❌ Database error: {e}")
        print("💡 Try running: python manage.py migrate")
        return False

def run_migrations():
    """Run Django migrations"""
    print("\n📊 Running Database Migrations...")
    try:
        from django.core.management import execute_from_command_line
        execute_from_command_line(['manage.py', 'migrate'])
        print("✅ Migrations completed successfully")
        return True
    except Exception as e:
        print(f"❌ Migration error: {e}")
        return False

def collect_static():
    """Collect static files"""
    print("\n📁 Collecting Static Files...")
    try:
        from django.core.management import execute_from_command_line
        execute_from_command_line(['manage.py', 'collectstatic', '--noinput'])
        print("✅ Static files collected successfully")
        return True
    except Exception as e:
        print(f"❌ Static collection error: {e}")
        return False

def create_settings_for_internet():
    """Create production settings for internet deployment"""
    print("\n⚙️  Creating Internet-Ready Settings...")
    
    settings_content = '''"""
Production settings for internet deployment
"""
from .settings import *
import os

# Security settings for internet deployment
DEBUG = False
ALLOWED_HOSTS = ['*']  # Allow all hosts for tunnel access

# CSRF settings for tunnel access
CSRF_TRUSTED_ORIGINS = [
    'https://*.trycloudflare.com',
    'https://*.cloudflare.com',
    'https://*.ngrok.io',
    'https://*.ngrok.app',
]

# Session settings
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SECURE_SSL_REDIRECT = False  # Handle SSL at tunnel level

# Static files for production
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')
STATICFILES_STORAGE = 'django.contrib.staticfiles.storage.StaticFilesStorage'

# Media files
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# Database optimization
DATABASES['default']['OPTIONS'] = {
    'timeout': 30,
}

# Logging
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': 'noctis_pro.log',
        },
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file', 'console'],
            'level': 'INFO',
            'propagate': True,
        },
    },
}
'''
    
    try:
        with open('noctis_pro/settings_internet.py', 'w') as f:
            f.write(settings_content)
        print("✅ Created settings_internet.py for production")
        return True
    except Exception as e:
        print(f"❌ Error creating settings: {e}")
        return False

def main():
    """Main execution function"""
    print("🚀 NoctisPro Login Fix & Internet Deployment Preparation")
    print("=" * 60)
    
    # Setup Django
    try:
        setup_django()
        print("✅ Django environment setup complete")
    except Exception as e:
        print(f"❌ Django setup failed: {e}")
        sys.exit(1)
    
    # Run migrations first
    if not run_migrations():
        print("⚠️  Migrations failed, but continuing...")
    
    # Check database health
    if not check_database_health():
        print("❌ Database health check failed")
        sys.exit(1)
    
    # Fix login issues
    admin_user = fix_login_issues()
    if not admin_user:
        print("❌ Failed to fix login issues")
        sys.exit(1)
    
    # Collect static files
    collect_static()
    
    # Create internet settings
    create_settings_for_internet()
    
    print("\n🎉 Setup Complete!")
    print("\n📋 Next Steps for Internet Access:")
    print("1. Use the Windows PowerShell script: deploy_internet_windows.ps1")
    print("2. Or use the Linux script: deploy_internet_linux.sh")
    print("3. Your system will be accessible via a public HTTPS URL")
    
    print(f"\n🔑 Login Credentials:")
    print(f"   Username: admin")
    print(f"   Password: Admin123!")
    print(f"   Role: Administrator")

if __name__ == "__main__":
    main()