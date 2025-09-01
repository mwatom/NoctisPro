from django.urls import path
from django.http import JsonResponse

def placeholder_view(request):
    return JsonResponse({'message': 'Reports coming soon'})

app_name = 'reports'
urlpatterns = [
    path('', placeholder_view, name='dashboard'),
]