#!/usr/bin/env python
import os
import sys
import django

# Add the project directory to Python path
sys.path.append('/workspace')

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from accounts.models import Facility

def test_facilities():
    print("=== Facility Test ===")
    
    # Get all facilities
    all_facilities = Facility.objects.all()
    print(f"Total facilities in database: {all_facilities.count()}")
    
    for facility in all_facilities:
        print(f"  - ID: {facility.id}, Name: {facility.name}, Active: {facility.is_active}")
    
    # Get active facilities (what the view uses)
    active_facilities = Facility.objects.filter(is_active=True)
    print(f"\nActive facilities (what should appear in dropdown): {active_facilities.count()}")
    
    for facility in active_facilities:
        print(f"  - ID: {facility.id}, Name: {facility.name}")
    
    # Test the view context
    print("\n=== Testing View Context ===")
    from django.test import RequestFactory
    from django.contrib.auth import get_user_model
    from admin_panel.views import user_create
    
    User = get_user_model()
    
    # Create a test admin user
    admin_user, created = User.objects.get_or_create(
        username='test_admin',
        defaults={'role': 'admin', 'is_staff': True, 'is_superuser': True}
    )
    
    # Create a request
    factory = RequestFactory()
    request = factory.get('/admin_panel/users/create/')
    request.user = admin_user
    
    # Test the view
    try:
        from admin_panel.views import user_create
        response = user_create(request)
        print("View executed successfully")
        
        # Check if facilities are in context
        if hasattr(response, 'context_data'):
            facilities_in_context = response.context_data.get('facilities', [])
            print(f"Facilities in view context: {len(facilities_in_context)}")
        else:
            print("Response doesn't have context_data (might be a redirect or different response type)")
            
    except Exception as e:
        print(f"Error testing view: {e}")

if __name__ == '__main__':
    test_facilities()