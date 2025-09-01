from django.urls import path
from django.http import JsonResponse

def placeholder_view(request):
    return JsonResponse({'message': 'AI Analysis coming soon'})

app_name = 'ai_analysis'
urlpatterns = [
    path('', placeholder_view, name='dashboard'),
]