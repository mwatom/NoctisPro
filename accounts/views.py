from django.shortcuts import render, redirect
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from django.contrib.auth.forms import AuthenticationForm
from .models import User, UserSession, Facility
import json

def login_view(request):
    """Custom login view with enhanced security tracking"""
    if request.user.is_authenticated:
        return redirect('worklist:dashboard')
    
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        
        if username and password:
            user = authenticate(request, username=username, password=password)
            
            if user is not None:
                if user.is_active:
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
                    
                    # Honor "next" parameter if present and looks like an internal path
                    next_url = request.GET.get('next') or request.POST.get('next')
                    if next_url and isinstance(next_url, str) and next_url.startswith('/'):
                        return redirect(next_url)
                    
                    # Redirect all users to worklist dashboard by default
                    return redirect('worklist:dashboard')
                else:
                    messages.error(request, 'Account is disabled. Please contact administrator.')
            else:
                messages.error(request, 'Invalid username or password.')
        else:
            messages.error(request, 'Please provide both username and password.')
    
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
    messages.success(request, 'You have been successfully logged out.')
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
