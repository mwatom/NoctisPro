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
import re
from django.utils.crypto import get_random_string


def is_admin(user):
    """Check if user is admin"""
    return user.is_authenticated and user.is_admin()

def _standardize_aetitle(source: str) -> str:
    """Generate a DICOM-compliant AE Title (<=16 chars, A-Z 0-9 _), ensure uniqueness."""
    base = re.sub(r"[^A-Z0-9 ]+", "", (source or "").upper()).strip().replace(" ", "_") or "FACILITY"
    aet = base[:16]
    suffix = 1
    # Ensure uniqueness (case-insensitive)
    while Facility.objects.filter(ae_title__iexact=aet).exists():
        tail = f"_{suffix}"
        aet = (base[: 16 - len(tail)] + tail)[:16] or f"FAC_{suffix:02d}"
        suffix += 1
        if suffix > 99:
            break
    return aet

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
            Q(email__icontains=search_query) |
            Q(phone__icontains=search_query) |
            Q(license_number__icontains=search_query) |
            Q(specialization__icontains=search_query)
        )
    
    # Role filtering
    role_filter = request.GET.get('role', '')
    if role_filter:
        users = users.filter(role=role_filter)
    
    # Facility filtering
    facility_filter = request.GET.get('facility', '')
    if facility_filter:
        users = users.filter(facility_id=facility_filter)
    
    # Status filtering
    status_filter = request.GET.get('status', '')
    if status_filter == 'active':
        users = users.filter(is_active=True)
    elif status_filter == 'inactive':
        users = users.filter(is_active=False)
    elif status_filter == 'verified':
        users = users.filter(is_verified=True)
    elif status_filter == 'unverified':
        users = users.filter(is_verified=False)
    
    # Export functionality
    export_format = request.GET.get('export', '')
    if export_format:
        return export_users(users, export_format)
    
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
            confirm_password = request.POST.get('password_confirm')
            phone = request.POST.get('phone', '')
            license_number = request.POST.get('license_number', '')
            specialization = request.POST.get('specialization', '')

            # Validation
            if not username or not password:
                messages.error(request, 'Username and password are required')
                return redirect('admin_panel:user_create')

            if password != confirm_password:
                messages.error(request, 'Passwords do not match')
                return redirect('admin_panel:user_create')

            if len(password) < 8:
                messages.error(request, 'Password must be at least 8 characters long')
                return redirect('admin_panel:user_create')

            if User.objects.filter(username=username).exists():
                messages.error(request, 'Username already exists')
                return redirect('admin_panel:user_create')
            
            if email and User.objects.filter(email=email).exists():
                messages.error(request, 'Email already exists')
                return redirect('admin_panel:user_create')
            
            # Handle facility assignment based on role
            facility = None
            if role == 'facility':
                # Facility users must have a facility assigned
                if not facility_id:
                    messages.error(request, 'Facility is required for Facility User role')
                    return redirect('admin_panel:user_create')
                facility = get_object_or_404(Facility, id=facility_id)
            elif role == 'radiologist' and facility_id:
                # Radiologists can optionally have a facility assigned
                try:
                    facility = Facility.objects.get(id=facility_id)
                except Facility.DoesNotExist:
                    messages.warning(request, 'Selected facility not found, radiologist will be created without facility assignment')
                    facility = None
            elif role == 'admin':
                # Admins don't need facility assignment
                facility = None

            # Create user
            user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                first_name=first_name,
                last_name=last_name
            )
            # Set additional fields after creation
            user.role = role
            if facility:
                user.facility = facility
            user.phone = phone
            user.license_number = license_number
            user.specialization = specialization
            user.is_verified = True  # Set new users as verified by default
            user.is_active = True  # Ensure user is active by default
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
            
            messages.success(request, f'User {username} created successfully. Username: {username}, Role: {user.get_role_display()}, Status: Active & Verified')
            return redirect('admin_panel:user_management')
            
        except Exception as e:
            messages.error(request, f'Error creating user: {str(e)}')
    
    # Get all active facilities, ordered by name for consistent display
    facilities = Facility.objects.filter(is_active=True).order_by('name')
    
    # Get pre-fill values from URL parameters
    preset_role = request.GET.get('role', '')
    preset_facility = request.GET.get('facility', '')
    
    # Debug logging for facility count
    import logging
    logger = logging.getLogger(__name__)
    logger.info(f"User create view: Found {facilities.count()} active facilities")
    for facility in facilities:
        logger.info(f"  - Facility ID: {facility.id}, Name: {facility.name}")
    
    context = {
        'facilities': facilities,
        'user_roles': User.USER_ROLES,
        'preset_role': preset_role,
        'preset_facility': preset_facility,
        'facilities_count': facilities.count(),  # Add count for debugging
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
    
    # Get all active facilities, ordered by name for consistent display
    facilities = Facility.objects.filter(is_active=True).order_by('name')
    
    # Debug logging for facility count
    import logging
    logger = logging.getLogger(__name__)
    logger.info(f"User edit view: Found {facilities.count()} active facilities")
    
    context = {
        'user_obj': user,
        'facilities': facilities,
        'user_roles': User.USER_ROLES,
        'edit_mode': True,
        'facilities_count': facilities.count(),  # Add count for debugging
    }
    
    return render(request, 'admin_panel/user_form.html', context)

@login_required
@user_passes_test(is_admin)
def user_delete(request, user_id):
    """Delete user immediately without confirmation"""
    user = get_object_or_404(User, id=user_id)
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

@login_required
@user_passes_test(is_admin)
def facility_management(request):
    """Enhanced facility management interface"""
    facilities = Facility.objects.all()
    
    # Search functionality
    search_query = request.GET.get('search', '')
    if search_query:
        facilities = facilities.filter(
            Q(name__icontains=search_query) |
            Q(address__icontains=search_query) |
            Q(license_number__icontains=search_query) |
            Q(email__icontains=search_query) |
            Q(phone__icontains=search_query) |
            Q(ae_title__icontains=search_query)
        )
    
    # Status filtering
    status_filter = request.GET.get('status', '')
    if status_filter == 'active':
        facilities = facilities.filter(is_active=True)
    elif status_filter == 'inactive':
        facilities = facilities.filter(is_active=False)
    
    # Sorting
    sort_by = request.GET.get('sort', 'name')
    if sort_by == 'name':
        facilities = facilities.order_by('name')
    elif sort_by == 'created_at':
        facilities = facilities.order_by('-created_at')
    elif sort_by == 'user_count':
        facilities = facilities.annotate(user_count=Count('user')).order_by('-user_count')
    elif sort_by == 'study_count':
        facilities = facilities.annotate(study_count=Count('study')).order_by('-study_count')
    
    # Export functionality
    export_format = request.GET.get('export', '')
    selected_ids = request.GET.get('selected', '')
    if export_format:
        if selected_ids:
            facility_ids = [int(id) for id in selected_ids.split(',')]
            export_facilities = facilities.filter(id__in=facility_ids)
        else:
            export_facilities = facilities
        return export_facilities_data(export_facilities, export_format)
    
    # Pagination
    paginator = Paginator(facilities, 12)  # 12 per page for grid view
    page_number = request.GET.get('page')
    facilities_page = paginator.get_page(page_number)
    
    # Statistics
    total_users = User.objects.count()
    total_studies = Study.objects.count() if hasattr(facilities.first(), 'study_set') else 0
    
    context = {
        'facilities': facilities_page,
        'search_query': search_query,
        'total_users': total_users,
        'total_studies': total_studies,
    }
    
    return render(request, 'admin_panel/facility_management.html', context)

def export_users(users, format):
    """Export users data in various formats"""
    import csv
    from django.http import HttpResponse
    import io
    
    if format == 'csv':
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="users_export.csv"'
        
        writer = csv.writer(response)
        writer.writerow([
            'Username', 'First Name', 'Last Name', 'Email', 'Phone', 
            'Role', 'Facility', 'License Number', 'Specialization', 
            'Active', 'Verified', 'Date Joined', 'Last Login'
        ])
        
        for user in users:
            writer.writerow([
                user.username,
                user.first_name,
                user.last_name,
                user.email,
                user.phone,
                user.get_role_display(),
                user.facility.name if user.facility else '',
                user.license_number,
                user.specialization,
                'Yes' if user.is_active else 'No',
                'Yes' if user.is_verified else 'No',
                user.date_joined.strftime('%Y-%m-%d %H:%M:%S'),
                user.last_login.strftime('%Y-%m-%d %H:%M:%S') if user.last_login else 'Never'
            ])
        
        return response
    
    elif format == 'excel':
        try:
            import openpyxl
            from openpyxl.utils.dataframe import dataframe_to_rows
            import pandas as pd
            
            # Create DataFrame
            data = []
            for user in users:
                data.append({
                    'Username': user.username,
                    'First Name': user.first_name,
                    'Last Name': user.last_name,
                    'Email': user.email,
                    'Phone': user.phone,
                    'Role': user.get_role_display(),
                    'Facility': user.facility.name if user.facility else '',
                    'License Number': user.license_number,
                    'Specialization': user.specialization,
                    'Active': 'Yes' if user.is_active else 'No',
                    'Verified': 'Yes' if user.is_verified else 'No',
                    'Date Joined': user.date_joined.strftime('%Y-%m-%d %H:%M:%S'),
                    'Last Login': user.last_login.strftime('%Y-%m-%d %H:%M:%S') if user.last_login else 'Never'
                })
            
            df = pd.DataFrame(data)
            
            # Create Excel response
            response = HttpResponse(content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
            response['Content-Disposition'] = 'attachment; filename="users_export.xlsx"'
            
            with pd.ExcelWriter(response, engine='openpyxl') as writer:
                df.to_excel(writer, sheet_name='Users', index=False)
            
            return response
            
        except ImportError:
            # Fallback to CSV if pandas/openpyxl not available
            return export_users(users, 'csv')
    
    # Default to CSV
    return export_users(users, 'csv')

def export_facilities_data(facilities, format):
    """Export facilities data in various formats"""
    import csv
    from django.http import HttpResponse
    
    if format == 'csv':
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="facilities_export.csv"'
        
        writer = csv.writer(response)
        writer.writerow([
            'Name', 'Address', 'Phone', 'Email', 'License Number', 
            'AE Title', 'Active', 'User Count', 'Study Count', 'Created Date'
        ])
        
        for facility in facilities:
            writer.writerow([
                facility.name,
                facility.address,
                facility.phone,
                facility.email,
                facility.license_number,
                facility.ae_title,
                'Yes' if facility.is_active else 'No',
                facility.user_set.count(),
                facility.study_set.count() if hasattr(facility, 'study_set') else 0,
                facility.created_at.strftime('%Y-%m-%d %H:%M:%S') if facility.created_at else ''
            ])
        
        return response
    
    elif format == 'excel':
        try:
            import pandas as pd
            
            # Create DataFrame
            data = []
            for facility in facilities:
                data.append({
                    'Name': facility.name,
                    'Address': facility.address,
                    'Phone': facility.phone,
                    'Email': facility.email,
                    'License Number': facility.license_number,
                    'AE Title': facility.ae_title,
                    'Active': 'Yes' if facility.is_active else 'No',
                    'User Count': facility.user_set.count(),
                    'Study Count': facility.study_set.count() if hasattr(facility, 'study_set') else 0,
                    'Created Date': facility.created_at.strftime('%Y-%m-%d %H:%M:%S') if facility.created_at else ''
                })
            
            df = pd.DataFrame(data)
            
            # Create Excel response
            response = HttpResponse(content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
            response['Content-Disposition'] = 'attachment; filename="facilities_export.xlsx"'
            
            with pd.ExcelWriter(response, engine='openpyxl') as writer:
                df.to_excel(writer, sheet_name='Facilities', index=False)
            
            return response
            
        except ImportError:
            # Fallback to CSV if pandas not available
            return export_facilities_data(facilities, 'csv')
    
    # Default to CSV
    return export_facilities_data(facilities, 'csv')

@csrf_exempt
@login_required
@user_passes_test(is_admin)
def bulk_user_action(request):
    """Handle bulk user actions"""
    if request.method != 'POST':
        return JsonResponse({'error': 'POST method required'}, status=405)
    
    try:
        data = json.loads(request.body)
        action = data.get('action')
        user_ids = data.get('user_ids', [])
        
        if not user_ids:
            return JsonResponse({'error': 'No users selected'}, status=400)
        
        users = User.objects.filter(id__in=user_ids)
        
        if action == 'activate':
            users.update(is_active=True)
            message = f'Activated {users.count()} users'
        elif action == 'deactivate':
            users.update(is_active=False)
            message = f'Deactivated {users.count()} users'
        elif action == 'verify':
            users.update(is_verified=True)
            message = f'Verified {users.count()} users'
        elif action == 'delete':
            count = users.count()
            users.delete()
            message = f'Deleted {count} users'
        else:
            return JsonResponse({'error': 'Invalid action'}, status=400)
        
        return JsonResponse({'success': True, 'message': message})
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@login_required
@user_passes_test(is_admin)
def bulk_facility_action(request):
    """Handle bulk facility actions"""
    if request.method != 'POST':
        return JsonResponse({'error': 'POST method required'}, status=405)
    
    try:
        data = json.loads(request.body)
        action = data.get('action')
        facility_ids = data.get('facility_ids', [])
        
        if not facility_ids:
            return JsonResponse({'error': 'No facilities selected'}, status=400)
        
        facilities = Facility.objects.filter(id__in=facility_ids)
        
        if action == 'activate':
            facilities.update(is_active=True)
            message = f'Activated {facilities.count()} facilities'
        elif action == 'deactivate':
            facilities.update(is_active=False)
            message = f'Deactivated {facilities.count()} facilities'
        elif action == 'delete':
            count = facilities.count()
            facilities.delete()
            message = f'Deleted {count} facilities'
        else:
            return JsonResponse({'error': 'Invalid action'}, status=400)
        
        return JsonResponse({'success': True, 'message': message})
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@user_passes_test(is_admin)
def facility_create(request):
    """Create new facility"""
    if request.method == 'POST':
        try:
            name = request.POST.get('name')
            ae_title_raw = (request.POST.get('ae_title', '') or '').strip()
            if ae_title_raw:
                # Standardize provided AE Title
                ae_title = _standardize_aetitle(ae_title_raw)
            else:
                ae_title = _standardize_aetitle(name)
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
            
            # Optionally create a facility user account
            if request.POST.get('create_facility_user') in ['on', '1', 'true', 'True']:
                desired_username = (request.POST.get('facility_username') or facility.ae_title or name or '').strip()
                desired_username = re.sub(r"[^A-Za-z0-9_.-]", "", desired_username)[:150] or facility.ae_title
                username = desired_username
                idx = 1
                while User.objects.filter(username=username).exists():
                    suffix = f"{idx}"
                    username = (desired_username[:150 - len(suffix)] + suffix)
                    idx += 1
                facility_email = request.POST.get('facility_email') or ''
                raw_password = request.POST.get('facility_password') or get_random_string(12)
                user = User.objects.create_user(
                    username=username,
                    email=facility_email,
                    password=raw_password,
                    role='facility'
                )
                user.facility = facility
                user.first_name = name
                user.save()
                AuditLog.objects.create(
                    user=request.user,
                    action='create',
                    model_name='User',
                    object_id=str(user.id),
                    object_repr=str(user),
                    description=f'Created facility user {user.username} for {facility.name}'
                )
                messages.success(request, f"Facility {facility.name} created. Facility login '{username}' has been created.")
            else:
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
            ae_title_raw = (request.POST.get('ae_title', '') or '').strip()
            facility.ae_title = _standardize_aetitle(ae_title_raw or facility.name)
            facility.is_active = request.POST.get('is_active') == 'on'
            
            # Handle letterhead upload
            if 'letterhead' in request.FILES:
                facility.letterhead = request.FILES['letterhead']
            
            facility.save()
            
            # Optionally create a facility user account during edit
            if request.POST.get('create_facility_user') in ['on', '1', 'true', 'True']:
                desired_username = (request.POST.get('facility_username') or facility.ae_title or facility.name or '').strip()
                desired_username = re.sub(r"[^A-Za-z0-9_.-]", "", desired_username)[:150] or facility.ae_title
                username = desired_username
                idx = 1
                while User.objects.filter(username=username).exists():
                    suffix = f"{idx}"
                    username = (desired_username[:150 - len(suffix)] + suffix)
                    idx += 1
                facility_email = request.POST.get('facility_email') or ''
                raw_password = request.POST.get('facility_password') or get_random_string(12)
                user = User.objects.create_user(
                    username=username,
                    email=facility_email,
                    password=raw_password,
                    role='facility'
                )
                user.facility = facility
                user.first_name = facility.name
                user.save()
                AuditLog.objects.create(
                    user=request.user,
                    action='create',
                    model_name='User',
                    object_id=str(user.id),
                    object_repr=str(user),
                    description=f'Created facility user {user.username} for {facility.name}'
                )
                messages.success(request, f"Facility updated. Facility login '{username}' has been created.")
            else:
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
