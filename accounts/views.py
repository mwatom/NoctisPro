from django.shortcuts import render, redirect
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.utils import timezone
from django.contrib.auth.forms import AuthenticationForm
from .models import User, UserSession, Facility
import json
import time

def login_view(request):
    """Custom login view with enhanced security tracking"""
    if request.user.is_authenticated:
        return redirect('worklist:dashboard')
    
    # Always clear any existing messages to prevent admin messages from showing
    # This ensures no success/info messages from admin operations appear on login
    storage = messages.get_messages(request)
    if storage:
        # Clear all messages completely
        list(storage)
        storage.used = True
    
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        
        user = authenticate(request, username=username, password=password)
        if user and user.is_active and user.is_verified:
            # Track login session
            login(request, user)
            
            # Get client information
            user_agent = request.META.get('HTTP_USER_AGENT', '')
            ip_address = get_client_ip(request)
            
            # Update user login tracking
            user.last_login_ip = ip_address
            user.save()
            
            # Create session record
            UserSession.objects.create(
                user=user,
                session_key=request.session.session_key,
                ip_address=ip_address,
                user_agent=user_agent
            )
            
            # Redirect all users to the worklist dashboard after login
            return redirect('worklist:dashboard')
        else:
            # Clear any existing messages before adding error
            list(messages.get_messages(request))
            # Only show a single generic error for any failure
            messages.error(request, 'Invalid username or password')
    
    return render(request, 'accounts/login.html', {'hide_navbar': True})

@login_required
def logout_view(request):
    """Custom logout view with session cleanup"""
    try:
        # Update session record
        session = UserSession.objects.get(
            user=request.user,
            session_key=request.session.session_key,
            is_active=True
        )
        session.logout_time = timezone.now()
        session.is_active = False
        session.save()
    except UserSession.DoesNotExist:
        pass
    
    logout(request)
    # Do not show any success/info messages on the login page
    return redirect('accounts:login')

@login_required
def profile_view(request):
    """User profile view and update"""
    user = request.user
    
    if request.method == 'POST':
        # Update profile information
        user.first_name = request.POST.get('first_name', user.first_name)
        user.last_name = request.POST.get('last_name', user.last_name)
        user.email = request.POST.get('email', user.email)
        user.phone = request.POST.get('phone', user.phone)
        user.specialization = request.POST.get('specialization', user.specialization)
        user.save()
        
        messages.success(request, 'Profile updated successfully.')
        return redirect('accounts:profile')
    
    context = {
        'user': user,
        'recent_sessions': UserSession.objects.filter(user=user).order_by('-login_time')[:10]
    }
    return render(request, 'accounts/profile.html', context)

@csrf_exempt
def check_session(request):
    """AJAX endpoint to check if user session is still valid"""
    if request.user.is_authenticated:
        return JsonResponse({
            'authenticated': True,
            'user': {
                'id': request.user.id,
                'username': request.user.username,
                'role': request.user.role,
                'facility': request.user.facility.name if request.user.facility else None
            }
        })
    return JsonResponse({'authenticated': False})

def get_client_ip(request):
    """Get client IP address from request"""
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip

@login_required
def change_password(request):
    """Change user password"""
    if request.method == 'POST':
        current_password = request.POST.get('current_password')
        new_password = request.POST.get('new_password')
        confirm_password = request.POST.get('confirm_password')
        
        if not request.user.check_password(current_password):
            messages.error(request, 'Current password is incorrect.')
            return redirect('accounts:profile')
        
        if new_password != confirm_password:
            messages.error(request, 'New passwords do not match.')
            return redirect('accounts:profile')
        
        if len(new_password) < 8:
            messages.error(request, 'Password must be at least 8 characters long.')
            return redirect('accounts:profile')
        
        request.user.set_password(new_password)
        request.user.save()
        
        # Re-authenticate user to maintain session
        user = authenticate(request, username=request.user.username, password=new_password)
        if user:
            login(request, user)
        
        messages.success(request, 'Password changed successfully.')
        return redirect('accounts:profile')
    
    return redirect('accounts:profile')

def user_api_info(request):
    """API endpoint for user information"""
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Not authenticated'}, status=401)
    
    user = request.user
    return JsonResponse({
        'id': user.id,
        'username': user.username,
        'full_name': f"{user.first_name} {user.last_name}",
        'email': user.email,
        'role': user.role,
        'facility': {
            'id': user.facility.id,
            'name': user.facility.name
        } if user.facility else None,
        'permissions': {
            'can_edit_reports': user.can_edit_reports(),
            'can_manage_users': user.can_manage_users(),
            'is_admin': user.is_admin(),
            'is_radiologist': user.is_radiologist(),
            'is_facility_user': user.is_facility_user(),
        }
    })


@login_required
@csrf_exempt
@require_http_methods(["POST"])
def session_extend(request):
    """Extend user session - reset the timeout timer"""
    try:
        # Update last activity time
        request.session['last_activity'] = time.time()
        request.session.modified = True
        
        return JsonResponse({
            'success': True,
            'message': 'Session extended successfully'
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=500)


@login_required
@csrf_exempt
@require_http_methods(["POST"])
def session_keep_alive(request):
    """Keep session alive during user activity"""
    try:
        # Update last activity time
        request.session['last_activity'] = time.time()
        request.session.modified = True
        
        return JsonResponse({
            'success': True,
            'status': 'active'
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=500)


@login_required
def session_status(request):
    """Get current session status and remaining time"""
    try:
        from django.conf import settings
        
        timeout_seconds = getattr(settings, 'SESSION_COOKIE_AGE', 1800)
        last_activity = request.session.get('last_activity', time.time())
        current_time = time.time()
        
        time_since_activity = current_time - last_activity
        remaining_time = max(0, timeout_seconds - time_since_activity)
        
        return JsonResponse({
            'authenticated': True,
            'remaining_time': int(remaining_time),
            'timeout_seconds': timeout_seconds,
            'warning_threshold': getattr(settings, 'SESSION_TIMEOUT_WARNING', 300)
        })
    except Exception as e:
        return JsonResponse({
            'authenticated': False,
            'error': str(e)
        }, status=500)
