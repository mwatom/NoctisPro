from django.urls import path
from . import views

app_name = 'worklist'

urlpatterns = [
    path('', views.dashboard, name='dashboard'),
    path('studies/', views.study_list, name='study_list'),
    path('upload/', views.upload_study, name='upload_study'),
    path('api/studies/', views.api_studies, name='api_studies'),
]