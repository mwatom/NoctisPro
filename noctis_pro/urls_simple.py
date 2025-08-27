"""
Simplified URL configuration for ngrok demo
"""
from django.contrib import admin
from django.urls import path, include
from django.http import HttpResponse

def home_view(request):
    return HttpResponse("""
    <html>
    <head><title>NoctisPro - Ngrok Demo</title></head>
    <body>
        <h1>🌟 NoctisPro Medical Imaging Platform</h1>
        <h2>🌐 Successfully running via ngrok!</h2>
        
        <div style="margin: 20px; padding: 20px; border: 1px solid #ccc; border-radius: 5px;">
            <h3>✅ Application Status</h3>
            <p><strong>✓</strong> Django server is running</p>
            <p><strong>✓</strong> ngrok tunnel is active</p>
            <p><strong>✓</strong> Internet access enabled</p>
        </div>
        
        <div style="margin: 20px;">
            <h3>🔗 Available Endpoints</h3>
            <ul>
                <li><a href="/admin/">Admin Panel</a></li>
                <li><a href="/api/">API Root</a> (if implemented)</li>
                <li><a href="/health/">Health Check</a></li>
            </ul>
        </div>
        
        <div style="margin: 20px; font-style: italic; color: #666;">
            <p>This is a simplified version of NoctisPro running for ngrok demonstration.</p>
            <p>The full application includes DICOM viewing, worklist management, and AI analysis features.</p>
        </div>
    </body>
    </html>
    """)

def health_view(request):
    return HttpResponse("OK - NoctisPro is healthy!", content_type="text/plain")

urlpatterns = [
    path('admin/', admin.site.urls),
    path('health/', health_view, name='health'),
    path('', home_view, name='home'),
]