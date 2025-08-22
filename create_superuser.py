#!/usr/bin/env python3
"""
Script to create a Django superuser automatically
"""
import os
import django
from django.contrib.auth import get_user_model
from django.core.management import execute_from_command_line

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings_production')
django.setup()

User = get_user_model()

def create_superuser():
    """Create a superuser if one doesn't exist"""
    if not User.objects.filter(is_superuser=True).exists():
        User.objects.create_superuser(
            username='admin',
            email='admin@noctis.local',
            password='admin123'  # Change this in production
        )
        print("✅ Superuser created:")
        print("   Username: admin")
        print("   Password: admin123")
        print("   ⚠️  Please change the password after first login!")
    else:
        print("✅ Superuser already exists")

if __name__ == '__main__':
    create_superuser()