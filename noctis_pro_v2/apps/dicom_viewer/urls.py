from django.urls import path
from . import views

app_name = 'dicom_viewer'

urlpatterns = [
    # Main viewer
    path('', views.viewer, name='viewer'),
    
    # API endpoints
    path('api/study/<int:study_id>/', views.api_study_data, name='api_study_data'),
    path('api/image/<int:image_id>/display/', views.api_image_display, name='api_image_display'),
    path('api/measurements/', views.api_measurements, name='api_measurements'),
    path('api/measurements/<int:study_id>/', views.api_measurements, name='api_measurements_study'),
    path('api/calculate-distance/', views.api_calculate_distance, name='api_calculate_distance'),
    
    # Upload
    path('upload/', views.upload_dicom, name='upload_dicom'),
]