from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse
from django.contrib import messages
from django.core.paginator import Paginator
from django.db.models import Q, Count
from django.utils import timezone
from .models import Study, Patient, Modality, Series, DicomImage
from accounts.models import User

@login_required
def dashboard(request):
    """Main dashboard view for the worklist"""
    user = request.user
    
    # Get basic statistics
    if user.is_facility_user():
        studies = Study.objects.filter(facility=user.facility)
    else:
        studies = Study.objects.all()
    
    stats = {
        'total_studies': studies.count(),
        'pending_studies': studies.filter(status='scheduled').count(),
        'in_progress_studies': studies.filter(status='in_progress').count(),
        'completed_studies': studies.filter(status='completed').count(),
        'urgent_studies': studies.filter(priority='urgent').count(),
    }
    
    # Recent studies for the dashboard
    recent_studies = studies.order_by('-upload_date')[:10]
    
    context = {
        'user': user,
        'stats': stats,
        'recent_studies': recent_studies,
    }
    
    return render(request, 'worklist/dashboard.html', context)

@login_required
def study_list(request):
    """List all studies with filtering and pagination"""
    user = request.user
    
    # Base queryset based on user role
    if user.is_facility_user():
        studies = Study.objects.filter(facility=user.facility)
    else:
        studies = Study.objects.all()
    
    # Apply filters
    status_filter = request.GET.get('status')
    modality_filter = request.GET.get('modality')
    priority_filter = request.GET.get('priority')
    search_query = request.GET.get('search')
    
    if status_filter:
        studies = studies.filter(status=status_filter)
    
    if modality_filter:
        studies = studies.filter(modality__code=modality_filter)
    
    if priority_filter:
        studies = studies.filter(priority=priority_filter)
    
    if search_query:
        studies = studies.filter(
            Q(accession_number__icontains=search_query) |
            Q(patient__first_name__icontains=search_query) |
            Q(patient__last_name__icontains=search_query) |
            Q(patient__patient_id__icontains=search_query)
        )
    
    studies = studies.order_by('-study_date')
    
    # Pagination
    paginator = Paginator(studies, 25)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    # Get filter options
    modalities = Modality.objects.filter(is_active=True)
    
    context = {
        'page_obj': page_obj,
        'modalities': modalities,
        'current_filters': {
            'status': status_filter,
            'modality': modality_filter,
            'priority': priority_filter,
            'search': search_query,
        }
    }
    
    return render(request, 'worklist/study_list.html', context)

@login_required
def study_detail(request, study_id):
    """Detailed view of a single study"""
    study = get_object_or_404(Study, id=study_id)
    
    # Check permissions
    user = request.user
    if user.is_facility_user() and study.facility != user.facility:
        messages.error(request, 'You do not have permission to view this study.')
        return redirect('worklist:study_list')
    
    # Get related data
    series = study.series_set.all().order_by('series_number')
    attachments = study.attachments.all()
    notes = study.notes.all().order_by('-created_at')
    
    context = {
        'study': study,
        'series': series,
        'attachments': attachments,
        'notes': notes,
    }
    
    return render(request, 'worklist/study_detail.html', context)

@login_required
def upload_study(request):
    """Upload new studies (placeholder for now)"""
    if request.method == 'POST':
        # This would handle file uploads
        messages.success(request, 'Study upload functionality will be implemented soon.')
        return redirect('worklist:dashboard')
    
    return render(request, 'worklist/upload.html')

@login_required
def api_studies(request):
    """API endpoint for studies data"""
    user = request.user
    
    if user.is_facility_user():
        studies = Study.objects.filter(facility=user.facility)
    else:
        studies = Study.objects.all()
    
    studies_data = []
    for study in studies.order_by('-study_date')[:50]:
        studies_data.append({
            'id': study.id,
            'accession_number': study.accession_number,
            'patient_name': study.patient.full_name,
            'modality': study.modality.code,
            'status': study.status,
            'priority': study.priority,
            'study_date': study.study_date.isoformat(),
            'facility': study.facility.name,
        })
    
    return JsonResponse({'studies': studies_data})
