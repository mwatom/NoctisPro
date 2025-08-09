from django.urls import path
from . import views

app_name = 'dicom_viewer'

urlpatterns = [
    # Main viewer interfaces
    path('', views.viewer, name='viewer'),
    path('study/<int:study_id>/', views.view_study, name='view_study'),
    
    # API endpoints for viewer functionality
    path('api/study/<int:study_id>/data/', views.api_study_data, name='api_study_data'),
    path('api/image/<int:image_id>/data/', views.api_image_data, name='api_image_data'),
    path('api/study/<int:study_id>/measurements/', views.api_measurements, name='api_measurements'),
    path('api/study/<int:study_id>/reconstruction/', views.api_reconstruction, name='api_reconstruction'),
    path('api/hounsfield-units/', views.api_hounsfield_units, name='api_hounsfield_units'),
    path('api/window-level/', views.api_window_level, name='api_window_level'),
    path('api/image/<int:image_id>/export/', views.api_export_image, name='api_export_image'),
    path('api/study/<int:study_id>/annotations/', views.api_annotations, name='api_annotations'),
    path('api/series/<int:series_id>/cine/', views.api_cine_mode, name='api_cine_mode'),
]