from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse, JsonResponse

@login_required
def notification_list(request):
    """List notifications"""
    return HttpResponse("Notifications - Coming Soon")

@login_required
def api_notifications(request):
    """API endpoint for notifications"""
    return JsonResponse({'notifications': []})
