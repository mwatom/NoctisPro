from django.urls import path
from . import views

app_name = 'worklist'

urlpatterns = [
    # Main views
    path('', views.dashboard, name='dashboard'),
    path('study/<int:study_id>/', views.study_detail, name='study_detail'),
    path('upload/', views.upload_view, name='upload'),
    
    # API endpoints
    path('api/studies/', views.api_studies, name='api_studies'),
    path('api/refresh-worklist/', views.api_refresh_worklist, name='api_refresh_worklist'),
    path('api/upload-stats/', views.api_upload_stats, name='api_upload_stats'),
    path('api/study/<int:study_id>/delete/', views.api_study_delete, name='api_study_delete'),
]