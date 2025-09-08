from django.urls import path
from django.http import JsonResponse

def placeholder_view(request):
    return JsonResponse({'message': 'Admin panel coming soon'})

app_name = 'admin_panel'
urlpatterns = [
    path('', placeholder_view, name='dashboard'),
]