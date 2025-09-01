from django.shortcuts import render, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt
from apps.worklist.models import Study, Series, DicomImage
from .models import ViewerSession, Measurement, Annotation
import json
import base64
from io import BytesIO
from PIL import Image
import numpy as np

try:
    import pydicom
    PYDICOM_AVAILABLE = True
except ImportError:
    PYDICOM_AVAILABLE = False


@login_required
def viewer(request):
    """Main DICOM viewer interface"""
    study_id = request.GET.get('study')
    study = None
    if study_id:
        study = get_object_or_404(Study, id=study_id)
        # Create or update viewer session
        session, created = ViewerSession.objects.get_or_create(
            user=request.user,
            study=study,
            defaults={'is_active': True}
        )
        if not created:
            session.is_active = True
            session.save()
    
    context = {
        'study': study,
    }
    
    return render(request, 'dicom_viewer/viewer.html', context)


@login_required
def api_study_data(request, study_id):
    """API endpoint to get study data"""
    try:
        study = get_object_or_404(Study, id=study_id)
        series_list = study.series.prefetch_related('images').all()
        
        data = {
            'study': {
                'id': study.id,
                'patient_name': study.patient.patient_name,
                'patient_id': study.patient.patient_id,
                'study_date': study.study_date.isoformat() if study.study_date else None,
                'study_description': study.study_description,
                'modality': study.modality.code if study.modality else '',
            },
            'series': []
        }
        
        for series in series_list:
            series_data = {
                'id': series.id,
                'series_number': series.series_number,
                'series_description': series.series_description,
                'modality': series.modality,
                'image_count': series.image_count,
                'images': []
            }
            
            for image in series.images.all()[:10]:  # Limit for performance
                image_data = {
                    'id': image.id,
                    'instance_number': image.instance_number,
                    'sop_instance_uid': image.sop_instance_uid,
                    'window_center': image.window_center,
                    'window_width': image.window_width,
                }
                series_data['images'].append(image_data)
            
            data['series'].append(series_data)
        
        return JsonResponse(data)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@login_required
def api_image_display(request, image_id):
    """API endpoint to get image for display"""
    try:
        image = get_object_or_404(DicomImage, id=image_id)
        
        if not PYDICOM_AVAILABLE or not image.file_path:
            # Return placeholder image
            return JsonResponse({
                'image_data': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
                'window_center': 128,
                'window_width': 256,
                'status': 'placeholder'
            })
        
        # In a real implementation, this would load and process DICOM data
        # For now, return a placeholder
        return JsonResponse({
            'image_data': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
            'window_center': image.window_center or 128,
            'window_width': image.window_width or 256,
            'status': 'success'
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@login_required
def api_measurements(request, study_id=None):
    """API endpoint for measurements"""
    if request.method == 'GET':
        measurements = Measurement.objects.filter(user=request.user)
        if study_id:
            measurements = measurements.filter(image__series__study_id=study_id)
        
        data = []
        for measurement in measurements:
            data.append({
                'id': measurement.id,
                'type': measurement.measurement_type,
                'value': measurement.value,
                'unit': measurement.unit,
                'coordinates': measurement.coordinates,
                'notes': measurement.notes,
                'created_at': measurement.created_at.isoformat(),
            })
        
        return JsonResponse({'measurements': data})
    
    elif request.method == 'POST':
        try:
            data = json.loads(request.body)
            measurement = Measurement.objects.create(
                user=request.user,
                image_id=data['image_id'],
                measurement_type=data['type'],
                value=data['value'],
                unit=data['unit'],
                coordinates=data['coordinates'],
                notes=data.get('notes', '')
            )
            return JsonResponse({
                'id': measurement.id,
                'status': 'success',
                'message': 'Measurement saved'
            })
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)


@login_required
@csrf_exempt
def api_calculate_distance(request):
    """API endpoint to calculate distance between two points"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            start_x = data.get('start_x', 0)
            start_y = data.get('start_y', 0)
            end_x = data.get('end_x', 0)
            end_y = data.get('end_y', 0)
            pixel_spacing = data.get('pixel_spacing', [1.0, 1.0])
            
            # Calculate pixel distance
            pixel_distance = ((end_x - start_x)**2 + (end_y - start_y)**2)**0.5
            
            # Convert to real world distance using pixel spacing
            real_distance = pixel_distance * pixel_spacing[0]  # Assuming square pixels
            
            return JsonResponse({
                'pixel_distance': pixel_distance,
                'real_distance': real_distance,
                'unit': 'mm',
                'status': 'success'
            })
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)


@login_required
def upload_dicom(request):
    """DICOM upload view"""
    if request.method == 'POST':
        # Handle DICOM file upload
        pass
    
    return render(request, 'dicom_viewer/upload.html')