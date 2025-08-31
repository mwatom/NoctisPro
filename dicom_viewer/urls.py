from django.urls import path
from . import views

app_name = 'dicom_viewer'

urlpatterns = [
    # Main viewer entry point
    path('', views.viewer, name='viewer'),
    
    # API endpoints for professional DICOM viewer
    path('api/study/<int:study_id>/', views.api_study_data, name='api_study_data'),
    path('api/image/<int:image_id>/display/', views.api_image_display, name='api_image_display'),
    path('api/mpr/<int:series_id>/', views.api_mpr_reconstruction, name='api_mpr_reconstruction'),
    path('api/mip/<int:series_id>/', views.api_mip_reconstruction, name='api_mip_reconstruction'),
    path('api/bone/<int:series_id>/', views.api_bone_reconstruction, name='api_bone_reconstruction'),
    path('api/hounsfield/', views.api_hounsfield_units, name='api_hounsfield_units'),
    path('api/calculate-distance/', views.api_calculate_distance, name='api_calculate_distance'),
    path('api/measurements/<int:study_id>/', views.api_measurements, name='api_measurements'),
    path('api/measurements/', views.api_measurements, name='api_measurements_standalone'),
    
    # Upload endpoint
    path('upload/', views.upload_dicom, name='upload_dicom'),
    
    # Web viewer endpoints
    path('web/series/<int:series_id>/images/', views.web_series_images, name='web_series_images'),
    
    # Legacy redirects to new viewer
    path('standalone/', views.launch_standalone_viewer, name='launch_standalone_viewer'),
    path('study/<int:study_id>/', views.launch_study_in_desktop_viewer, name='launch_study_in_desktop_viewer'),
    path('web/', views.web_index, name='web_index'),
    path('web/viewer/', views.web_viewer, name='web_viewer'),
]