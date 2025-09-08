from django.urls import path
from django.http import JsonResponse

def placeholder_view(request):
    return JsonResponse({'message': 'Notifications coming soon'})

app_name = 'notifications'
urlpatterns = [
    path('', placeholder_view, name='dashboard'),
]