from django.urls import path
from . import views
from attachment_viewer import api_view_attachment, attachment_viewer_page, api_attachment_search

app_name = 'worklist'

urlpatterns = [
    # Main worklist interfaces
    path('', views.dashboard, name='dashboard'),
    path('ui/', views.modern_worklist, name='modern_worklist'),
    path('upload/', views.upload_study, name='upload_study'),
    path('studies/', views.study_list, name='study_list'),
    path('study/<int:study_id>/', views.study_detail, name='study_detail'),
    
    # Study attachments
    path('study/<int:study_id>/upload/', views.upload_attachment, name='upload_attachment'),
    path('attachment/<int:attachment_id>/view/', views.view_attachment, name='view_attachment'),
    path('attachment/<int:attachment_id>/comments/', views.attachment_comments, name='attachment_comments'),
    path('attachment/<int:attachment_id>/delete/', views.delete_attachment, name='delete_attachment'),
    
    # Attachment viewer
    path('attachment/<int:attachment_id>/viewer/', attachment_viewer_page, name='attachment_viewer'),
    path('api/attachment/<int:attachment_id>/view/', api_view_attachment, name='api_view_attachment'),
    path('api/attachment/<int:attachment_id>/search/', api_attachment_search, name='api_attachment_search'),
    
    # API endpoints
    path('api/studies/', views.api_studies, name='api_studies'),
    path('api/search-studies/', views.api_search_studies, name='api_search_studies'),
    path('api/study/<int:study_id>/update-status/', views.api_update_study_status, name='api_update_study_status'),
]