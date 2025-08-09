from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse

@login_required
def dashboard(request):
    """Admin dashboard"""
    return HttpResponse("Admin Dashboard - Coming Soon")

@login_required
def user_management(request):
    """User management interface"""
    return HttpResponse("User Management - Coming Soon")

@login_required
def facility_management(request):
    """Facility management interface"""
    return HttpResponse("Facility Management - Coming Soon")

@login_required
def invoice_management(request):
    """Invoice management interface"""
    return HttpResponse("Invoice Management - Coming Soon")
