from django.urls import path
from . import views

app_name = 'chat'

urlpatterns = [
    path('', views.chat_rooms, name='chat_rooms'),
    path('room/<str:room_id>/', views.chat_room, name='chat_room'),
]