"""
NoctisPro V2 URL Configuration
Clean and organized routing with universal DICOM viewer integration
"""
from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.conf.urls.static import static
from django.shortcuts import redirect
from django.http import HttpResponse
from django.views.generic.base import RedirectView

def home_redirect(request):
    """Redirect home page to login or dashboard based on authentication"""
    if request.user.is_authenticated:
        return redirect('worklist:dashboard')
    return redirect('accounts:login')

def favicon_view(request):
    """Return an empty response for favicon requests to avoid 404 errors"""
    return HttpResponse(status=204)  # No content

def health_check(request):
    """Simple health check endpoint"""
    return HttpResponse('OK', content_type='text/plain')

urlpatterns = [
    # Admin interface
    path('admin/', admin.site.urls),
    
    # Favicon
    path('favicon.ico', favicon_view, name='favicon'),
    
    # Health check
    path('health/', health_check, name='health_check'),
    path('health/simple/', health_check, name='simple_health_check'),
    
    # Home redirect
    path('', home_redirect, name='home'),
    
    # Authentication
    path('', include('apps.accounts.urls')),
    
    # Main applications
    path('worklist/', include('apps.worklist.urls')),
    path('dicom-viewer/', include('apps.dicom_viewer.urls')),
    path('admin-panel/', include('apps.admin_panel.urls')),
    path('reports/', include('apps.reports.urls')),
    path('notifications/', include('apps.notifications.urls')),
    path('chat/', include('apps.chat.urls')),
    path('ai/', include('apps.ai_analysis.urls')),
    
    # API endpoints (for backwards compatibility)
    path('api/studies/', include(('apps.worklist.urls', 'worklist_api'), namespace='worklist_api')),
    
    # Legacy redirects
    path('viewer/', RedirectView.as_view(url='/dicom-viewer/', permanent=False)),
]

# Serve media files during development and production
if settings.DEBUG or True:  # Always serve media for ngrok deployment
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)