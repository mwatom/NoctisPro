"""
URL configuration for noctis_pro project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.conf.urls.static import static
from . import views
from django.shortcuts import redirect
from django.http import HttpResponse
from worklist import views as worklist_views
from admin_panel import views as admin_views
from django.views.generic.base import RedirectView
from . import health

def home_redirect(request):
    """Redirect home page to login or dashboard based on authentication"""
    if request.user.is_authenticated:
        # Temporarily redirect all authenticated users to worklist dashboard
        return redirect('worklist:dashboard')
    return redirect('accounts:login')

def favicon_view(request):
    """Return an empty response for favicon requests to avoid 404 errors"""
    return HttpResponse(status=204)  # No content

urlpatterns = [
    # Django admin interface
    path('admin/', admin.site.urls),
    path('favicon.ico', favicon_view, name='favicon'),
    path('', home_redirect, name='home'),
    path('', include('accounts.urls')),
    path('worklist/', include('worklist.urls')),
    # Alias endpoints expected by the dashboard UI
    path('api/studies/', worklist_views.api_studies, name='api_studies_root'),
    path('api/admin/dashboard/', admin_views.api_admin_dashboard, name='api_admin_dashboard'),
    path('admin-panel/api/dashboard/', admin_views.api_admin_dashboard, name='api_admin_dashboard_alt'),
    path('dicom-viewer/', include(('dicom_viewer.urls','dicom_viewer'), namespace='dicom_viewer')),
    path('viewer/', RedirectView.as_view(url='/dicom-viewer/', permanent=False, query_string=True)),
    path('viewer/<path:subpath>/', RedirectView.as_view(url='/dicom-viewer/%(subpath)s/', permanent=False, query_string=True)),
    path('reports/', include('reports.urls')),
    path('admin-panel/', include('admin_panel.urls')),
    path('chat/', include('chat.urls')),  # Re-enabled to fix template URLs
    path('notifications/', include('notifications.urls')),  # Re-enabled to fix template URLs
    path('ai/', include('ai_analysis.urls')),
    
    # Health check endpoints
    path('health/', health.health_check, name='health_check'),
    path('health/simple/', health.simple_health_check, name='simple_health_check'),
    path('health/ready/', health.ready_check, name='ready_check'),
    path('health/live/', health.live_check, name='live_check'),
    
    # Optimized media serving
    re_path(r'^media/(?P<path>.*)$', views.OptimizedMediaView.as_view(), name='optimized_media'),
    path('connection-info/', views.connection_info, name='connection_info'),
]

# Serve media files during development and production (for ngrok deployment)
# Note: In production with a proper web server, this should be handled by nginx/apache
if settings.DEBUG or getattr(settings, 'SERVE_MEDIA_FILES', False):
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
