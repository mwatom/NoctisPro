#!/usr/bin/env python
"""
Emergency Admin User Fix Script
Run this with: python manage.py shell < fix_admin_user.py
"""

from django.contrib.auth import get_user_model

User = get_user_model()

# Check if admin user exists
if not User.objects.filter(username='admin').exists():
    # Create admin user
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
    print('✅ Admin user created successfully!')
    print('   Username: admin')
    print('   Email: admin@noctispro.com') 
    print('   Password: admin123')
else:
    print('✅ Admin user already exists')
    admin_user = User.objects.get(username='admin')
    print(f'   Username: {admin_user.username}')
    print(f'   Email: {admin_user.email}')
    print('   Password: admin123 (if unchanged)')

print('')
print('🎉 Admin user setup complete!')
print('You can now login at: http://localhost:8000/admin/')