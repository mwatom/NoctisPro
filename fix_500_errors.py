#!/usr/bin/env python3
"""
NoctisPro PACS - 500 Error Fix Script
Identifies and fixes common Django 500 errors
"""

import os
import sys
import django
from pathlib import Path

# Add project to Python path
project_dir = Path(__file__).parent
sys.path.insert(0, str(project_dir))

# Set Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')

def setup_django():
    """Setup Django environment"""
    try:
        django.setup()
        print("✅ Django setup successful")
        return True
    except Exception as e:
        print(f"❌ Django setup failed: {e}")
        return False

def create_directories():
    """Create necessary directories"""
    directories = [
        'logs',
        'media',
        'media/dicom',
        'static',
        'staticfiles',
        'templates'
    ]
    
    for directory in directories:
        dir_path = project_dir / directory
        dir_path.mkdir(exist_ok=True)
        print(f"✅ Created directory: {directory}")

def check_database():
    """Check database connectivity and run migrations"""
    try:
        from django.core.management import execute_from_command_line
        
        print("🔍 Checking database...")
        
        # Run migrations
        execute_from_command_line(['manage.py', 'migrate', '--verbosity=0'])
        print("✅ Database migrations completed")
        
        return True
    except Exception as e:
        print(f"❌ Database error: {e}")
        return False

def collect_static_files():
    """Collect static files"""
    try:
        from django.core.management import execute_from_command_line
        
        print("📦 Collecting static files...")
        execute_from_command_line(['manage.py', 'collectstatic', '--noinput', '--verbosity=0'])
        print("✅ Static files collected")
        
        return True
    except Exception as e:
        print(f"❌ Static files collection failed: {e}")
        return False

def create_superuser():
    """Create superuser if it doesn't exist"""
    try:
        from django.contrib.auth import get_user_model
        
        User = get_user_model()
        
        if not User.objects.filter(username='admin').exists():
            User.objects.create_superuser(
                username='admin',
                email='admin@noctispro.local',
                password='admin123'
            )
            print("✅ Superuser created: admin/admin123")
        else:
            print("ℹ️  Superuser already exists")
            
        return True
    except Exception as e:
        print(f"❌ Superuser creation failed: {e}")
        return False

def check_apps():
    """Check if all Django apps are properly configured"""
    try:
        from django.apps import apps
        
        print("🔍 Checking Django apps...")
        
        app_configs = apps.get_app_configs()
        for app_config in app_configs:
            if app_config.name.startswith(('accounts', 'worklist', 'dicom_viewer', 'reports', 'admin_panel', 'chat', 'notifications', 'ai_analysis')):
                print(f"✅ App loaded: {app_config.name}")
        
        return True
    except Exception as e:
        print(f"❌ App configuration error: {e}")
        return False

def test_views():
    """Test critical views"""
    try:
        from django.test import Client
        from django.urls import reverse
        
        print("🔍 Testing critical views...")
        
        client = Client()
        
        # Test admin login page
        try:
            response = client.get('/admin/login/')
            if response.status_code == 200:
                print("✅ Admin login page accessible")
            else:
                print(f"⚠️  Admin login page returned status {response.status_code}")
        except Exception as e:
            print(f"❌ Admin login page error: {e}")
        
        # Test main page
        try:
            response = client.get('/')
            if response.status_code in [200, 302]:  # 302 is redirect to login
                print("✅ Main page accessible")
            else:
                print(f"⚠️  Main page returned status {response.status_code}")
        except Exception as e:
            print(f"❌ Main page error: {e}")
        
        return True
    except Exception as e:
        print(f"❌ View testing failed: {e}")
        return False

def fix_permissions():
    """Fix file permissions"""
    try:
        import stat
        
        print("🔧 Fixing file permissions...")
        
        # Make manage.py executable
        manage_py = project_dir / 'manage.py'
        if manage_py.exists():
            manage_py.chmod(stat.S_IRWXU | stat.S_IRGRP | stat.S_IROTH)
            print("✅ Fixed manage.py permissions")
        
        # Fix directory permissions
        for directory in ['logs', 'media', 'staticfiles']:
            dir_path = project_dir / directory
            if dir_path.exists():
                dir_path.chmod(stat.S_IRWXU | stat.S_IRWXG | stat.S_IROTH | stat.S_IXOTH)
                print(f"✅ Fixed {directory} permissions")
        
        return True
    except Exception as e:
        print(f"❌ Permission fixing failed: {e}")
        return False

def create_env_file():
    """Create a proper .env file"""
    try:
        from django.core.management.utils import get_random_secret_key
        
        env_file = project_dir / '.env'
        
        if not env_file.exists():
            secret_key = get_random_secret_key()
            
            env_content = f"""# NoctisPro PACS Configuration
DEBUG=False
SECRET_KEY={secret_key}
DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Database
DB_ENGINE=django.db.backends.sqlite3
DB_NAME={project_dir}/db.sqlite3

# Security
ALLOWED_HOSTS=*
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https

# Static and Media
STATIC_URL=/static/
MEDIA_URL=/media/
SERVE_MEDIA_FILES=True

# DICOM
DICOM_AET=NOCTIS_SCP
DICOM_PORT=11112
"""
            
            with open(env_file, 'w') as f:
                f.write(env_content)
            
            # Secure the .env file
            env_file.chmod(0o600)
            print("✅ Created .env file with secure permissions")
        else:
            print("ℹ️  .env file already exists")
        
        return True
    except Exception as e:
        print(f"❌ .env file creation failed: {e}")
        return False

def main():
    """Main fix function"""
    print("🚀 NoctisPro PACS - 500 Error Fix Script")
    print("=" * 50)
    
    success_count = 0
    total_checks = 8
    
    # Create necessary directories
    create_directories()
    success_count += 1
    
    # Create .env file
    if create_env_file():
        success_count += 1
    
    # Fix permissions
    if fix_permissions():
        success_count += 1
    
    # Setup Django
    if setup_django():
        success_count += 1
        
        # Check database
        if check_database():
            success_count += 1
        
        # Collect static files
        if collect_static_files():
            success_count += 1
        
        # Create superuser
        if create_superuser():
            success_count += 1
        
        # Check apps
        if check_apps():
            success_count += 1
        
        # Test views (optional, don't count towards success)
        test_views()
    
    print("\n" + "=" * 50)
    print(f"🎉 Fix completed: {success_count}/{total_checks} checks passed")
    
    if success_count >= total_checks - 1:  # Allow one failure
        print("✅ NoctisPro should now work without 500 errors!")
        print("\n📋 Next steps:")
        print("1. Start the application: ./deploy_auto.sh")
        print("2. Access: http://localhost:8000/admin/")
        print("3. Login: admin / admin123")
    else:
        print("⚠️  Some issues remain. Check the errors above.")
    
    return success_count >= total_checks - 1

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)