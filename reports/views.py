from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse, JsonResponse
from django.contrib import messages
from django.db.models import Count, Q
from django.utils import timezone
from .models import Report, ReportTemplate
from worklist.models import Study
from accounts.models import User

@login_required
def report_list(request):
    """List all reports"""
    # Get filter parameters
    search_query = request.GET.get('search', '')
    status_filter = request.GET.get('status', '')
    modality_filter = request.GET.get('modality', '')
    
    # Base queryset
    reports = Report.objects.select_related('study', 'study__patient', 'study__modality', 'radiologist').all()
    
    # Apply filters
    if search_query:
        reports = reports.filter(
            Q(study__patient__first_name__icontains=search_query) |
            Q(study__patient__last_name__icontains=search_query) |
            Q(study__accession_number__icontains=search_query) |
            Q(radiologist__first_name__icontains=search_query) |
            Q(radiologist__last_name__icontains=search_query)
        )
    
    if status_filter:
        reports = reports.filter(status=status_filter)
    
    if modality_filter:
        reports = reports.filter(study__modality__code=modality_filter)
    
    # Order by most recent
    reports = reports.order_by('-report_date')
    
    # Calculate statistics
    total_reports = Report.objects.count()
    draft_reports = Report.objects.filter(status='draft').count()
    pending_reports = Report.objects.filter(status='preliminary').count()
    final_reports = Report.objects.filter(status='final').count()
    
    context = {
        'reports': reports,
        'total_reports': total_reports,
        'draft_reports': draft_reports,
        'pending_reports': pending_reports,
        'final_reports': final_reports,
        'search_query': search_query,
        'status_filter': status_filter,
        'modality_filter': modality_filter,
    }
    
    return render(request, 'reports/report_list.html', context)

@login_required
def write_report(request, study_id):
    """Write report for study"""
    study = get_object_or_404(Study, id=study_id)
    
    # Try to get existing report or create new one
    try:
        report = Report.objects.get(study=study)
        is_new_report = False
    except Report.DoesNotExist:
        report = None
        is_new_report = True
    
    if request.method == 'POST':
        # Get form data
        clinical_history = request.POST.get('clinical_history', '')
        technique = request.POST.get('technique', '')
        comparison = request.POST.get('comparison', '')
        findings = request.POST.get('findings', '')
        impression = request.POST.get('impression', '')
        recommendations = request.POST.get('recommendations', '')
        status = request.POST.get('status', 'draft')
        action = request.POST.get('action', 'save')
        
        if is_new_report:
            # Create new report
            report = Report.objects.create(
                study=study,
                radiologist=request.user,
                clinical_history=clinical_history,
                technique=technique,
                comparison=comparison,
                findings=findings,
                impression=impression,
                recommendations=recommendations,
                status=status
            )
            messages.success(request, 'Report created successfully!')
        else:
            # Update existing report
            report.clinical_history = clinical_history
            report.technique = technique
            report.comparison = comparison
            report.findings = findings
            report.impression = impression
            report.recommendations = recommendations
            report.status = status
            report.last_modified = timezone.now()
            
            # If finalizing the report
            if action == 'submit' and status == 'final':
                report.signed_date = timezone.now()
            
            report.save()
            messages.success(request, 'Report updated successfully!')
        
        # Redirect based on action
        if action == 'submit':
            messages.success(request, 'Report submitted successfully!')
            return redirect('reports:report_list')
        else:
            # Stay on the same page for continued editing
            return redirect('reports:write_report', study_id=study_id)
    
    context = {
        'study': study,
        'report': report,
        'is_new_report': is_new_report,
    }
    
    return render(request, 'reports/write_report.html', context)
