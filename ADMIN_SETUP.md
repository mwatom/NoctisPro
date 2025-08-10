# Admin Panel Access Setup Guide

## Problem
The admin panel button is not visible on the patients overview page because the current user doesn't have admin privileges.

## Solution
The admin panel button visibility is controlled by the user's role in the system. Here are the options available:

### 1. Create an Admin User (Recommended)

Use the built-in management command to create an admin user:

```bash
# Navigate to the project directory
cd /workspace

# Activate virtual environment (if you have one)
source venv/bin/activate

# Create an admin user with default credentials
python manage.py create_admin

# Or create with custom credentials
python manage.py create_admin --username myadmin --email admin@example.com --password mypassword123
```

Default credentials:
- Username: `admin`
- Password: `admin123`
- Email: `admin@noctispro.com`

### 2. Upgrade Existing User to Admin

If you want to make an existing user an admin, you can:

1. **Using Django Shell:**
```bash
python manage.py shell
```

Then run:
```python
from accounts.models import User
user = User.objects.get(username='your_username')
user.role = 'admin'
user.save()
print(f"User {user.username} is now an admin: {user.is_admin()}")
```

2. **Using the create_admin command on existing user:**
```bash
python manage.py create_admin --username existing_username
```

### 3. Understanding User Roles

The system has three user roles:

1. **Administrator (`admin`)**: Full access to admin panel and all features
2. **Radiologist (`radiologist`)**: Limited admin access, can edit reports
3. **Facility User (`facility`)**: Basic access, limited to their facility's data

### 4. Admin Panel Features

Once you have admin access, the admin panel provides:
- User management (create, edit, delete users)
- Facility management
- System configuration
- Audit logs
- Usage statistics

### 5. Visual Indicators

The updated interface now shows:
- Role badges next to user names
- Access level information panel
- Different button options based on user role:
  - **Admin**: "Admin Panel" button
  - **Radiologist**: "Radiologist Panel" button  
  - **Facility**: "Request Admin Access" button

### 6. Security Notes

- Always change default passwords after first login
- The admin panel is protected with `@user_passes_test(is_admin)` decorators
- Radiologists have limited access to certain admin features
- All admin actions should be logged for audit purposes

### 7. Troubleshooting

If you still can't see the admin panel button after following these steps:

1. Verify the user's role:
```python
# In Django shell
user = User.objects.get(username='your_username')
print(f"Role: {user.role}")
print(f"Is Admin: {user.is_admin()}")
```

2. Check if you're logged in with the correct user
3. Clear browser cache and refresh the page
4. Check the Django logs for any errors

## Quick Start

For immediate admin access:

```bash
cd /workspace
python manage.py create_admin
# Login with username: admin, password: admin123
```

Then refresh the dashboard page and you should see the "Admin Panel" button in the quick actions bar.