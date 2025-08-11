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
import numpy as np
import pydicom
from io import BytesIO
# import cv2  # Optional for advanced image processing
from PIL import Image
from django.utils import timezone
import uuid

# Removed web-based viewer entrypoints (standalone_viewer, advanced_standalone_viewer, view_study)

@login_required
def viewer(request):
    """Deprecated: web viewer removed. Redirect to desktop launcher endpoint."""
    return redirect('dicom_viewer:launch_standalone_viewer')

@login_required
def advanced_standalone_viewer(request):
    """Deprecated: web viewer removed. Redirect to desktop launcher endpoint."""
    return redirect('dicom_viewer:launch_standalone_viewer')

@login_required
def view_study(request, study_id):
    """Deprecated: web viewer removed. Redirect to desktop launcher endpoint for the specific study."""
    return redirect('dicom_viewer:launch_study_in_desktop_viewer', study_id=study_id)

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
    if user.is_facility_user() and image.series.study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    data = {
        'id': image.id,
        'instance_number': image.instance_number,
        'file_path': image.file_path.url if image.file_path else '',
        'slice_location': image.slice_location,
        'image_position': image.image_position,
        'file_size': image.file_size,
        'series_id': image.series.id,
        'study_id': image.series.study.id,
    }
    
    return JsonResponse(data)

@login_required
@csrf_exempt
def api_mpr_reconstruction(request, series_id):
    """API endpoint for Multiplanar Reconstruction (MPR)"""
    series = get_object_or_404(Series, id=series_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and series.study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    try:
        # Get all images in the series sorted by slice location
        images = series.images.all().order_by('slice_location', 'instance_number')
        
        if images.count() < 2:
            return JsonResponse({'error': 'Need at least 2 images for MPR'}, status=400)
        
        # Read DICOM data
        volume_data = []
        default_window_width = 400
        default_window_level = 40
        
        for img in images:
            try:
                dicom_path = os.path.join('/workspace/media', str(img.file_path))
                ds = pydicom.dcmread(dicom_path)
                
                # Get pixel array and apply rescale slope/intercept
                pixel_array = ds.pixel_array.astype(np.float32)
                if hasattr(ds, 'RescaleSlope') and hasattr(ds, 'RescaleIntercept'):
                    pixel_array = pixel_array * float(ds.RescaleSlope) + float(ds.RescaleIntercept)
                
                # Get default window/level from first image
                if len(volume_data) == 0:
                    default_window_width = getattr(ds, 'WindowWidth', 400)
                    default_window_level = getattr(ds, 'WindowCenter', 40)
                    if hasattr(default_window_width, '__iter__') and not isinstance(default_window_width, str):
                        default_window_width = default_window_width[0]
                    if hasattr(default_window_level, '__iter__') and not isinstance(default_window_level, str):
                        default_window_level = default_window_level[0]
                
                volume_data.append(pixel_array)
            except Exception as e:
                continue
        
        if len(volume_data) < 2:
            return JsonResponse({'error': 'Could not read enough images for MPR'}, status=400)
        
        # Stack into 3D volume
        volume = np.stack(volume_data, axis=0)
        
        # Get windowing parameters from request
        window_width = float(request.GET.get('window_width', default_window_width))
        window_level = float(request.GET.get('window_level', default_window_level))
        inverted = request.GET.get('inverted', 'false').lower() == 'true'
        
        # Generate MPR views
        mpr_views = {}
        
        # Axial (original orientation)
        axial_slice = volume[volume.shape[0] // 2]
        mpr_views['axial'] = _array_to_base64_image(axial_slice, window_width, window_level, inverted)
        
        # Sagittal (YZ plane)
        sagittal_slice = volume[:, :, volume.shape[2] // 2]
        mpr_views['sagittal'] = _array_to_base64_image(sagittal_slice, window_width, window_level, inverted)
        
        # Coronal (XZ plane)
        coronal_slice = volume[:, volume.shape[1] // 2, :]
        mpr_views['coronal'] = _array_to_base64_image(coronal_slice, window_width, window_level, inverted)
        
        return JsonResponse({
            'mpr_views': mpr_views,
            'volume_shape': volume.shape,
            'series_info': {
                'id': series.id,
                'description': series.series_description,
                'modality': series.modality
            }
        })
        
    except Exception as e:
        return JsonResponse({'error': f'Error generating MPR: {str(e)}'}, status=500)

@login_required
@csrf_exempt
def api_mip_reconstruction(request, series_id):
    """API endpoint for Maximum Intensity Projection (MIP)"""
    series = get_object_or_404(Series, id=series_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and series.study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    try:
        # Get all images in the series
        images = series.images.all().order_by('slice_location', 'instance_number')
        
        if images.count() < 2:
            return JsonResponse({'error': 'Need at least 2 images for MIP'}, status=400)
        
        # Read DICOM data
        volume_data = []
        default_window_width = 400
        default_window_level = 40
        
        for img in images:
            try:
                dicom_path = os.path.join('/workspace/media', str(img.file_path))
                ds = pydicom.dcmread(dicom_path)
                
                # Get pixel array and apply rescale slope/intercept
                pixel_array = ds.pixel_array.astype(np.float32)
                if hasattr(ds, 'RescaleSlope') and hasattr(ds, 'RescaleIntercept'):
                    pixel_array = pixel_array * float(ds.RescaleSlope) + float(ds.RescaleIntercept)
                
                # Get default window/level from first image
                if len(volume_data) == 0:
                    default_window_width = getattr(ds, 'WindowWidth', 400)
                    default_window_level = getattr(ds, 'WindowCenter', 40)
                    if hasattr(default_window_width, '__iter__') and not isinstance(default_window_width, str):
                        default_window_width = default_window_width[0]
                    if hasattr(default_window_level, '__iter__') and not isinstance(default_window_level, str):
                        default_window_level = default_window_level[0]
                
                volume_data.append(pixel_array)
            except Exception as e:
                continue
        
        if len(volume_data) < 2:
            return JsonResponse({'error': 'Could not read enough images for MIP'}, status=400)
        
        # Stack into 3D volume
        volume = np.stack(volume_data, axis=0)
        
        # Get windowing parameters from request
        window_width = float(request.GET.get('window_width', default_window_width))
        window_level = float(request.GET.get('window_level', default_window_level))
        inverted = request.GET.get('inverted', 'false').lower() == 'true'
        
        # Generate MIP projections
        mip_views = {}
        
        # Axial MIP (maximum along Z-axis)
        mip_axial = np.max(volume, axis=0)
        mip_views['axial'] = _array_to_base64_image(mip_axial, window_width, window_level, inverted)
        
        # Sagittal MIP (maximum along Y-axis)
        mip_sagittal = np.max(volume, axis=1)
        mip_views['sagittal'] = _array_to_base64_image(mip_sagittal, window_width, window_level, inverted)
        
        # Coronal MIP (maximum along X-axis)
        mip_coronal = np.max(volume, axis=2)
        mip_views['coronal'] = _array_to_base64_image(mip_coronal, window_width, window_level, inverted)
        
        return JsonResponse({
            'mip_views': mip_views,
            'volume_shape': volume.shape,
            'series_info': {
                'id': series.id,
                'description': series.series_description,
                'modality': series.modality
            }
        })
        
    except Exception as e:
        return JsonResponse({'error': f'Error generating MIP: {str(e)}'}, status=500)

@login_required
@csrf_exempt
def api_bone_reconstruction(request, series_id):
    """API endpoint for bone reconstruction using thresholding"""
    series = get_object_or_404(Series, id=series_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and series.study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    try:
        # Get threshold from request
        threshold = int(request.GET.get('threshold', 300))  # Default bone threshold in HU
        
        # Get all images in the series
        images = series.images.all().order_by('slice_location', 'instance_number')
        
        if images.count() < 2:
            return JsonResponse({'error': 'Need at least 2 images for bone reconstruction'}, status=400)
        
        # Read DICOM data
        volume_data = []
        for img in images:
            try:
                dicom_path = os.path.join('/workspace/media', str(img.file_path))
                ds = pydicom.dcmread(dicom_path)
                
                # Convert to Hounsfield Units if possible
                pixel_array = ds.pixel_array.astype(np.float32)
                
                # Apply rescale slope and intercept if available
                if hasattr(ds, 'RescaleSlope') and hasattr(ds, 'RescaleIntercept'):
                    pixel_array = pixel_array * ds.RescaleSlope + ds.RescaleIntercept
                
                volume_data.append(pixel_array)
            except Exception as e:
                continue
        
        if len(volume_data) < 2:
            return JsonResponse({'error': 'Could not read enough images for bone reconstruction'}, status=400)
        
        # Stack into 3D volume
        volume = np.stack(volume_data, axis=0)
        
        # Apply bone threshold
        bone_mask = volume >= threshold
        bone_volume = volume * bone_mask
        
        # Get windowing parameters optimized for bone
        window_width = float(request.GET.get('window_width', 2000))  # Bone window
        window_level = float(request.GET.get('window_level', 300))   # Bone level
        inverted = request.GET.get('inverted', 'false').lower() == 'true'
        
        # Generate bone reconstruction views
        bone_views = {}
        
        # Axial bone view
        axial_bone = bone_volume[bone_volume.shape[0] // 2]
        bone_views['axial'] = _array_to_base64_image(axial_bone, window_width, window_level, inverted)
        
        # Sagittal bone view
        sagittal_bone = bone_volume[:, :, bone_volume.shape[2] // 2]
        bone_views['sagittal'] = _array_to_base64_image(sagittal_bone, window_width, window_level, inverted)
        
        # Coronal bone view
        coronal_bone = bone_volume[:, bone_volume.shape[1] // 2, :]
        bone_views['coronal'] = _array_to_base64_image(coronal_bone, window_width, window_level, inverted)
        
        # MIP of bone structures
        bone_mip_axial = np.max(bone_volume, axis=0)
        bone_views['mip_axial'] = _array_to_base64_image(bone_mip_axial, window_width, window_level, inverted)
        
        bone_mip_sagittal = np.max(bone_volume, axis=1)
        bone_views['mip_sagittal'] = _array_to_base64_image(bone_mip_sagittal, window_width, window_level, inverted)
        
        bone_mip_coronal = np.max(bone_volume, axis=2)
        bone_views['mip_coronal'] = _array_to_base64_image(bone_mip_coronal, window_width, window_level, inverted)
        
        return JsonResponse({
            'bone_views': bone_views,
            'threshold': threshold,
            'volume_shape': volume.shape,
            'series_info': {
                'id': series.id,
                'description': series.series_description,
                'modality': series.modality
            }
        })
        
    except Exception as e:
        return JsonResponse({'error': f'Error generating bone reconstruction: {str(e)}'}, status=500)

@login_required
@csrf_exempt
def api_realtime_studies(request):
    """API endpoint for real-time study updates"""
    user = request.user
    
    # Get timestamp from request
    last_update = request.GET.get('last_update')
    
    try:
        if last_update:
            last_update_time = timezone.datetime.fromisoformat(last_update.replace('Z', '+00:00'))
        else:
            last_update_time = timezone.now() - timezone.timedelta(minutes=5)
    except:
        last_update_time = timezone.now() - timezone.timedelta(minutes=5)
    
    # Get studies updated since last check
    if user.is_facility_user():
        studies = Study.objects.filter(
            facility=user.facility,
            last_updated__gt=last_update_time
        ).order_by('-last_updated')[:20]
    else:
        studies = Study.objects.filter(
            last_updated__gt=last_update_time
        ).order_by('-last_updated')[:20]
    
    studies_data = []
    for study in studies:
        studies_data.append({
            'id': study.id,
            'accession_number': study.accession_number,
            'patient_name': study.patient.full_name,
            'patient_id': study.patient.patient_id,
            'study_date': study.study_date.isoformat(),
            'modality': study.modality.code,
            'description': study.study_description,
            'status': study.status,
            'priority': study.priority,
            'facility': study.facility.name,
            'last_updated': study.last_updated.isoformat(),
            'series_count': study.series_set.count(),
            'image_count': sum(series.images.count() for series in study.series_set.all())
        })
    
    return JsonResponse({
        'studies': studies_data,
        'timestamp': timezone.now().isoformat(),
        'count': len(studies_data)
    })

@login_required
@csrf_exempt
def api_study_progress(request, study_id):
    """API endpoint to get study processing progress"""
    study = get_object_or_404(Study, id=study_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    # Calculate progress
    total_images = 0
    processed_images = 0
    
    for series in study.series_set.all():
        series_images = series.images.all()
        total_images += series_images.count()
        processed_images += series_images.filter(processed=True).count()
    
    progress_percentage = (processed_images / total_images * 100) if total_images > 0 else 0
    
    return JsonResponse({
        'study_id': study.id,
        'total_images': total_images,
        'processed_images': processed_images,
        'progress_percentage': round(progress_percentage, 2),
        'status': study.status,
        'last_updated': study.last_updated.isoformat()
    })

def _array_to_base64_image(array, window_width=None, window_level=None, inverted=False):
    """Convert numpy array to base64 encoded image with proper windowing"""
    try:
        # Convert to float for calculations
        image_data = array.astype(np.float32)
        
        # Apply windowing if parameters provided
        if window_width is not None and window_level is not None:
            # Apply window/level
            min_val = window_level - window_width / 2
            max_val = window_level + window_width / 2
            
            # Clip and normalize
            image_data = np.clip(image_data, min_val, max_val)
            if max_val > min_val:
                image_data = (image_data - min_val) / (max_val - min_val) * 255
            else:
                image_data = np.zeros_like(image_data)
        else:
            # Default normalization
            if image_data.max() > image_data.min():
                image_data = ((image_data - image_data.min()) / (image_data.max() - image_data.min()) * 255)
            else:
                image_data = np.zeros_like(image_data)
        
        # Apply inversion if requested
        if inverted:
            image_data = 255 - image_data
        
        # Convert to uint8
        normalized = image_data.astype(np.uint8)
        
        # Convert to PIL Image
        img = Image.fromarray(normalized, mode='L')
        
        # Convert to base64
        buffer = BytesIO()
        img.save(buffer, format='PNG')
        img_str = base64.b64encode(buffer.getvalue()).decode()
        
        return f"data:image/png;base64,{img_str}"
    except Exception as e:
        return None

@login_required
@csrf_exempt 
def api_dicom_image_display(request, image_id):
    """API endpoint to get processed DICOM image with windowing"""
    image = get_object_or_404(DicomImage, id=image_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and image.series.study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    try:
        # Get windowing parameters from request
        window_width = float(request.GET.get('window_width', 400))
        window_level = float(request.GET.get('window_level', 40))
        inverted = request.GET.get('inverted', 'false').lower() == 'true'
        
        # Read DICOM file
        dicom_path = os.path.join('/workspace/media', str(image.file_path))
        ds = pydicom.dcmread(dicom_path)
        
        # Get pixel array
        pixel_array = ds.pixel_array.astype(np.float32)
        
        # Apply rescale slope and intercept if available (convert to Hounsfield Units)
        if hasattr(ds, 'RescaleSlope') and hasattr(ds, 'RescaleIntercept'):
            pixel_array = pixel_array * float(ds.RescaleSlope) + float(ds.RescaleIntercept)
        
        # Generate image with proper windowing
        image_data_url = _array_to_base64_image(pixel_array, window_width, window_level, inverted)
        
        if not image_data_url:
            return JsonResponse({'error': 'Failed to process image'}, status=500)
        
        # Get default window/level values from DICOM if available
        default_window_width = getattr(ds, 'WindowWidth', window_width)
        default_window_level = getattr(ds, 'WindowCenter', window_level)
        
        # Handle multiple window values (take first if array)
        if hasattr(default_window_width, '__iter__') and not isinstance(default_window_width, str):
            default_window_width = default_window_width[0]
        if hasattr(default_window_level, '__iter__') and not isinstance(default_window_level, str):
            default_window_level = default_window_level[0]
        
        return JsonResponse({
            'image_data': image_data_url,
            'image_info': {
                'id': image.id,
                'instance_number': image.instance_number,
                'slice_location': image.slice_location,
                'dimensions': [int(ds.Rows), int(ds.Columns)],
                'pixel_spacing': getattr(ds, 'PixelSpacing', [1.0, 1.0]),
                'slice_thickness': getattr(ds, 'SliceThickness', 1.0),
                'default_window_width': float(default_window_width),
                'default_window_level': float(default_window_level),
                'modality': getattr(ds, 'Modality', ''),
                'series_description': getattr(ds, 'SeriesDescription', ''),
                'patient_name': str(getattr(ds, 'PatientName', '')),
                'study_date': str(getattr(ds, 'StudyDate', '')),
                'bits_allocated': getattr(ds, 'BitsAllocated', 16),
                'bits_stored': getattr(ds, 'BitsStored', 16),
                'photometric_interpretation': getattr(ds, 'PhotometricInterpretation', ''),
            },
            'windowing': {
                'window_width': window_width,
                'window_level': window_level,
                'inverted': inverted
            }
        })
        
    except Exception as e:
        return JsonResponse({'error': f'Error processing DICOM image: {str(e)}'}, status=500)

@login_required
@csrf_exempt
def api_measurements(request, study_id=None):
    """API endpoint for saving/loading measurements"""
    if study_id:
        study = get_object_or_404(Study, id=study_id)
        user = request.user
        
        # Check permissions
        if user.is_facility_user() and study.facility != user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
    
    if request.method == 'POST':
        # Save measurements
        try:
            data = json.loads(request.body)
            measurements = data.get('measurements', [])
            annotations = data.get('annotations', [])
            
            # Store measurements in session for standalone viewer
            if not study_id:
                request.session['measurements'] = measurements
                request.session['annotations'] = annotations
            else:
                # Save to database for study-based viewer
                # For now, store in session as well
                request.session[f'measurements_{study_id}'] = measurements
                request.session[f'annotations_{study_id}'] = annotations
            
            return JsonResponse({'success': True, 'message': 'Measurements saved'})
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON data'}, status=400)
    
    elif request.method == 'GET':
        # Load measurements
        if not study_id:
            measurements = request.session.get('measurements', [])
            annotations = request.session.get('annotations', [])
        else:
            measurements = request.session.get(f'measurements_{study_id}', [])
            annotations = request.session.get(f'annotations_{study_id}', [])
        
        return JsonResponse({
            'measurements': measurements,
            'annotations': annotations
        })
    
    elif request.method == 'DELETE':
        # Clear measurements
        if not study_id:
            request.session.pop('measurements', None)
            request.session.pop('annotations', None)
        else:
            request.session.pop(f'measurements_{study_id}', None)
            request.session.pop(f'annotations_{study_id}', None)
        
        return JsonResponse({'success': True, 'message': 'Measurements cleared'})

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
@csrf_exempt
def api_calculate_distance(request):
    """API endpoint to calculate distance with pixel spacing"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            start_x = data.get('start_x')
            start_y = data.get('start_y')
            end_x = data.get('end_x')
            end_y = data.get('end_y')
            pixel_spacing = data.get('pixel_spacing', [1.0, 1.0])
            
            # Calculate pixel distance
            pixel_distance = np.sqrt((end_x - start_x)**2 + (end_y - start_y)**2)
            
            # Calculate real-world distance if pixel spacing is available
            if len(pixel_spacing) >= 2:
                try:
                    spacing_x = float(pixel_spacing[0])
                    spacing_y = float(pixel_spacing[1])
                    avg_spacing = (spacing_x + spacing_y) / 2
                    distance_mm = pixel_distance * avg_spacing
                    distance_cm = distance_mm / 10.0
                    
                    return JsonResponse({
                        'pixel_distance': round(pixel_distance, 2),
                        'distance_mm': round(distance_mm, 2),
                        'distance_cm': round(distance_cm, 2),
                        'formatted_text': f"{distance_mm:.1f} mm / {distance_cm:.2f} cm"
                    })
                except (ValueError, TypeError):
                    pass
            
            return JsonResponse({
                'pixel_distance': round(pixel_distance, 2),
                'formatted_text': f"{pixel_distance:.1f} px"
            })
            
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

@csrf_exempt
def upload_dicom(request):
    """Upload DICOM files for processing"""
    if request.method == 'POST':
        try:
            # Handle both multiple files and single file
            uploaded_files = request.FILES.getlist('dicom_files')
            if not uploaded_files:
                # Try single file upload for standalone viewer
                dicom_file = request.FILES.get('dicom_file')
                if dicom_file:
                    uploaded_files = [dicom_file]
            
            if not uploaded_files:
                return JsonResponse({'success': False, 'error': 'No files uploaded'})
            
            # Generate upload ID for tracking
            upload_id = str(uuid.uuid4())
            
            # Process DICOM files and create temporary Study/Series/Image records
            total_files = len(uploaded_files)
            processed_files = 0
            processed_images = []
            
            # Create a temporary study for standalone uploads
            temp_study = Study.objects.create(
                patient_name=f'Temp Upload {upload_id[:8]}',
                patient_id=f'TEMP_{upload_id[:8]}',
                study_date=timezone.now().date(),
                study_description='Temporary upload for standalone viewer',
                accession_number=f'TEMP_{upload_id[:8]}',
                modality='CT',  # Default, will be updated from DICOM
                status='completed'
            )
            
            # Create a temporary series
            temp_series = Series.objects.create(
                study=temp_study,
                series_number=1,
                series_description='Temporary series',
                modality='CT',  # Default, will be updated from DICOM
                series_uid=f'temp.{upload_id}',
                image_count=0
            )
            
            for file in uploaded_files:
                # Validate file type
                if not (file.name.lower().endswith('.dcm') or file.name.lower().endswith('.dicom')):
                    continue
                
                try:
                    # Save file temporarily
                    file_path = f'temp_uploads/{upload_id}_{file.name}'
                    full_path = os.path.join('/workspace/media', file_path)
                    os.makedirs(os.path.dirname(full_path), exist_ok=True)
                    
                    with open(full_path, 'wb+') as destination:
                        for chunk in file.chunks():
                            destination.write(chunk)
                    
                    # Read DICOM metadata
                    ds = pydicom.dcmread(full_path)
                    
                    # Update series metadata from first file
                    if processed_files == 0:
                        temp_series.modality = getattr(ds, 'Modality', 'CT')
                        temp_series.series_description = getattr(ds, 'SeriesDescription', 'Uploaded DICOM')
                        temp_study.patient_name = str(getattr(ds, 'PatientName', f'Temp Upload {upload_id[:8]}'))
                        temp_study.modality = getattr(ds, 'Modality', 'CT')
                        temp_study.save()
                        temp_series.save()
                    
                    # Create image record
                    image = DicomImage.objects.create(
                        series=temp_series,
                        instance_number=getattr(ds, 'InstanceNumber', processed_files + 1),
                        slice_location=getattr(ds, 'SliceLocation', 0),
                        image_position=str(getattr(ds, 'ImagePositionPatient', '')),
                        file_path=file_path,
                        file_size=file.size
                    )
                    
                    processed_images.append({
                        'id': image.id,
                        'instance_number': image.instance_number,
                        'slice_location': image.slice_location
                    })
                    
                    processed_files += 1
                    
                except Exception as e:
                    print(f"Error processing file {file.name}: {str(e)}")
                    continue
            
            # Update series image count
            temp_series.image_count = processed_files
            temp_series.save()
            
            if processed_files == 0:
                temp_study.delete()  # Clean up
                return JsonResponse({'success': False, 'error': 'No valid DICOM files found'})
            
            return JsonResponse({
                'success': True, 
                'message': f'Successfully uploaded {processed_files} DICOM files',
                'upload_id': upload_id,
                'processed_files': processed_files,
                'total_files': total_files,
                'study_id': temp_study.id,
                'series_id': temp_series.id,
                'images': processed_images
            })
            
        except Exception as e:
            return JsonResponse({'success': False, 'error': str(e)})
    
    return render(request, 'dicom_viewer/upload.html')

@login_required
@csrf_exempt
def api_upload_progress(request, upload_id):
    """API endpoint to check upload progress"""
    try:
        # This would check the actual upload progress
        # For now, we'll simulate progress
        progress = {
            'upload_id': upload_id,
            'status': 'completed',
            'progress': 100,
            'processed_files': 10,
            'total_files': 10,
            'current_file': '',
            'message': 'Upload completed successfully'
        }
        
        return JsonResponse(progress)
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def api_process_study(request, study_id):
    """API endpoint to process/reprocess a study"""
    study = get_object_or_404(Study, id=study_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            processing_options = data.get('options', {})
            
            # This would trigger study reprocessing
            # For now, we'll simulate processing
            result = {
                'success': True,
                'message': f'Study {study.accession_number} processing started',
                'study_id': study.id,
                'processing_options': processing_options,
                'estimated_time': '5-10 minutes'
            }
            
            return JsonResponse(result)
            
        except json.JSONDecodeError:
            return JsonResponse({'error': 'Invalid JSON data'}, status=400)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)

@login_required
def launch_standalone_viewer(request):
    """Launch the standalone DICOM viewer application"""
    import subprocess
    import sys
    import os
    
    try:
        # Get study ID if provided in POST data
        study_id = None
        if request.method == 'POST':
            data = json.loads(request.body) if request.body else {}
            study_id = data.get('study_id')
        
        # Path to the launcher script
        launcher_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 
                                   'tools', 'launch_dicom_viewer.py')
        
        if os.path.exists(launcher_path):
            # Build command with appropriate arguments
            cmd = [sys.executable, launcher_path, '--debug']
            
            # Add study ID if provided
            if study_id:
                cmd.extend(['--study-id', str(study_id)])
            
            # Run the launcher synchronously to capture success/failure
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                message = 'Standalone DICOM viewer launched successfully'
                if study_id:
                    message += f' with study ID {study_id}'
                return JsonResponse({'success': True, 'message': message})
            else:
                stderr = (result.stderr or '').strip()
                stdout = (result.stdout or '').strip()
                details = stderr or stdout or 'Unknown error'
                return JsonResponse({
                    'success': False,
                    'message': 'Failed to launch DICOM viewer',
                    'details': details[:500]
                }, status=500)
        else:
            return JsonResponse({
                'success': False, 
                'message': 'Standalone viewer launcher not found',
                'details': f'Missing launcher at {launcher_path}'
            }, status=404)
            
    except Exception as e:
        return JsonResponse({
            'success': False, 
            'message': f'Error launching standalone viewer: {str(e)}'
        }, status=500)

@login_required
def launch_study_in_desktop_viewer(request, study_id):
    """Launch a specific study in the desktop viewer"""
    import subprocess
    import sys
    import os
    
    try:
        # Verify study exists and user has access
        study = get_object_or_404(Study, id=study_id)
        user = request.user
        
        # Check permissions
        if user.is_facility_user() and study.facility != user.facility:
            return JsonResponse({
                'success': False,
                'message': 'You do not have permission to view this study.'
            }, status=403)
        
        # Path to the launcher script
        launcher_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 
                                   'tools', 'launch_dicom_viewer.py')
        
        if os.path.exists(launcher_path):
            # Build command with study ID
            cmd = [sys.executable, launcher_path, '--debug', '--study-id', str(study_id)]
            
            # Run the launcher synchronously to capture success/failure
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                return JsonResponse({
                    'success': True, 
                    'message': f'Desktop viewer launched for study: {study.patient.full_name} ({study.study_date})'
                })
            else:
                stderr = (result.stderr or '').strip()
                stdout = (result.stdout or '').strip()
                details = stderr or stdout or 'Unknown error'
                return JsonResponse({
                    'success': False,
                    'message': 'Failed to launch DICOM viewer',
                    'details': details[:500]
                }, status=500)
        else:
            return JsonResponse({
                'success': False, 
                'message': 'Desktop viewer launcher not found',
                'details': f'Missing launcher at {launcher_path}'
            }, status=404)
            
    except Exception as e:
        return JsonResponse({
            'success': False, 
            'message': f'Error launching desktop viewer: {str(e)}'
        }, status=500)
