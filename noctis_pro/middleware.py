"""
Middleware for NoctisPro - Image optimization for slow connections
"""

import os
import io
from PIL import Image
from django.http import HttpResponse, FileResponse
from django.conf import settings
from django.core.files.storage import default_storage
import mimetypes


class ImageOptimizationMiddleware:
    """
    Middleware to optimize images for slow internet connections
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        response = self.get_response(request)
        
        # Check if this is an image request
        if self.should_optimize_image(request, response):
            response = self.optimize_image_response(request, response)
        
        return response
    
    def should_optimize_image(self, request, response):
        """
        Determine if we should optimize this image
        """
        # Check if response is a file response
        if not isinstance(response, (HttpResponse, FileResponse)):
            return False
        
        # Check if it's an image
        content_type = response.get('Content-Type', '')
        if not content_type.startswith('image/'):
            return False
        
        # Check if client wants optimization (from query params)
        optimize = request.GET.get('optimize', 'true').lower()
        if optimize == 'false':
            return False
        
        # Check connection speed hint from query params
        connection = request.GET.get('connection', 'auto').lower()
        
        return True
    
    def optimize_image_response(self, request, response):
        """
        Optimize image based on connection speed and requirements
        """
        try:
            # Get optimization parameters from request
            quality = int(request.GET.get('quality', '70'))  # Default 70% quality
            max_width = int(request.GET.get('max_width', '1920'))
            max_height = int(request.GET.get('max_height', '1080'))
            format_type = request.GET.get('format', 'auto').upper()
            connection = request.GET.get('connection', 'auto').lower()
            
            # Adjust settings based on connection type
            if connection == 'slow':
                quality = min(quality, 50)
                max_width = min(max_width, 800)
                max_height = min(max_height, 600)
            elif connection == 'mobile':
                quality = min(quality, 60)
                max_width = min(max_width, 1200)
                max_height = min(max_height, 800)
            
            # Get image content
            if hasattr(response, 'streaming_content'):
                content = b''.join(response.streaming_content)
            else:
                content = response.content
            
            if not content:
                return response
            
            # Open and process image
            img = Image.open(io.BytesIO(content))
            
            # Convert RGBA to RGB if saving as JPEG
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
            if format_type == 'auto':
                # Use WebP for better compression if supported
                if 'webp' in request.META.get('HTTP_ACCEPT', '').lower():
                    output_format = 'WEBP'
                    content_type = 'image/webp'
                else:
                    output_format = 'JPEG'
                    content_type = 'image/jpeg'
            else:
                output_format = format_type
                content_type = f'image/{format_type.lower()}'
            
            # Save optimized image
            output = io.BytesIO()
            
            if output_format == 'WEBP':
                img.save(output, format='WEBP', quality=quality, optimize=True)
            elif output_format == 'JPEG':
                img.save(output, format='JPEG', quality=quality, optimize=True)
            elif output_format == 'PNG':
                img.save(output, format='PNG', optimize=True)
            else:
                img.save(output, format=output_format, quality=quality if output_format != 'PNG' else None)
            
            # Create optimized response
            optimized_content = output.getvalue()
            optimized_response = HttpResponse(optimized_content, content_type=content_type)
            
            # Copy headers from original response
            for header, value in response.items():
                if header.lower() not in ['content-length', 'content-type']:
                    optimized_response[header] = value
            
            # Add optimization headers
            optimized_response['X-Image-Optimized'] = 'true'
            optimized_response['X-Original-Size'] = str(len(content))
            optimized_response['X-Optimized-Size'] = str(len(optimized_content))
            optimized_response['X-Compression-Ratio'] = f"{(1 - len(optimized_content)/len(content))*100:.1f}%"
            
            # Add cache headers for optimized images
            optimized_response['Cache-Control'] = 'public, max-age=86400'  # 24 hours
            
            return optimized_response
            
        except Exception as e:
            # If optimization fails, return original response
            print(f"Image optimization failed: {e}")
            return response


class SlowConnectionOptimizationMiddleware:
    """
    Middleware to detect slow connections and adjust content accordingly
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        # Detect connection speed from various headers
        self.detect_connection_speed(request)
        
        response = self.get_response(request)
        
        # Add optimization hints to HTML responses
        if response.get('Content-Type', '').startswith('text/html'):
            self.add_optimization_script(request, response)
        
        return response
    
    def detect_connection_speed(self, request):
        """
        Detect connection speed from various indicators
        """
        # Check for explicit connection parameter
        connection = request.GET.get('connection')
        if connection:
            request.connection_speed = connection
            return
        
        # Check for network information from headers
        downlink = request.META.get('HTTP_DOWNLINK')
        effective_type = request.META.get('HTTP_ECT')  # Effective Connection Type
        rtt = request.META.get('HTTP_RTT')  # Round Trip Time
        
        # Estimate connection speed
        if effective_type:
            if effective_type in ['slow-2g', '2g']:
                request.connection_speed = 'slow'
            elif effective_type == '3g':
                request.connection_speed = 'medium'
            else:
                request.connection_speed = 'fast'
        elif downlink:
            try:
                downlink_mbps = float(downlink)
                if downlink_mbps < 1.5:
                    request.connection_speed = 'slow'
                elif downlink_mbps < 10:
                    request.connection_speed = 'medium'
                else:
                    request.connection_speed = 'fast'
            except ValueError:
                request.connection_speed = 'auto'
        else:
            request.connection_speed = 'auto'
    
    def add_optimization_script(self, request, response):
        """
        Add JavaScript for client-side optimization
        """
        if not hasattr(response, 'content'):
            return
        
        connection_speed = getattr(request, 'connection_speed', 'auto')
        
        optimization_script = f"""
        <script>
        // NoctisPro Image Optimization for Slow Connections
        (function() {{
            const connectionSpeed = '{connection_speed}';
            const isSlowConnection = connectionSpeed === 'slow' || 
                                   (navigator.connection && 
                                    navigator.connection.effectiveType && 
                                    ['slow-2g', '2g'].includes(navigator.connection.effectiveType));
            
            // Optimize images based on connection
            function optimizeImages() {{
                const images = document.querySelectorAll('img');
                images.forEach(img => {{
                    if (img.dataset.optimized) return; // Already optimized
                    
                    const src = img.src;
                    if (!src) return;
                    
                    // Add optimization parameters
                    const url = new URL(src, window.location.href);
                    
                    if (isSlowConnection) {{
                        url.searchParams.set('quality', '50');
                        url.searchParams.set('max_width', '800');
                        url.searchParams.set('max_height', '600');
                        url.searchParams.set('connection', 'slow');
                    }} else if (connectionSpeed === 'medium') {{
                        url.searchParams.set('quality', '60');
                        url.searchParams.set('max_width', '1200');
                        url.searchParams.set('connection', 'medium');
                    }}
                    
                    url.searchParams.set('optimize', 'true');
                    
                    // Update image source if different
                    if (url.href !== img.src) {{
                        img.src = url.href;
                        img.dataset.optimized = 'true';
                    }}
                }});
            }}
            
            // Optimize on page load
            if (document.readyState === 'loading') {{
                document.addEventListener('DOMContentLoaded', optimizeImages);
            }} else {{
                optimizeImages();
            }}
            
            // Optimize dynamically loaded images
            const observer = new MutationObserver(function(mutations) {{
                mutations.forEach(function(mutation) {{
                    mutation.addedNodes.forEach(function(node) {{
                        if (node.nodeType === 1) {{ // Element node
                            if (node.tagName === 'IMG') {{
                                setTimeout(optimizeImages, 100);
                            }} else if (node.querySelectorAll) {{
                                const images = node.querySelectorAll('img');
                                if (images.length > 0) {{
                                    setTimeout(optimizeImages, 100);
                                }}
                            }}
                        }}
                    }});
                }});
            }});
            
            observer.observe(document.body, {{
                childList: true,
                subtree: true
            }});
            
            // Add connection info to page
            if (isSlowConnection) {{
                console.log('🐌 Slow connection detected - images will be optimized');
            }}
        }})();
        </script>
        """
        
        # Insert script before closing </body> tag
        content = response.content.decode('utf-8')
        if '</body>' in content:
            content = content.replace('</body>', optimization_script + '</body>')
            response.content = content.encode('utf-8')