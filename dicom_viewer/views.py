from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib import messages
from worklist.models import Study, Series, DicomImage
from accounts.models import User
import json
import base64
import os
import time

@login_required
def viewer(request):
    """Main DICOM viewer interface"""
    user = request.user
    
    # Get recent studies for quick access
    if user.is_facility_user():
        recent_studies = Study.objects.filter(facility=user.facility).order_by('-study_date')[:10]
    else:
        recent_studies = Study.objects.all().order_by('-study_date')[:10]
    
    context = {
        'user': user,
        'recent_studies': recent_studies,
    }
    
    return render(request, 'dicom_viewer/viewer.html', context)

@login_required
def view_study(request, study_id):
    """View specific study in DICOM viewer"""
    study = get_object_or_404(Study, id=study_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and study.facility != user.facility:
        messages.error(request, 'You do not have permission to view this study.')
        return redirect('dicom_viewer:viewer')
    
    # Update study status to in_progress if it was scheduled
    if study.status == 'scheduled':
        study.status = 'in_progress'
        study.save()
    
    # Get series and images
    series_list = study.series_set.all().order_by('series_number')
    
    # Prepare series data for viewer
    series_data = []
    for series in series_list:
        images = series.images.all().order_by('instance_number')
        series_data.append({
            'id': series.id,
            'series_number': series.series_number,
            'description': series.series_description,
            'modality': series.modality,
            'image_count': images.count(),
            'slice_thickness': series.slice_thickness,
            'pixel_spacing': series.pixel_spacing,
            'images': [
                {
                    'id': img.id,
                    'instance_number': img.instance_number,
                    'file_path': img.file_path.url if img.file_path else '',
                    'slice_location': img.slice_location,
                    'image_position': img.image_position,
                } for img in images
            ]
        })
    
    context = {
        'study': study,
        'series_data': json.dumps(series_data),
        'user': user,
    }
    
    return render(request, 'dicom_viewer/study_viewer.html', context)

@login_required
@csrf_exempt
def api_study_data(request, study_id):
    """API endpoint to get study data for viewer"""
    study = get_object_or_404(Study, id=study_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    series_list = study.series_set.all().order_by('series_number')
    
    data = {
        'study': {
            'id': study.id,
            'accession_number': study.accession_number,
            'patient_name': study.patient.full_name,
            'patient_id': study.patient.patient_id,
            'study_date': study.study_date.isoformat(),
            'modality': study.modality.code,
            'description': study.study_description,
            'body_part': study.body_part,
        },
        'series': []
    }
    
    for series in series_list:
        images = series.images.all().order_by('instance_number')
        series_info = {
            'id': series.id,
            'series_number': series.series_number,
            'description': series.series_description,
            'modality': series.modality,
            'image_count': images.count(),
            'slice_thickness': series.slice_thickness,
            'pixel_spacing': series.pixel_spacing,
            'image_orientation': series.image_orientation,
            'images': []
        }
        
        for img in images:
            image_info = {
                'id': img.id,
                'instance_number': img.instance_number,
                'file_path': img.file_path.url if img.file_path else '',
                'slice_location': img.slice_location,
                'image_position': img.image_position,
                'file_size': img.file_size,
            }
            series_info['images'].append(image_info)
        
        data['series'].append(series_info)
    
    return JsonResponse(data)

@login_required
@csrf_exempt
def api_image_data(request, image_id):
    """API endpoint to get specific image data"""
    image = get_object_or_404(DicomImage, id=image_id)
    user = request.user
    
    # Check permissions
    study = image.series.study
    if user.is_facility_user() and study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    # This would normally process DICOM file and return pixel data
    # For now, we'll return metadata
    data = {
        'id': image.id,
        'instance_number': image.instance_number,
        'slice_location': image.slice_location,
        'image_position': image.image_position,
        'file_path': image.file_path.url if image.file_path else '',
        'processed': image.processed,
        'series_id': image.series.id,
        'study_id': study.id,
    }
    
    return JsonResponse(data)

@login_required
@csrf_exempt
def api_measurements(request, study_id):
    """API endpoint for saving/loading measurements"""
    study = get_object_or_404(Study, id=study_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    if request.method == 'POST':
        # Save measurements
        try:
            data = json.loads(request.body)
            # This would save measurements to database
            # For now, we'll just return success
            return JsonResponse({'success': True, 'message': 'Measurements saved'})
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON data'}, status=400)
    
    elif request.method == 'GET':
        # Load measurements
        # This would load measurements from database
        measurements = []
        return JsonResponse({'measurements': measurements})

@login_required
@csrf_exempt
def api_reconstruction(request, study_id):
    """API endpoint for 3D reconstruction processing"""
    study = get_object_or_404(Study, id=study_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            reconstruction_type = data.get('type')  # 'mpr', 'mip', 'bone', 'endoscopy', 'surgery'
            parameters = data.get('parameters', {})
            
            # This would process the reconstruction
            # For now, we'll simulate processing
            result = {
                'success': True,
                'reconstruction_id': f"recon_{study_id}_{reconstruction_type}",
                'type': reconstruction_type,
                'status': 'processing',
                'progress': 0,
                'estimated_time': 30,  # seconds
            }
            
            return JsonResponse(result)
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON data'}, status=400)
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)

@login_required
@csrf_exempt
def api_hounsfield_units(request):
    """API endpoint for Hounsfield Unit calculations"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            x = data.get('x')
            y = data.get('y')
            image_id = data.get('image_id')
            
            # This would calculate actual HU values from DICOM data
            # For demonstration, we'll return simulated values
            hu_value = -800 + (x + y) % 1600  # Simulated HU value
            
            result = {
                'hu_value': hu_value,
                'position': {'x': x, 'y': y},
                'image_id': image_id,
                'timestamp': '2024-01-01T12:00:00Z'
            }
            
            return JsonResponse(result)
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON data'}, status=400)
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)

@login_required
@csrf_exempt
def api_window_level(request):
    """API endpoint for window/level adjustments"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            window_center = data.get('window_center')
            window_width = data.get('window_width')
            preset = data.get('preset')  # 'lung', 'bone', 'soft_tissue', 'brain', etc.
            
            # Predefined window/level presets
            presets = {
                'lung': {'center': -600, 'width': 1600},
                'bone': {'center': 300, 'width': 1500},
                'soft_tissue': {'center': 40, 'width': 350},
                'brain': {'center': 40, 'width': 80},
                'liver': {'center': 60, 'width': 160},
                'mediastinum': {'center': 50, 'width': 350},
            }
            
            if preset and preset in presets:
                window_center = presets[preset]['center']
                window_width = presets[preset]['width']
            
            result = {
                'window_center': window_center,
                'window_width': window_width,
                'preset': preset,
                'success': True
            }
            
            return JsonResponse(result)
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON data'}, status=400)
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)

@login_required
def api_export_image(request, image_id):
    """API endpoint to export image in various formats"""
    image = get_object_or_404(DicomImage, id=image_id)
    user = request.user
    
    # Check permissions
    study = image.series.study
    if user.is_facility_user() and study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    export_format = request.GET.get('format', 'png')  # png, jpg, tiff, dicom
    
    # This would export the image in the requested format
    # For now, we'll return a success message
    result = {
        'success': True,
        'download_url': f'/media/exports/image_{image_id}.{export_format}',
        'format': export_format,
        'filename': f'image_{image_id}.{export_format}'
    }
    
    return JsonResponse(result)

@login_required
@csrf_exempt
def api_annotations(request, study_id):
    """API endpoint for saving/loading annotations"""
    study = get_object_or_404(Study, id=study_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            annotations = data.get('annotations', [])
            
            # This would save annotations to database
            # For now, we'll just return success
            return JsonResponse({
                'success': True, 
                'message': f'Saved {len(annotations)} annotations',
                'annotation_count': len(annotations)
            })
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON data'}, status=400)
    
    elif request.method == 'GET':
        # Load annotations
        # This would load annotations from database
        annotations = []
        return JsonResponse({'annotations': annotations})

@login_required
def api_cine_mode(request, series_id):
    """API endpoint for cine mode playback"""
    series = get_object_or_404(Series, id=series_id)
    user = request.user
    
    # Check permissions
    study = series.study
    if user.is_facility_user() and study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    images = series.images.all().order_by('instance_number')
    
    cine_data = {
        'series_id': series_id,
        'image_count': images.count(),
        'frame_rate': 10,  # Default FPS
        'images': [
            {
                'id': img.id,
                'instance_number': img.instance_number,
                'file_path': img.file_path.url if img.file_path else '',
            } for img in images
        ]
    }
    
    return JsonResponse(cine_data)

@login_required
@csrf_exempt
def api_export_measurements(request, study_id):
    """API endpoint to export measurements as PDF"""
    study = get_object_or_404(Study, id=study_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            measurements = data.get('measurements', [])
            
            # This would generate a PDF report with measurements
            # For now, we'll simulate the export
            filename = f'measurements_{study.accession_number}_{int(time.time())}.pdf'
            download_url = f'/media/exports/{filename}'
            
            result = {
                'success': True,
                'download_url': download_url,
                'filename': filename,
                'measurement_count': len(measurements)
            }
            
            return JsonResponse(result)
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON data'}, status=400)
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)
