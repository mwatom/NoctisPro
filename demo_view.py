from django.shortcuts import render
from django.http import JsonResponse
from django.contrib.auth.decorators import login_required
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth import authenticate, login
import json

def demo_page(request):
    """Demo page showcasing Noctis Pro PACS v2 features"""
    context = {
        'title': 'Noctis Pro PACS v2.0 - Medical Imaging Masterpiece',
        'features': [
            {
                'name': 'DICOM Viewer',
                'description': 'Advanced DICOM image viewing with windowing, zoom, pan, and measurement tools',
                'icon': 'fas fa-images',
                'url': '/dicom-viewer/'
            },
            {
                'name': 'Worklist Management',
                'description': 'Complete DICOM worklist management with study scheduling and tracking',
                'icon': 'fas fa-list-ul',
                'url': '/worklist/'
            },
            {
                'name': 'AI Analysis',
                'description': 'AI-powered medical image analysis and automated reporting',
                'icon': 'fas fa-brain',
                'url': '/ai-analysis/'
            },
            {
                'name': 'Admin Panel',
                'description': 'Comprehensive administration interface for system management',
                'icon': 'fas fa-cogs',
                'url': '/admin/'
            },
            {
                'name': 'Reports & Analytics',
                'description': 'Advanced reporting and analytics dashboard',
                'icon': 'fas fa-chart-line',
                'url': '/reports/'
            },
            {
                'name': 'User Management',
                'description': 'Complete user and role management system',
                'icon': 'fas fa-users',
                'url': '/accounts/'
            }
        ],
        'stats': {
            'total_studies': 1247,
            'active_users': 15,
            'processed_images': 45632,
            'ai_analyses': 892
        }
    }
    return render(request, 'demo.html', context)

@csrf_exempt
def api_demo(request):
    """API endpoint for testing"""
    return JsonResponse({
        'status': 'success',
        'message': 'Noctis Pro PACS v2.0 API is fully operational',
        'version': '2.0.0',
        'features': ['DICOM Processing', 'AI Analysis', 'Worklist Management', 'User Authentication']
    })