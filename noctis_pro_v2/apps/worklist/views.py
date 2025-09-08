from django.shortcuts import render, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from django.db.models import Q, Count
from .models import Study, Patient, Series, DicomImage, Modality
import json


@login_required
def dashboard(request):
    """Main dashboard view with worklist"""
    # Get studies with filters
    studies = Study.objects.select_related('patient', 'modality').prefetch_related('series')
    
    # Apply filters
    status_filter = request.GET.get('status')
    if status_filter:
        studies = studies.filter(status=status_filter)
    
    modality_filter = request.GET.get('modality')
    if modality_filter:
        studies = studies.filter(modality__code=modality_filter)
    
    date_filter = request.GET.get('date')
    if date_filter:
        studies = studies.filter(study_date=date_filter)
    
    # Get statistics
    stats = {
        'total_studies': Study.objects.count(),
        'completed_today': Study.objects.filter(
            status='completed',
            updated_at__date=timezone.now().date()
        ).count(),
        'in_progress': Study.objects.filter(status='in_progress').count(),
        'urgent': Study.objects.filter(status='urgent').count(),
    }
    
    # Get available modalities for filter
    modalities = Modality.objects.filter(is_active=True)
    
    context = {
        'studies': studies[:50],  # Limit for performance
        'stats': stats,
        'modalities': modalities,
        'current_filters': {
            'status': status_filter,
            'modality': modality_filter,
            'date': date_filter,
        }
    }
    
    return render(request, 'worklist/dashboard.html', context)


@login_required
def api_studies(request):
    """API endpoint for studies list"""
    try:
        studies = Study.objects.select_related('patient', 'modality').all()[:50]
        
        data = []
        for study in studies:
            data.append({
                'id': study.id,
                'study_instance_uid': study.study_instance_uid,
                'patient_name': study.patient.patient_name,
                'patient_id': study.patient.patient_id,
                'study_date': study.study_date.isoformat() if study.study_date else None,
                'study_description': study.study_description,
                'modality': study.modality.code if study.modality else '',
                'status': study.status,
                'accession_number': study.accession_number,
                'referring_physician': study.referring_physician,
                'series_count': study.series.count(),
            })
        
        return JsonResponse({'studies': data, 'status': 'success'})
    except Exception as e:
        return JsonResponse({'error': str(e), 'status': 'error'}, status=500)


@login_required
def api_refresh_worklist(request):
    """API endpoint to refresh worklist"""
    try:
        # In a real implementation, this would refresh from PACS
        count = Study.objects.count()
        return JsonResponse({
            'status': 'success',
            'message': f'Worklist refreshed. {count} studies found.',
            'count': count
        })
    except Exception as e:
        return JsonResponse({'error': str(e), 'status': 'error'}, status=500)


@login_required
def api_upload_stats(request):
    """API endpoint for upload statistics"""
    try:
        today = timezone.now().date()
        stats = {
            'today': Study.objects.filter(created_at__date=today).count(),
            'this_week': Study.objects.filter(created_at__week=timezone.now().isocalendar()[1]).count(),
            'total': Study.objects.count(),
        }
        return JsonResponse({'stats': stats, 'status': 'success'})
    except Exception as e:
        return JsonResponse({'error': str(e), 'status': 'error'}, status=500)


@login_required
def study_detail(request, study_id):
    """Study detail view"""
    study = get_object_or_404(Study, id=study_id)
    series_list = study.series.prefetch_related('images').all()
    
    context = {
        'study': study,
        'series_list': series_list,
    }
    
    return render(request, 'worklist/study_detail.html', context)


@login_required
def upload_view(request):
    """DICOM upload view"""
    if request.method == 'POST':
        # Handle file upload
        pass
    
    return render(request, 'worklist/upload.html')


@login_required
@csrf_exempt
def api_study_delete(request, study_id):
    """API endpoint to delete a study"""
    if request.method == 'POST':
        try:
            study = get_object_or_404(Study, id=study_id)
            study_name = f"{study.patient.patient_name} - {study.study_description}"
            study.delete()
            return JsonResponse({
                'status': 'success',
                'message': f'Study "{study_name}" deleted successfully.'
            })
        except Exception as e:
            return JsonResponse({'error': str(e), 'status': 'error'}, status=500)
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)