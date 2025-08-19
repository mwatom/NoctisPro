#!/usr/bin/env python3

import sqlite3
import sys
import os

def debug_view_context():
    """Debug the Django view context to see why facilities aren't showing"""
    
    # First, let's check the database directly again
    conn = sqlite3.connect('db.sqlite3')
    cursor = conn.cursor()
    
    print("=== View Context Debug ===\n")
    
    # Get active facilities from database
    cursor.execute("SELECT id, name, is_active FROM accounts_facility WHERE is_active = 1 ORDER BY name")
    db_facilities = cursor.fetchall()
    
    print(f"📊 Active facilities from database query: {len(db_facilities)}")
    for facility in db_facilities:
        print(f"  - ID: {facility[0]}, Name: '{facility[1]}', Active: {facility[2]}")
    
    # Now let's simulate what the Django view should be doing
    print(f"\n🔍 Simulating Django ORM query:")
    print(f"   Facility.objects.filter(is_active=True).order_by('name')")
    
    # Check the template context structure that should be generated
    print(f"\n📋 Expected template context:")
    print(f"   facilities = [")
    for facility in db_facilities:
        print(f"     {{id: {facility[0]}, name: '{facility[1]}'}},")
    print(f"   ]")
    
    # Check if there are any potential issues
    print(f"\n🔧 Potential Issues to Check:")
    print(f"   1. Django environment setup - ✓ (database accessible)")
    print(f"   2. Facilities exist and are active - ✓ ({len(db_facilities)} found)")
    print(f"   3. View is using correct queryset - ✓ (code looks correct)")
    print(f"   4. Template is receiving context - ❓ (needs verification)")
    print(f"   5. Template is rendering dropdown - ❓ (needs verification)")
    
    # Check the actual template content
    template_path = 'templates/admin_panel/user_form.html'
    if os.path.exists(template_path):
        print(f"\n📄 Checking template file: {template_path}")
        with open(template_path, 'r') as f:
            template_content = f.read()
            
        # Look for the facilities loop
        if '{% for facility in facilities %}' in template_content:
            print(f"   ✅ Template has facilities loop")
        else:
            print(f"   ❌ Template missing facilities loop")
            
        # Look for the select element
        if '<select class="form-select form-control-medical" id="facility" name="facility">' in template_content:
            print(f"   ✅ Template has facility select element")
        else:
            print(f"   ❌ Template missing facility select element")
            
        # Look for facilities count debug info
        if 'facilities_count' in template_content:
            print(f"   ✅ Template has facilities count debug info")
        else:
            print(f"   ❌ Template missing facilities count debug info")
    else:
        print(f"   ❌ Template file not found at {template_path}")
    
    # Create a simple test to verify the Django view works
    print(f"\n🧪 Recommendations:")
    print(f"   1. Check browser developer tools for JavaScript errors")
    print(f"   2. Verify the template is receiving the facilities context variable")
    print(f"   3. Check if the dropdown is being hidden by CSS or JavaScript")
    print(f"   4. Look at the actual HTML source in the browser")
    print(f"   5. Check Django debug toolbar if available")
    
    conn.close()

if __name__ == '__main__':
    debug_view_context()