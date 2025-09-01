from django.shortcuts import render, redirect
from django.contrib.auth import authenticate, login, logout
from django.contrib import messages
from django.http import HttpResponse

def login_view(request):
    """Simple, bulletproof login view"""
    if request.user.is_authenticated:
        return redirect('/worklist/')
    
    if request.method == 'POST':
        username = request.POST.get('username', '').strip()
        password = request.POST.get('password', '')
        
        if username and password:
            user = authenticate(request, username=username, password=password)
            if user is not None:
                login(request, user)
                return redirect('/worklist/')
            else:
                messages.error(request, 'Invalid username or password.')
        else:
            messages.error(request, 'Please enter both username and password.')
    
    return render(request, 'accounts/login.html')

def logout_view(request):
    """Simple logout view"""
    logout(request)
    return redirect('/login/')