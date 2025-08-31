from django.shortcuts import render, redirect
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.utils import timezone
from django.contrib.auth.forms import AuthenticationForm
from django.db import transaction
from .models import User, UserSession, Facility
import json
import time
import logging

logger = logging.getLogger(__name__)

def login_view(request):
    """Professional login view with enhanced security and UX"""
    if request.user.is_authenticated:
        return redirect('worklist:dashboard')
    
    # Clear any existing messages to prevent admin messages from showing
    storage = messages.get_messages(request)
    if storage:
        list(storage)
        storage.used = True
    
    if request.method == 'POST':
        username = request.POST.get('username', '').strip()
        password = request.POST.get('password', '')
        
        # Input validation
        if not username or len(username) < 3:
            messages.error(request, 'Username must be at least 3 characters long.')
            return render(request, 'accounts/login.html', {'hide_navbar': True})
        
        if not password or len(password) < 3:
            messages.error(request, 'Invalid credentials provided.')
            return render(request, 'accounts/login.html', {'hide_navbar': True})
        
        # Authenticate user
        user = authenticate(request, username=username, password=password)
        
        if user is not None:
            if not user.is_active:
                messages.error(request, 'Your account has been deactivated. Please contact administrator.')
                logger.warning(f"Inactive user login attempt: {username}")
                return render(request, 'accounts/login.html', {'hide_navbar': True})
            
            if not user.is_verified:
                messages.error(request, 'Your account is pending verification. Please contact administrator.')
                logger.warning(f"Unverified user login attempt: {username}")
                return render(request, 'accounts/login.html', {'hide_navbar': True})
            
            # Successful authentication - proceed with login
            try:
                with transaction.atomic():
                    # Login user
                    login(request, user)
                    
                    # Get client information
                    user_agent = request.META.get('HTTP_USER_AGENT', '')[:500]  # Limit length
                    ip_address = get_client_ip(request)
                    
                    # Update user login tracking
                    user.last_login_ip = ip_address
                    user.last_login = timezone.now()
                    user.save(update_fields=['last_login_ip', 'last_login'])
                    
                    # Deactivate any existing sessions for this user
                    UserSession.objects.filter(user=user, is_active=True).update(
                        is_active=False,
                        logout_time=timezone.now()
                    )
                    
                    # Create new session record
                    UserSession.objects.create(
                        user=user,
                        session_key=request.session.session_key,
                        ip_address=ip_address,
                        user_agent=user_agent
                    )
                    
                    # Set session timeout
                    request.session['last_activity'] = time.time()
                    request.session.set_expiry(600)  # 10 minutes
                    
                    logger.info(f"Successful login: {username} from {ip_address}")
                    
                    # Redirect to dashboard
                    return redirect('worklist:dashboard')
                    
            except Exception as e:
                logger.error(f"Login session creation error for {username}: {str(e)}")
                messages.error(request, 'Login failed due to system error. Please try again.')
                return render(request, 'accounts/login.html', {'hide_navbar': True})
        else:
            # Authentication failed
            logger.warning(f"Failed login attempt: {username} from {get_client_ip(request)}")
            messages.error(request, 'Invalid username or password.')
    
    return render(request, 'accounts/login.html', {'hide_navbar': True})

@login_required
def logout_view(request):
    """Professional logout view with proper session cleanup"""
    try:
        with transaction.atomic():
            # Update session record
            session = UserSession.objects.filter(
                user=request.user,
                session_key=request.session.session_key,
                is_active=True
            ).first()
            
            if session:
                session.logout_time = timezone.now()
                session.is_active = False
                session.save(update_fields=['logout_time', 'is_active'])
            
            logger.info(f"User logout: {request.user.username}")
            
    except Exception as e:
        logger.error(f"Logout session cleanup error: {str(e)}")
    
    logout(request)
    return redirect('accounts:login')

@login_required
def profile_view(request):
    """User profile view and update"""
    user = request.user
    
    if request.method == 'POST':
        try:
            with transaction.atomic():
                # Update profile information
                user.first_name = request.POST.get('first_name', '').strip()
                user.last_name = request.POST.get('last_name', '').strip()
                user.email = request.POST.get('email', '').strip()
                user.phone = request.POST.get('phone', '').strip()
                user.specialization = request.POST.get('specialization', '').strip()
                
                # Validate email if provided
                if user.email:
                    from django.core.validators import validate_email
                    from django.core.exceptions import ValidationError
                    try:
                        validate_email(user.email)
                    except ValidationError:
                        messages.error(request, 'Please enter a valid email address.')
                        return redirect('accounts:profile')
                
                user.save()
                messages.success(request, 'Profile updated successfully.')
                logger.info(f"Profile updated: {user.username}")
                
        except Exception as e:
            logger.error(f"Profile update error for {user.username}: {str(e)}")
            messages.error(request, 'Failed to update profile. Please try again.')
        
        return redirect('accounts:profile')
    
    # Get recent sessions for security display
    recent_sessions = UserSession.objects.filter(
        user=user
    ).order_by('-login_time')[:10]
    
    context = {
        'user': user,
        'recent_sessions': recent_sessions
    }
    return render(request, 'accounts/profile.html', context)

@csrf_exempt
@require_http_methods(["GET"])
def check_session(request):
    """AJAX endpoint to check if user session is still valid"""
    if not request.user.is_authenticated:
        return JsonResponse({'authenticated': False})
    
    try:
        # Check if session is still valid
        last_activity = request.session.get('last_activity', 0)
        current_time = time.time()
        session_timeout = 600  # 10 minutes
        
        if current_time - last_activity > session_timeout:
            return JsonResponse({'authenticated': False, 'reason': 'session_expired'})
        
        return JsonResponse({
            'authenticated': True,
            'user': {
                'id': request.user.id,
                'username': request.user.username,
                'full_name': f"{request.user.first_name} {request.user.last_name}".strip(),
                'role': request.user.role,
                'facility': request.user.facility.name if request.user.facility else None
            },
            'remaining_time': int(session_timeout - (current_time - last_activity))
        })
    except Exception as e:
        logger.error(f"Session check error: {str(e)}")
        return JsonResponse({'authenticated': False, 'reason': 'error'})

def get_client_ip(request):
    """Get client IP address from request with proper proxy handling"""
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        # Take the first IP in the chain
        ip = x_forwarded_for.split(',')[0].strip()
    else:
        ip = request.META.get('REMOTE_ADDR', 'unknown')
    return ip

@login_required
def change_password(request):
    """Change user password with proper validation"""
    if request.method == 'POST':
        try:
            current_password = request.POST.get('current_password', '')
            new_password = request.POST.get('new_password', '')
            confirm_password = request.POST.get('confirm_password', '')
            
            # Validate current password
            if not request.user.check_password(current_password):
                messages.error(request, 'Current password is incorrect.')
                return redirect('accounts:profile')
            
            # Validate new password
            if new_password != confirm_password:
                messages.error(request, 'New passwords do not match.')
                return redirect('accounts:profile')
            
            if len(new_password) < 8:
                messages.error(request, 'Password must be at least 8 characters long.')
                return redirect('accounts:profile')
            
            # Check password complexity
            if not any(c.isupper() for c in new_password):
                messages.error(request, 'Password must contain at least one uppercase letter.')
                return redirect('accounts:profile')
            
            if not any(c.islower() for c in new_password):
                messages.error(request, 'Password must contain at least one lowercase letter.')
                return redirect('accounts:profile')
            
            if not any(c.isdigit() for c in new_password):
                messages.error(request, 'Password must contain at least one number.')
                return redirect('accounts:profile')
            
            with transaction.atomic():
                # Set new password
                request.user.set_password(new_password)
                request.user.save()
                
                # Re-authenticate user to maintain session
                user = authenticate(request, username=request.user.username, password=new_password)
                if user:
                    login(request, user)
                
                # Invalidate all other sessions
                UserSession.objects.filter(user=request.user).exclude(
                    session_key=request.session.session_key
                ).update(is_active=False, logout_time=timezone.now())
                
                logger.info(f"Password changed: {request.user.username}")
                messages.success(request, 'Password changed successfully. All other sessions have been logged out.')
                
        except Exception as e:
            logger.error(f"Password change error for {request.user.username}: {str(e)}")
            messages.error(request, 'Failed to change password. Please try again.')
        
        return redirect('accounts:profile')
    
    return redirect('accounts:profile')

@login_required
@require_http_methods(["GET"])
def user_api_info(request):
    """API endpoint for user information"""
    try:
        user = request.user
        return JsonResponse({
            'id': user.id,
            'username': user.username,
            'full_name': f"{user.first_name} {user.last_name}".strip(),
            'email': user.email,
            'role': user.role,
            'role_display': user.get_role_display(),
            'facility': {
                'id': user.facility.id,
                'name': user.facility.name,
                'ae_title': user.facility.ae_title
            } if user.facility else None,
            'permissions': {
                'can_edit_reports': user.can_edit_reports(),
                'can_manage_users': user.can_manage_users(),
                'is_admin': user.is_admin(),
                'is_radiologist': user.is_radiologist(),
                'is_facility_user': user.is_facility_user(),
            },
            'last_login': user.last_login.isoformat() if user.last_login else None,
            'is_verified': user.is_verified
        })
    except Exception as e:
        logger.error(f"User API info error: {str(e)}")
        return JsonResponse({'error': 'Failed to retrieve user information'}, status=500)

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
            'message': 'Session extended successfully',
            'remaining_time': 600  # 10 minutes
        })
    except Exception as e:
        logger.error(f"Session extend error: {str(e)}")
        return JsonResponse({
            'success': False,
            'error': 'Failed to extend session'
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
            'status': 'active',
            'timestamp': int(time.time())
        })
    except Exception as e:
        logger.error(f"Session keep alive error: {str(e)}")
        return JsonResponse({
            'success': False,
            'error': 'Failed to update session'
        }, status=500)

@login_required
@require_http_methods(["GET"])
def session_status(request):
    """Get current session status and remaining time"""
    try:
        from django.conf import settings
        
        timeout_seconds = getattr(settings, 'SESSION_COOKIE_AGE', 600)
        last_activity = request.session.get('last_activity', time.time())
        current_time = time.time()
        
        time_since_activity = current_time - last_activity
        remaining_time = max(0, timeout_seconds - time_since_activity)
        
        return JsonResponse({
            'authenticated': True,
            'remaining_time': int(remaining_time),
            'timeout_seconds': timeout_seconds,
            'warning_threshold': getattr(settings, 'SESSION_TIMEOUT_WARNING', 300),
            'current_time': int(current_time),
            'last_activity': int(last_activity)
        })
    except Exception as e:
        logger.error(f"Session status error: {str(e)}")
        return JsonResponse({
            'authenticated': False,
            'error': 'Failed to get session status'
        }, status=500)

@login_required
@require_http_methods(["GET"])
def user_sessions(request):
    """Get user's active sessions for security monitoring"""
    try:
        sessions = UserSession.objects.filter(
            user=request.user,
            is_active=True
        ).order_by('-login_time')
        
        session_data = []
        for session in sessions:
            session_data.append({
                'id': session.id,
                'ip_address': session.ip_address,
                'login_time': session.login_time.isoformat(),
                'user_agent': session.user_agent[:100],  # Truncate for display
                'is_current': session.session_key == request.session.session_key
            })
        
        return JsonResponse({
            'sessions': session_data,
            'total_active': len(session_data)
        })
    except Exception as e:
        logger.error(f"User sessions error: {str(e)}")
        return JsonResponse({'error': 'Failed to retrieve sessions'}, status=500)

@login_required
@csrf_exempt
@require_http_methods(["POST"])
def terminate_session(request):
    """Terminate a specific user session"""
    try:
        session_id = request.POST.get('session_id')
        if not session_id:
            return JsonResponse({'error': 'Session ID required'}, status=400)
        
        session = UserSession.objects.filter(
            id=session_id,
            user=request.user,
            is_active=True
        ).first()
        
        if not session:
            return JsonResponse({'error': 'Session not found'}, status=404)
        
        # Don't allow terminating current session
        if session.session_key == request.session.session_key:
            return JsonResponse({'error': 'Cannot terminate current session'}, status=400)
        
        session.is_active = False
        session.logout_time = timezone.now()
        session.save(update_fields=['is_active', 'logout_time'])
        
        logger.info(f"Session terminated: {request.user.username} - {session.ip_address}")
        
        return JsonResponse({
            'success': True,
            'message': 'Session terminated successfully'
        })
        
    except Exception as e:
        logger.error(f"Session termination error: {str(e)}")
        return JsonResponse({'error': 'Failed to terminate session'}, status=500)