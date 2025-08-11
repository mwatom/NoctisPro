from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required, user_passes_test
from django.contrib import messages
from django.http import JsonResponse
from django.db.models import Q, Count
from django.core.paginator import Paginator
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from accounts.models import User, Facility
from worklist.models import Study, Modality
from .models import SystemConfiguration, AuditLog, SystemUsageStatistics
import json


def is_admin(user):
    """Check if user is admin"""
    return user.is_authenticated and user.is_admin()

@login_required
@user_passes_test(is_admin)
def dashboard(request):
    """Admin dashboard with system overview"""
    # Get system statistics
    total_users = User.objects.count()
    total_facilities = Facility.objects.count()
    total_studies = Study.objects.count()
    active_users_today = User.objects.filter(last_login__date=timezone.now().date()).count()
    
    # Recent activities
    recent_studies = Study.objects.select_related('patient', 'facility', 'modality').order_by('-upload_date')[:10]
    recent_users = User.objects.order_by('-date_joined')[:10]
    
    # System usage by modality
    modality_stats = Study.objects.values('modality__name').annotate(
        count=Count('id')
    ).order_by('-count')[:5]
    
    context = {
        'total_users': total_users,
        'total_facilities': total_facilities,
        'total_studies': total_studies,
        'active_users_today': active_users_today,
        'recent_studies': recent_studies,
        'recent_users': recent_users,
        'modality_stats': modality_stats,
    }
    
    return render(request, 'admin_panel/dashboard.html', context)

@login_required
@user_passes_test(is_admin)
def system_logs(request):
    """Placeholder: system logs view."""
    messages.info(request, 'System Logs view is under construction.')
    return dashboard(request)

@login_required
@user_passes_test(is_admin)
def settings_view(request):
    """Placeholder: settings view."""
    messages.info(request, 'Settings view is under construction.')
    return dashboard(request)

@login_required
@user_passes_test(is_admin)
def user_management(request):
    """User management interface with search and filtering"""
    users = User.objects.select_related('facility').all()
    
    # Search functionality
    search_query = request.GET.get('search', '')
    if search_query:
        users = users.filter(
            Q(username__icontains=search_query) |
            Q(first_name__icontains=search_query) |
            Q(last_name__icontains=search_query) |
            Q(email__icontains=search_query)
        )
    
    # Role filtering
    role_filter = request.GET.get('role', '')
    if role_filter:
        users = users.filter(role=role_filter)
    
    # Facility filtering
    facility_filter = request.GET.get('facility', '')
    if facility_filter:
        users = users.filter(facility_id=facility_filter)
    
    # Pagination
    paginator = Paginator(users, 20)
    page_number = request.GET.get('page')
    users_page = paginator.get_page(page_number)
    
    # Get facilities for filter dropdown
    facilities = Facility.objects.filter(is_active=True)
    
    context = {
        'users': users_page,
        'facilities': facilities,
        'search_query': search_query,
        'role_filter': role_filter,
        'facility_filter': facility_filter,
        'user_roles': User.USER_ROLES,
    }
    
    return render(request, 'admin_panel/user_management.html', context)

@login_required
@user_passes_test(is_admin)
def user_create(request):
    """Create new user"""
    if request.method == 'POST':
        try:
            # Get form data
            username = request.POST.get('username')
            email = request.POST.get('email')
            first_name = request.POST.get('first_name')
            last_name = request.POST.get('last_name')
            role = request.POST.get('role')
            facility_id = request.POST.get('facility')
            password = request.POST.get('password')
            
            # Validation
            if User.objects.filter(username=username).exists():
                messages.error(request, 'Username already exists')
                return redirect('admin_panel:user_create')
            
            if User.objects.filter(email=email).exists():
                messages.error(request, 'Email already exists')
                return redirect('admin_panel:user_create')
            
            # Create user
            user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                first_name=first_name,
                last_name=last_name,
                role=role
            )
            
            # Set facility if provided
            if facility_id:
                facility = get_object_or_404(Facility, id=facility_id)
                user.facility = facility
                user.save()
            
            # Log the action
            AuditLog.objects.create(
                user=request.user,
                action='create',
                model_name='User',
                object_id=str(user.id),
                object_repr=str(user),
                description=f'Created user {user.username}'
            )
            
            messages.success(request, f'User {username} created successfully')
            return redirect('admin_panel:user_management')
            
        except Exception as e:
            messages.error(request, f'Error creating user: {str(e)}')
    
    facilities = Facility.objects.filter(is_active=True)
    
    # Get pre-fill values from URL parameters
    preset_role = request.GET.get('role', '')
    preset_facility = request.GET.get('facility', '')
    
    context = {
        'facilities': facilities,
        'user_roles': User.USER_ROLES,
        'preset_role': preset_role,
        'preset_facility': preset_facility,
    }
    
    return render(request, 'admin_panel/user_form.html', context)

@login_required
@user_passes_test(is_admin)
def user_edit(request, user_id):
    """Edit existing user"""
    user = get_object_or_404(User, id=user_id)
    
    if request.method == 'POST':
        try:
            # Update user fields
            user.username = request.POST.get('username')
            user.email = request.POST.get('email')
            user.first_name = request.POST.get('first_name')
            user.last_name = request.POST.get('last_name')
            user.role = request.POST.get('role')
            user.phone = request.POST.get('phone', '')
            user.license_number = request.POST.get('license_number', '')
            user.specialization = request.POST.get('specialization', '')
            user.is_active = request.POST.get('is_active') == 'on'
            user.is_verified = request.POST.get('is_verified') == 'on'
            
            # Update facility
            facility_id = request.POST.get('facility')
            if facility_id:
                user.facility = get_object_or_404(Facility, id=facility_id)
            else:
                user.facility = None
            
            # Update password if provided
            new_password = request.POST.get('password')
            if new_password:
                user.set_password(new_password)
            
            user.save()
            
            # Log the action
            AuditLog.objects.create(
                user=request.user,
                action='update',
                model_name='User',
                object_id=str(user.id),
                object_repr=str(user),
                description=f'Updated user {user.username}'
            )
            
            messages.success(request, f'User {user.username} updated successfully')
            return redirect('admin_panel:user_management')
            
        except Exception as e:
            messages.error(request, f'Error updating user: {str(e)}')
    
    facilities = Facility.objects.filter(is_active=True)
    context = {
        'user_obj': user,
        'facilities': facilities,
        'user_roles': User.USER_ROLES,
        'edit_mode': True,
    }
    
    return render(request, 'admin_panel/user_form.html', context)

@login_required
@user_passes_test(is_admin)
def user_delete(request, user_id):
    """Delete user"""
    user = get_object_or_404(User, id=user_id)
    
    if request.method == 'POST':
        username = user.username
        
        # Log the action before deleting
        AuditLog.objects.create(
            user=request.user,
            action='delete',
            model_name='User',
            object_id=str(user.id),
            object_repr=str(user),
            description=f'Deleted user {username}'
        )
        
        user.delete()
        messages.success(request, f'User {username} deleted successfully')
        return redirect('admin_panel:user_management')
    
    context = {'user_obj': user}
    return render(request, 'admin_panel/user_confirm_delete.html', context)

@login_required
@user_passes_test(is_admin)
def facility_management(request):
    """Facility management interface"""
    facilities = Facility.objects.all()
    
    # Search functionality
    search_query = request.GET.get('search', '')
    if search_query:
        facilities = facilities.filter(
            Q(name__icontains=search_query) |
            Q(address__icontains=search_query) |
            Q(license_number__icontains=search_query)
        )
    
    # Status filtering
    status_filter = request.GET.get('status', '')
    if status_filter == 'active':
        facilities = facilities.filter(is_active=True)
    elif status_filter == 'inactive':
        facilities = facilities.filter(is_active=False)
    
    # Pagination
    paginator = Paginator(facilities, 20)
    page_number = request.GET.get('page')
    facilities_page = paginator.get_page(page_number)
    
    context = {
        'facilities': facilities_page,
        'search_query': search_query,
        'status_filter': status_filter,
    }
    
    return render(request, 'admin_panel/facility_management.html', context)

@login_required
@user_passes_test(is_admin)
def facility_create(request):
    """Create new facility"""
    if request.method == 'POST':
        try:
            name = request.POST.get('name')
            ae_title = (request.POST.get('ae_title', '') or '').strip().upper()
            # Auto-generate AE Title if missing
            if not ae_title and name:
                base = ''.join(ch for ch in name.upper() if ch.isalnum() or ch == ' ').strip().replace(' ', '_')
                ae_title = (base[:12] or 'FACILITY')  # limit length, DICOM AE max 16; keep some headroom
            facility = Facility.objects.create(
                name=name,
                address=request.POST.get('address'),
                phone=request.POST.get('phone'),
                email=request.POST.get('email'),
                license_number=request.POST.get('license_number'),
                ae_title=ae_title,
                is_active=request.POST.get('is_active') == 'on'
            )
            
            # Handle letterhead upload
            if 'letterhead' in request.FILES:
                facility.letterhead = request.FILES['letterhead']
                facility.save()
            
            # Log the action
            AuditLog.objects.create(
                user=request.user,
                action='create',
                model_name='Facility',
                object_id=str(facility.id),
                object_repr=str(facility),
                description=f'Created facility {facility.name}'
            )
            
            messages.success(request, f'Facility {facility.name} created successfully')
            return redirect('admin_panel:facility_management')
            
        except Exception as e:
            messages.error(request, f'Error creating facility: {str(e)}')
    
    return render(request, 'admin_panel/facility_form.html')

@login_required
@user_passes_test(is_admin)
def facility_edit(request, facility_id):
    """Edit existing facility"""
    facility = get_object_or_404(Facility, id=facility_id)
    
    if request.method == 'POST':
        try:
            facility.name = request.POST.get('name')
            facility.address = request.POST.get('address')
            facility.phone = request.POST.get('phone')
            facility.email = request.POST.get('email')
            facility.license_number = request.POST.get('license_number')
            ae_title = (request.POST.get('ae_title', '') or '').strip().upper()
            if not ae_title and facility.name:
                base = ''.join(ch for ch in facility.name.upper() if ch.isalnum() or ch == ' ').strip().replace(' ', '_')
                ae_title = (base[:12] or 'FACILITY')
            facility.ae_title = ae_title
            facility.is_active = request.POST.get('is_active') == 'on'
            
            # Handle letterhead upload
            if 'letterhead' in request.FILES:
                facility.letterhead = request.FILES['letterhead']
            
            facility.save()
            
            # Log the action
            AuditLog.objects.create(
                user=request.user,
                action='update',
                model_name='Facility',
                object_id=str(facility.id),
                object_repr=str(facility),
                description=f'Updated facility {facility.name}'
            )
            
            messages.success(request, f'Facility {facility.name} updated successfully')
            return redirect('admin_panel:facility_management')
            
        except Exception as e:
            messages.error(request, f'Error updating facility: {str(e)}')
    
    return render(request, 'admin_panel/facility_form.html', { 'facility': facility })

@login_required
@user_passes_test(is_admin)
def facility_delete(request, facility_id):
    """Delete facility"""
    facility = get_object_or_404(Facility, id=facility_id)
    
    if request.method == 'POST':
        facility_name = facility.name
        
        # Check if facility has users
        if facility.user_set.exists():
            messages.error(request, 'Cannot delete facility with existing users. Please reassign or delete users first.')
            return redirect('admin_panel:facility_management')
        
        # Log the action before deleting
        AuditLog.objects.create(
            user=request.user,
            action='delete',
            model_name='Facility',
            object_id=str(facility.id),
            object_repr=str(facility),
            description=f'Deleted facility {facility_name}'
        )
        
        facility.delete()
        messages.success(request, f'Facility {facility_name} deleted successfully')
        return redirect('admin_panel:facility_management')
    
    context = {'facility': facility}
    return render(request, 'admin_panel/facility_confirm_delete.html', context)
