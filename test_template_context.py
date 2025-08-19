#!/usr/bin/env python3

import sqlite3

def test_template_context():
    """Test what the template context should contain"""
    
    print("=== Template Context Test ===\n")
    
    # Connect to database
    conn = sqlite3.connect('db.sqlite3')
    cursor = conn.cursor()
    
    # Get active facilities (same query as in the view)
    cursor.execute("SELECT id, name FROM accounts_facility WHERE is_active = 1 ORDER BY name")
    facilities = cursor.fetchall()
    
    print(f"📊 Template Context Data:")
    print(f"   facilities_count: {len(facilities)}")
    print(f"   facilities: [")
    for facility in facilities:
        print(f"     {{id: {facility[0]}, name: '{facility[1]}'}},")
    print(f"   ]")
    
    # Generate expected HTML output
    print(f"\n🔍 Expected HTML Output:")
    print(f'<select class="form-select form-control-medical" id="facility" name="facility">')
    print(f'  <option value="">-- No Facility Assignment --</option>')
    for facility in facilities:
        print(f'  <option value="{facility[0]}">{facility[1]}</option>')
    print(f'</select>')
    
    # Generate facility count display
    if facilities:
        count = len(facilities)
        plural = "ies" if count != 1 else "y"
        print(f'\n<div class="form-text text-info mt-1">')
        print(f'  <small><i class="fas fa-info-circle me-1"></i>{count} active facilit{plural} available</small>')
        print(f'</div>')
    else:
        print(f'\n<div class="form-text text-warning mt-1">')
        print(f'  <small><i class="fas fa-exclamation-triangle me-1"></i>No active facilities found. Please <a href="/admin_panel/facilities/create/" class="text-warning">add facilities first</a>.</small>')
        print(f'</div>')
    
    conn.close()
    
    print(f"\n✅ If facilities are still not showing in the browser:")
    print(f"   1. Check browser developer console for JavaScript errors")
    print(f"   2. Clear browser cache and hard refresh (Ctrl+Shift+R)")
    print(f"   3. Check if Django is running in debug mode")
    print(f"   4. Verify the Django view is actually being called")
    print(f"   5. Check if there are any template caching issues")

if __name__ == '__main__':
    test_template_context()