from django.urls import path
from . import views

app_name = 'admin_panel'

urlpatterns = [
    path('', views.dashboard, name='dashboard'),
    
    # User management
    path('users/', views.user_management, name='user_management'),
    path('users/create/', views.user_create, name='user_create'),
    path('users/edit/<int:user_id>/', views.user_edit, name='user_edit'),
    path('users/delete/<int:user_id>/', views.user_delete, name='user_delete'),
    path('users/bulk-action/', views.bulk_user_action, name='bulk_user_action'),
    
    # Facility management
    path('facilities/', views.facility_management, name='facility_management'),
    path('facilities/create/', views.facility_create, name='facility_create'),
    path('facilities/edit/<int:facility_id>/', views.facility_edit, name='facility_edit'),
    path('facilities/delete/<int:facility_id>/', views.facility_delete, name='facility_delete'),
    path('facilities/bulk-action/', views.bulk_facility_action, name='bulk_facility_action'),

    # API endpoints
    path('api/dashboard/', views.api_admin_dashboard, name='api_admin_dashboard'),
    
    # Placeholder routes referenced by templates
    path('logs/', views.system_logs, name='system_logs'),
    path('settings/', views.settings_view, name='settings'),
]