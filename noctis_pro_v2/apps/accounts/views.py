from django.shortcuts import render, redirect
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import json


def login_view(request):
    """User login view"""
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        
        if username and password:
            user = authenticate(request, username=username, password=password)
            if user is not None:
                login(request, user)
                next_url = request.GET.get('next', '/worklist/')
                return redirect(next_url)
            else:
                messages.error(request, 'Invalid username or password')
        else:
            messages.error(request, 'Please enter both username and password')
    
    return render(request, 'accounts/login.html')


@login_required
def logout_view(request):
    """User logout view"""
    logout(request)
    return redirect('accounts:login')


@login_required
def profile_view(request):
    """User profile view"""
    return render(request, 'accounts/profile.html', {
        'user': request.user
    })


def register_view(request):
    """User registration view (admin only)"""
    if not request.user.is_superuser:
        messages.error(request, 'Only administrators can register new users')
        return redirect('accounts:login')
    
    if request.method == 'POST':
        # Handle registration logic here
        pass
    
    return render(request, 'accounts/register.html')