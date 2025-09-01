from django.urls import path
from . import views

app_name = 'dicom_viewer'

urlpatterns = [
    # Main viewer entry point
    path('', views.viewer, name='viewer'),
    
    # API endpoints for professional DICOM viewer
    path('api/studies/', views.api_studies_list, name='api_studies_list'),
    path('api/study/<int:study_id>/', views.api_study_data, name='api_study_data'),
    path('api/image/<int:image_id>/display/', views.api_image_display, name='api_image_display'),
    
    # Demo endpoints - available but not prioritized in production
    # path('api/study/<int:study_id>/bulletproof/', views.api_study_data_bulletproof, name='api_study_data_bulletproof'),
    # path('api/image/<int:image_id>/display/bulletproof/', views.api_image_display_bulletproof, name='api_image_display_bulletproof'),
    
    # Basic reconstruction
    path('api/mpr/<int:series_id>/', views.api_mpr_reconstruction, name='api_mpr_reconstruction'),
    path('api/mip/<int:series_id>/', views.api_mip_reconstruction, name='api_mip_reconstruction'),
    path('api/bone/<int:series_id>/', views.api_bone_reconstruction, name='api_bone_reconstruction'),
    path('api/series/<int:series_id>/volume/', views.api_volume_reconstruction, name='api_volume_reconstruction'),
    
    # Advanced modality-specific reconstruction
    path('api/mri/<int:series_id>/', views.api_mri_reconstruction, name='api_mri_reconstruction'),
    path('api/pet/<int:series_id>/', views.api_pet_reconstruction, name='api_pet_reconstruction'),
    path('api/spect/<int:series_id>/', views.api_spect_reconstruction, name='api_spect_reconstruction'),
    path('api/nuclear/<int:series_id>/', views.api_nuclear_reconstruction, name='api_nuclear_reconstruction'),
    path('api/modality-options/<int:series_id>/', views.api_modality_reconstruction_options, name='api_modality_options'),
    
    # Utility endpoints
    path('api/hounsfield/', views.api_hounsfield_units, name='api_hounsfield_units'),
    path('api/hu/', views.api_hu_value, name='api_hu_value'),
    path('api/calculate-distance/', views.api_calculate_distance, name='api_calculate_distance'),
    path('api/measurements/<int:study_id>/', views.api_measurements, name='api_measurements'),
    path('api/measurements/', views.api_measurements, name='api_measurements_standalone'),
    
    # Upload endpoint
    path('upload/', views.upload_dicom, name='upload_dicom'),
    
    # Web viewer endpoints
    path('web/series/<int:series_id>/images/', views.web_series_images, name='web_series_images'),
    # path('web/series/<int:series_id>/images/bulletproof/', views.web_series_images_bulletproof, name='web_series_images_bulletproof'),
    
    # HU Calibration endpoints
    path('hu-calibration/', views.hu_calibration_dashboard, name='hu_calibration_dashboard'),
    path('hu-calibration/phantoms/', views.manage_qa_phantoms, name='manage_qa_phantoms'),
    
    # Legacy redirects to new viewer
    path('standalone/', views.launch_standalone_viewer, name='launch_standalone_viewer'),
    path('study/<int:study_id>/', views.launch_study_in_desktop_viewer, name='launch_study_in_desktop_viewer'),
    path('web/', views.web_index, name='web_index'),
    path('web/viewer/', views.web_viewer, name='web_viewer'),
]