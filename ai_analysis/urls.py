from django.urls import path
from . import views

app_name = 'ai_analysis'

urlpatterns = [
    path('', views.ai_dashboard, name='ai_dashboard'),
    path('analyze/<int:study_id>/', views.analyze_study, name='analyze_study'),
]