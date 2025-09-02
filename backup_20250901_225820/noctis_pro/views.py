"""
Views for NoctisPro core functionality
"""

import os
import mimetypes
from django.http import HttpResponse, Http404, FileResponse
from django.conf import settings
from django.views.decorators.cache import cache_control
from django.views.decorators.http import require_http_methods
from django.utils.decorators import method_decorator
from django.views import View
from PIL import Image
import io


class OptimizedMediaView(View):
    """
    Serve media files with optimization for slow connections
    """
    
    @method_decorator(cache_control(max_age=86400))  # 24 hours cache
    def get(self, request, path):
        """
        Serve optimized media file
        """
        # Security check - prevent directory traversal
        if '..' in path or path.startswith('/'):
            raise Http404("File not found")
        
        file_path = os.path.join(settings.MEDIA_ROOT, path)
        
        # Check if file exists
        if not os.path.exists(file_path):
            raise Http404("File not found")
        
        # Get MIME type
        content_type, _ = mimetypes.guess_type(file_path)
        
        # If it's an image and optimization is enabled, optimize it
        if (content_type and content_type.startswith('image/') and 
            getattr(settings, 'IMAGE_OPTIMIZATION', {}).get('ENABLE', False)):
            
            return self.serve_optimized_image(request, file_path, content_type)
        
        # Serve regular file
        return FileResponse(open(file_path, 'rb'), content_type=content_type)
    
    def serve_optimized_image(self, request, file_path, content_type):
        """
        Serve optimized image based on connection speed
        """
        try:
            # Get optimization parameters
            quality = int(request.GET.get('quality', settings.IMAGE_OPTIMIZATION.get('DEFAULT_QUALITY', 70)))
            max_width = int(request.GET.get('max_width', settings.IMAGE_OPTIMIZATION.get('MAX_WIDTH', 1920)))
            max_height = int(request.GET.get('max_height', settings.IMAGE_OPTIMIZATION.get('MAX_HEIGHT', 1080)))
            format_type = request.GET.get('format', 'auto').upper()
            connection = request.GET.get('connection', getattr(request, 'connection_speed', 'auto')).lower()
            
            # Adjust for slow connections
            if connection == 'slow':
                quality = min(quality, settings.IMAGE_OPTIMIZATION.get('SLOW_CONNECTION_QUALITY', 50))
                max_width = min(max_width, settings.IMAGE_OPTIMIZATION.get('SLOW_CONNECTION_MAX_WIDTH', 800))
                max_height = min(max_height, settings.IMAGE_OPTIMIZATION.get('SLOW_CONNECTION_MAX_HEIGHT', 600))
            
            # Open and process image
            with open(file_path, 'rb') as f:
                img = Image.open(f)
                img = img.copy()  # Copy to avoid file handle issues
            
            # Convert RGBA to RGB if needed
            if img.mode in ('RGBA', 'LA') and format_type in ('JPEG', 'auto'):
                background = Image.new('RGB', img.size, (255, 255, 255))
                if img.mode == 'LA':
                    img = img.convert('RGBA')
                background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
                img = background
            
            # Resize if needed
            if img.width > max_width or img.height > max_height:
                img.thumbnail((max_width, max_height), Image.Resampling.LANCZOS)
            
            # Determine output format
            if format_type == 'AUTO':
                # Use WebP for better compression if supported
                if 'webp' in request.META.get('HTTP_ACCEPT', '').lower():
                    output_format = 'WEBP'
                    response_content_type = 'image/webp'
                else:
                    output_format = 'JPEG'
                    response_content_type = 'image/jpeg'
            else:
                output_format = format_type
                response_content_type = f'image/{format_type.lower()}'
            
            # Save optimized image
            output = io.BytesIO()
            
            if output_format == 'WEBP':
                img.save(output, format='WEBP', quality=quality, optimize=True)
            elif output_format == 'JPEG':
                img.save(output, format='JPEG', quality=quality, optimize=True)
            elif output_format == 'PNG':
                img.save(output, format='PNG', optimize=True)
            
            # Create response
            output.seek(0)
            response = HttpResponse(output.getvalue(), content_type=response_content_type)
            
            # Add optimization headers
            response['X-Image-Optimized'] = 'true'
            response['X-Optimization-Quality'] = str(quality)
            response['X-Optimization-Size'] = f"{img.width}x{img.height}"
            response['X-Connection-Speed'] = connection
            
            return response
            
        except Exception as e:
            # If optimization fails, serve original file
            print(f"Image optimization failed for {file_path}: {e}")
            return FileResponse(open(file_path, 'rb'), content_type=content_type)


@require_http_methods(["GET"])
def connection_info(request):
    """
    Return connection information for debugging
    """
    connection_speed = getattr(request, 'connection_speed', 'unknown')
    
    info = {
        'connection_speed': connection_speed,
        'headers': {
            'downlink': request.META.get('HTTP_DOWNLINK'),
            'ect': request.META.get('HTTP_ECT'),
            'rtt': request.META.get('HTTP_RTT'),
            'user_agent': request.META.get('HTTP_USER_AGENT'),
        },
        'optimization_active': getattr(settings, 'IMAGE_OPTIMIZATION', {}).get('ENABLE', False),
    }
    
    return HttpResponse(
        f"<h1>Connection Info</h1><pre>{info}</pre>",
        content_type='text/html'
    )