from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse

@login_required
def report_list(request):
    """List all reports"""
    return HttpResponse("Reports List - Coming Soon")

@login_required
def write_report(request, study_id):
    """Write report for study"""
    return HttpResponse(f"Report Writing for Study {study_id} - Coming Soon")
