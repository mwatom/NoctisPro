from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse

@login_required
def ai_dashboard(request):
    """AI analysis dashboard"""
    return HttpResponse("AI Analysis Dashboard - Coming Soon")

@login_required
def analyze_study(request, study_id):
    """Run AI analysis on study"""
    return HttpResponse(f"AI Analysis for Study {study_id} - Coming Soon")
