from django.shortcuts import render, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse, HttpResponse, Http404
from django.views.decorators.csrf import csrf_exempt
from django.core.files.storage import default_storage
from django.conf import settings
from worklist.models import Study
from .models import DicomImage
import os
import json
import numpy as np

try:
    import pydicom
    from PIL import Image
    DICOM_AVAILABLE = True
except ImportError:
    DICOM_AVAILABLE = False

@login_required
def dicom_viewer(request):
    """Main DICOM viewer interface"""
    studies = Study.objects.all()
    
    context = {
        'studies': studies,
        'dicom_available': DICOM_AVAILABLE,
    }
    
    return render(request, 'dicom_viewer/viewer.html', context)

@csrf_exempt
def api_dicom_studies(request):
    """API endpoint for DICOM studies"""
    if request.method == 'GET':
        studies = Study.objects.filter(dicom_images__isnull=False).distinct()
        data = []
        
        for study in studies:
            image_count = study.dicom_images.count()
            data.append({
                'id': study.id,
                'patient_name': study.patient_name,
                'patient_id': study.patient_id,
                'study_date': study.study_date.isoformat(),
                'modality': study.modality,
                'study_description': study.study_description,
                'image_count': image_count,
            })
        
        return JsonResponse({'studies': data})
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)

@csrf_exempt
def api_study_images(request, study_id):
    """API endpoint for study images"""
    if request.method == 'GET':
        study = get_object_or_404(Study, id=study_id)
        images = study.dicom_images.all()
        
        data = []
        for image in images:
            # Create sample image data for demonstration
            image_data = {
                'id': image.id,
                'instance_number': image.instance_number,
                'rows': image.rows,
                'columns': image.columns,
                'window_width': image.window_width,
                'window_center': image.window_center,
                'pixel_spacing': image.pixel_spacing,
                'slice_location': image.slice_location,
                'file_url': f'/media/{image.dicom_file.name}' if image.dicom_file else None,
            }
            
            # If we can process DICOM files, add more data
            if DICOM_AVAILABLE and image.dicom_file:
                try:
                    dicom_path = image.get_file_path()
                    if dicom_path and os.path.exists(dicom_path):
                        ds = pydicom.dcmread(dicom_path)
                        if hasattr(ds, 'pixel_array'):
                            # Convert to base64 for web display
                            pixel_array = ds.pixel_array
                            # Apply basic windowing
                            windowed = apply_windowing(pixel_array, image.window_width, image.window_center)
                            # Convert to PIL Image and then to base64
                            pil_image = Image.fromarray(windowed.astype(np.uint8))
                            import base64
                            import io
                            buffer = io.BytesIO()
                            pil_image.save(buffer, format='PNG')
                            img_str = base64.b64encode(buffer.getvalue()).decode()
                            image_data['image_base64'] = f"data:image/png;base64,{img_str}"
                except Exception as e:
                    print(f"Error processing DICOM: {e}")
            
            data.append(image_data)
        
        return JsonResponse({'images': data})
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)

def apply_windowing(pixel_array, window_width, window_center):
    """Apply window/level to pixel array"""
    min_val = window_center - window_width / 2
    max_val = window_center + window_width / 2
    
    # Clip and normalize to 0-255
    windowed = np.clip(pixel_array, min_val, max_val)
    windowed = ((windowed - min_val) / (max_val - min_val) * 255)
    
    return windowed

@login_required
@csrf_exempt
def upload_dicom(request):
    """Upload DICOM files"""
    if request.method == 'POST':
        try:
            study_id = request.POST.get('study_id')
            if not study_id:
                return JsonResponse({'error': 'Study ID required'}, status=400)
            
            study = get_object_or_404(Study, id=study_id)
            
            files = request.FILES.getlist('dicom_files')
            if not files:
                return JsonResponse({'error': 'No files provided'}, status=400)
            
            uploaded_count = 0
            for file in files:
                # Create DicomImage instance
                dicom_image = DicomImage(
                    study=study,
                    dicom_file=file,
                    instance_number=uploaded_count + 1,
                )
                
                # If pydicom is available, extract metadata
                if DICOM_AVAILABLE:
                    try:
                        # Save file temporarily to read metadata
                        dicom_image.save()
                        ds = pydicom.dcmread(dicom_image.dicom_file.path)
                        
                        # Extract metadata
                        dicom_image.rows = getattr(ds, 'Rows', 512)
                        dicom_image.columns = getattr(ds, 'Columns', 512)
                        dicom_image.instance_number = getattr(ds, 'InstanceNumber', uploaded_count + 1)
                        dicom_image.slice_location = getattr(ds, 'SliceLocation', None)
                        dicom_image.slice_thickness = getattr(ds, 'SliceThickness', None)
                        
                        # Window/Level
                        dicom_image.window_width = getattr(ds, 'WindowWidth', 400)
                        dicom_image.window_center = getattr(ds, 'WindowCenter', 40)
                        
                        # Pixel spacing
                        if hasattr(ds, 'PixelSpacing'):
                            dicom_image.pixel_spacing = f"{ds.PixelSpacing[0]}\\{ds.PixelSpacing[1]}"
                        
                    except Exception as e:
                        print(f"Error reading DICOM metadata: {e}")
                
                dicom_image.save()
                uploaded_count += 1
            
            return JsonResponse({
                'success': True,
                'message': f'Uploaded {uploaded_count} DICOM files',
                'count': uploaded_count
            })
            
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)