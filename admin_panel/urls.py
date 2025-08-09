from django.urls import path
from . import views

app_name = 'admin_panel'

urlpatterns = [
    path('', views.dashboard, name='dashboard'),
    path('users/', views.user_management, name='user_management'),
    path('facilities/', views.facility_management, name='facility_management'),
    path('invoices/', views.invoice_management, name='invoice_management'),
]