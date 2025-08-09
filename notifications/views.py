from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse, JsonResponse
from .models import Notification

@login_required
def notification_list(request):
    """List notifications"""
    return HttpResponse("Notifications - Coming Soon")

@login_required
def api_notifications(request):
    """API endpoint for notifications"""
    return JsonResponse({'notifications': []})

@login_required
def api_unread_count(request):
    """API endpoint to get unread notifications count"""
    user = request.user
    unread_count = Notification.objects.filter(recipient=user, is_read=False).count()
    return JsonResponse({'count': unread_count})
