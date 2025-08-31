"""
Professional Admin-Only Security Decorators
Ensures strict admin-only access to user management functions
"""

from django.contrib.auth.decorators import user_passes_test
from django.shortcuts import redirect
from django.contrib import messages
from functools import wraps

def admin_only_strict(view_func):
    """
    Decorator that ensures ONLY admin users can access the view.
    Provides clear error messages and redirects non-admin users.
    """
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        if not request.user.is_authenticated:
            messages.error(request, 'Authentication required. Please log in.')
            return redirect('accounts:login')
        
        if not hasattr(request.user, 'role') or request.user.role != 'admin':
            messages.error(request, 'UNAUTHORIZED ACCESS: Only administrators can perform this action.')
            return redirect('worklist:dashboard')
        
        if not request.user.is_verified:
            messages.error(request, 'Account not verified. Contact system administrator.')
            return redirect('worklist:dashboard')
        
        if not request.user.is_active:
            messages.error(request, 'Account is inactive. Contact system administrator.')
            return redirect('accounts:login')
        
        return view_func(request, *args, **kwargs)
    
    return wrapper

def admin_only_api(view_func):
    """
    Decorator for API endpoints that ensures ONLY admin users can access.
    Returns JSON error responses for unauthorized access.
    """
    from django.http import JsonResponse
    
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        if not request.user.is_authenticated:
            return JsonResponse({
                'error': 'Authentication required',
                'code': 'AUTH_REQUIRED'
            }, status=401)
        
        if not hasattr(request.user, 'role') or request.user.role != 'admin':
            return JsonResponse({
                'error': 'UNAUTHORIZED: Only administrators can perform this action',
                'code': 'ADMIN_ONLY',
                'user_role': getattr(request.user, 'role', 'unknown')
            }, status=403)
        
        if not request.user.is_verified:
            return JsonResponse({
                'error': 'Account not verified',
                'code': 'NOT_VERIFIED'
            }, status=403)
        
        if not request.user.is_active:
            return JsonResponse({
                'error': 'Account is inactive',
                'code': 'INACTIVE'
            }, status=403)
        
        return view_func(request, *args, **kwargs)
    
    return wrapper

def check_admin_privileges(user):
    """
    Comprehensive admin privilege check
    Returns tuple (is_admin, error_message)
    """
    if not user.is_authenticated:
        return False, "User not authenticated"
    
    if not hasattr(user, 'role'):
        return False, "User role not defined"
    
    if user.role != 'admin':
        return False, f"User role '{user.role}' is not admin"
    
    if not user.is_verified:
        return False, "Admin account not verified"
    
    if not user.is_active:
        return False, "Admin account is inactive"
    
    return True, "Admin privileges confirmed"

def log_admin_action(user, action, target=None, details=None):
    """
    Log admin actions for audit trail
    """
    try:
        from .models import AuditLog
        
        description = f"Admin {user.username} performed {action}"
        if target:
            description += f" on {target}"
        if details:
            description += f" - {details}"
        
        AuditLog.objects.create(
            user=user,
            action=action,
            model_name=target.__class__.__name__ if target else 'System',
            object_id=str(target.id) if target and hasattr(target, 'id') else '',
            object_repr=str(target) if target else '',
            description=description
        )
    except Exception as e:
        # Don't fail the main operation if logging fails
        print(f"Warning: Failed to log admin action: {e}")

# Convenience function for template usage
def user_is_admin(user):
    """Template-friendly admin check"""
    is_admin, _ = check_admin_privileges(user)
    return is_admin