#!/usr/bin/env python
import os
import sys
import django

# Add the project directory to Python path
sys.path.append('/workspace')

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from django.template import Context, Template
from accounts.models import Facility, User

def test_template_rendering():
    print("=== Template Rendering Test ===")
    
    # Get active facilities
    facilities = Facility.objects.filter(is_active=True)
    print(f"Active facilities: {facilities.count()}")
    
    # Create a simple template similar to the user form
    template_content = """
    <select id="facility" name="facility">
        <option value="">-- No Facility Assignment --</option>
        {% for facility in facilities %}
        <option value="{{ facility.id }}">{{ facility.name }}</option>
        {% endfor %}
    </select>
    """
    
    template = Template(template_content)
    context = Context({
        'facilities': facilities,
        'user_roles': User.USER_ROLES,
    })
    
    rendered = template.render(context)
    print("Rendered template:")
    print(rendered)
    
    # Count options in rendered template
    import re
    options = re.findall(r'<option value="(\d+)"', rendered)
    print(f"\nFound {len(options)} facility options in rendered template")
    for option in options:
        facility = facilities.get(id=int(option))
        print(f"  - Option ID: {option}, Name: {facility.name}")

if __name__ == '__main__':
    test_template_rendering()