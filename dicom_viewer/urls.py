from django.urls import path
from . import views

app_name = 'dicom_viewer'

urlpatterns = [
    # Main viewer interface
    path('', views.viewer, name='viewer'),
    path('launch-desktop/', views.launch_standalone_viewer, name='launch_standalone_viewer'),
    path('launch-desktop/<int:study_id>/', views.launch_study_in_desktop_viewer, name='launch_study_in_desktop_viewer'),
    
    # API endpoints
    path('api/studies/', views.api_studies_list, name='api_studies_list'),
    path('api/study/<int:study_id>/', views.api_study_data, name='api_study_data'),
    path('api/study/<int:study_id>/data/', views.api_study_data, name='api_study_data_alt'),
    path('api/image/<int:image_id>/display/', views.api_image_display, name='api_image_display'),
    path('api/image/<int:image_id>/', views.api_image_display, name='api_image_display_alt'),
    
    # Advanced reconstruction endpoints
    path('api/mpr/<int:series_id>/', views.api_mpr_reconstruction, name='api_mpr_reconstruction'),
    path('api/mpr/<int:series_id>/update/', views.api_mpr_update, name='api_mpr_update'),
    path('api/mip/<int:series_id>/', views.api_mip_reconstruction, name='api_mip_reconstruction'),
    path('api/bone/<int:series_id>/', views.api_bone_reconstruction, name='api_bone_reconstruction'),
    path('api/series/<int:series_id>/mpr/', views.api_mpr_reconstruction, name='api_series_mpr_reconstruction'),
    path('api/series/<int:series_id>/mip/', views.api_mip_reconstruction, name='api_series_mip_reconstruction'),
    path('api/series/<int:series_id>/bone/', views.api_bone_reconstruction, name='api_series_bone_reconstruction'),
    path('api/series/<int:series_id>/volume/', views.api_volume_reconstruction, name='api_volume_reconstruction'),
    path('api/hu/', views.api_hu_value, name='api_hu_value'),
    
    # Advanced modality-specific reconstruction
    path('api/mri/<int:series_id>/', views.api_mri_reconstruction, name='api_mri_reconstruction'),
    path('api/pet/<int:series_id>/', views.api_pet_reconstruction, name='api_pet_reconstruction'),
    path('api/spect/<int:series_id>/', views.api_spect_reconstruction, name='api_spect_reconstruction'),
    path('api/nuclear/<int:series_id>/', views.api_nuclear_reconstruction, name='api_nuclear_reconstruction'),
    path('api/modality-options/<int:series_id>/', views.api_modality_reconstruction_options, name='api_modality_options'),
    
    # Measurements and utilities
    path('api/study/<int:study_id>/measurements/', views.api_measurements, name='api_measurements'),
    path('api/measurements/', views.api_measurements, name='api_measurements_standalone'),
    path('api/measurement/<int:measurement_id>/delete/', views.api_delete_measurement, name='api_delete_measurement'),
    path('api/calculate-distance/', views.api_calculate_distance, name='api_calculate_distance'),
    path('api/hounsfield/', views.api_hounsfield_units, name='api_hounsfield_units'),
    
    # DICOM file upload
    path('upload/', views.upload_dicom, name='upload_dicom'),
    path('api/upload/progress/<str:upload_id>/', views.api_upload_progress, name='api_upload_progress'),
    
    # HU Calibration (basic)
    path('hu-calibration/', views.hu_calibration_dashboard, name='hu_calibration_dashboard'),
]

urlpatterns += [
    # Web viewer pages
    path('web/', views.web_index, name='web_index'),
    path('web/viewer/', views.web_viewer, name='web_viewer'),
    path('web/series/<int:series_id>/images/', views.web_series_images, name='web_series_images'),
    
    # Legacy redirects to new viewer
    path('standalone/', views.launch_standalone_viewer, name='launch_standalone_viewer_legacy'),
    path('study/<int:study_id>/', views.launch_study_in_desktop_viewer, name='launch_study_in_desktop_viewer_legacy'),
]