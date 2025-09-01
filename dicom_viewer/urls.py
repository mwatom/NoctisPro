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
    path('api/image/<int:image_id>/data/', views.api_image_data, name='api_image_data'),
    path('api/image/<int:image_id>/display/', views.api_image_display, name='api_image_display'),
    path('api/image/<int:image_id>/display/', views.api_dicom_image_display, name='api_dicom_image_display'),
    
    # Advanced reconstruction endpoints
    path('api/mpr/<int:series_id>/', views.api_mpr_reconstruction, name='api_mpr_reconstruction'),
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
    
    # Hounsfield Unit Calibration
    path('hu-calibration/', views.hu_calibration_dashboard, name='hu_calibration_dashboard'),
    path('hu-calibration/validate/<int:study_id>/', views.validate_hu_calibration, name='validate_hu_calibration'),
    path('hu-calibration/report/<int:calibration_id>/', views.hu_calibration_report, name='hu_calibration_report'),
    path('hu-calibration/phantoms/', views.manage_qa_phantoms, name='manage_qa_phantoms'),
    
    # Real-time features
    path('api/realtime/studies/', views.api_realtime_studies, name='api_realtime_studies'),
    path('api/study/<int:study_id>/progress/', views.api_study_progress, name='api_study_progress'),
    
    # Measurements and annotations
    path('api/study/<int:study_id>/measurements/', views.api_measurements, name='api_measurements'),
    path('api/measurements/', views.api_measurements, name='api_measurements_standalone'),
    path('api/calculate-distance/', views.api_calculate_distance, name='api_calculate_distance'),
    path('api/study/<int:study_id>/annotations/', views.api_annotations, name='api_annotations'),
    
    # Presets and hanging protocols
    path('api/presets/', views.api_user_presets, name='api_user_presets'),
    path('api/hanging/', views.api_hanging_protocols, name='api_hanging_protocols'),
    
    # DICOM SR export
    path('api/study/<int:study_id>/export-sr/', views.api_export_dicom_sr, name='api_export_dicom_sr'),
    
    # Volume endpoint for GPU VR
    path('api/series/<int:series_id>/volume/', views.api_series_volume_uint8, name='api_series_volume_uint8'),
    
    # DICOM file upload and processing
    path('upload/', views.upload_dicom, name='upload_dicom'),
    path('api/upload/progress/<str:upload_id>/', views.api_upload_progress, name='api_upload_progress'),
    path('api/process/study/<int:study_id>/', views.api_process_study, name='api_process_study'),

    # Removed C++ desktop viewer integration endpoints
    
    # Print endpoints
    path('print/', views.print_dicom_image, name='print_dicom_image'),
    path('print/printers/', views.get_available_printers, name='get_available_printers'),
    path('print/settings/', views.print_settings_view, name='print_settings_view'),
    path('print/layouts/', views.get_print_layouts, name='get_print_layouts'),
]

urlpatterns += [
    # Web viewer pages
    path('web/', views.web_index, name='web_index'),
    path('web/viewer/', views.web_viewer, name='web_viewer'),

    # Web viewer JSON APIs
    path('study/<int:study_id>/', views.web_study_detail, name='web_study_detail'),
    path('web/series/<int:series_id>/images/', views.web_series_images, name='web_series_images'),
    path('api/reconstruction/types/', views.api_reconstruction_types, name='api_reconstruction_types'),
    path('api/reconstruction/<str:type>/<int:series_id>/', views.api_reconstruction_data, name='api_reconstruction_data'),
    
    # Legacy redirects to new viewer
    path('standalone/', views.launch_standalone_viewer, name='launch_standalone_viewer_legacy'),
    path('study/<int:study_id>/', views.launch_study_in_desktop_viewer, name='launch_study_in_desktop_viewer_legacy'),
]