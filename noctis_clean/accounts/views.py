from django.shortcuts import render, redirect
from django.contrib.auth import authenticate, login, logout
from django.contrib import messages
from django.http import HttpResponse

def login_view(request):
    """Simple, bulletproof login view"""
    if request.user.is_authenticated:
        return HttpResponse('<html><body><h1>✅ Already Logged In!</h1><p><a href="/worklist/">Go to Dashboard</a></p></body></html>')
    
    if request.method == 'POST':
        username = request.POST.get('username', '').strip()
        password = request.POST.get('password', '')
        
        if username and password:
            user = authenticate(request, username=username, password=password)
            if user is not None:
                login(request, user)
                return HttpResponse(f'<html><body><h1>✅ Login Successful!</h1><p>Welcome {user.username}!</p><p><a href="/worklist/">Continue to Dashboard</a></p></body></html>')
            else:
                messages.error(request, 'Invalid username or password.')
        else:
            messages.error(request, 'Please enter both username and password.')
    
    return render(request, 'accounts/login.html')

def logout_view(request):
    """Simple logout view"""
    logout(request)
    return HttpResponse('<html><body><h1>✅ Logged Out!</h1><p><a href="/login/">Login Again</a></p></body></html>')