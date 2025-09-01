#!/usr/bin/env python3
import os
import sys
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
sys.path.insert(0, '/workspace')
django.setup()

from django.contrib.auth import authenticate
from accounts.models import User

# Test authentication
print("Testing authentication...")
user = authenticate(username='admin', password='admin123')
if user:
    print(f"✅ Authentication successful: {user.username}")
    print(f"   Role: {user.role}")
    print(f"   Active: {user.is_active}")
    print(f"   Verified: {user.is_verified}")
    print(f"   Facility: {user.facility}")
else:
    print("❌ Authentication failed")
    
    # Check if user exists
    try:
        db_user = User.objects.get(username='admin')
        print(f"User exists in DB: {db_user.username}")
        print(f"Password check: {db_user.check_password('admin123')}")
    except User.DoesNotExist:
        print("User does not exist in database")