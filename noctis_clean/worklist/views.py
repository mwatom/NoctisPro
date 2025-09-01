from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.core.paginator import Paginator
from .models import Study
import json
from datetime import datetime

@login_required
def dashboard(request):
    """Main dashboard view"""
    studies = Study.objects.all()
    
    # Statistics
    total_studies = studies.count()
    pending_studies = studies.filter(status='pending').count()
    in_progress_studies = studies.filter(status='in_progress').count()
    completed_studies = studies.filter(status='completed').count()
    urgent_studies = studies.filter(priority='urgent').count()
    
    context = {
        'total_studies': total_studies,
        'pending_studies': pending_studies,
        'in_progress_studies': in_progress_studies,
        'completed_studies': completed_studies,
        'urgent_studies': urgent_studies,
        'recent_studies': studies[:10],
    }
    
    return render(request, 'worklist/dashboard.html', context)

@login_required
def study_list(request):
    """Study list view with pagination"""
    studies = Study.objects.all()
    
    # Filtering
    status_filter = request.GET.get('status')
    if status_filter:
        studies = studies.filter(status=status_filter)
    
    modality_filter = request.GET.get('modality')
    if modality_filter:
        studies = studies.filter(modality=modality_filter)
    
    # Pagination
    paginator = Paginator(studies, 20)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'page_obj': page_obj,
        'status_filter': status_filter,
        'modality_filter': modality_filter,
    }
    
    return render(request, 'worklist/study_list.html', context)

@login_required
def upload_study(request):
    """Upload new study"""
    if request.method == 'POST':
        try:
            study = Study.objects.create(
                patient_name=request.POST.get('patient_name', ''),
                patient_id=request.POST.get('patient_id', ''),
                study_uid=f"STUDY_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{request.user.id}",
                study_description=request.POST.get('study_description', ''),
                modality=request.POST.get('modality', 'CT'),
                referring_physician=request.POST.get('referring_physician', ''),
                assigned_to=request.user,
            )
            return redirect('worklist:dashboard')
        except Exception as e:
            return HttpResponse(f'Error creating study: {str(e)}', status=500)
    
    return render(request, 'worklist/upload_study.html')

@csrf_exempt
def api_studies(request):
    """API endpoint for studies"""
    if request.method == 'GET':
        studies = Study.objects.all()
        data = []
        for study in studies:
            data.append({
                'id': study.id,
                'patient_name': study.patient_name,
                'patient_id': study.patient_id,
                'study_date': study.study_date.isoformat(),
                'modality': study.modality,
                'status': study.status,
                'priority': study.priority,
                'study_description': study.study_description,
            })
        return JsonResponse({'studies': data})
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)