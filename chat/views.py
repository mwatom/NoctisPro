from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse

# Create your views here.

@login_required
def chat_rooms(request):
    """List chat rooms"""
    return HttpResponse("Chat Rooms - Coming Soon")

@login_required
def chat_room(request, room_id):
    """Individual chat room"""
    return HttpResponse(f"Chat Room {room_id} - Coming Soon")
