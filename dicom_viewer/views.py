from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse, HttpResponse, FileResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.contrib import messages
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.utils import timezone
from django.db import transaction
from django.conf import settings

import json
import base64
import os
import time
import numpy as np
import pydicom
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont
import uuid
import logging
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import threading

# Import models and utilities
from worklist.models import Study, Series, DicomImage, Patient, Modality
from accounts.models import User, Facility
from .models import ViewerSession, Measurement, Annotation, ReconstructionJob
from .dicom_utils import DicomProcessor
from .reconstruction import (MPRProcessor, MIPProcessor, Bone3DProcessor, 
                             MRI3DProcessor, PETProcessor, SPECTProcessor, 
                             NuclearMedicineProcessor, create_processor, 
                             get_modality_specific_processor, get_available_reconstruction_types)

logger = logging.getLogger(__name__)

# Professional caching system for DICOM data
_DICOM_CACHE = {}
_DICOM_CACHE_LOCK = threading.Lock()
_MAX_CACHE_SIZE = 100

# Volume cache for 3D operations
_VOLUME_CACHE = {}
_VOLUME_CACHE_LOCK = threading.Lock()
_MAX_VOLUME_CACHE = 5

def _cache_dicom_data(file_path, dataset):
    """Cache DICOM dataset with LRU eviction"""
    with _DICOM_CACHE_LOCK:
        if len(_DICOM_CACHE) >= _MAX_CACHE_SIZE:
            # Remove oldest entry
            oldest_key = next(iter(_DICOM_CACHE))
            del _DICOM_CACHE[oldest_key]
        _DICOM_CACHE[file_path] = dataset

def _get_cached_dicom(file_path):
    """Get cached DICOM dataset"""
    with _DICOM_CACHE_LOCK:
        return _DICOM_CACHE.get(file_path)

def _load_dicom_optimized(file_path):
    """Load DICOM with caching and error handling"""
    cached = _get_cached_dicom(file_path)
    if cached is not None:
        return cached
    
    try:
        dataset = pydicom.dcmread(file_path, force=True)
        dataset.decompress()
        _cache_dicom_data(file_path, dataset)
        return dataset
    except Exception as e:
        logger.error(f"Failed to load DICOM file {file_path}: {e}")
        return None

def _apply_windowing_fast(image, window_width, window_level, invert=False):
    """Professional windowing algorithm from PyQt implementation"""
    # Convert to float for calculations
    image_data = image.astype(np.float32)
    
    # Apply window/level
    min_val = window_level - window_width / 2
    max_val = window_level + window_width / 2
    
    # Clip and normalize
    image_data = np.clip(image_data, min_val, max_val)
    
    if max_val > min_val:
        image_data = (image_data - min_val) / (max_val - min_val) * 255
    else:
        image_data = np.zeros_like(image_data)
    
    if invert:
        image_data = 255 - image_data
    
    return image_data.astype(np.uint8)

def _array_to_base64_image(array, window_width=None, window_level=None, inverted=False):
    """Convert numpy array to base64 encoded image with professional windowing"""
    try:
        if array is None or array.size == 0:
            return None
        
        # Ensure array is contiguous for performance
        if not array.flags['C_CONTIGUOUS']:
            array = np.ascontiguousarray(array)
        
        # Handle different array dimensions
        if array.ndim == 1:
            size = int(np.sqrt(array.size))
            if size * size == array.size:
                array = array.reshape(size, size)
            else:
                return None
        elif array.ndim > 2:
            array = array[0] if array.ndim == 3 else array.reshape(array.shape[-2:])
        
        # Handle invalid data
        if np.any(np.isnan(array)) or np.any(np.isinf(array)):
            array = np.nan_to_num(array, nan=0.0, posinf=0.0, neginf=0.0, copy=False)
        
        # Apply windowing
        if window_width is not None and window_level is not None:
            image_data = _apply_windowing_fast(array, window_width, window_level, inverted)
        else:
            # Auto-scaling
            array_min, array_max = array.min(), array.max()
            if array_max > array_min:
                image_data = (array - array_min) * (255.0 / (array_max - array_min))
                if inverted:
                    image_data = 255.0 - image_data
                image_data = image_data.astype(np.uint8)
            else:
                image_data = np.zeros_like(array, dtype=np.uint8)
        
        # Convert to PIL Image
        img = Image.fromarray(image_data, mode='L')
        
        # Save to buffer with optimized settings
        buffer = BytesIO()
        img.save(buffer, format='PNG', optimize=False, compress_level=1)
        
        img_str = base64.b64encode(buffer.getvalue()).decode('ascii')
        return f"data:image/png;base64,{img_str}"
        
    except Exception as e:
        logger.error(f"Error converting array to base64: {e}")
        return None

@login_required
def viewer(request):
    """Main DICOM viewer entry point with improved error handling"""
    study_id = request.GET.get('study')
    context = {'study_id': study_id} if study_id else {}
    
    # Mark study as in progress if user can edit reports
    if study_id:
        try:
            study = get_object_or_404(Study, id=int(study_id))
            if hasattr(request.user, 'can_edit_reports') and request.user.can_edit_reports():
                if study.status in ['scheduled', 'suspended']:
                    study.status = 'in_progress'
                    study.save(update_fields=['status'])
        except Exception as e:
            logger.warning(f"Could not update study status: {e}")
    
    # Use bulletproof viewer template for demo
    return render(request, 'dicom_viewer/viewer_bulletproof.html', context)

@login_required
@csrf_exempt
def api_studies_list(request):
    """API endpoint to list all studies available to the user"""
    try:
        user = request.user
        
        # Get studies based on user permissions
        if user.is_superuser:
            studies = Study.objects.all()
        elif user.is_facility_user() and getattr(user, 'facility', None):
            studies = Study.objects.filter(facility=user.facility)
        else:
            studies = Study.objects.none()
        
        studies_data = []
        for study in studies.order_by('-study_date')[:50]:  # Limit to 50 most recent
            studies_data.append({
                'id': study.id,
                'accession_number': study.accession_number,
                'patient_name': study.patient.full_name if study.patient else 'Unknown',
                'patient_id': study.patient.patient_id if study.patient else '',
                'study_date': study.study_date.isoformat() if study.study_date else '',
                'modality': study.modality.code if study.modality else 'Unknown',
                'description': study.study_description or '',
                'body_part': study.body_part or '',
                'priority': str(study.priority or 'normal'),
                'facility': study.facility.name if study.facility else ''
            })
        
        return JsonResponse({
            'success': True,
            'studies': studies_data,
            'total_count': studies.count()
        })
        
    except Exception as e:
        logger.error(f"Error in api_studies_list: {str(e)}")
        return JsonResponse({
            'success': False,
            'error': 'Failed to load studies list',
            'message': str(e)
        }, status=500)

@login_required
@csrf_exempt
def api_study_data(request, study_id):
    """Enhanced API endpoint for study data with professional error handling"""
    try:
        study = get_object_or_404(Study, id=study_id)
        user = request.user
        
        # Check permissions
        if user.is_facility_user() and getattr(user, 'facility', None) and study.facility != user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
        
        # Get series with image counts
        series_list = study.series_set.all().order_by('series_number')
        
        study_data = {
            'study': {
                'id': study.id,
                'accession_number': study.accession_number,
                'patient_name': study.patient.full_name,
                'patient_id': study.patient.patient_id,
                'study_date': study.study_date.isoformat(),
                'modality': study.modality.code,
                'description': study.study_description,
                'body_part': study.body_part,
                'priority': str(study.priority or 'normal'),
                'clinical_info': str(study.clinical_info or ''),
                'facility': study.facility.name
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
                    'slice_location': img.slice_location,
                    'image_position': img.image_position,
                    'file_size': img.file_size,
                }
                series_info['images'].append(image_info)
            
            study_data['series'].append(series_info)
        
        return JsonResponse(study_data)
        
    except Exception as e:
        logger.error(f"Error in api_study_data: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def api_image_display(request, image_id):
    """Professional image display API with PyQt-level quality"""
    try:
        image = get_object_or_404(DicomImage, id=image_id)
        user = request.user
        
        # Check permissions
        if user.is_facility_user() and getattr(user, 'facility', None) and image.series.study.facility != user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
        
        # Get windowing parameters
        window_width = float(request.GET.get('ww', 400))
        window_level = float(request.GET.get('wl', 40))
        inverted = request.GET.get('invert', 'false').lower() == 'true'
        
        # Load DICOM file
        try:
            if hasattr(image.file_path, 'name'):
                file_path = os.path.join(settings.MEDIA_ROOT, image.file_path.name)
            else:
                file_path = str(image.file_path)
                if not os.path.isabs(file_path):
                    file_path = os.path.join(settings.MEDIA_ROOT, file_path)
            
            if not os.path.exists(file_path):
                # Try to find file by SOP Instance UID
                import glob
                pattern = f'{settings.MEDIA_ROOT}/**/*{image.sop_instance_uid}*.dcm'
                matches = glob.glob(pattern, recursive=True)
                if matches:
                    file_path = matches[0]
                else:
                    raise FileNotFoundError(f"DICOM file not found: {file_path}")
            
            ds = _load_dicom_optimized(file_path)
            if ds is None:
                raise ValueError("Failed to load DICOM dataset")
            
            # Get pixel data with proper calibration
            pixel_array = ds.pixel_array.astype(np.float32)
            
            # Apply rescaling for HU values
            slope = getattr(ds, 'RescaleSlope', 1.0)
            intercept = getattr(ds, 'RescaleIntercept', 0.0)
            pixel_array = pixel_array * float(slope) + float(intercept)
            
            # Get default window/level from DICOM if not specified in request
            if request.GET.get('ww') is None or request.GET.get('wl') is None:
                default_ww = getattr(ds, 'WindowWidth', window_width)
                default_wl = getattr(ds, 'WindowCenter', window_level)
                
                if hasattr(default_ww, '__iter__') and not isinstance(default_ww, str):
                    default_ww = default_ww[0]
                if hasattr(default_wl, '__iter__') and not isinstance(default_wl, str):
                    default_wl = default_wl[0]
                
                if request.GET.get('ww') is None:
                    window_width = float(default_ww)
                if request.GET.get('wl') is None:
                    window_level = float(default_wl)
            
            # Handle modality-specific defaults
            modality = getattr(ds, 'Modality', '').upper()
            photometric = getattr(ds, 'PhotometricInterpretation', '').upper()
            
            if modality in ['DX', 'CR', 'XA', 'RF', 'MG']:
                if request.GET.get('ww') is None:
                    window_width = 3000.0
                if request.GET.get('wl') is None:
                    window_level = 1500.0
                if request.GET.get('invert') is None:
                    inverted = (photometric == 'MONOCHROME1')
            
            # Apply windowing
            windowed_image = _apply_windowing_fast(pixel_array, window_width, window_level, inverted)
            
            # Convert to base64
            image_data_url = _array_to_base64_image(windowed_image)
            
            if not image_data_url:
                raise ValueError("Failed to generate image data")
            
            # Prepare image info
            image_info = {
                'id': image.id,
                'instance_number': image.instance_number,
                'slice_location': image.slice_location,
                'dimensions': [int(getattr(ds, 'Rows', 0)), int(getattr(ds, 'Columns', 0))],
                'pixel_spacing': getattr(ds, 'PixelSpacing', [1.0, 1.0]),
                'slice_thickness': getattr(ds, 'SliceThickness', 1.0),
                'default_window_width': float(window_width),
                'default_window_level': float(window_level),
                'modality': getattr(ds, 'Modality', ''),
                'series_description': getattr(ds, 'SeriesDescription', ''),
                'patient_name': str(getattr(ds, 'PatientName', '')),
                'study_date': str(getattr(ds, 'StudyDate', '')),
                'institution': str(getattr(ds, 'InstitutionName', '')),
                'bits_allocated': getattr(ds, 'BitsAllocated', 16),
                'photometric_interpretation': photometric,
            }
            
            return JsonResponse({
                'image_data': image_data_url,
                'image_info': image_info,
                'windowing': {
                    'window_width': window_width,
                    'window_level': window_level,
                    'inverted': inverted
                }
            })
            
        except Exception as e:
            logger.error(f"Error loading DICOM image: {e}")
            
            # Return placeholder image for failed loads
            placeholder_img = Image.new('RGB', (512, 512), color=(40, 40, 40))
            draw = ImageDraw.Draw(placeholder_img)
            
            text_lines = [
                "DICOM Image",
                "Not Available",
                "",
                f"Image ID: {image.id}",
                f"Error: {str(e)[:50]}"
            ]
            
            y_offset = 200
            for line in text_lines:
                try:
                    draw.text((256, y_offset), line, fill=(200, 200, 200), anchor="mm")
                except:
                    draw.text((200, y_offset), line, fill=(200, 200, 200))
                y_offset += 30
            
            buffer = BytesIO()
            placeholder_img.save(buffer, format='PNG')
            img_data = base64.b64encode(buffer.getvalue()).decode('utf-8')
            placeholder_url = f'data:image/png;base64,{img_data}'
            
            return JsonResponse({
                'image_data': placeholder_url,
                'image_info': {
                    'id': image.id,
                    'error': str(e),
                    'dimensions': [512, 512],
                    'pixel_spacing': [1.0, 1.0],
                    'default_window_width': 400.0,
                    'default_window_level': 40.0
                },
                'windowing': {
                    'window_width': window_width,
                    'window_level': window_level,
                    'inverted': inverted
                },
                'error': str(e)
            })
            
    except Exception as e:
        logger.error(f"Fatal error in api_image_display: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
def web_series_images(request, series_id):
    """Enhanced series images API"""
    try:
        series = get_object_or_404(Series, id=series_id)
        
        # Check permissions
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and series.study.facility != request.user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
        
        images = series.images.all().order_by('instance_number')
        
        data = {
            'series': {
                'id': series.id,
                'series_number': series.series_number,
                'series_description': series.series_description,
                'modality': series.modality,
                'slice_thickness': series.slice_thickness,
                'pixel_spacing': series.pixel_spacing,
                'image_orientation': series.image_orientation,
                'image_count': images.count()
            },
            'images': []
        }
        
        for img in images:
            image_data = {
                'id': img.id,
                'instance_number': img.instance_number,
                'slice_location': img.slice_location,
                'image_position': img.image_position,
                'file_size': img.file_size,
                'sop_instance_uid': img.sop_instance_uid
            }
            data['images'].append(image_data)
        
        return JsonResponse(data)
        
    except Exception as e:
        logger.error(f"Error in web_series_images: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def api_mpr_reconstruction(request, series_id):
    """Professional MPR reconstruction with enhanced 3D capabilities"""
    try:
        series = get_object_or_404(Series, id=series_id)
        
        # Check permissions
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and series.study.facility != request.user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
        
        # Get parameters
        window_width = float(request.GET.get('ww', 400))
        window_level = float(request.GET.get('wl', 40))
        invert = request.GET.get('invert', 'false').lower() == 'true'
        
        # Check cache first
        cache_key = f"mpr_{series_id}_{window_width}_{window_level}_{invert}"
        with _VOLUME_CACHE_LOCK:
            cached_result = _VOLUME_CACHE.get(cache_key)
            if cached_result:
                return JsonResponse(cached_result)
        
        # Load volume data
        images = series.images.all().order_by('instance_number')
        if not images.exists():
            return JsonResponse({'error': 'No images found in series'}, status=404)
        
        # Load volume in parallel for performance
        volume_data = []
        spacing = [1.0, 1.0, 1.0]
        
        def load_image(image):
            try:
                file_path = os.path.join(settings.MEDIA_ROOT, str(image.file_path))
                if not os.path.exists(file_path):
                    return None
                
                ds = _load_dicom_optimized(file_path)
                if ds is None:
                    return None
                
                pixel_array = ds.pixel_array.astype(np.float32)
                slope = float(getattr(ds, 'RescaleSlope', 1.0))
                intercept = float(getattr(ds, 'RescaleIntercept', 0.0))
                pixel_array = pixel_array * slope + intercept
                
                return pixel_array, ds
                
            except Exception as e:
                logger.error(f"Error loading image {image.id}: {e}")
                return None
        
        # Load images in parallel
        with ThreadPoolExecutor(max_workers=4) as executor:
            results = list(executor.map(load_image, images))
        
        # Filter out failed loads and extract data
        valid_results = [r for r in results if r is not None]
        if not valid_results:
            return JsonResponse({'error': 'Failed to load any images'}, status=500)
        
        volume_data = [r[0] for r in valid_results]
        first_ds = valid_results[0][1]
        
        # Extract spacing from first image
        pixel_spacing = getattr(first_ds, 'PixelSpacing', [1.0, 1.0])
        slice_thickness = getattr(first_ds, 'SliceThickness', 1.0)
        spacing = [float(slice_thickness), float(pixel_spacing[0]), float(pixel_spacing[1])]
        
        # Create 3D volume
        volume = np.stack(volume_data, axis=0)
        
        # Enhance thin stacks for better MPR quality
        if volume.shape[0] < 16:
            from scipy import ndimage
            factor = max(2, int(np.ceil(16 / volume.shape[0])))
            volume = ndimage.zoom(volume, (factor, 1, 1), order=1)
        
        # Generate MPR views
        slices, rows, cols = volume.shape
        
        # Calculate center indices
        axial_idx = slices // 2
        sagittal_idx = cols // 2
        coronal_idx = rows // 2
        
        # Extract orthogonal slices
        axial_slice = volume[axial_idx, :, :]
        sagittal_slice = volume[:, :, sagittal_idx]
        coronal_slice = volume[:, coronal_idx, :]
        
        # Apply windowing and convert to base64
        views = {}
        views['axial'] = _array_to_base64_image(axial_slice, window_width, window_level, invert)
        views['sagittal'] = _array_to_base64_image(sagittal_slice, window_width, window_level, invert)
        views['coronal'] = _array_to_base64_image(coronal_slice, window_width, window_level, invert)
        
        result = {
            'views': views,
            'metadata': {
                'volume_shape': list(volume.shape),
                'spacing': spacing,
                'center_indices': {
                    'axial': axial_idx,
                    'sagittal': sagittal_idx,
                    'coronal': coronal_idx
                }
            }
        }
        
        # Cache result
        with _VOLUME_CACHE_LOCK:
            if len(_VOLUME_CACHE) >= _MAX_VOLUME_CACHE:
                oldest_key = next(iter(_VOLUME_CACHE))
                del _VOLUME_CACHE[oldest_key]
            _VOLUME_CACHE[cache_key] = result
        
        return JsonResponse(result)
        
    except Exception as e:
        logger.error(f"Error in MPR reconstruction: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def api_mip_reconstruction(request, series_id):
    """Professional MIP reconstruction"""
    try:
        series = get_object_or_404(Series, id=series_id)
        
        # Check permissions
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and series.study.facility != request.user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
        
        # Get parameters
        window_width = float(request.GET.get('ww', 400))
        window_level = float(request.GET.get('wl', 40))
        invert = request.GET.get('invert', 'false').lower() == 'true'
        
        # Load volume data (reuse MPR loading logic)
        images = series.images.all().order_by('instance_number')
        if not images.exists():
            return JsonResponse({'error': 'No images found in series'}, status=404)
        
        volume_data = []
        for image in images:
            try:
                file_path = os.path.join(settings.MEDIA_ROOT, str(image.file_path))
                if not os.path.exists(file_path):
                    continue
                
                ds = _load_dicom_optimized(file_path)
                if ds is None:
                    continue
                
                pixel_array = ds.pixel_array.astype(np.float32)
                slope = float(getattr(ds, 'RescaleSlope', 1.0))
                intercept = float(getattr(ds, 'RescaleIntercept', 0.0))
                pixel_array = pixel_array * slope + intercept
                
                volume_data.append(pixel_array)
                
            except Exception as e:
                logger.error(f"Error loading image for MIP: {e}")
                continue
        
        if not volume_data:
            return JsonResponse({'error': 'Failed to load volume data'}, status=500)
        
        # Create 3D volume
        volume = np.stack(volume_data, axis=0)
        
        # Calculate MIP projections
        mip_views = {}
        mip_views['axial'] = _array_to_base64_image(np.max(volume, axis=0), window_width, window_level, invert)
        mip_views['sagittal'] = _array_to_base64_image(np.max(volume, axis=2), window_width, window_level, invert)
        mip_views['coronal'] = _array_to_base64_image(np.max(volume, axis=1), window_width, window_level, invert)
        
        return JsonResponse({
            'success': True,
            'mip_views': mip_views,
            'volume_shape': volume.shape,
            'counts': {
                'axial': volume.shape[0],
                'sagittal': volume.shape[2],
                'coronal': volume.shape[1]
            }
        })
        
    except Exception as e:
        logger.error(f"Error in MIP reconstruction: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def api_bone_reconstruction(request, series_id):
    """Professional bone 3D reconstruction"""
    try:
        series = get_object_or_404(Series, id=series_id)
        
        # Check permissions
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and series.study.facility != request.user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
        
        # Get parameters
        threshold = int(request.GET.get('threshold', 200))
        window_width = float(request.GET.get('ww', 2000))
        window_level = float(request.GET.get('wl', 300))
        invert = request.GET.get('invert', 'false').lower() == 'true'
        want_mesh = request.GET.get('mesh', 'false').lower() == 'true'
        
        # Load volume data
        images = series.images.all().order_by('instance_number')
        if images.count() < 2:
            return JsonResponse({'error': 'Bone reconstruction requires at least 2 images'}, status=400)
        
        volume_data = []
        for image in images:
            try:
                file_path = os.path.join(settings.MEDIA_ROOT, str(image.file_path))
                ds = _load_dicom_optimized(file_path)
                if ds is None:
                    continue
                
                pixel_array = ds.pixel_array.astype(np.float32)
                slope = float(getattr(ds, 'RescaleSlope', 1.0))
                intercept = float(getattr(ds, 'RescaleIntercept', 0.0))
                pixel_array = pixel_array * slope + intercept
                
                volume_data.append(pixel_array)
                
            except Exception:
                continue
        
        if len(volume_data) < 2:
            return JsonResponse({'error': 'Failed to load sufficient volume data'}, status=500)
        
        # Create 3D volume
        volume = np.stack(volume_data, axis=0)
        
        # Enhance for thin stacks
        if volume.shape[0] < 32:
            from scipy import ndimage
            factor = max(2, int(np.ceil(32 / volume.shape[0])))
            volume = ndimage.zoom(volume, (factor, 1, 1), order=3)
        
        # Apply bone threshold
        bone_mask = volume >= threshold
        bone_volume = volume * bone_mask
        
        # Generate bone views
        bone_views = {}
        axial_idx = bone_volume.shape[0] // 2
        sagittal_idx = bone_volume.shape[2] // 2
        coronal_idx = bone_volume.shape[1] // 2
        
        bone_views['axial'] = _array_to_base64_image(bone_volume[axial_idx], window_width, window_level, invert)
        bone_views['sagittal'] = _array_to_base64_image(bone_volume[:, :, sagittal_idx], window_width, window_level, invert)
        bone_views['coronal'] = _array_to_base64_image(bone_volume[:, coronal_idx, :], window_width, window_level, invert)
        
        result = {
            'bone_views': bone_views,
            'volume_shape': list(bone_volume.shape),
            'counts': {
                'axial': int(bone_volume.shape[0]),
                'sagittal': int(bone_volume.shape[2]),
                'coronal': int(bone_volume.shape[1])
            },
            'threshold': threshold
        }
        
        # Generate mesh if requested
        if want_mesh:
            try:
                from skimage import measure
                verts, faces, normals, values = measure.marching_cubes(
                    (bone_volume > 0).astype(np.float32), level=0.5
                )
                
                # Simplify mesh for web display
                if len(verts) > 25000:
                    step = len(verts) // 12500
                    verts = verts[::step]
                    faces = faces[::step]
                
                result['mesh'] = {
                    'vertices': verts.tolist(),
                    'faces': faces.tolist()
                }
            except Exception as e:
                logger.warning(f"Mesh generation failed: {e}")
                result['mesh'] = None
        
        return JsonResponse(result)
        
    except Exception as e:
        logger.error(f"Error in bone reconstruction: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def api_volume_reconstruction(request, series_id):
    """Professional volume rendering reconstruction"""
    try:
        series = get_object_or_404(Series, id=series_id)
        
        # Check permissions
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and series.study.facility != request.user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
        
        # Get parameters
        window_width = float(request.GET.get('ww', 400))
        window_level = float(request.GET.get('wl', 40))
        invert = request.GET.get('invert', 'false').lower() == 'true'
        opacity = float(request.GET.get('opacity', 0.8))
        
        # Load volume data
        images = series.images.all().order_by('instance_number')
        if images.count() < 3:
            return JsonResponse({'error': 'Volume rendering requires at least 3 images'}, status=400)
        
        volume_data = []
        spacing = [1.0, 1.0, 1.0]
        
        for image in images:
            try:
                file_path = os.path.join(settings.MEDIA_ROOT, str(image.file_path))
                if not os.path.exists(file_path):
                    continue
                
                ds = _load_dicom_optimized(file_path)
                if ds is None:
                    continue
                
                pixel_array = ds.pixel_array.astype(np.float32)
                slope = float(getattr(ds, 'RescaleSlope', 1.0))
                intercept = float(getattr(ds, 'RescaleIntercept', 0.0))
                pixel_array = pixel_array * slope + intercept
                
                volume_data.append(pixel_array)
                
                # Get spacing from first image
                if len(volume_data) == 1:
                    pixel_spacing = getattr(ds, 'PixelSpacing', [1.0, 1.0])
                    slice_thickness = getattr(ds, 'SliceThickness', 1.0)
                    spacing = [float(slice_thickness), float(pixel_spacing[0]), float(pixel_spacing[1])]
                
            except Exception as e:
                logger.error(f"Error loading image for volume rendering: {e}")
                continue
        
        if len(volume_data) < 3:
            return JsonResponse({'error': 'Failed to load sufficient volume data'}, status=500)
        
        # Create 3D volume
        volume = np.stack(volume_data, axis=0)
        
        # Generate volume renderings (simplified version)
        slices, rows, cols = volume.shape
        
        # Calculate center indices for volume views
        axial_idx = slices // 2
        sagittal_idx = cols // 2
        coronal_idx = rows // 2
        
        # Create volume projections
        volume_views = {}
        
        # Use maximum intensity projection for volume rendering effect
        volume_views['axial'] = _array_to_base64_image(
            np.max(volume[max(0, axial_idx-5):min(slices, axial_idx+5)], axis=0), 
            window_width, window_level, invert
        )
        volume_views['sagittal'] = _array_to_base64_image(
            np.max(volume[:, :, max(0, sagittal_idx-5):min(cols, sagittal_idx+5)], axis=2), 
            window_width, window_level, invert
        )
        volume_views['coronal'] = _array_to_base64_image(
            np.max(volume[:, max(0, coronal_idx-5):min(rows, coronal_idx+5), :], axis=1), 
            window_width, window_level, invert
        )
        
        return JsonResponse({
            'success': True,
            'volume_views': volume_views,
            'volume_shape': list(volume.shape),
            'spacing': spacing,
            'opacity': opacity,
            'modality': series.modality
        })
        
    except Exception as e:
        logger.error(f"Error in volume reconstruction: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def api_hounsfield_units(request):
    """Professional HU calculation"""
    if request.method != 'POST':
        return JsonResponse({'error': 'Method not allowed'}, status=405)
    
    try:
        data = json.loads(request.body)
        x = int(data.get('x', 0))
        y = int(data.get('y', 0))
        image_id = data.get('image_id')
        
        if not image_id:
            return JsonResponse({'error': 'Image ID required'}, status=400)
        
        image = get_object_or_404(DicomImage, id=image_id)
        
        # Check permissions
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and image.series.study.facility != request.user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
        
        # Load DICOM and calculate HU
        file_path = os.path.join(settings.MEDIA_ROOT, str(image.file_path))
        ds = _load_dicom_optimized(file_path)
        
        if ds is None:
            return JsonResponse({'error': 'Failed to load DICOM data'}, status=500)
        
        pixel_array = ds.pixel_array
        
        # Validate coordinates
        if y >= pixel_array.shape[0] or x >= pixel_array.shape[1] or x < 0 or y < 0:
            return JsonResponse({'error': 'Coordinates out of bounds'}, status=400)
        
        # Get raw pixel value
        raw_value = int(pixel_array[y, x])
        
        # Apply rescaling for HU
        slope = float(getattr(ds, 'RescaleSlope', 1.0))
        intercept = float(getattr(ds, 'RescaleIntercept', 0.0))
        hu_value = raw_value * slope + intercept
        
        return JsonResponse({
            'hu_value': round(float(hu_value), 1),
            'raw_value': raw_value,
            'position': {'x': x, 'y': y},
            'rescale_slope': slope,
            'rescale_intercept': intercept
        })
        
    except Exception as e:
        logger.error(f"Error calculating HU: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
def api_hu_value(request):
    """Get HU value at specific coordinates - supports both GET and POST"""
    try:
        if request.method == 'GET':
            # GET request with query parameters
            x = request.GET.get('x')
            y = request.GET.get('y')
            image_id = request.GET.get('image_id')
            mode = request.GET.get('mode', 'image')
        elif request.method == 'POST':
            # POST request with JSON body
            data = json.loads(request.body)
            x = data.get('x')
            y = data.get('y')
            image_id = data.get('image_id')
            mode = data.get('mode', 'image')
        else:
            return JsonResponse({'error': 'Method not allowed'}, status=405)
        
        # Validate parameters
        if x is None or y is None or image_id is None:
            return JsonResponse({'error': 'Missing required parameters: x, y, image_id'}, status=400)
        
        try:
            x = int(x)
            y = int(y)
            image_id = int(image_id)
        except (ValueError, TypeError):
            return JsonResponse({'error': 'Invalid parameter values'}, status=400)
        
        # Get image
        image = get_object_or_404(DicomImage, id=image_id)
        
        # Check permissions
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and image.series.study.facility != request.user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
        
        # Load DICOM and calculate HU
        file_path = os.path.join(settings.MEDIA_ROOT, str(image.file_path))
        if not os.path.exists(file_path):
            return JsonResponse({'error': 'DICOM file not found'}, status=404)
        
        ds = _load_dicom_optimized(file_path)
        if ds is None:
            return JsonResponse({'error': 'Failed to load DICOM data'}, status=500)
        
        pixel_array = ds.pixel_array
        
        # Validate coordinates
        if y >= pixel_array.shape[0] or x >= pixel_array.shape[1] or x < 0 or y < 0:
            return JsonResponse({'error': 'Coordinates out of bounds'}, status=400)
        
        # Get raw pixel value
        raw_value = int(pixel_array[y, x])
        
        # Apply rescaling for HU
        slope = float(getattr(ds, 'RescaleSlope', 1.0))
        intercept = float(getattr(ds, 'RescaleIntercept', 0.0))
        hu_value = raw_value * slope + intercept
        
        return JsonResponse({
            'hu_value': round(float(hu_value), 1),
            'raw_value': raw_value,
            'position': {'x': x, 'y': y},
            'rescale_slope': slope,
            'rescale_intercept': intercept,
            'mode': mode
        })
        
    except Exception as e:
        logger.error(f"Error calculating HU value: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def upload_dicom(request):
    """Professional DICOM upload with enhanced processing and error handling"""
    if request.method != 'POST':
        return JsonResponse({'error': 'Method not allowed'}, status=405)
    
    try:
        uploaded_files = request.FILES.getlist('dicom_files')
        if not uploaded_files:
            dicom_file = request.FILES.get('dicom_file')
            if dicom_file:
                uploaded_files = [dicom_file]
        
        if not uploaded_files:
            return JsonResponse({'success': False, 'error': 'No files uploaded'})
        
        upload_id = str(uuid.uuid4())
        processed_files = 0
        
        # Group by study and series UIDs
        studies_map = {}
        invalid_files = 0
        
        for file in uploaded_files:
            try:
                ds = pydicom.dcmread(file, force=True)
                study_uid = getattr(ds, 'StudyInstanceUID', None)
                series_uid = getattr(ds, 'SeriesInstanceUID', None)
                
                if not study_uid or not series_uid:
                    invalid_files += 1
                    continue
                
                if study_uid not in studies_map:
                    studies_map[study_uid] = {}
                if series_uid not in studies_map[study_uid]:
                    studies_map[study_uid][series_uid] = []
                
                studies_map[study_uid][series_uid].append((ds, file))
                
            except Exception:
                invalid_files += 1
                continue
        
        if not studies_map:
            return JsonResponse({'success': False, 'error': 'No valid DICOM files found'})
        
        # Process first study found
        study_uid = next(iter(studies_map.keys()))
        series_map = studies_map[study_uid]
        
        # Create patient and study records
        first_ds = next(iter(next(iter(series_map.values()))))[0]
        
        # Extract patient info
        patient_id = str(getattr(first_ds, 'PatientID', f'TEMP_{upload_id[:8]}'))
        patient_name = str(getattr(first_ds, 'PatientName', 'TEMP^UPLOAD'))
        name_parts = patient_name.replace('^', ' ').split()
        first_name = name_parts[0] if name_parts else 'TEMP'
        last_name = name_parts[1] if len(name_parts) > 1 else upload_id[:8]
        
        # Handle birth date
        birth_date = getattr(first_ds, 'PatientBirthDate', None)
        if birth_date:
            try:
                from datetime import datetime
                dob = datetime.strptime(birth_date, '%Y%m%d').date()
            except Exception:
                dob = timezone.now().date()
        else:
            dob = timezone.now().date()
        
        gender = getattr(first_ds, 'PatientSex', 'O')
        if gender not in ['M', 'F', 'O']:
            gender = 'O'
        
        with transaction.atomic():
            # Create or get patient
            patient, _ = Patient.objects.get_or_create(
                patient_id=patient_id,
                defaults={
                    'first_name': first_name,
                    'last_name': last_name,
                    'date_of_birth': dob,
                    'gender': gender
                }
            )
            
            # Get or create facility
            facility = getattr(request.user, 'facility', None)
            if not facility:
                facility = Facility.objects.filter(is_active=True).first()
            if not facility:
                if hasattr(request.user, 'is_admin') and request.user.is_admin():
                    facility = Facility.objects.create(
                        name='Default Facility',
                        address='N/A',
                        phone='N/A',
                        email='default@example.com',
                        license_number=f'DEFAULT-{upload_id[:8]}',
                        is_active=True
                    )
                else:
                    return JsonResponse({'success': False, 'error': 'No facility configured'})
            
            # Create modality and study
            modality_code = getattr(first_ds, 'Modality', 'OT')
            modality, _ = Modality.objects.get_or_create(
                code=modality_code,
                defaults={'name': modality_code}
            )
            
            study_description = getattr(first_ds, 'StudyDescription', 'Uploaded DICOM Study')
            accession_number = getattr(first_ds, 'AccessionNumber', f"UPLOAD_{upload_id[:8]}")
            
            # Handle study date
            study_date = getattr(first_ds, 'StudyDate', None)
            study_time = getattr(first_ds, 'StudyTime', '000000')
            if study_date:
                try:
                    from datetime import datetime
                    sdt = datetime.strptime(f"{study_date}{study_time[:6]}", '%Y%m%d%H%M%S')
                    sdt = timezone.make_aware(sdt)
                except Exception:
                    sdt = timezone.now()
            else:
                sdt = timezone.now()
            
            study, _ = Study.objects.get_or_create(
                study_instance_uid=study_uid,
                defaults={
                    'accession_number': accession_number,
                    'patient': patient,
                    'facility': facility,
                    'modality': modality,
                    'study_description': study_description,
                    'study_date': sdt,
                    'referring_physician': str(getattr(first_ds, 'ReferringPhysicianName', 'UNKNOWN')).replace('^', ' '),
                    'status': 'completed',
                    'priority': 'normal',
                    'uploaded_by': request.user,
                }
            )
            
            # Create series and images
            for series_uid, items in series_map.items():
                ds0, _ = items[0]
                series_number = getattr(ds0, 'SeriesNumber', 1) or 1
                series_desc = getattr(ds0, 'SeriesDescription', f'Series {series_number}')
                
                series_obj, _ = Series.objects.get_or_create(
                    series_instance_uid=series_uid,
                    defaults={
                        'study': study,
                        'series_number': int(series_number),
                        'series_description': series_desc,
                        'modality': getattr(ds0, 'Modality', modality_code),
                        'body_part': getattr(ds0, 'BodyPartExamined', ''),
                        'slice_thickness': getattr(ds0, 'SliceThickness', None),
                        'pixel_spacing': str(getattr(ds0, 'PixelSpacing', '')),
                        'image_orientation': str(getattr(ds0, 'ImageOrientationPatient', '')),
                    }
                )
                
                for ds, file_obj in items:
                    try:
                        sop_uid = getattr(ds, 'SOPInstanceUID')
                        instance_number = getattr(ds, 'InstanceNumber', 1) or 1
                        
                        # Save file
                        rel_path = f"dicom/images/{study_uid}/{series_uid}/{sop_uid}.dcm"
                        file_obj.seek(0)
                        saved_path = default_storage.save(rel_path, ContentFile(file_obj.read()))
                        
                        DicomImage.objects.get_or_create(
                            sop_instance_uid=sop_uid,
                            defaults={
                                'series': series_obj,
                                'instance_number': int(instance_number),
                                'image_position': str(getattr(ds, 'ImagePositionPatient', '')),
                                'slice_location': getattr(ds, 'SliceLocation', None),
                                'file_path': saved_path,
                                'file_size': getattr(file_obj, 'size', 0) or 0,
                                'processed': True,
                            }
                        )
                        processed_files += 1
                        
                    except Exception as e:
                        logger.error(f"Error processing DICOM file: {e}")
                        continue
        
        if processed_files == 0:
            return JsonResponse({'success': False, 'error': 'No files processed successfully'})
        
        return JsonResponse({
            'success': True,
            'message': f'Successfully uploaded {processed_files} DICOM files',
            'study_id': study.id,
            'processed_files': processed_files,
            'total_files': len(uploaded_files),
            'series_count': len(series_map)
        })
        
    except Exception as e:
        logger.error(f"Error in DICOM upload: {e}")
        return JsonResponse({'success': False, 'error': str(e)})

# Import bulletproof functions for demo
from .views_bulletproof import api_study_data_bulletproof, api_image_display_bulletproof, web_series_images_bulletproof

@login_required
@csrf_exempt
def api_measurements(request, study_id=None):
    """Professional measurements API"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            measurements_data = data.get('measurements', [])
            annotations_data = data.get('annotations', [])
            
            if study_id:
                study = get_object_or_404(Study, id=study_id)
                
                # Check permissions
                if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and study.facility != request.user.facility:
                    return JsonResponse({'error': 'Permission denied'}, status=403)
                
                # Save to database
                with transaction.atomic():
                    for measurement_data in measurements_data:
                        try:
                            image_id = measurement_data.get('image_id')
                            if image_id:
                                image = DicomImage.objects.get(id=image_id)
                                Measurement.objects.create(
                                    user=request.user,
                                    image=image,
                                    measurement_type=measurement_data.get('type', 'length'),
                                    points=json.dumps(measurement_data.get('points', [])),
                                    value=measurement_data.get('value'),
                                    unit=measurement_data.get('unit', 'mm'),
                                    notes=measurement_data.get('notes', '')
                                )
                        except Exception as e:
                            logger.warning(f"Failed to save measurement: {e}")
                    
                    for annotation_data in annotations_data:
                        try:
                            image_id = annotation_data.get('image_id')
                            if image_id:
                                image = DicomImage.objects.get(id=image_id)
                                Annotation.objects.create(
                                    user=request.user,
                                    image=image,
                                    position_x=annotation_data.get('x', 0),
                                    position_y=annotation_data.get('y', 0),
                                    text=annotation_data.get('text', ''),
                                    color=annotation_data.get('color', '#FFFF00')
                                )
                        except Exception as e:
                            logger.warning(f"Failed to save annotation: {e}")
            
            return JsonResponse({'success': True, 'message': 'Measurements saved successfully'})
            
        except Exception as e:
            logger.error(f"Error saving measurements: {e}")
            return JsonResponse({'error': str(e)}, status=500)
    
    elif request.method == 'GET':
        # Load measurements
        if study_id:
            try:
                study = get_object_or_404(Study, id=study_id)
                study_images = DicomImage.objects.filter(series__study=study)
                
                measurements = Measurement.objects.filter(
                    image__in=study_images,
                    user=request.user
                )
                
                annotations = Annotation.objects.filter(
                    image__in=study_images,
                    user=request.user
                )
                
                measurements_data = []
                for m in measurements:
                    measurements_data.append({
                        'id': m.id,
                        'image_id': m.image.id,
                        'type': m.measurement_type,
                        'points': m.get_points(),
                        'value': m.value,
                        'unit': m.unit,
                        'notes': m.notes,
                        'created_at': m.created_at.isoformat()
                    })
                
                annotations_data = []
                for a in annotations:
                    annotations_data.append({
                        'id': a.id,
                        'image_id': a.image.id,
                        'x': a.position_x,
                        'y': a.position_y,
                        'text': a.text,
                        'color': a.color,
                        'created_at': a.created_at.isoformat()
                    })
                
                return JsonResponse({
                    'measurements': measurements_data,
                    'annotations': annotations_data
                })
                
            except Exception as e:
                logger.error(f"Error loading measurements: {e}")
                return JsonResponse({'error': str(e)}, status=500)
        else:
            # Session-based measurements for standalone viewer
            measurements = request.session.get('measurements', [])
            annotations = request.session.get('annotations', [])
            return JsonResponse({
                'measurements': measurements,
                'annotations': annotations
            })
    
    else:
        return JsonResponse({'error': 'Method not allowed'}, status=405)

@login_required
@csrf_exempt
def api_calculate_distance(request):
    """Professional distance calculation with pixel spacing"""
    if request.method != 'POST':
        return JsonResponse({'error': 'Method not allowed'}, status=405)
    
    try:
        data = json.loads(request.body)
        start_x = data.get('start_x')
        start_y = data.get('start_y')
        end_x = data.get('end_x')
        end_y = data.get('end_y')
        
        # Validate that all required parameters are provided
        if start_x is None or start_y is None or end_x is None or end_y is None:
            return JsonResponse({'error': 'Missing required parameters: start_x, start_y, end_x, end_y'}, status=400)
        
        # Convert to float with error handling
        try:
            start_x = float(start_x)
            start_y = float(start_y)
            end_x = float(end_x)
            end_y = float(end_y)
        except (ValueError, TypeError):
            return JsonResponse({'error': 'Invalid coordinate values'}, status=400)
        
        pixel_spacing = data.get('pixel_spacing', [1.0, 1.0])
        
        # Calculate pixel distance
        pixel_distance = np.sqrt((end_x - start_x)**2 + (end_y - start_y)**2)
        
        # Calculate real-world distance
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
            except Exception:
                pass
        
        return JsonResponse({
            'pixel_distance': round(pixel_distance, 2),
            'formatted_text': f"{pixel_distance:.1f} px"
        })
        
    except Exception as e:
        logger.error(f"Error calculating distance: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def api_mri_reconstruction(request, series_id):
    """Professional MRI reconstruction with tissue-specific analysis"""
    try:
        series = get_object_or_404(Series, id=series_id)
        
        # Check permissions
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and series.study.facility != request.user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
        
        # Get parameters
        tissue_type = request.GET.get('tissue_type', 'brain')
        window_width = float(request.GET.get('ww', 200))
        window_level = float(request.GET.get('wl', 100))
        invert = request.GET.get('invert', 'false').lower() == 'true'
        
        # Load volume data
        images = series.images.all().order_by('instance_number')
        if not images.exists():
            return JsonResponse({'error': 'No images found in series'}, status=404)
        
        volume_data = []
        spacing = [1.0, 1.0, 1.0]
        
        for image in images:
            try:
                file_path = os.path.join(settings.MEDIA_ROOT, str(image.file_path))
                if not os.path.exists(file_path):
                    continue
                
                ds = _load_dicom_optimized(file_path)
                if ds is None:
                    continue
                
                pixel_array = ds.pixel_array.astype(np.float32)
                
                # MRI typically doesn't need HU conversion
                # but may need intensity normalization
                volume_data.append(pixel_array)
                
                # Get spacing from first image
                if len(volume_data) == 1:
                    pixel_spacing = getattr(ds, 'PixelSpacing', [1.0, 1.0])
                    slice_thickness = getattr(ds, 'SliceThickness', 1.0)
                    spacing = [float(slice_thickness), float(pixel_spacing[0]), float(pixel_spacing[1])]
                
            except Exception as e:
                logger.error(f"Error loading MRI image: {e}")
                continue
        
        if not volume_data:
            return JsonResponse({'error': 'Failed to load MRI volume data'}, status=500)
        
        # Create 3D volume
        volume = np.stack(volume_data, axis=0)
        
        # Create metadata
        from .reconstruction import VolumeMetadata, ReconstructionParameters
        metadata = VolumeMetadata(
            dimensions=volume.shape,
            spacing=tuple(spacing),
            origin=(0.0, 0.0, 0.0),
            orientation=[1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
            modality='MR',
            patient_id=series.study.patient.patient_id,
            study_uid=series.study.study_instance_uid,
            series_uid=series.series_instance_uid
        )
        
        params = ReconstructionParameters(algorithm='mri_3d', quality='normal')
        
        # Create MRI processor and reconstruct
        processor = MRI3DProcessor()
        results = processor.create_mri_reconstruction(volume, metadata, params, tissue_type)
        
        # Convert projections to base64
        mri_views = {}
        for view_name, projection in results['projections'].items():
            mri_views[view_name] = _array_to_base64_image(projection, window_width, window_level, invert)
        
        return JsonResponse({
            'success': True,
            'mri_views': mri_views,
            'tissue_type': tissue_type,
            'contrast_analysis': results.get('contrast_analysis', {}),
            'volume_shape': list(volume.shape),
            'modality': 'MRI'
        })
        
    except Exception as e:
        logger.error(f"Error in MRI reconstruction: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def api_pet_reconstruction(request, series_id):
    """Professional PET reconstruction with SUV analysis"""
    try:
        series = get_object_or_404(Series, id=series_id)
        
        # Check permissions
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and series.study.facility != request.user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
        
        # Get parameters
        window_width = float(request.GET.get('ww', 1000))
        window_level = float(request.GET.get('wl', 500))
        invert = request.GET.get('invert', 'false').lower() == 'true'
        
        # Load volume data
        images = series.images.all().order_by('instance_number')
        if not images.exists():
            return JsonResponse({'error': 'No images found in series'}, status=404)
        
        volume_data = []
        spacing = [1.0, 1.0, 1.0]
        
        for image in images:
            try:
                file_path = os.path.join(settings.MEDIA_ROOT, str(image.file_path))
                if not os.path.exists(file_path):
                    continue
                
                ds = _load_dicom_optimized(file_path)
                if ds is None:
                    continue
                
                pixel_array = ds.pixel_array.astype(np.float32)
                
                # PET data is typically in counts, may need calibration
                slope = float(getattr(ds, 'RescaleSlope', 1.0))
                intercept = float(getattr(ds, 'RescaleIntercept', 0.0))
                pixel_array = pixel_array * slope + intercept
                
                volume_data.append(pixel_array)
                
                # Get spacing
                if len(volume_data) == 1:
                    pixel_spacing = getattr(ds, 'PixelSpacing', [1.0, 1.0])
                    slice_thickness = getattr(ds, 'SliceThickness', 1.0)
                    spacing = [float(slice_thickness), float(pixel_spacing[0]), float(pixel_spacing[1])]
                
            except Exception as e:
                logger.error(f"Error loading PET image: {e}")
                continue
        
        if not volume_data:
            return JsonResponse({'error': 'Failed to load PET volume data'}, status=500)
        
        # Create 3D volume
        volume = np.stack(volume_data, axis=0)
        
        # Create metadata
        from .reconstruction import VolumeMetadata, ReconstructionParameters
        metadata = VolumeMetadata(
            dimensions=volume.shape,
            spacing=tuple(spacing),
            origin=(0.0, 0.0, 0.0),
            orientation=[1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
            modality='PT',
            patient_id=series.study.patient.patient_id,
            study_uid=series.study.study_instance_uid,
            series_uid=series.series_instance_uid
        )
        
        params = ReconstructionParameters(algorithm='pet', quality='normal')
        
        # Create PET processor and reconstruct
        processor = PETProcessor()
        results = processor.create_pet_reconstruction(volume, metadata, params)
        
        # Convert projections to base64 (PET projections are already colored)
        pet_views = {}
        for view_name, projection in results['projections'].items():
            if projection.ndim == 3:  # Colored projection
                # Convert RGB to grayscale for windowing, then back to RGB
                gray = np.dot(projection, [0.299, 0.587, 0.114])
                windowed = _apply_windowing_fast(gray, window_width, window_level, invert)
                # Convert back to RGB
                rgb_windowed = np.stack([windowed, windowed, windowed], axis=-1)
                pet_views[view_name] = _array_to_base64_image(rgb_windowed)
            else:
                pet_views[view_name] = _array_to_base64_image(projection, window_width, window_level, invert)
        
        return JsonResponse({
            'success': True,
            'pet_views': pet_views,
            'hotspots': results.get('hotspots', []),
            'volume_shape': list(volume.shape),
            'modality': 'PET'
        })
        
    except Exception as e:
        logger.error(f"Error in PET reconstruction: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def api_spect_reconstruction(request, series_id):
    """Professional SPECT reconstruction with perfusion analysis"""
    try:
        series = get_object_or_404(Series, id=series_id)
        
        # Check permissions
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and series.study.facility != request.user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
        
        # Get parameters
        tracer_type = request.GET.get('tracer', 'tc99m')
        window_width = float(request.GET.get('ww', 800))
        window_level = float(request.GET.get('wl', 400))
        invert = request.GET.get('invert', 'false').lower() == 'true'
        
        # Load volume data
        images = series.images.all().order_by('instance_number')
        if not images.exists():
            return JsonResponse({'error': 'No images found in series'}, status=404)
        
        volume_data = []
        spacing = [1.0, 1.0, 1.0]
        
        for image in images:
            try:
                file_path = os.path.join(settings.MEDIA_ROOT, str(image.file_path))
                if not os.path.exists(file_path):
                    continue
                
                ds = _load_dicom_optimized(file_path)
                if ds is None:
                    continue
                
                pixel_array = ds.pixel_array.astype(np.float32)
                
                # SPECT data calibration
                slope = float(getattr(ds, 'RescaleSlope', 1.0))
                intercept = float(getattr(ds, 'RescaleIntercept', 0.0))
                pixel_array = pixel_array * slope + intercept
                
                volume_data.append(pixel_array)
                
                # Get spacing
                if len(volume_data) == 1:
                    pixel_spacing = getattr(ds, 'PixelSpacing', [1.0, 1.0])
                    slice_thickness = getattr(ds, 'SliceThickness', 1.0)
                    spacing = [float(slice_thickness), float(pixel_spacing[0]), float(pixel_spacing[1])]
                
            except Exception as e:
                logger.error(f"Error loading SPECT image: {e}")
                continue
        
        if not volume_data:
            return JsonResponse({'error': 'Failed to load SPECT volume data'}, status=500)
        
        # Create 3D volume
        volume = np.stack(volume_data, axis=0)
        
        # Create metadata
        from .reconstruction import VolumeMetadata, ReconstructionParameters
        metadata = VolumeMetadata(
            dimensions=volume.shape,
            spacing=tuple(spacing),
            origin=(0.0, 0.0, 0.0),
            orientation=[1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
            modality='NM',
            patient_id=series.study.patient.patient_id,
            study_uid=series.study.study_instance_uid,
            series_uid=series.series_instance_uid
        )
        
        params = ReconstructionParameters(algorithm='spect', quality='normal')
        
        # Create SPECT processor and reconstruct
        processor = SPECTProcessor()
        results = processor.create_spect_reconstruction(volume, metadata, params, tracer_type)
        
        # Convert projections to base64
        spect_views = {}
        for view_name, projection in results['projections'].items():
            if projection.ndim == 3:  # Colored projection
                # Convert RGB to base64
                img = Image.fromarray(projection.astype(np.uint8))
                buffer = BytesIO()
                img.save(buffer, format='PNG')
                img_str = base64.b64encode(buffer.getvalue()).decode('ascii')
                spect_views[view_name] = f"data:image/png;base64,{img_str}"
            else:
                spect_views[view_name] = _array_to_base64_image(projection, window_width, window_level, invert)
        
        return JsonResponse({
            'success': True,
            'spect_views': spect_views,
            'tracer_type': tracer_type,
            'defects': results.get('defects', []),
            'polar_maps': results.get('polar_maps', {}),
            'volume_shape': list(volume.shape),
            'modality': 'SPECT'
        })
        
    except Exception as e:
        logger.error(f"Error in SPECT reconstruction: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def api_nuclear_reconstruction(request, series_id):
    """Professional Nuclear Medicine reconstruction for various isotopes"""
    try:
        series = get_object_or_404(Series, id=series_id)
        
        # Check permissions
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and series.study.facility != request.user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
        
        # Get parameters
        isotope = request.GET.get('isotope', 'tc99m')
        window_width = float(request.GET.get('ww', 600))
        window_level = float(request.GET.get('wl', 300))
        invert = request.GET.get('invert', 'false').lower() == 'true'
        
        # Load volume data
        images = series.images.all().order_by('instance_number')
        if not images.exists():
            return JsonResponse({'error': 'No images found in series'}, status=404)
        
        volume_data = []
        spacing = [1.0, 1.0, 1.0]
        
        for image in images:
            try:
                file_path = os.path.join(settings.MEDIA_ROOT, str(image.file_path))
                if not os.path.exists(file_path):
                    continue
                
                ds = _load_dicom_optimized(file_path)
                if ds is None:
                    continue
                
                pixel_array = ds.pixel_array.astype(np.float32)
                
                # Nuclear medicine calibration
                slope = float(getattr(ds, 'RescaleSlope', 1.0))
                intercept = float(getattr(ds, 'RescaleIntercept', 0.0))
                pixel_array = pixel_array * slope + intercept
                
                volume_data.append(pixel_array)
                
                # Get spacing
                if len(volume_data) == 1:
                    pixel_spacing = getattr(ds, 'PixelSpacing', [1.0, 1.0])
                    slice_thickness = getattr(ds, 'SliceThickness', 1.0)
                    spacing = [float(slice_thickness), float(pixel_spacing[0]), float(pixel_spacing[1])]
                
            except Exception as e:
                logger.error(f"Error loading nuclear medicine image: {e}")
                continue
        
        if not volume_data:
            return JsonResponse({'error': 'Failed to load nuclear medicine volume data'}, status=500)
        
        # Create 3D volume
        volume = np.stack(volume_data, axis=0)
        
        # Create metadata
        from .reconstruction import VolumeMetadata, ReconstructionParameters
        metadata = VolumeMetadata(
            dimensions=volume.shape,
            spacing=tuple(spacing),
            origin=(0.0, 0.0, 0.0),
            orientation=[1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
            modality='NM',
            patient_id=series.study.patient.patient_id,
            study_uid=series.study.study_instance_uid,
            series_uid=series.series_instance_uid
        )
        
        params = ReconstructionParameters(algorithm='nuclear', quality='normal')
        
        # Create Nuclear Medicine processor and reconstruct
        processor = NuclearMedicineProcessor()
        results = processor.create_nuclear_reconstruction(volume, metadata, params, isotope)
        
        # Convert projections to base64
        nuclear_views = {}
        for view_name, projection in results['projections'].items():
            nuclear_views[view_name] = _array_to_base64_image(projection, window_width, window_level, invert)
        
        return JsonResponse({
            'success': True,
            'nuclear_views': nuclear_views,
            'isotope': isotope,
            'energy_window': results.get('energy_window', 'N/A'),
            'volume_shape': list(volume.shape),
            'modality': 'Nuclear Medicine'
        })
        
    except Exception as e:
        logger.error(f"Error in nuclear medicine reconstruction: {e}")
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def api_modality_reconstruction_options(request, series_id):
    """Get available reconstruction options for a specific modality"""
    try:
        series = get_object_or_404(Series, id=series_id)
        
        # Check permissions
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and series.study.facility != request.user.facility:
            return JsonResponse({'error': 'Permission denied'}, status=403)
        
        modality = series.modality.upper()
        available_types = get_available_reconstruction_types(modality)
        recommended_processor = get_modality_specific_processor(modality)
        
        # Modality-specific parameters
        modality_params = {
            'CT': {
                'default_ww': 400,
                'default_wl': 40,
                'presets': ['lung', 'bone', 'soft', 'brain'],
                'features': ['MPR', 'MIP', 'Bone 3D', 'Volume Rendering']
            },
            'MR': {
                'default_ww': 200,
                'default_wl': 100,
                'presets': ['brain', 'spine', 'cardiac'],
                'features': ['MPR', 'MIP', 'Tissue Segmentation', 'T1/T2 Analysis']
            },
            'PT': {
                'default_ww': 1000,
                'default_wl': 500,
                'presets': ['suv', 'hotspot'],
                'features': ['SUV Analysis', 'Hotspot Detection', 'MIP', 'Fusion']
            },
            'NM': {
                'default_ww': 600,
                'default_wl': 300,
                'presets': ['perfusion', 'cardiac'],
                'features': ['Perfusion Analysis', 'Polar Maps', 'Defect Detection']
            }
        }
        
        params = modality_params.get(modality, {
            'default_ww': 400,
            'default_wl': 40,
            'presets': ['standard'],
            'features': ['MPR', 'MIP']
        })
        
        return JsonResponse({
            'modality': modality,
            'available_reconstructions': available_types,
            'recommended_processor': recommended_processor,
            'parameters': params,
            'series_info': {
                'id': series.id,
                'description': series.series_description,
                'image_count': series.images.count()
            }
        })
        
    except Exception as e:
        logger.error(f"Error getting reconstruction options: {e}")
        return JsonResponse({'error': str(e)}, status=500)

# Redirect old endpoints to new professional viewer
@login_required
def launch_standalone_viewer(request):
    """Launch standalone viewer - redirect to web viewer"""
    return redirect('dicom_viewer:viewer')

@login_required
def launch_study_in_desktop_viewer(request, study_id):
    """Launch study in desktop viewer - redirect to web viewer with study"""
    return redirect(f'/dicom-viewer/?study={study_id}')

@login_required
def web_index(request):
    """Web viewer index - redirect to main viewer"""
    return redirect('dicom_viewer:viewer')

@login_required
def web_viewer(request):
    """Web viewer - redirect to main viewer"""
    study_id = request.GET.get('study_id')
    if study_id:
        return redirect(f'/dicom-viewer/?study={study_id}')
    return redirect('dicom_viewer:viewer')

# Additional missing functions for HU calibration and QA phantoms
from django.contrib.auth.decorators import user_passes_test

@login_required
@user_passes_test(lambda u: hasattr(u, 'is_admin') and u.is_admin() or hasattr(u, 'is_technician') and u.is_technician())
def hu_calibration_dashboard(request):
    """Hounsfield Unit calibration dashboard"""
    try:
        from .models import HounsfieldCalibration, HounsfieldQAPhantom
        from .dicom_utils import DicomProcessor
    except ImportError:
        # If models don't exist, return empty context
        context = {
            'recent_calibrations': [],
            'total_calibrations': 0,
            'valid_calibrations': 0,
            'invalid_calibrations': 0,
            'success_rate': 0,
            'scanner_stats': {},
            'available_phantoms': [],
        }
        return render(request, 'dicom_viewer/hu_calibration_dashboard.html', context)
    
    # Get recent calibrations
    recent_calibrations = HounsfieldCalibration.objects.all()[:20] if HounsfieldCalibration else []
    
    # Get calibration statistics
    total_calibrations = HounsfieldCalibration.objects.count() if HounsfieldCalibration else 0
    valid_calibrations = HounsfieldCalibration.objects.filter(is_valid=True).count() if HounsfieldCalibration else 0
    invalid_calibrations = HounsfieldCalibration.objects.filter(is_valid=False).count() if HounsfieldCalibration else 0
    
    # Get scanner statistics
    scanner_stats = {}
    if HounsfieldCalibration:
        for calibration in HounsfieldCalibration.objects.all():
            scanner_key = f"{calibration.manufacturer} {calibration.model}"
            if scanner_key not in scanner_stats:
                scanner_stats[scanner_key] = {
                    'total': 0,
                    'valid': 0,
                    'invalid': 0,
                    'latest_date': None
                }
            
            scanner_stats[scanner_key]['total'] += 1
            if calibration.is_valid:
                scanner_stats[scanner_key]['valid'] += 1
            else:
                scanner_stats[scanner_key]['invalid'] += 1
            
            if not scanner_stats[scanner_key]['latest_date'] or calibration.created_at.date() > scanner_stats[scanner_key]['latest_date']:
                scanner_stats[scanner_key]['latest_date'] = calibration.created_at.date()
    
    # Get available phantoms
    available_phantoms = HounsfieldQAPhantom.objects.filter(is_active=True) if HounsfieldQAPhantom else []
    
    context = {
        'recent_calibrations': recent_calibrations,
        'total_calibrations': total_calibrations,
        'valid_calibrations': valid_calibrations,
        'invalid_calibrations': invalid_calibrations,
        'success_rate': (valid_calibrations / total_calibrations * 100) if total_calibrations > 0 else 0,
        'scanner_stats': scanner_stats,
        'available_phantoms': available_phantoms,
    }
    
    return render(request, 'dicom_viewer/hu_calibration_dashboard.html', context)

@login_required
@user_passes_test(lambda u: hasattr(u, 'is_admin') and u.is_admin())
def manage_qa_phantoms(request):
    """Manage QA phantoms for HU calibration"""
    try:
        from .models import HounsfieldQAPhantom
    except ImportError:
        # If model doesn't exist, return empty context
        phantoms = []
        context = {'phantoms': phantoms}
        return render(request, 'dicom_viewer/manage_qa_phantoms.html', context)
    
    phantoms = HounsfieldQAPhantom.objects.all().order_by('-created_at')
    
    if request.method == 'POST':
        action = request.POST.get('action')
        
        if action == 'create':
            try:
                phantom = HounsfieldQAPhantom.objects.create(
                    name=request.POST.get('name'),
                    manufacturer=request.POST.get('manufacturer'),
                    model=request.POST.get('model'),
                    description=request.POST.get('description', ''),
                    water_roi_coordinates=json.loads(request.POST.get('water_roi', '{}')),
                    air_roi_coordinates=json.loads(request.POST.get('air_roi', '{}')),
                    expected_water_hu=float(request.POST.get('expected_water_hu', 0.0)),
                    expected_air_hu=float(request.POST.get('expected_air_hu', -1000.0)),
                    water_tolerance=float(request.POST.get('water_tolerance', 5.0)),
                    air_tolerance=float(request.POST.get('air_tolerance', 50.0))
                )
                messages.success(request, f'QA phantom "{phantom.name}" created successfully')
            except Exception as e:
                messages.error(request, f'Error creating phantom: {str(e)}')
        
        elif action == 'toggle_active':
            phantom_id = request.POST.get('phantom_id')
            try:
                phantom = HounsfieldQAPhantom.objects.get(id=phantom_id)
                phantom.is_active = not phantom.is_active
                phantom.save()
                status = 'activated' if phantom.is_active else 'deactivated'
                messages.success(request, f'Phantom "{phantom.name}" {status}')
            except HounsfieldQAPhantom.DoesNotExist:
                messages.error(request, 'Phantom not found')
        
        return redirect('dicom_viewer:manage_qa_phantoms')
    
    context = {
        'phantoms': phantoms,
    }
    
    return render(request, 'dicom_viewer/manage_qa_phantoms.html', context)