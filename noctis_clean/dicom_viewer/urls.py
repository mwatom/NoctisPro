from django.urls import path
from . import views

app_name = 'dicom_viewer'

urlpatterns = [
    path('', views.dicom_viewer, name='viewer'),
    path('api/studies/', views.api_dicom_studies, name='api_studies'),
    path('api/study/<int:study_id>/images/', views.api_study_images, name='api_study_images'),
    path('upload/', views.upload_dicom, name='upload_dicom'),
]