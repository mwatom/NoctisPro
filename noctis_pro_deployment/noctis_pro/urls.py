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
from django.shortcuts import redirect
from django.http import HttpResponse
# from worklist import views as worklist_views  # DISABLED - Heavy dependencies
from django.views.generic.base import RedirectView
from . import views

def home_redirect(request):
    """Redirect home page to login or admin panel"""
    if request.user.is_authenticated:
        # Redirect authenticated users to admin panel for now
        return redirect('admin:index')
    return redirect('accounts:login')

def favicon_view(request):
    """Return an empty response for favicon requests to avoid 404 errors"""
    return HttpResponse(status=204)  # No content

urlpatterns = [
    # ULTRA MINIMAL - Core Django only
    path('admin/', admin.site.urls),
    path('favicon.ico', favicon_view, name='favicon'),
    path('', home_redirect, name='home'),
    path('', include('accounts.urls')),
    # ALL OTHER FEATURES DISABLED TO SHOW CLEAN REFINED SYSTEM
    # path('admin-panel/', include('admin_panel.urls')),  # DISABLED
    # path('worklist/', include('worklist.urls')),  # DISABLED
    # path('dicom-viewer/', include(('dicom_viewer.urls','dicom_viewer'), namespace='dicom_viewer')),  # DISABLED
    # path('reports/', include('reports.urls')),  # DISABLED
    # path('chat/', include('chat.urls')),  # DISABLED
    # path('notifications/', include('notifications.urls')),  # DISABLED
    # path('ai/', include('ai_analysis.urls')),  # DISABLED
]

# Serve media files during development and production (for ngrok deployment)
# Note: In production with a proper web server, this should be handled by nginx/apache
if settings.DEBUG or getattr(settings, 'SERVE_MEDIA_FILES', False):
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    # Use custom static file view for proper MIME type handling
    urlpatterns += [
        re_path(r'^static/(?P<path>.*)$', views.StaticFileView.as_view(), name='static_files'),
    ]
