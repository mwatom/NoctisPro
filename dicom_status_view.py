"""
DICOM Status and Facility Management Views
Provides status information for DICOM connectivity and facility management
"""

from django.shortcuts import render, get_object_or_404
from django.contrib.auth.decorators import login_required, user_passes_test
from django.http import JsonResponse
from django.db.models import Count, Q
from django.utils import timezone
from datetime import datetime, timedelta
import socket
import json
import logging

from accounts.models import Facility, User
from worklist.models import Study, DicomImage
from admin_panel.models import AuditLog

logger = logging.getLogger(__name__)

def is_admin_or_facility_user(user):
    """Check if user is admin or facility user"""
    return user.is_authenticated and user.role in ['admin', 'facility']

@login_required
@user_passes_test(is_admin_or_facility_user)
def dicom_status(request):
    """DICOM status page for facility administrators"""
    
    # Get user's facility (if facility user) or all facilities (if admin)
    if request.user.role == 'facility' and request.user.facility:
        facilities = [request.user.facility]
        user_facility = request.user.facility
    else:
        facilities = Facility.objects.filter(is_active=True)
        user_facility = None
    
    # DICOM connectivity test
    dicom_status = test_dicom_connectivity()
    
    # Get facility statistics
    facility_stats = []
    for facility in facilities:
        # Recent studies (last 7 days)
        recent_studies = Study.objects.filter(
            facility=facility,
            upload_date__gte=timezone.now() - timedelta(days=7)
        ).count()
        
        # Total studies
        total_studies = Study.objects.filter(facility=facility).count()
        
        # Recent DICOM images (last 24 hours)
        recent_images = DicomImage.objects.filter(
            series__study__facility=facility,
            series__study__upload_date__gte=timezone.now() - timedelta(hours=24)
        ).count()
        
        # Last activity
        last_study = Study.objects.filter(facility=facility).order_by('-upload_date').first()
        
        facility_stats.append({
            'facility': facility,
            'recent_studies': recent_studies,
            'total_studies': total_studies,
            'recent_images': recent_images,
            'last_activity': last_study.upload_date if last_study else None,
            'ae_title': facility.ae_title,
            'status': 'Active' if facility.is_active else 'Inactive'
        })
    
    # System-wide statistics
    total_facilities = Facility.objects.filter(is_active=True).count()
    total_studies_today = Study.objects.filter(
        upload_date__date=timezone.now().date()
    ).count()
    
    # Recent DICOM activity
    recent_activity = Study.objects.select_related('facility', 'patient', 'modality').filter(
        upload_date__gte=timezone.now() - timedelta(hours=24)
    ).order_by('-upload_date')[:10]
    
    context = {
        'facility_stats': facility_stats,
        'user_facility': user_facility,
        'dicom_status': dicom_status,
        'total_facilities': total_facilities,
        'total_studies_today': total_studies_today,
        'recent_activity': recent_activity,
        'is_admin': request.user.role == 'admin',
    }
    
    return render(request, 'dicom/status.html', context)

@login_required
@user_passes_test(is_admin_or_facility_user)
def dicom_connectivity_test(request):
    """AJAX endpoint for testing DICOM connectivity"""
    
    if request.method != 'POST':
        return JsonResponse({'error': 'POST method required'}, status=405)
    
    try:
        # Test DICOM port
        result = test_dicom_connectivity()
        
        # Test specific facility AE title if provided
        facility_id = request.POST.get('facility_id')
        if facility_id:
            try:
                facility = Facility.objects.get(id=facility_id, is_active=True)
                result['facility'] = {
                    'name': facility.name,
                    'ae_title': facility.ae_title,
                    'status': 'configured'
                }
            except Facility.DoesNotExist:
                result['facility'] = {'status': 'not_found'}
        
        return JsonResponse(result)
        
    except Exception as e:
        logger.error(f"Error testing DICOM connectivity: {e}")
        return JsonResponse({'error': str(e)}, status=500)

def test_dicom_connectivity():
    """Test DICOM port connectivity"""
    try:
        # Test local DICOM port
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex(('localhost', 11112))
        sock.close()
        
        return {
            'port_accessible': result == 0,
            'test_time': datetime.now().isoformat(),
            'port': 11112,
            'status': 'accessible' if result == 0 else 'not_accessible'
        }
        
    except Exception as e:
        return {
            'port_accessible': False,
            'test_time': datetime.now().isoformat(),
            'port': 11112,
            'status': 'error',
            'error': str(e)
        }

@login_required
@user_passes_test(is_admin_or_facility_user)
def facility_dicom_config(request, facility_id):
    """Get DICOM configuration for a specific facility"""
    
    try:
        facility = get_object_or_404(Facility, id=facility_id, is_active=True)
        
        # Check if user has access to this facility
        if request.user.role == 'facility' and request.user.facility != facility:
            return JsonResponse({'error': 'Access denied'}, status=403)
        
        # Get server configuration
        domain_name = getattr(settings, 'DOMAIN_NAME', 'localhost')
        
        config = {
            'facility_name': facility.name,
            'ae_title': facility.ae_title,
            'dicom_config': {
                'called_ae_title': 'NOCTIS_SCP',
                'calling_ae_title': facility.ae_title,
                'hostname': domain_name,
                'port': 11112,
                'protocol': 'DICOM TCP/IP',
                'timeout': 30
            },
            'test_commands': {
                'telnet': f'telnet {domain_name} 11112',
                'ping': f'echoscu -aet {facility.ae_title} -aec NOCTIS_SCP {domain_name} 11112',
                'store': f'storescu -aet {facility.ae_title} -aec NOCTIS_SCP {domain_name} 11112 /path/to/dicom/file.dcm'
            }
        }
        
        return JsonResponse(config)
        
    except Exception as e:
        logger.error(f"Error getting facility DICOM config: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
def facility_management_test(request):
    """Test facility management functionality"""
    
    if not request.user.is_admin():
        return JsonResponse({'error': 'Admin access required'}, status=403)
    
    try:
        # Test facility creation functionality
        from admin_panel.views import _standardize_aetitle
        
        test_results = {
            'facility_model': True,
            'ae_title_generation': True,
            'facility_count': Facility.objects.count(),
            'active_facilities': Facility.objects.filter(is_active=True).count(),
            'user_count': User.objects.count(),
            'admin_count': User.objects.filter(role='admin').count(),
            'facility_users': User.objects.filter(role='facility').count(),
            'radiologists': User.objects.filter(role='radiologist').count(),
        }
        
        # Test AE title generation
        test_names = ['Test Hospital', 'Regional Medical Center', 'City Clinic']
        ae_title_tests = {}
        for name in test_names:
            ae_title_tests[name] = _standardize_aetitle(name)
        
        test_results['ae_title_examples'] = ae_title_tests
        
        # Recent facility activities
        recent_facilities = Facility.objects.order_by('-created_at')[:5]
        test_results['recent_facilities'] = [
            {
                'name': f.name,
                'ae_title': f.ae_title,
                'created_at': f.created_at.isoformat() if f.created_at else None,
                'is_active': f.is_active
            }
            for f in recent_facilities
        ]
        
        return JsonResponse({
            'status': 'success',
            'test_results': test_results,
            'message': 'Facility management is working correctly'
        })
        
    except Exception as e:
        logger.error(f"Error testing facility management: {e}")
        return JsonResponse({
            'status': 'error',
            'error': str(e)
        }, status=500)