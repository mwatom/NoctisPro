from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib import messages
from worklist.models import Study, Series, DicomImage, Patient, Modality
from accounts.models import User, Facility
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
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

from django.views.decorators.http import require_http_methods
from django.core.paginator import Paginator
from django.db.models import Q, Count
from django.conf import settings
from io import BytesIO
from PIL import Image
import base64
from pydicom.pixel_data_handlers.util import apply_voi_lut
import scipy.ndimage as ndimage
import logging

from .models import ViewerSession, Measurement, Annotation, ReconstructionJob
from .dicom_utils import DicomProcessor
from .reconstruction import MPRProcessor, MIPProcessor, Bone3DProcessor, MRI3DProcessor
from .models import WindowLevelPreset, HangingProtocol

# Initialize logger
logger = logging.getLogger(__name__)

# MPR volume small LRU cache (per-process)
from threading import Lock

_MPR_CACHE_LOCK = Lock()
_MPR_CACHE = {}  # series_id -> { 'volume': np.ndarray }
_MPR_CACHE_ORDER = []
_MAX_MPR_CACHE = 4

# Encoded MPR slice cache (LRU) to avoid repeated windowing+encoding per slice/plane/WW/WL
_MPR_IMG_CACHE_LOCK = Lock()
_MPR_IMG_CACHE = {}  # key -> base64 data URL
_MPR_IMG_CACHE_ORDER = []  # list of keys in LRU order
_MAX_MPR_IMG_CACHE = 800

def _mpr_cache_key(series_id, plane, slice_index, ww, wl, inverted):
    return f"{series_id}|{plane}|{int(slice_index)}|{int(round(float(ww)))}|{int(round(float(wl)))}|{1 if inverted else 0}"

def _mpr_cache_get(series_id, plane, slice_index, ww, wl, inverted):
    key = _mpr_cache_key(series_id, plane, slice_index, ww, wl, inverted)
    with _MPR_IMG_CACHE_LOCK:
        val = _MPR_IMG_CACHE.get(key)
        if val is not None:
            try:
                _MPR_IMG_CACHE_ORDER.remove(key)
            except ValueError:
                pass
            _MPR_IMG_CACHE_ORDER.append(key)
        return val

def _mpr_cache_set(series_id, plane, slice_index, ww, wl, inverted, img_b64):
    key = _mpr_cache_key(series_id, plane, slice_index, ww, wl, inverted)
    with _MPR_IMG_CACHE_LOCK:
        if key not in _MPR_IMG_CACHE:
            while len(_MPR_IMG_CACHE_ORDER) >= _MAX_MPR_IMG_CACHE:
                evict = _MPR_IMG_CACHE_ORDER.pop(0)
                _MPR_IMG_CACHE.pop(evict, None)
        _MPR_IMG_CACHE[key] = img_b64
        try:
            _MPR_IMG_CACHE_ORDER.remove(key)
        except ValueError:
            pass
        _MPR_IMG_CACHE_ORDER.append(key)

def _get_encoded_mpr_slice(series_id, volume, plane, slice_index, ww, wl, inverted):
    """Get encoded base64 PNG for given MPR slice, using cache if possible.
    volume is a numpy array (depth,height,width).
    """
    cached = _mpr_cache_get(series_id, plane, slice_index, ww, wl, inverted)
    if cached is not None:
        return cached
    
    # Validate slice index
    if plane == 'axial':
        if slice_index < 0 or slice_index >= volume.shape[0]:
            logger.warning(f"Invalid axial slice index {slice_index} for volume shape {volume.shape}")
            slice_index = min(max(0, slice_index), volume.shape[0] - 1)
        slice_array = volume[slice_index, :, :]
    elif plane == 'sagittal':
        if slice_index < 0 or slice_index >= volume.shape[2]:
            logger.warning(f"Invalid sagittal slice index {slice_index} for volume shape {volume.shape}")
            slice_index = min(max(0, slice_index), volume.shape[2] - 1)
        slice_array = volume[:, :, slice_index]
    else:  # coronal
        if slice_index < 0 or slice_index >= volume.shape[1]:
            logger.warning(f"Invalid coronal slice index {slice_index} for volume shape {volume.shape}")
            slice_index = min(max(0, slice_index), volume.shape[1] - 1)
        slice_array = volume[:, slice_index, :]
    
    img_b64 = _array_to_base64_image(slice_array, ww, wl, inverted)
    if img_b64:
        _mpr_cache_set(series_id, plane, slice_index, ww, wl, inverted, img_b64)
    else:
        logger.error(f"Failed to generate base64 image for MPR slice: series={series_id}, plane={plane}, slice={slice_index}")
    return img_b64

def _get_mpr_volume_for_series(series):
    """Return a 3D numpy volume (depth, height, width) for the given series.
    Uses a tiny LRU cache to avoid re-reading and decoding DICOMs on each request.
    """
    # Local import to avoid circular issues
    import numpy as _np
    import pydicom as _pydicom
    import os as _os

    with _MPR_CACHE_LOCK:
        entry = _MPR_CACHE.get(series.id)
        if entry is not None and isinstance(entry.get('volume'), _np.ndarray):
            # touch LRU order
            try:
                _MPR_CACHE_ORDER.remove(series.id)
            except ValueError:
                pass
            _MPR_CACHE_ORDER.append(series.id)
            return entry['volume']

    # Build the volume (read from disk once)
    images_qs = series.images.all().order_by('slice_location', 'instance_number')
    volume_data = []
    for img in images_qs:
        try:
            dicom_path = _os.path.join(settings.MEDIA_ROOT, str(img.file_path))
            ds = _pydicom.dcmread(dicom_path)
            try:
                pixel_array = ds.pixel_array.astype(_np.float32)
            except Exception:
                # Fallback to SimpleITK for compressed/transcoded pixel data
                try:
                    import SimpleITK as _sitk
                    sitk_image = _sitk.ReadImage(dicom_path)
                    px = _sitk.GetArrayFromImage(sitk_image)
                    if px.ndim == 3 and px.shape[0] == 1:
                        px = px[0]
                    pixel_array = px.astype(_np.float32)
                except Exception:
                    continue
            if hasattr(ds, 'RescaleSlope') and hasattr(ds, 'RescaleIntercept'):
                try:
                    pixel_array = pixel_array * float(ds.RescaleSlope) + float(ds.RescaleIntercept)
                except Exception:
                    pass
            volume_data.append(pixel_array)
        except Exception:
            continue

    if len(volume_data) < 2:
        raise ValueError('Not enough images for MPR')

    volume = _np.stack(volume_data, axis=0)
    # For very thin stacks, interpolate along depth to stabilize reformats
    if volume.shape[0] < 16:
        factor = max(2, int(_np.ceil(16 / max(volume.shape[0], 1))))
        volume = ndimage.zoom(volume, (factor, 1, 1), order=1)

    with _MPR_CACHE_LOCK:
        if series.id not in _MPR_CACHE:
            # Enforce tiny LRU size
            while len(_MPR_CACHE_ORDER) >= _MAX_MPR_CACHE:
                evict_id = _MPR_CACHE_ORDER.pop(0)
                _MPR_CACHE.pop(evict_id, None)
            _MPR_CACHE[series.id] = { 'volume': volume }
            _MPR_CACHE_ORDER.append(series.id)
        else:
            # Update existing
            _MPR_CACHE[series.id]['volume'] = volume
            try:
                _MPR_CACHE_ORDER.remove(series.id)
            except ValueError:
                pass
            _MPR_CACHE_ORDER.append(series.id)

    return volume


# Removed web-based viewer entrypoints (standalone_viewer, advanced_standalone_viewer, view_study)

@login_required
def viewer(request):
    """Entry: if ?study=<id> is provided, open that study in desktop viewer; else open launcher."""
    study_id = request.GET.get('study')
    if study_id:
        try:
            return redirect('dicom_viewer:launch_study_in_desktop_viewer', study_id=int(study_id))
        except Exception:
            return redirect('dicom_viewer:launch_standalone_viewer')
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
            'priority': study.priority,
            'clinical_info': study.clinical_info,
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
            'priority': series.study.priority,
            'clinical_info': series.study.clinical_info,
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
    """API endpoint for Multiplanar Reconstruction (MPR)
    - If no plane is provided, returns mid-slice preview images for axial/sagittal/coronal plus counts
    - If plane is provided (?plane=axial|sagittal|coronal&slice=<idx>), returns that slice image and counts
    """
    series = get_object_or_404(Series, id=series_id)
    user = request.user

    # Check permissions
    if user.is_facility_user() and getattr(user, 'facility', None) and series.study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)

    try:
        # Load isotropically-resampled volume from cache or build once
        volume, _spacing = _get_mpr_volume_and_spacing(series)
        
        # Validate volume data
        if volume is None or volume.size == 0:
            raise ValueError("Empty volume data")
        if volume.ndim != 3:
            raise ValueError(f"Volume must be 3D, got {volume.ndim}D")
        if np.any(np.isnan(volume)) or np.any(np.isinf(volume)):
            logger.warning(f"Volume contains NaN or inf values for series {series_id}")
            volume = np.nan_to_num(volume, nan=0.0, posinf=0.0, neginf=0.0)

        # Windowing params
        def _derive_window(arr, fallback=(400.0, 40.0)):
            try:
                flat = arr.astype(np.float32).flatten()
                p1 = float(np.percentile(flat, 1))
                p99 = float(np.percentile(flat, 99))
                ww = max(1.0, p99 - p1)
                wl = (p99 + p1) / 2.0
                return ww, wl
            except Exception:
                return fallback

        # Use provided window params if present; otherwise derive once
        ww_param = request.GET.get('window_width')
        wl_param = request.GET.get('window_level')
        inverted = request.GET.get('inverted', 'false').lower() == 'true'
        if ww_param is None or wl_param is None:
            default_window_width, default_window_level = _derive_window(volume)
            window_width = float(ww_param) if ww_param is not None else float(default_window_width)
            window_level = float(wl_param) if wl_param is not None else float(default_window_level)
        else:
            window_width = float(ww_param)
            window_level = float(wl_param)

        # Counts per plane
        counts = {
            'axial': int(volume.shape[0]),
            'sagittal': int(volume.shape[2]),
            'coronal': int(volume.shape[1]),
        }

        plane = request.GET.get('plane')
        if plane:
            plane = plane.lower()
            if plane not in counts:
                return JsonResponse({'error': 'Invalid plane'}, status=400)
            # slice index
            try:
                slice_index = int(request.GET.get('slice', counts[plane] // 2))
            except Exception:
                slice_index = counts[plane] // 2
            slice_index = max(0, min(counts[plane] - 1, slice_index))

            # Get encoded slice via cache
            img_b64 = _get_encoded_mpr_slice(series.id, volume, plane, slice_index, window_width, window_level, inverted)
            return JsonResponse({
                'plane': plane,
                'index': slice_index,
                'count': counts[plane],
                'image': img_b64,
                'counts': counts,
                'volume_shape': tuple(int(x) for x in volume.shape),
                'series_info': {
                    'id': series.id,
                    'description': series.series_description,
                    'modality': series.modality,
                },
            })

        # Default: return mid-slice previews for all planes
        mpr_views = {}
        axial_idx = volume.shape[0] // 2
        sagittal_idx = volume.shape[2] // 2
        coronal_idx = volume.shape[1] // 2
        mpr_views['axial'] = _get_encoded_mpr_slice(series.id, volume, 'axial', axial_idx, window_width, window_level, inverted)
        mpr_views['sagittal'] = _get_encoded_mpr_slice(series.id, volume, 'sagittal', sagittal_idx, window_width, window_level, inverted)
        mpr_views['coronal'] = _get_encoded_mpr_slice(series.id, volume, 'coronal', coronal_idx, window_width, window_level, inverted)

        return JsonResponse({
            'mpr_views': mpr_views,
            'volume_shape': tuple(int(x) for x in volume.shape),
            'counts': counts,
            'series_info': {
                'id': series.id,
                'description': series.series_description,
                'modality': series.modality
            }
        })

    except Exception as e:
        logger.error(f"MPR reconstruction failed for series {series_id}: {str(e)}")
        import traceback
        logger.error(f"MPR traceback: {traceback.format_exc()}")
        return JsonResponse({'error': f'Error generating MPR: {str(e)}'}, status=500)

@login_required
@csrf_exempt
def api_mip_reconstruction(request, series_id):
    """API endpoint for Maximum Intensity Projection (MIP)
    Optimized to reuse cached 3D volume when available for instant response."""
    series = get_object_or_404(Series, id=series_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and getattr(user, 'facility', None) and series.study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    try:
        # Prefer isotropic volume for higher-quality MIP
        try:
            volume, _spacing = _get_mpr_volume_and_spacing(series)
            default_window_width, default_window_level = 400, 40
        except Exception:
            # Fallback: build volume from DICOMs (slower)
            images = series.images.all().order_by('slice_location', 'instance_number')
            if images.count() < 2:
                return JsonResponse({'error': 'Need at least 2 images for MIP'}, status=400)
            volume_data = []
            default_window_width = 400
            default_window_level = 40
            for img in images:
                try:
                    dicom_path = os.path.join(settings.MEDIA_ROOT, str(img.file_path))
                    ds = pydicom.dcmread(dicom_path)
                    px = ds.pixel_array.astype(np.float32)
                    if hasattr(ds, 'RescaleSlope') and hasattr(ds, 'RescaleIntercept'):
                        px = px * float(ds.RescaleSlope) + float(ds.RescaleIntercept)
                    if not volume_data:
                        ww = getattr(ds, 'WindowWidth', 400); wl = getattr(ds, 'WindowCenter', 40)
                        if hasattr(ww, '__iter__') and not isinstance(ww, str): ww = ww[0]
                        if hasattr(wl, '__iter__') and not isinstance(wl, str): wl = wl[0]
                        default_window_width, default_window_level = ww, wl
                    volume_data.append(px)
                except Exception:
                    continue
            if len(volume_data) < 2:
                return JsonResponse({'error': 'Could not read enough images for MIP'}, status=400)
            volume = np.stack(volume_data, axis=0)
        
        # If very thin stack, interpolate along depth to stabilize MIP unless high quality requested
        quality = request.GET.get('quality', '').lower()
        if quality != 'high' and volume.shape[0] < 16:
            factor = max(2, int(np.ceil(16 / max(volume.shape[0], 1))))
            volume = ndimage.zoom(volume, (factor, 1, 1), order=1)
        
        # Get windowing parameters from request
        window_width = float(request.GET.get('window_width', default_window_width))
        window_level = float(request.GET.get('window_level', default_window_level))
        inverted = request.GET.get('inverted', 'false').lower() == 'true'
        
        # Generate MIP projections (vectorized)
        mip_views = {}
        mip_views['axial'] = _array_to_base64_image(np.max(volume, axis=0), window_width, window_level, inverted)
        mip_views['sagittal'] = _array_to_base64_image(np.max(volume, axis=1), window_width, window_level, inverted)
        mip_views['coronal'] = _array_to_base64_image(np.max(volume, axis=2), window_width, window_level, inverted)
        
        return JsonResponse({
            'mip_views': mip_views,
            'volume_shape': tuple(int(x) for x in volume.shape),
            'counts': {
                'axial': int(volume.shape[0]),
                'sagittal': int(volume.shape[2]),
                'coronal': int(volume.shape[1]),
            },
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
    """API endpoint for bone reconstruction using thresholding
    Optimized to reuse cached 3D volume when available; returns 3-plane previews instantly."""
    series = get_object_or_404(Series, id=series_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and getattr(user, 'facility', None) and series.study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    try:
        # Parameters
        threshold = int(request.GET.get('threshold', 300))
        want_mesh = (request.GET.get('mesh','false').lower() == 'true')
        quality = (request.GET.get('quality','').lower())
        
        # Fast path: reuse cached volume (isotropic for better quality)
        try:
            volume, _sp = _get_mpr_volume_and_spacing(series)
        except Exception:
            # Fallback: construct volume
            images = series.images.all().order_by('slice_location', 'instance_number')
            if images.count() < 2:
                return JsonResponse({'error': 'Need at least 2 images for bone reconstruction'}, status=400)
            volume_data = []
            for img in images:
                try:
                    dicom_path = os.path.join(settings.MEDIA_ROOT, str(img.file_path))
                    ds = pydicom.dcmread(dicom_path)
                    px = ds.pixel_array.astype(np.float32)
                    if hasattr(ds, 'RescaleSlope') and hasattr(ds, 'RescaleIntercept'):
                        px = px * ds.RescaleSlope + ds.RescaleIntercept
                    volume_data.append(px)
                except Exception:
                    continue
            if len(volume_data) < 2:
                return JsonResponse({'error': 'Could not read enough images for bone reconstruction'}, status=400)
            volume = np.stack(volume_data, axis=0)
        
        # Stabilize thin stacks
        if volume.shape[0] < 16:
            factor = max(2, int(np.ceil(16 / max(volume.shape[0], 1))))
            volume = ndimage.zoom(volume, (factor, 1, 1), order=1)
        
        # Threshold to bone
        bone_mask = volume >= threshold
        bone_volume = volume * bone_mask
        
        # Windowing defaults for bone
        window_width = float(request.GET.get('window_width', 2000))
        window_level = float(request.GET.get('window_level', 300))
        inverted = request.GET.get('inverted', 'false').lower() == 'true'
        
        # 3-plane orthogonal previews
        bone_views = {}
        axial_idx = bone_volume.shape[0] // 2
        sag_idx = bone_volume.shape[2] // 2
        cor_idx = bone_volume.shape[1] // 2
        bone_views['axial'] = _array_to_base64_image(bone_volume[axial_idx], window_width, window_level, inverted)
        bone_views['sagittal'] = _array_to_base64_image(bone_volume[:, :, sag_idx], window_width, window_level, inverted)
        bone_views['coronal'] = _array_to_base64_image(bone_volume[:, cor_idx, :], window_width, window_level, inverted)
        
        mesh_payload = None
        if want_mesh:
            try:
                from skimage import measure as _measure
                if quality == 'high':
                    vol_for_mesh = (bone_volume > 0).astype(np.float32)
                else:
                    ds_factor = max(1, int(np.ceil(max(1, bone_volume.shape[0]) / 128)))
                    vol_for_mesh = (bone_volume[::ds_factor, ::2, ::2] > 0).astype(np.float32)
                verts, faces, normals, values = _measure.marching_cubes(vol_for_mesh, level=0.5)
                mesh_payload = {
                    'vertices': verts.tolist(),
                    'faces': faces.tolist(),
                }
            except Exception:
                mesh_payload = None
        
        return JsonResponse({
            'bone_views': bone_views,
            'volume_shape': tuple(int(x) for x in bone_volume.shape),
            'counts': {
                'axial': int(bone_volume.shape[0]),
                'sagittal': int(bone_volume.shape[2]),
                'coronal': int(bone_volume.shape[1]),
            },
            'series_info': {
                'id': series.id,
                'description': series.series_description,
                'modality': series.modality
            },
            'mesh': mesh_payload
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
        # Validate input
        if array is None or array.size == 0:
            logger.warning("_array_to_base64_image: received empty array")
            return None
            
        # Convert to float for calculations
        image_data = array.astype(np.float32)
        
        # Check for invalid data
        if np.any(np.isnan(image_data)) or np.any(np.isinf(image_data)):
            logger.warning("_array_to_base64_image: array contains NaN or inf values")
            image_data = np.nan_to_num(image_data, nan=0.0, posinf=0.0, neginf=0.0)
        
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
            data_min, data_max = image_data.min(), image_data.max()
            if data_max > data_min:
                image_data = ((image_data - data_min) / (data_max - data_min) * 255)
            else:
                image_data = np.zeros_like(image_data)
        
        # Apply inversion if requested
        if inverted:
            image_data = 255 - image_data
        
        # Convert to uint8
        normalized = np.clip(image_data, 0, 255).astype(np.uint8)
        
        # Convert to PIL Image
        img = Image.fromarray(normalized, mode='L')
        
        # Convert to base64
        buffer = BytesIO()
        try:
            # Favor speed over size
            img.save(buffer, format='PNG', optimize=False, compress_level=1)
        except Exception as save_err:
            logger.warning(f"PNG save with optimization failed: {save_err}, trying basic save")
            img.save(buffer, format='PNG')
        
        img_str = base64.b64encode(buffer.getvalue()).decode()
        
        return f"data:image/png;base64,{img_str}"
    except Exception as e:
        logger.error(f"_array_to_base64_image failed: {str(e)}, array shape: {getattr(array, 'shape', 'unknown')}, dtype: {getattr(array, 'dtype', 'unknown')}")
        return None

@login_required
@csrf_exempt 
def api_dicom_image_display(request, image_id):
    """API endpoint to get processed DICOM image with windowing
    - If pixel data cannot be decoded, still return metadata and sensible window defaults
    """
    image = get_object_or_404(DicomImage, id=image_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and getattr(user, 'facility', None) and image.series.study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    # Always attempt to return a response (avoid 500 for robustness)
    warnings = {}
    try:
        # Get windowing parameters from request
        window_width_param = request.GET.get('window_width')
        window_level_param = request.GET.get('window_level')
        inverted = request.GET.get('inverted', 'false').lower() == 'true'

        # Read DICOM file (best-effort)
        ds = None
        try:
            dicom_path = os.path.join(settings.MEDIA_ROOT, str(image.file_path))
            ds = pydicom.dcmread(dicom_path, stop_before_pixels=False)
        except Exception as e:
            warnings['dicom_read_error'] = str(e)

        pixel_array = None
        pixel_decode_error = None
        if ds is not None:
            try:
                pixel_array = ds.pixel_array
                try:
                    modality = str(getattr(ds, 'Modality', '')).upper()
                    if modality in ['DX','CR','XA','RF','MG']:
                        pixel_array = apply_voi_lut(pixel_array, ds)
                except Exception:
                    pass
                pixel_array = pixel_array.astype(np.float32)
            except Exception as e:
                # Fallback for compressed DICOMs without pixel handler: try SimpleITK
                try:
                    import SimpleITK as sitk
                    dicom_path = os.path.join(settings.MEDIA_ROOT, str(image.file_path))
                    sitk_image = sitk.ReadImage(dicom_path)
                    pixel_array = sitk.GetArrayFromImage(sitk_image)
                    if pixel_array.ndim == 3 and pixel_array.shape[0] == 1:
                        pixel_array = pixel_array[0]
                    pixel_array = pixel_array.astype(np.float32)
                except Exception as _e:
                    pixel_decode_error = str(_e)
                    pixel_array = None
        
        # Apply rescale slope/intercept
        if pixel_array is not None and ds is not None and hasattr(ds, 'RescaleSlope') and hasattr(ds, 'RescaleIntercept'):
            try:
                pixel_array = pixel_array * float(ds.RescaleSlope) + float(ds.RescaleIntercept)
            except Exception:
                pass
        
        # Derive sensible defaults
        def derive_window(arr, fallback=(400.0, 40.0)):
            if arr is None:
                return fallback
            flat = arr.flatten()
            try:
                p1 = float(np.percentile(flat, 1))
                p99 = float(np.percentile(flat, 99))
            except Exception:
                return fallback
            ww = max(1.0, p99 - p1)
            wl = (p99 + p1) / 2.0
            return ww, wl
        
        default_window_width = None
        default_window_level = None
        if ds is not None:
            default_window_width = getattr(ds, 'WindowWidth', None)
            default_window_level = getattr(ds, 'WindowCenter', None)
            if hasattr(default_window_width, '__iter__') and not isinstance(default_window_width, str):
                default_window_width = default_window_width[0]
            if hasattr(default_window_level, '__iter__') and not isinstance(default_window_level, str):
                default_window_level = default_window_level[0]
        if default_window_width is None or default_window_level is None:
            dw, dl = derive_window(pixel_array)
            default_window_width = default_window_width or dw
            default_window_level = default_window_level or dl
        
        # CR/DX defaults and MONOCHROME1 auto-invert
        modality = getattr(ds, 'Modality', '') if ds is not None else (image.series.modality or '')
        photo = str(getattr(ds, 'PhotometricInterpretation', '')).upper() if ds is not None else ''
        default_inverted = False
        if str(modality).upper() in ['DX','CR','XA','RF']:
            default_window_width = float(default_window_width) if default_window_width is not None else 3000.0
            default_window_level = float(default_window_level) if default_window_level is not None else 1500.0
            default_inverted = (photo == 'MONOCHROME1')
        
        # Overwrite request params only if not provided
        try:
            if window_width_param is None:
                window_width = float(default_window_width)
            else:
                window_width = float(window_width_param)
            if window_level_param is None:
                window_level = float(default_window_level)
            else:
                window_level = float(window_level_param)
            if request.GET.get('inverted') is None:
                inverted = bool(default_inverted)
        except Exception:
            window_width = float(default_window_width)
            window_level = float(default_window_level)
        
        # Generate image if pixels are available
        image_data_url = None
        if pixel_array is not None:
            try:
                image_data_url = _array_to_base64_image(pixel_array, window_width, window_level, inverted)
            except Exception as e:
                warnings['render_error'] = str(e)
                image_data_url = None
        
        # Build image_info from ds if possible, otherwise from model/series
        def safe_float(v, fallback):
            try:
                return float(v)
            except Exception:
                return fallback
        
        image_info = {
            'id': image.id,
            'instance_number': getattr(image, 'instance_number', None),
            'slice_location': getattr(image, 'slice_location', None),
            'dimensions': [int(getattr(ds, 'Rows', 0) or 0), int(getattr(ds, 'Columns', 0) or 0)] if ds is not None else [0, 0],
            'pixel_spacing': getattr(ds, 'PixelSpacing', [1.0, 1.0]) if ds is not None else (image.series.pixel_spacing or [1.0, 1.0]),
            'slice_thickness': getattr(ds, 'SliceThickness', 1.0) if ds is not None else safe_float(getattr(image.series, 'slice_thickness', 1.0), 1.0),
            'default_window_width': float(default_window_width) if default_window_width is not None else 400.0,
            'default_window_level': float(default_window_level) if default_window_level is not None else 40.0,
            'modality': getattr(ds, 'Modality', '') if ds is not None else (image.series.modality or ''),
            'series_description': getattr(ds, 'SeriesDescription', '') if ds is not None else getattr(image.series, 'series_description', ''),
            'patient_name': str(getattr(ds, 'PatientName', '')) if ds is not None else (getattr(image.series.study.patient, 'full_name', '') if hasattr(image.series.study, 'patient') else ''),
            'study_date': str(getattr(ds, 'StudyDate', '')) if ds is not None else (getattr(image.series.study, 'study_date', '') or ''),
            'bits_allocated': getattr(ds, 'BitsAllocated', 16) if ds is not None else 16,
            'bits_stored': getattr(ds, 'BitsStored', 16) if ds is not None else 16,
            'photometric_interpretation': getattr(ds, 'PhotometricInterpretation', '') if ds is not None else '',
        }
        
        payload = {
            'image_data': image_data_url,
            'image_info': image_info,
            'windowing': {
                'window_width': window_width,
                'window_level': window_level,
                'inverted': inverted
            },
            'warnings': ({'pixel_decode_error': pixel_decode_error, **warnings} if (pixel_decode_error or warnings) else None)
        }
        return JsonResponse(payload)
    except Exception as e:
        # Last-resort: never 500; return minimal defaults
        minimal = {
            'image_data': None,
            'image_info': {
                'id': image.id,
                'instance_number': getattr(image, 'instance_number', None),
                'slice_location': getattr(image, 'slice_location', None),
                'dimensions': [0, 0],
                'pixel_spacing': [1.0, 1.0],
                'slice_thickness': 1.0,
                'default_window_width': 400.0,
                'default_window_level': 40.0,
                'modality': image.series.modality if hasattr(image.series, 'modality') else '',
                'series_description': getattr(image.series, 'series_description', ''),
                'patient_name': getattr(image.series.study.patient, 'full_name', '') if hasattr(image.series.study, 'patient') else '',
                'study_date': str(getattr(image.series.study, 'study_date', '')),
                'bits_allocated': 16,
                'bits_stored': 16,
                'photometric_interpretation': ''
            },
            'windowing': {
                'window_width': 400.0,
                'window_level': 40.0,
                'inverted': False
            },
            'warnings': {'fatal_error': str(e), **warnings}
        }
        return JsonResponse(minimal)  # 200 OK to avoid frontend failure

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

@login_required
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
            
            upload_id = str(uuid.uuid4())
            total_files = len(uploaded_files)
            processed_files = 0
            processed_images = []

            # First pass: group by StudyInstanceUID and SeriesInstanceUID
            studies_map = {}
            invalid_files = 0
            rep_ds = None
            for in_file in uploaded_files:
                try:
                    ds = pydicom.dcmread(in_file, force=True)
                    study_uid = getattr(ds, 'StudyInstanceUID', None)
                    series_uid = getattr(ds, 'SeriesInstanceUID', None)
                    if not study_uid or not series_uid:
                        invalid_files += 1
                        continue
                    if rep_ds is None:
                        rep_ds = ds
                    if study_uid not in studies_map:
                        studies_map[study_uid] = {}
                    if series_uid not in studies_map[study_uid]:
                        studies_map[study_uid][series_uid] = []
                    studies_map[study_uid][series_uid].append((ds, in_file))
                except Exception:
                    invalid_files += 1
                    continue

            if not studies_map:
                return JsonResponse({'success': False, 'error': 'No valid DICOM files found'})

            # For viewer uploads, process only the first study UID found
            study_uid = next(iter(studies_map.keys()))
            series_map = studies_map[study_uid]

            # Extract and normalize patient info from representative dataset
            patient_id = str(getattr(rep_ds, 'PatientID', f'TEMP_{upload_id[:8]}'))
            patient_name = str(getattr(rep_ds, 'PatientName', 'TEMP^UPLOAD'))
            name_parts = patient_name.replace('^', ' ').split()
            first_name = name_parts[0] if len(name_parts) > 0 else 'TEMP'
            last_name = name_parts[1] if len(name_parts) > 1 else upload_id[:8]
            birth_date = getattr(rep_ds, 'PatientBirthDate', None)
            from datetime import datetime
            if birth_date:
                try:
                    dob = datetime.strptime(birth_date, '%Y%m%d').date()
                except Exception:
                    dob = timezone.now().date()
            else:
                dob = timezone.now().date()
            gender = getattr(rep_ds, 'PatientSex', 'O')
            if gender not in ['M', 'F', 'O']:
                gender = 'O'

            patient, _ = Patient.objects.get_or_create(
                patient_id=patient_id,
                defaults={'first_name': first_name, 'last_name': last_name, 'date_of_birth': dob, 'gender': gender}
            )

            facility = getattr(request.user, 'facility', None)
            if not facility:
                facility = Facility.objects.filter(is_active=True).first()
            if not facility:
                # Allow admin uploads without configured facility by creating a default one
                if hasattr(request.user, 'is_admin') and request.user.is_admin():
                    facility = Facility.objects.create(
                        name='Default Facility',
                        address='N/A',
                        phone='N/A',
                        email='default@example.com',
                        license_number=f'DEFAULT-{upload_id[:8]}',
                        ae_title='',
                        is_active=True
                    )
                else:
                    return JsonResponse({'success': False, 'error': 'No active facility configured'})

            modality_code = getattr(rep_ds, 'Modality', 'OT')
            modality_obj, _ = Modality.objects.get_or_create(code=modality_code, defaults={'name': modality_code})

            study_description = getattr(rep_ds, 'StudyDescription', 'Temporary DICOM Upload')
            referring_physician = str(getattr(rep_ds, 'ReferringPhysicianName', 'UNKNOWN')).replace('^', ' ')
            accession_number = getattr(rep_ds, 'AccessionNumber', f"TEMP_{upload_id[:8]}")
            study_date = getattr(rep_ds, 'StudyDate', None)
            study_time = getattr(rep_ds, 'StudyTime', '000000')
            if study_date:
                try:
                    sdt = datetime.strptime(f"{study_date}{study_time[:6]}", '%Y%m%d%H%M%S')
                    sdt = timezone.make_aware(sdt)
                except Exception:
                    sdt = timezone.now()
            else:
                sdt = timezone.now()

            temp_study, _ = Study.objects.get_or_create(
                study_instance_uid=study_uid,
                defaults={
                    'accession_number': accession_number,
                    'patient': patient,
                    'facility': facility,
                    'modality': modality_obj,
                    'study_description': study_description,
                    'study_date': sdt,
                    'referring_physician': referring_physician,
                    'status': 'completed',
                    'priority': 'normal',
                    'uploaded_by': request.user,
                }
            )

            # Create series and images for each series UID
            for series_uid, items in series_map.items():
                ds0, _ = items[0]
                series_number = getattr(ds0, 'SeriesNumber', 1) or 1
                series_desc = getattr(ds0, 'SeriesDescription', f'Series {series_number}')
                slice_thickness = getattr(ds0, 'SliceThickness', None)
                pixel_spacing = str(getattr(ds0, 'PixelSpacing', ''))
                image_orientation = str(getattr(ds0, 'ImageOrientationPatient', ''))

                series_obj, _ = Series.objects.get_or_create(
                    series_instance_uid=series_uid,
                    defaults={
                        'study': temp_study,
                        'series_number': int(series_number),
                        'series_description': series_desc,
                        'modality': getattr(ds0, 'Modality', modality_code),
                        'body_part': getattr(ds0, 'BodyPartExamined', ''),
                        'slice_thickness': slice_thickness if slice_thickness is not None else None,
                        'pixel_spacing': pixel_spacing,
                        'image_orientation': image_orientation,
                    }
                )

                for ds, fobj in items:
                    try:
                        sop_uid = getattr(ds, 'SOPInstanceUID')
                        instance_number = getattr(ds, 'InstanceNumber', 1) or 1
                        rel_path = f"dicom/images/{study_uid}/{series_uid}/{sop_uid}.dcm"
                        # Ensure we read from start
                        try:
                            fobj.seek(0)
                        except Exception:
                            pass
                        saved_path = default_storage.save(rel_path, ContentFile(fobj.read()))
                        DicomImage.objects.get_or_create(
                            sop_instance_uid=sop_uid,
                            defaults={
                                'series': series_obj,
                                'instance_number': int(instance_number),
                                'image_position': str(getattr(ds, 'ImagePositionPatient', '')),
                                'slice_location': getattr(ds, 'SliceLocation', None),
                                'file_path': saved_path,
                                'file_size': getattr(fobj, 'size', 0) or 0,
                                'processed': False,
                            }
                        )
                        processed_files += 1
                    except Exception as e:
                        print(f"Error processing instance in series {series_uid}: {str(e)}")
                        continue

            if processed_files == 0:
                return JsonResponse({'success': False, 'error': 'No valid DICOM files found'})

            return JsonResponse({
                'success': True,
                'message': f'Successfully uploaded {processed_files} DICOM file(s) across {len(series_map)} series',
                'upload_id': upload_id,
                'processed_files': processed_files,
                'total_files': total_files,
                'study_id': temp_study.id,
                'series_count': len(series_map),
            })

        except Exception as e:
            return JsonResponse({'success': False, 'error': str(e)})
    
    # Render a minimal upload helper if needed
    return JsonResponse({'success': False, 'error': 'Use POST to upload DICOM files'})

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
@csrf_exempt
def launch_standalone_viewer(request):
    """Launch the standalone DICOM viewer application (Python PyQt)."""
    import subprocess
    import sys
    import os

    # If this looks like a normal browser navigation (expects HTML), redirect to web UI
    accept_header = request.headers.get('Accept', '')
    wants_html = 'text/html' in accept_header or 'application/xhtml+xml' in accept_header

    try:
        study_id = None
        if request.method == 'POST':
            data = json.loads(request.body) if request.body else {}
            study_id = data.get('study_id')

        launcher_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'tools', 'launch_dicom_viewer.py')

        if os.path.exists(launcher_path):
            cmd = [sys.executable, launcher_path, '--debug']
            if study_id:
                cmd.extend(['--study-id', str(study_id)])

            result = subprocess.run(cmd, capture_output=True, text=True)
            if wants_html:
                # For direct navigations, always show the web viewer UI
                web_url = '/dicom-viewer/web/viewer/'
                if study_id:
                    web_url += f'?study_id={study_id}'
                return redirect(web_url)

            if result.returncode == 0:
                message = 'Python DICOM viewer launched successfully'
                if study_id:
                    message += f' with study ID {study_id}'
                return JsonResponse({'success': True, 'message': message})
            else:
                stdout = (result.stdout or '').strip()
                stderr = (result.stderr or '').strip()
                details = stderr or stdout or 'Unknown error'
                return JsonResponse({
                    'success': False,
                    'message': 'Failed to launch DICOM viewer',
                    'details': details[:500]
                }, status=500)
        else:
            web_url = '/dicom-viewer/web/viewer/'
            if study_id:
                web_url += f'?study_id={study_id}'
            if wants_html:
                return redirect(web_url)
            return JsonResponse({
                'success': True,
                'message': 'Opening web-based DICOM viewer',
                'fallback_url': web_url,
                'details': 'Python launcher not found, using web viewer'
            })

    except Exception as e:
        web_url = '/dicom-viewer/web/viewer/'
        if study_id:
            web_url += f'?study_id={study_id}'
        if wants_html:
            return redirect(web_url)
        return JsonResponse({
            'success': True,
            'message': 'Opening web-based DICOM viewer',
            'fallback_url': web_url,
            'details': f'Error: {str(e)}, using web viewer'
        })


@login_required
def launch_study_in_desktop_viewer(request, study_id):
    """Launch a specific study in the desktop viewer (Python PyQt)."""
    import subprocess
    import sys
    import os

    # If this looks like a normal browser navigation (expects HTML), redirect to web UI
    accept_header = request.headers.get('Accept', '')
    wants_html = 'text/html' in accept_header or 'application/xhtml+xml' in accept_header

    try:
        study = get_object_or_404(Study, id=study_id)
        user = request.user
        # Mark study in progress for admins/radiologists when they open the viewer
        try:
            if hasattr(user, 'can_edit_reports') and user.can_edit_reports() and study.status in ['scheduled', 'suspended']:
                study.status = 'in_progress'
                study.save(update_fields=['status'])
        except Exception:
            pass
        if user.is_facility_user() and study.facility != user.facility:
            # Gracefully fall back to web viewer rather than hard 403, to match frontend behavior
            web_url = f'/dicom-viewer/web/viewer/?study_id={study_id}'
            if wants_html:
                return redirect(web_url)
            return JsonResponse({'success': True, 'fallback_url': web_url, 'message': 'Opening web-based DICOM viewer due to permissions'}, status=200)

        launcher_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'tools', 'launch_dicom_viewer.py')

        if os.path.exists(launcher_path):
            cmd = [sys.executable, launcher_path, '--debug', '--study-id', str(study_id)]
            result = subprocess.run(cmd, capture_output=True, text=True)

            if wants_html:
                # For direct navigations, always show the web viewer UI
                return redirect(f'/dicom-viewer/web/viewer/?study_id={study_id}')

            if result.returncode == 0:
                return JsonResponse({'success': True, 'message': f'Viewer launched for study: {study.patient.full_name} ({study.study_date})'})
            else:
                stdout = (result.stdout or '').strip()
                stderr = (result.stderr or '').strip()
                details = stderr or stdout or 'Unknown error'
                return JsonResponse({
                    'success': False,
                    'message': 'Failed to launch DICOM viewer',
                    'details': details[:500]
                }, status=500)
        else:
            web_url = f'/viewer/web/viewer/?study_id={study_id}'
            if wants_html:
                return redirect(web_url)
            return JsonResponse({
                'success': True,
                'message': f'Opening web-based DICOM viewer for study: {study.patient.full_name}',
                'fallback_url': web_url,
                'details': 'Python launcher not found, using web viewer'
            })

    except Exception as e:
        web_url = f'/viewer/web/viewer/?study_id={study_id}'
        if wants_html:
            return redirect(web_url)
        return JsonResponse({
            'success': True,
            'message': 'Opening web-based DICOM viewer',
            'fallback_url': web_url,
            'details': f'Error: {str(e)}, using web viewer'
        })


@login_required
def web_index(request):
    """Main web viewer index page listing recent studies"""
    # Keep permissions consistent with existing APIs
    if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user():
        studies = Study.objects.filter(facility=request.user.facility).order_by('-study_date')[:50]
    else:
        studies = Study.objects.order_by('-study_date')[:50]
    return render(request, 'dicom_viewer/index.html', {'studies': studies})


@login_required
def web_viewer(request):
    """Render the web viewer page. Expects ?study_id in query."""
    # If an admin/radiologist opens a specific study, mark it in_progress
    try:
        study_id_param = request.GET.get('study_id')
        if study_id_param and hasattr(request.user, 'can_edit_reports') and request.user.can_edit_reports():
            try:
                study = get_object_or_404(Study, id=int(study_id_param))
                # Only update if not already completed/cancelled
                if study.status in ['scheduled', 'suspended']:
                    study.status = 'in_progress'
                    study.save(update_fields=['status'])
            except Exception:
                pass
    except Exception:
        pass
    return render(request, 'dicom_viewer/base.html')


@login_required
def web_study_detail(request, study_id):
    """Return study detail JSON for web viewer"""
    study = get_object_or_404(Study, id=study_id)
    if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and study.facility != request.user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    series_qs = study.series_set.all().annotate(image_count=Count('images')).order_by('series_number')
    data = {
        'study': {
            'id': study.id,
            'patient_name': study.patient.full_name,
            'patient_id': study.patient.patient_id,
            'study_date': study.study_date.isoformat(),
            'modality': study.modality.code,
        },
        'series_list': [{
            'id': s.id,
            'series_uid': getattr(s, 'series_instance_uid', ''),
            'series_number': s.series_number,
            'series_description': s.series_description,
            'modality': s.modality,
            'slice_thickness': s.slice_thickness,
            'pixel_spacing': s.pixel_spacing,
            'image_orientation': s.image_orientation,
            'image_count': s.image_count,
        } for s in series_qs],
    }
    return JsonResponse(data)


@login_required
def web_series_images(request, series_id):
    series = get_object_or_404(Series, id=series_id)
    if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and series.study.facility != request.user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    images = series.images.all().order_by('instance_number')
    data = {
        'series': {
            'id': series.id,
            'series_uid': getattr(series, 'series_instance_uid', ''),
            'series_number': series.series_number,
            'series_description': series.series_description,
            'modality': series.modality,
            'slice_thickness': series.slice_thickness,
            'pixel_spacing': series.pixel_spacing,
            'image_orientation': series.image_orientation,
        },
        'images': [{
            'id': img.id,
            'sop_instance_uid': img.sop_instance_uid,
            'instance_number': img.instance_number,
            'image_position': img.image_position,
            'rows': None,
            'columns': None,
            'window_center': None,
            'window_width': None,
        } for img in images],
    }
    return JsonResponse(data)


@login_required
def web_dicom_image(request, image_id):
    image = get_object_or_404(DicomImage, id=image_id)
    if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and image.series.study.facility != request.user.facility:
        return HttpResponse(status=403)
    window_width = float(request.GET.get('ww', 400))
    window_level = float(request.GET.get('wl', 40))
    inv_param = request.GET.get('invert')
    invert = (inv_param or '').lower() == 'true'
    try:
        file_path = os.path.join(settings.MEDIA_ROOT, image.file_path.name)
        ds = pydicom.dcmread(file_path)
        # Robust pixel decode with SimpleITK fallback
        try:
            pixel_array = ds.pixel_array
        except Exception:
            try:
                import SimpleITK as sitk
                sitk_image = sitk.ReadImage(file_path)
                px = sitk.GetArrayFromImage(sitk_image)
                if px.ndim == 3 and px.shape[0] == 1:
                    px = px[0]
                pixel_array = px
            except Exception:
                return HttpResponse(status=500)
        # Apply VOI LUT only for projection modalities (CR/DX/XA/RF/MG) to avoid CT distortion
        try:
            modality = str(getattr(ds, 'Modality', '')).upper()
            if modality in ['DX', 'CR', 'XA', 'RF', 'MG']:
                from pydicom.pixel_data_handlers.util import apply_voi_lut as _apply_voi_lut
                pixel_array = _apply_voi_lut(pixel_array, ds)
        except Exception:
            pass
        # apply slope/intercept
        slope = getattr(ds, 'RescaleSlope', 1.0)
        intercept = getattr(ds, 'RescaleIntercept', 0.0)
        pixel_array = pixel_array.astype(np.float32) * float(slope) + float(intercept)
        # Derive defaults if not provided in query
        modality = str(getattr(ds, 'Modality', '')).upper()
        photo = str(getattr(ds, 'PhotometricInterpretation', '')).upper()
        def _derive_window(arr):
            flat = arr.astype(np.float32).flatten()
            p1 = float(np.percentile(flat, 1))
            p99 = float(np.percentile(flat, 99))
            return max(1.0, p99 - p1), (p99 + p1) / 2.0
        ww_param = request.GET.get('ww')
        wl_param = request.GET.get('wl')
        if ww_param is None or wl_param is None:
            dw = getattr(ds, 'WindowWidth', None)
            dl = getattr(ds, 'WindowCenter', None)
            if hasattr(dw, '__iter__') and not isinstance(dw, str):
                dw = dw[0]
            if hasattr(dl, '__iter__') and not isinstance(dl, str):
                dl = dl[0]
            if dw is None or dl is None:
                dww, dwl = _derive_window(pixel_array)
                dw = dw or dww
                dl = dl or dwl
            if modality in ['DX','CR','XA','RF']:
                dw = float(dw) if dw is not None else 3000.0
                dl = float(dl) if dl is not None else 1500.0
            if ww_param is None:
                window_width = float(dw)
            if wl_param is None:
                window_level = float(dl)
        # Default invert for MONOCHROME1 when not explicitly provided
        if inv_param is None and photo == 'MONOCHROME1':
            invert = True
        processor = DicomProcessor()
        windowed = processor.apply_windowing(pixel_array, window_width, window_level, invert)
        pil_image = Image.fromarray(windowed)
        buffer = BytesIO()
        pil_image.save(buffer, format='PNG')
        buffer.seek(0)
        response = HttpResponse(buffer.getvalue(), content_type='image/png')
        response['Cache-Control'] = 'max-age=3600'
        return response
    except Exception as e:
        return HttpResponse(status=500)


@login_required
@csrf_exempt
@require_http_methods(["POST"])
def web_save_measurement(request):
    try:
        data = json.loads(request.body)
        image_id = data.get('image_id')
        measurement_type = data.get('type')
        points = data.get('points')
        value = data.get('value')
        unit = data.get('unit', 'mm')
        notes = data.get('notes', '')
        image = get_object_or_404(DicomImage, id=image_id)
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and image.series.study.facility != request.user.facility:
            return JsonResponse({'success': False, 'error': 'Permission denied'}, status=403)
        measurement = Measurement.objects.create(
            user=request.user,
            image=image,
            measurement_type=measurement_type,
            value=value,
            unit=unit,
            notes=notes,
        )
        measurement.set_points(points or [])
        measurement.save()
        return JsonResponse({'success': True, 'id': measurement.id})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)})


@login_required
@csrf_exempt
@require_http_methods(["POST"])
def web_save_annotation(request):
    try:
        data = json.loads(request.body)
        image_id = data.get('image_id')
        position_x = data.get('position_x')
        position_y = data.get('position_y')
        text = data.get('text')
        color = data.get('color', '#FFFF00')
        image = get_object_or_404(DicomImage, id=image_id)
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and image.series.study.facility != request.user.facility:
            return JsonResponse({'success': False, 'error': 'Permission denied'}, status=403)
        annotation = Annotation.objects.create(
            user=request.user,
            image=image,
            position_x=position_x,
            position_y=position_y,
            text=text,
            color=color,
        )
        return JsonResponse({'success': True, 'id': annotation.id})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)})


@login_required
def web_get_measurements(request, image_id):
    image = get_object_or_404(DicomImage, id=image_id)
    if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and image.series.study.facility != request.user.facility:
        return JsonResponse({'measurements': []})
    measurements = Measurement.objects.filter(image=image, user=request.user)
    data = [{
        'id': m.id,
        'type': m.measurement_type,
        'points': m.get_points(),
        'value': m.value,
        'unit': m.unit,
        'notes': m.notes,
        'created_at': m.created_at.isoformat(),
    } for m in measurements]
    return JsonResponse({'measurements': data})


@login_required
def web_get_annotations(request, image_id):
    image = get_object_or_404(DicomImage, id=image_id)
    if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and image.series.study.facility != request.user.facility:
        return JsonResponse({'annotations': []})
    annotations = Annotation.objects.filter(image=image, user=request.user)
    data = [{
        'id': a.id,
        'position_x': a.position_x,
        'position_y': a.position_y,
        'text': a.text,
        'color': a.color,
        'created_at': a.created_at.isoformat(),
    } for a in annotations]
    return JsonResponse({'annotations': data})


@login_required
@csrf_exempt
@require_http_methods(["POST"])
def web_save_viewer_session(request):
    try:
        payload = json.loads(request.body)
        study_id = payload.get('study_id')
        session_data = payload.get('session_data')
        study = get_object_or_404(Study, id=study_id)
        if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and study.facility != request.user.facility:
            return JsonResponse({'success': False, 'error': 'Permission denied'}, status=403)
        session, created = ViewerSession.objects.get_or_create(
            user=request.user, study=study, defaults={'session_data': json.dumps(session_data or {})}
        )
        if not created:
            session.set_session_data(session_data or {})
            session.save()
        return JsonResponse({'success': True})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)})


@login_required
def web_load_viewer_session(request, study_id):
    study = get_object_or_404(Study, id=study_id)
    try:
        session = ViewerSession.objects.get(user=request.user, study=study)
        return JsonResponse({'success': True, 'session_data': session.get_session_data()})
    except ViewerSession.DoesNotExist:
        return JsonResponse({'success': False, 'error': 'No session found'})


@login_required
@csrf_exempt
@require_http_methods(["POST"])
def web_start_reconstruction(request):
    try:
        data = json.loads(request.body)
        series_id = data.get('series_id')
        job_type = data.get('job_type')
        parameters = data.get('parameters', {})
        series = get_object_or_404(Series, id=series_id)
        job = ReconstructionJob.objects.create(user=request.user, series=series, job_type=job_type, status='pending')
        job.set_parameters(parameters)
        job.save()
        if job_type == 'mpr':
            process_mpr_reconstruction.delay(job.id)
        elif job_type == 'mip':
            process_mip_reconstruction.delay(job.id)
        elif job_type == 'bone_3d':
            process_bone_reconstruction.delay(job.id)
        elif job_type == 'mri_3d':
            process_mri_reconstruction.delay(job.id)
        return JsonResponse({'success': True, 'job_id': job.id})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)})


@login_required
def web_reconstruction_status(request, job_id):
    job = get_object_or_404(ReconstructionJob, id=job_id, user=request.user)
    data = {
        'id': job.id,
        'job_type': job.job_type,
        'status': job.status,
        'result_path': job.result_path,
        'error_message': job.error_message,
        'created_at': job.created_at.isoformat(),
        'completed_at': job.completed_at.isoformat() if job.completed_at else None,
    }
    return JsonResponse(data)


@login_required
def web_reconstruction_result(request, job_id):
    job = get_object_or_404(ReconstructionJob, id=job_id, user=request.user)
    if job.status != 'completed' or not job.result_path:
        return HttpResponse(status=404)
    try:
        with open(job.result_path, 'rb') as f:
            response = HttpResponse(f.read(), content_type='application/octet-stream')
            response['Content-Disposition'] = f'attachment; filename="reconstruction_{job_id}.zip"'
            return response
    except FileNotFoundError:
        return HttpResponse(status=404)


# Celery tasks
from celery import shared_task

@shared_task
def process_mpr_reconstruction(job_id):
    try:
        job = ReconstructionJob.objects.get(id=job_id)
        job.status = 'processing'
        job.save()
        processor = MPRProcessor()
        result_path = processor.process_series(job.series, job.get_parameters())
        job.status = 'completed'
        job.result_path = result_path
        job.completed_at = timezone.now()
        job.save()
    except Exception as e:
        job = ReconstructionJob.objects.get(id=job_id)
        job.status = 'failed'
        job.error_message = str(e)
        job.save()


@shared_task
def process_mip_reconstruction(job_id):
    try:
        job = ReconstructionJob.objects.get(id=job_id)
        job.status = 'processing'
        job.save()
        processor = MIPProcessor()
        result_path = processor.process_series(job.series, job.get_parameters())
        job.status = 'completed'
        job.result_path = result_path
        job.completed_at = timezone.now()
        job.save()
    except Exception as e:
        job = ReconstructionJob.objects.get(id=job_id)
        job.status = 'failed'
        job.error_message = str(e)
        job.save()


@shared_task
def process_bone_reconstruction(job_id):
    try:
        job = ReconstructionJob.objects.get(id=job_id)
        job.status = 'processing'
        job.save()
        processor = Bone3DProcessor()
        result_path = processor.process_series(job.series, job.get_parameters())
        job.status = 'completed'
        job.result_path = result_path
        job.completed_at = timezone.now()
        job.save()
    except Exception as e:
        job = ReconstructionJob.objects.get(id=job_id)
        job.status = 'failed'
        job.error_message = str(e)
        job.save()


@shared_task
def process_mri_reconstruction(job_id):
    try:
        job = ReconstructionJob.objects.get(id=job_id)
        job.status = 'processing'
        job.save()
        processor = MRI3DProcessor()
        result_path = processor.process_series(job.series, job.get_parameters())
        job.status = 'completed'
        job.result_path = result_path
        job.completed_at = timezone.now()
        job.save()
    except Exception as e:
        job = ReconstructionJob.objects.get(id=job_id)
        job.status = 'failed'
        job.error_message = str(e)
        job.save()

@login_required
@csrf_exempt
def api_hu_value(request):
    """Return Hounsfield Unit at a given pixel.
    Query params:
    - mode=series&image_id=<id>&x=<col>&y=<row>
    - mode=mpr&series_id=<id>&plane=axial|sagittal|coronal&slice=<idx>&x=<col>&y=<row>
    Optional ROI:
     - shape=ellipse&cx=<cx>&cy=<cy>&rx=<rx>&ry=<ry>
    Coordinates x,y are in pixel indices within the displayed 2D slice (0-based).
    """
    user = request.user
    mode = (request.GET.get('mode') or '').lower()

    try:
        if mode == 'series':
            image_id = int(request.GET.get('image_id'))
            x = int(float(request.GET.get('x')))
            y = int(float(request.GET.get('y')))
            image = get_object_or_404(DicomImage, id=image_id)
            if user.is_facility_user() and getattr(user, 'facility', None) and image.series.study.facility != user.facility:
                return JsonResponse({'error': 'Permission denied'}, status=403)
            dicom_path = os.path.join(settings.MEDIA_ROOT, str(image.file_path))
            ds = pydicom.dcmread(dicom_path)
            arr = ds.pixel_array.astype(np.float32)
            slope = float(getattr(ds, 'RescaleSlope', 1.0))
            intercept = float(getattr(ds, 'RescaleIntercept', 0.0))
            arr = arr * slope + intercept
            h, w = arr.shape[:2]
            shape = (request.GET.get('shape') or '').lower()
            if shape == 'ellipse':
                cx = int(float(request.GET.get('cx', x)))
                cy = int(float(request.GET.get('cy', y)))
                rx = max(1, int(float(request.GET.get('rx', 1))))
                ry = max(1, int(float(request.GET.get('ry', 1))))
                yy, xx = np.ogrid[:h, :w]
                mask = ((xx - cx) ** 2) / (rx ** 2) + ((yy - cy) ** 2) / (ry ** 2) <= 1.0
                roi = arr[mask]
                if roi.size == 0:
                    return JsonResponse({'error': 'Empty ROI'}, status=400)
                stats = {
                    'mean': float(np.mean(roi)),
                    'std': float(np.std(roi)),
                    'min': float(np.min(roi)),
                    'max': float(np.max(roi)),
                    'n': int(roi.size),
                }
                return JsonResponse({'mode': 'series', 'image_id': image_id, 'stats': stats})
            if x < 0 or y < 0 or x >= w or y >= h:
                return JsonResponse({'error': 'Out of bounds'}, status=400)
            hu = float(arr[y, x])
            return JsonResponse({'mode': 'series', 'image_id': image_id, 'x': x, 'y': y, 'hu': round(hu, 2)})

        elif mode == 'mpr':
            series_id = int(request.GET.get('series_id'))
            plane = (request.GET.get('plane') or '').lower()
            slice_index = int(float(request.GET.get('slice', '0')))
            x = int(float(request.GET.get('x')))
            y = int(float(request.GET.get('y')))
            series = get_object_or_404(Series, id=series_id)
            if user.is_facility_user() and getattr(user, 'facility', None) and series.study.facility != user.facility:
                return JsonResponse({'error': 'Permission denied'}, status=403)
            images = series.images.all().order_by('slice_location', 'instance_number')
            if images.count() < 2:
                return JsonResponse({'error': 'Need at least 2 images for MPR'}, status=400)
            volume_data = []
            for img in images:
                try:
                    dicom_path = os.path.join(settings.MEDIA_ROOT, str(img.file_path))
                    ds = pydicom.dcmread(dicom_path)
                    a = ds.pixel_array.astype(np.float32)
                    slope = float(getattr(ds, 'RescaleSlope', 1.0))
                    intercept = float(getattr(ds, 'RescaleIntercept', 0.0))
                    a = a * slope + intercept
                    volume_data.append(a)
                except Exception:
                    continue
            if len(volume_data) < 2:
                return JsonResponse({'error': 'Could not read enough images for MPR'}, status=400)
            volume = np.stack(volume_data, axis=0)
            if volume.shape[0] < 16:
                factor = max(2, int(np.ceil(16 / max(volume.shape[0], 1))))
                volume = ndimage.zoom(volume, (factor, 1, 1), order=1)
            counts = {
                'axial': int(volume.shape[0]),
                'sagittal': int(volume.shape[2]),
                'coronal': int(volume.shape[1]),
            }
            if plane not in counts:
                return JsonResponse({'error': 'Invalid plane'}, status=400)
            slice_index = max(0, min(counts[plane] - 1, slice_index))
            # Map x,y (col,row) from 2D plane to volume indices
            if plane == 'axial':
                h, w = volume.shape[1], volume.shape[2]
                shape = (request.GET.get('shape') or '').lower()
                if shape == 'ellipse':
                    cx = int(float(request.GET.get('cx', x)))
                    cy = int(float(request.GET.get('cy', y)))
                    rx = max(1, int(float(request.GET.get('rx', 1))))
                    ry = max(1, int(float(request.GET.get('ry', 1))))
                    yy, xx = np.ogrid[:h, :w]
                    mask = ((xx - cx) ** 2) / (rx ** 2) + ((yy - cy) ** 2) / (ry ** 2) <= 1.0
                    roi = volume[slice_index][mask]
                    if roi.size == 0:
                        return JsonResponse({'error': 'Empty ROI'}, status=400)
                    stats = {
                        'mean': float(np.mean(roi)),
                        'std': float(np.std(roi)),
                        'min': float(np.min(roi)),
                        'max': float(np.max(roi)),
                        'n': int(roi.size),
                    }
                    return JsonResponse({'mode': 'mpr', 'series_id': series_id, 'plane': plane, 'slice': slice_index, 'stats': stats})
                if x < 0 or y < 0 or x >= w or y >= h:
                    return JsonResponse({'error': 'Out of bounds'}, status=400)
                hu = float(volume[slice_index, int(y), int(x)])
            elif plane == 'sagittal':
                # slice = volume[:, :, slice_index] shape (depth, height)
                h, w = volume.shape[0], volume.shape[1]
                shape = (request.GET.get('shape') or '').lower()
                if shape == 'ellipse':
                    cx = int(float(request.GET.get('cx', x)))
                    cy = int(float(request.GET.get('cy', y)))
                    rx = max(1, int(float(request.GET.get('rx', 1))))
                    ry = max(1, int(float(request.GET.get('ry', 1))))
                    yy, xx = np.ogrid[:h, :w]
                    mask = ((xx - cx) ** 2) / (rx ** 2) + ((yy - cy) ** 2) / (ry ** 2) <= 1.0
                    z_idx = yy
                    y_idx = xx
                    roi = volume[z_idx, y_idx, slice_index][mask]
                    if roi.size == 0:
                        return JsonResponse({'error': 'Empty ROI'}, status=400)
                    stats = { 'mean': float(np.mean(roi)), 'std': float(np.std(roi)), 'min': float(np.min(roi)), 'max': float(np.max(roi)), 'n': int(roi.size) }
                    return JsonResponse({'mode': 'mpr', 'series_id': series_id, 'plane': plane, 'slice': slice_index, 'stats': stats})
                if x < 0 or y < 0 or x >= w or y >= h:
                    return JsonResponse({'error': 'Out of bounds'}, status=400)
                hu = float(volume[int(y), int(x), slice_index])
            else:  # coronal
                # slice = volume[:, slice_index, :] shape (depth, width)
                h, w = volume.shape[0], volume.shape[2]
                shape = (request.GET.get('shape') or '').lower()
                if shape == 'ellipse':
                    cx = int(float(request.GET.get('cx', x)))
                    cy = int(float(request.GET.get('cy', y)))
                    rx = max(1, int(float(request.GET.get('rx', 1))))
                    ry = max(1, int(float(request.GET.get('ry', 1))))
                    yy, xx = np.ogrid[:h, :w]
                    mask = ((xx - cx) ** 2) / (rx ** 2) + ((yy - cy) ** 2) / (ry ** 2) <= 1.0
                    z_idx = yy
                    x_idx = xx
                    roi = volume[z_idx, slice_index, x_idx][mask]
                    if roi.size == 0:
                        return JsonResponse({'error': 'Empty ROI'}, status=400)
                    stats = { 'mean': float(np.mean(roi)), 'std': float(np.std(roi)), 'min': float(np.min(roi)), 'max': float(np.max(roi)), 'n': int(roi.size) }
                    return JsonResponse({'mode': 'mpr', 'series_id': series_id, 'plane': plane, 'slice': slice_index, 'stats': stats})
                if x < 0 or y < 0 or x >= w or y >= h:
                    return JsonResponse({'error': 'Out of bounds'}, status=400)
                hu = float(volume[int(y), slice_index, int(x)])
            return JsonResponse({'mode': 'mpr', 'series_id': series_id, 'plane': plane, 'slice': slice_index, 'x': x, 'y': y, 'hu': round(hu, 2)})

        else:
            return JsonResponse({'error': 'Invalid mode'}, status=400)
    except Exception as e:
        return JsonResponse({'error': f'Failed to compute HU: {str(e)}'}, status=500)

def _get_mpr_volume_and_spacing(series, force_rebuild=False):
    """Return (volume, spacing) where spacing is (z,y,x) in mm.
    - Sorts slices using ImageOrientationPatient/ImagePositionPatient when available
    - Applies rescale slope/intercept
    - Optionally resamples along Z to approximate isotropic voxels based on in-plane pixel spacing
      to improve MPR quality without degrading in-plane resolution
    - Uses tiny LRU cache; extends existing cache entry with spacing when available
    """
    import numpy as _np
    import pydicom as _pydicom
    import os as _os

    # Try cache first
    with _MPR_CACHE_LOCK:
        entry = _MPR_CACHE.get(series.id)
        if entry is not None and isinstance(entry.get('volume'), _np.ndarray) and not force_rebuild:
            vol = entry['volume']
            sp = entry.get('spacing')
            if sp is not None:
                return vol, tuple(sp)

    images_qs = series.images.all().order_by('instance_number')
    if images_qs.count() < 2:
        raise ValueError('Not enough images for MPR')

    # Gather slice data with positional sorting info
    items = []  # (pos_along_normal, pixel_array)
    first_ps = (1.0, 1.0)
    st = None
    normal = None
    for img in images_qs:
        try:
            dicom_path = _os.path.join(settings.MEDIA_ROOT, str(img.file_path))
            ds = _pydicom.dcmread(dicom_path)
            try:
                arr = ds.pixel_array.astype(_np.float32)
            except Exception:
                try:
                    import SimpleITK as _sitk
                    sitk_image = _sitk.ReadImage(dicom_path)
                    px = _sitk.GetArrayFromImage(sitk_image)
                    if px.ndim == 3 and px.shape[0] == 1:
                        px = px[0]
                    arr = px.astype(_np.float32)
                except Exception:
                    continue
            slope = float(getattr(ds, 'RescaleSlope', 1.0) or 1.0)
            intercept = float(getattr(ds, 'RescaleIntercept', 0.0) or 0.0)
            arr = arr * slope + intercept

            # Orientation-aware sorting
            pos = getattr(ds, 'ImagePositionPatient', None)
            iop = getattr(ds, 'ImageOrientationPatient', None)
            if iop is not None and len(iop) == 6:
                # row (x) and col (y) direction cosines
                r = _np.array([float(iop[0]), float(iop[1]), float(iop[2])], dtype=_np.float64)
                c = _np.array([float(iop[3]), float(iop[4]), float(iop[5])], dtype=_np.float64)
                n = _np.cross(r, c)
                if normal is None:
                    normal = n / ( _np.linalg.norm(n) + 1e-8 )
            else:
                n = _np.array([0.0, 0.0, 1.0], dtype=_np.float64)
                if normal is None:
                    normal = n
            if pos is not None and len(pos) == 3:
                p = _np.array([float(pos[0]), float(pos[1]), float(pos[2])], dtype=_np.float64)
                d = float(_np.dot(p, normal))
            else:
                # Fallback to slice_location, then instance number
                d = float(getattr(ds, 'SliceLocation', getattr(ds, 'InstanceNumber', 0)) or 0)

            # Pixel spacing & slice thickness (from first slice)
            if st is None:
                st = getattr(ds, 'SpacingBetweenSlices', None)
                if st is None:
                    st = getattr(ds, 'SliceThickness', 1.0)
                try:
                    st = float(st)
                except Exception:
                    st = 1.0
                ps_attr = getattr(ds, 'PixelSpacing', [1.0, 1.0])
                try:
                    first_ps = (float(ps_attr[0]), float(ps_attr[1]))
                except Exception:
                    first_ps = (1.0, 1.0)

            items.append((d, arr))
        except Exception:
            continue

    if len(items) < 2:
        raise ValueError('Could not read enough images for MPR')

    # Sort by position along normal
    items.sort(key=lambda x: x[0])
    volume = _np.stack([a for _, a in items], axis=0)

    # Interpolate along depth for thin stacks to stabilize reformats
    if volume.shape[0] < 16:
        factor = max(2, int(_np.ceil(16 / max(volume.shape[0], 1))))
        volume = ndimage.zoom(volume, (factor, 1, 1), order=1)
        st = st / max(1, factor)

    # Resample along Z to approximate isotropic voxels using in-plane pixel spacing average
    # Keep in-plane resolution; only resample depth for quality MPR
    try:
        py, px = float(first_ps[0]), float(first_ps[1])
        target_xy = (py + px) / 2.0
        if st and target_xy and st > 0 and target_xy > 0:
            z_factor = max(1e-6, float(st) / float(target_xy))
            # If z_factor > 1, we need to upsample Z to match XY spacing
            # Cap the target depth to avoid memory blow-ups
            max_depth = 2048
            target_depth = int(min(max_depth, round(volume.shape[0] * z_factor)))
            if target_depth > volume.shape[0] + 1 or z_factor > 1.05:
                volume = ndimage.zoom(volume, (float(target_depth) / volume.shape[0], 1, 1), order=1)
                st = target_xy
    except Exception:
        pass

    spacing = (float(st or 1.0), float(first_ps[0] or 1.0), float(first_ps[1] or 1.0))

    with _MPR_CACHE_LOCK:
        # Store/refresh cache and attach spacing for future calls
        entry = _MPR_CACHE.get(series.id)
        if entry is None:
            while len(_MPR_CACHE_ORDER) >= _MAX_MPR_CACHE:
                evict_id = _MPR_CACHE_ORDER.pop(0)
                _MPR_CACHE.pop(evict_id, None)
            _MPR_CACHE[series.id] = { 'volume': volume, 'spacing': spacing }
            _MPR_CACHE_ORDER.append(series.id)
        else:
            entry['volume'] = volume
            entry['spacing'] = spacing
            try:
                _MPR_CACHE_ORDER.remove(series.id)
            except ValueError:
                pass
            _MPR_CACHE_ORDER.append(series.id)

    return volume, spacing

@login_required
@csrf_exempt
def api_user_presets(request):
    """CRUD for per-user window/level presets.
    GET: list presets (optionally filter by modality/body_part)
    POST: create/update {name, modality?, body_part?, window_width, window_level, inverted}
    DELETE: ?name=...&modality=...&body_part=...
    """
    user = request.user
    if request.method == 'GET':
        modality = request.GET.get('modality')
        body_part = request.GET.get('body_part')
        qs = WindowLevelPreset.objects.filter(user=user)
        if modality: qs = qs.filter(modality=modality)
        if body_part: qs = qs.filter(body_part=body_part)
        data = [{
            'name': p.name,
            'modality': p.modality,
            'body_part': p.body_part,
            'window_width': p.window_width,
            'window_level': p.window_level,
            'inverted': p.inverted,
        } for p in qs.order_by('name')]
        return JsonResponse({'presets': data})
    elif request.method == 'POST':
        try:
            payload = json.loads(request.body or '{}')
        except Exception:
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        name = (payload.get('name') or '').strip()
        if not name:
            return JsonResponse({'error': 'name required'}, status=400)
        preset, _ = WindowLevelPreset.objects.update_or_create(
            user=user,
            name=name,
            modality=payload.get('modality',''),
            body_part=payload.get('body_part',''),
            defaults={
                'window_width': float(payload.get('window_width', 400)),
                'window_level': float(payload.get('window_level', 40)),
                'inverted': bool(payload.get('inverted', False)),
            }
        )
        return JsonResponse({'success': True})
    elif request.method == 'DELETE':
        name = (request.GET.get('name') or '').strip()
        modality = request.GET.get('modality','')
        body_part = request.GET.get('body_part','')
        if not name:
            return JsonResponse({'error': 'name required'}, status=400)
        WindowLevelPreset.objects.filter(user=user, name=name, modality=modality, body_part=body_part).delete()
        return JsonResponse({'success': True})
    return JsonResponse({'error': 'Method not allowed'}, status=405)


@login_required
def api_hanging_protocols(request):
    """Return available hanging protocols and a suggested default for a given modality/body_part."""
    modality = request.GET.get('modality','')
    body_part = request.GET.get('body_part','')
    qs = HangingProtocol.objects.all()
    all_protocols = [{ 'id': hp.id, 'name': hp.name, 'layout': hp.layout, 'modality': hp.modality, 'body_part': hp.body_part, 'is_default': hp.is_default } for hp in qs]
    # suggested default
    default = (qs.filter(modality=modality or '', body_part=body_part or '', is_default=True).first() or 
               qs.filter(modality=modality or '', is_default=True).first() or 
               qs.filter(is_default=True).first())
    suggested = {'id': default.id, 'name': default.name, 'layout': default.layout} if default else None
    return JsonResponse({'protocols': all_protocols, 'suggested': suggested})


@login_required
def api_export_dicom_sr(request, study_id):
    """Export measurements/annotations of a study to a DICOM SR (TID 1500-like simplification).
    Returns a download URL for the generated SR file.
    """
    try:
        from highdicom.sr.coding import CodedConcept
        from highdicom.sr import ValueTypeCodes, SRDocument, ObservationContext, ContentItem, RelationshipTypeValues
        from pydicom.uid import generate_uid
    except Exception as e:
        return JsonResponse({'error': f'highdicom not available: {e}'}, status=500)

    study = get_object_or_404(Study, id=study_id)
    if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and study.facility != request.user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)

    # Gather measurements linked to images in this study for current user
    image_ids = list(study.series_set.values_list('images__id', flat=True))
    image_ids = [i for i in image_ids if i]
    ms = Measurement.objects.filter(user=request.user, image_id__in=image_ids).order_by('created_at')

    if not ms.exists():
        return JsonResponse({'error': 'No measurements to export'}, status=400)

    # Minimal SR document with text items listing measurements
    try:
        now = timezone.now()
        doc = SRDocument(
            evidence=[],
            series_number=1,
            instance_number=1,
            manufacturer='Noctis Pro',
            manufacturer_model_name='Web Viewer',
            series_instance_uid=generate_uid(),
            sop_instance_uid=generate_uid(),
            study_instance_uid=study.study_instance_uid or generate_uid(),
            series_description='Measurements',
            content_date=now.date(),
            content_time=now.time(),
            observation_context=ObservationContext(),
            concept_name=CodedConcept('125007', 'DCM', 'Measurement Report')
        )
        items = []
        for m in ms:
            pts = m.get_points()
            text = f"{m.measurement_type}: {m.value:.2f} {m.unit} (points={pts})"
            items.append(ContentItem(ValueTypeCodes.TEXT, name=CodedConcept('121071','DCM','Finding'), text_value=text))
        for it in items:
            doc.append(ContentItem(it.value_type, name=it.name, text_value=it.text_value), relationship_type=RelationshipTypeValues.CONTAINS)

        # Save DICOM SR
        out_dir = os.path.join(settings.MEDIA_ROOT, 'sr_exports')
        os.makedirs(out_dir, exist_ok=True)
        filename = f"SR_{study.accession_number}_{int(time.time())}.dcm"
        out_path = os.path.join(out_dir, filename)
        doc.to_dataset().save_as(out_path)
        return JsonResponse({'success': True, 'download_url': f"{settings.MEDIA_URL}sr_exports/{filename}", 'filename': filename})
    except Exception as e:
        return JsonResponse({'error': f'Failed to export SR: {e}'}, status=500)

@login_required
@csrf_exempt
def api_series_volume_uint8(request, series_id):
    """Return a downsampled uint8 volume for GPU VR with basic windowing.
    Query: ww, wl, max_dim (e.g., 256)
    Response: { shape:[z,y,x], spacing:[z,y,x], data: base64 of raw uint8 array (z*y*x) }
    """
    series = get_object_or_404(Series, id=series_id)
    if hasattr(request.user, 'is_facility_user') and request.user.is_facility_user() and getattr(request.user, 'facility', None) and series.study.facility != request.user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    try:
        volume, spacing = _get_mpr_volume_and_spacing(series)
        ww = float(request.GET.get('ww', 400))
        wl = float(request.GET.get('wl', 40))
        max_dim = int(request.GET.get('max_dim', 256))
        # Normalize via window/level
        min_val = wl - ww/2.0; max_val = wl + ww/2.0
        vol = np.clip(volume, min_val, max_val)
        if max_val > min_val:
            vol = (vol - min_val) / (max_val - min_val) * 255.0
        vol = vol.astype(np.uint8)
        # Downsample to fit max_dim
        z, y, x = vol.shape
        scale = min(1.0, float(max_dim)/max(z, y, x))
        if scale < 0.999:
            vol = ndimage.zoom(vol, (scale, scale, scale), order=1)
        buf = vol.tobytes()
        import base64
        b64 = base64.b64encode(buf).decode('ascii')
        return JsonResponse({
            'shape': [int(vol.shape[0]), int(vol.shape[1]), int(vol.shape[2])],
            'spacing': [float(spacing[0]), float(spacing[1]), float(spacing[2])],
            'data': b64,
        })
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)
