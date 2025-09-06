from django.urls import path
from django.http import JsonResponse

def placeholder_view(request):
    return JsonResponse({'message': 'Chat coming soon'})

app_name = 'chat'
urlpatterns = [
    path('', placeholder_view, name='dashboard'),
]