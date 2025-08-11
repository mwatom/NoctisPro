import numpy as np
import pydicom
from PIL import Image
import os
import json
import logging
from django.conf import settings

logger = logging.getLogger(__name__)


class DicomProcessor:
    """Utility class for DICOM image processing"""

    def __init__(self):
        self.window_presets = {
            'lung': {'ww': 1500, 'wl': -600},
            'bone': {'ww': 2000, 'wl': 300},
            'soft': {'ww': 400, 'wl': 40},
            'brain': {'ww': 100, 'wl': 50},
            'abdomen': {'ww': 350, 'wl': 50},
            'liver': {'ww': 150, 'wl': 30},
            'mediastinum': {'ww': 350, 'wl': 50},
        }

    def apply_windowing(self, pixel_array, window_width, window_level, invert=False):
        """Apply windowing to DICOM pixel array"""
        image_data = pixel_array.astype(np.float32)

        min_val = window_level - window_width / 2
        max_val = window_level + window_width / 2

        image_data = np.clip(image_data, min_val, max_val)
        if max_val > min_val:
            image_data = (image_data - min_val) / (max_val - min_val) * 255
        else:
            image_data = np.zeros_like(image_data)

        if invert:
            image_data = 255 - image_data

        return image_data.astype(np.uint8)

    def get_pixel_spacing(self, dicom_data):
        try:
            if hasattr(dicom_data, 'PixelSpacing'):
                spacing = dicom_data.PixelSpacing
                return float(spacing[0]), float(spacing[1])
            elif hasattr(dicom_data, 'ImagerPixelSpacing'):
                spacing = dicom_data.ImagerPixelSpacing
                return float(spacing[0]), float(spacing[1])
            else:
                return 1.0, 1.0
        except (ValueError, IndexError, AttributeError):
            return 1.0, 1.0

    def get_slice_thickness(self, dicom_data):
        try:
            if hasattr(dicom_data, 'SliceThickness'):
                return float(dicom_data.SliceThickness)
            elif hasattr(dicom_data, 'SpacingBetweenSlices'):
                return float(dicom_data.SpacingBetweenSlices)
            else:
                return 1.0
        except (ValueError, AttributeError):
            return 1.0

    def get_image_position(self, dicom_data):
        try:
            if hasattr(dicom_data, 'ImagePositionPatient'):
                pos = dicom_data.ImagePositionPatient
                return float(pos[0]), float(pos[1]), float(pos[2])
            else:
                return 0.0, 0.0, 0.0
        except (ValueError, IndexError, AttributeError):
            return 0.0, 0.0, 0.0

    def get_image_orientation(self, dicom_data):
        try:
            if hasattr(dicom_data, 'ImageOrientationPatient'):
                return list(map(float, dicom_data.ImageOrientationPatient))
            else:
                return [1.0, 0.0, 0.0, 0.0, 1.0, 0.0]
        except (ValueError, AttributeError):
            return [1.0, 0.0, 0.0, 0.0, 1.0, 0.0]

    def calculate_distance(self, point1, point2, pixel_spacing=(1.0, 1.0)):
        dx = (point2[0] - point1[0]) * pixel_spacing[0]
        dy = (point2[1] - point1[1]) * pixel_spacing[1]
        return float(np.sqrt(dx * dx + dy * dy))

    def calculate_area(self, points, pixel_spacing=(1.0, 1.0)):
        if len(points) < 3:
            return 0.0
        mm_points = [(p[0] * pixel_spacing[0], p[1] * pixel_spacing[1]) for p in points]
        area = 0.0
        n = len(mm_points)
        for i in range(n):
            j = (i + 1) % n
            area += mm_points[i][0] * mm_points[j][1]
            area -= mm_points[j][0] * mm_points[i][1]
        return abs(area) / 2.0

    def calculate_angle(self, point1, point2, point3):
        v1 = np.array([point1[0] - point2[0], point1[1] - point2[1]])
        v2 = np.array([point3[0] - point2[0], point3[1] - point2[1]])
        denom = (np.linalg.norm(v1) * np.linalg.norm(v2))
        if denom == 0:
            return 0.0
        cos_angle = np.dot(v1, v2) / denom
        angle = np.arccos(np.clip(cos_angle, -1.0, 1.0))
        return float(np.degrees(angle))


class DicomFileHandler:
    """Handle DICOM file operations"""

    @staticmethod
    def load_dicom_series(file_paths):
        dicom_files = []
        for file_path in file_paths:
            try:
                ds = pydicom.dcmread(file_path)
                dicom_files.append({
                    'file_path': file_path,
                    'dicom_data': ds,
                    'instance_number': getattr(ds, 'InstanceNumber', 0),
                })
            except Exception as e:
                logger.error(f"Error loading DICOM file {file_path}: {str(e)}")
                continue
        dicom_files.sort(key=lambda x: x['instance_number'])
        return dicom_files

    @staticmethod
    def validate_dicom_file(file_path):
        try:
            pydicom.dcmread(file_path, stop_before_pixels=True)
            return True
        except Exception:
            return False

    @staticmethod
    def extract_dicom_metadata(dicom_data):
        metadata = {}
        metadata['patient_id'] = getattr(dicom_data, 'PatientID', '')
        metadata['patient_name'] = str(getattr(dicom_data, 'PatientName', ''))
        metadata['patient_birth_date'] = getattr(dicom_data, 'PatientBirthDate', '')
        metadata['patient_sex'] = getattr(dicom_data, 'PatientSex', '')
        metadata['study_instance_uid'] = getattr(dicom_data, 'StudyInstanceUID', '')
        metadata['study_date'] = getattr(dicom_data, 'StudyDate', '')
        metadata['study_time'] = getattr(dicom_data, 'StudyTime', '')
        metadata['study_description'] = getattr(dicom_data, 'StudyDescription', '')
        metadata['referring_physician'] = getattr(dicom_data, 'ReferringPhysicianName', '')
        metadata['institution_name'] = getattr(dicom_data, 'InstitutionName', '')
        metadata['series_instance_uid'] = getattr(dicom_data, 'SeriesInstanceUID', '')
        metadata['series_number'] = getattr(dicom_data, 'SeriesNumber', None)
        metadata['series_description'] = getattr(dicom_data, 'SeriesDescription', '')
        metadata['modality'] = getattr(dicom_data, 'Modality', '')
        metadata['body_part_examined'] = getattr(dicom_data, 'BodyPartExamined', '')
        metadata['sop_instance_uid'] = getattr(dicom_data, 'SOPInstanceUID', '')
        metadata['instance_number'] = getattr(dicom_data, 'InstanceNumber', None)
        metadata['rows'] = getattr(dicom_data, 'Rows', None)
        metadata['columns'] = getattr(dicom_data, 'Columns', None)
        metadata['bits_stored'] = getattr(dicom_data, 'BitsStored', None)
        window_center = getattr(dicom_data, 'WindowCenter', None)
        window_width = getattr(dicom_data, 'WindowWidth', None)
        if window_center is not None:
            try:
                metadata['window_center'] = float(window_center[0]) if hasattr(window_center, '__iter__') and not isinstance(window_center, str) else float(window_center)
            except Exception:
                pass
        if window_width is not None:
            try:
                metadata['window_width'] = float(window_width[0]) if hasattr(window_width, '__iter__') and not isinstance(window_width, str) else float(window_width)
            except Exception:
                pass
        if hasattr(dicom_data, 'PixelSpacing'):
            metadata['pixel_spacing'] = '\\'.join(map(str, dicom_data.PixelSpacing))
        if hasattr(dicom_data, 'SliceThickness'):
            metadata['slice_thickness'] = float(dicom_data.SliceThickness)
        if hasattr(dicom_data, 'ImagePositionPatient'):
            metadata['image_position'] = '\\'.join(map(str, dicom_data.ImagePositionPatient))
        if hasattr(dicom_data, 'ImageOrientationPatient'):
            metadata['image_orientation'] = '\\'.join(map(str, dicom_data.ImageOrientationPatient))
        return metadata


class VolumeRenderer:
    """3D volume rendering utilities"""

    def __init__(self):
        self.volume_data = None
        self.spacing = None
        self.origin = None

    def load_volume_from_series(self, dicom_files):
        if not dicom_files:
            raise ValueError("No DICOM files provided")
        first_dicom = dicom_files[0]['dicom_data']
        rows = first_dicom.Rows
        cols = first_dicom.Columns
        volume_shape = (len(dicom_files), rows, cols)
        self.volume_data = np.zeros(volume_shape, dtype=np.float32)
        for i, dicom_file in enumerate(dicom_files):
            ds = dicom_file['dicom_data']
            pixel_array = ds.pixel_array.astype(np.float32)
            slope = getattr(ds, 'RescaleSlope', 1.0)
            intercept = getattr(ds, 'RescaleIntercept', 0.0)
            pixel_array = pixel_array * slope + intercept
            self.volume_data[i] = pixel_array
        processor = DicomProcessor()
        pixel_spacing = processor.get_pixel_spacing(first_dicom)
        slice_thickness = processor.get_slice_thickness(first_dicom)
        self.spacing = (slice_thickness, pixel_spacing[0], pixel_spacing[1])
        self.origin = processor.get_image_position(first_dicom)
        return self.volume_data

    def get_orthogonal_slices(self, volume_data, slice_indices):
        if volume_data is None:
            raise ValueError("No volume data loaded")
        depth, height, width = volume_data.shape
        axial_idx = min(slice_indices.get('axial', depth // 2), depth - 1)
        axial_slice = volume_data[axial_idx, :, :]
        sagittal_idx = min(slice_indices.get('sagittal', width // 2), width - 1)
        sagittal_slice = volume_data[:, :, sagittal_idx]
        coronal_idx = min(slice_indices.get('coronal', height // 2), height - 1)
        coronal_slice = volume_data[:, coronal_idx, :]
        return {
            'axial': axial_slice,
            'sagittal': sagittal_slice,
            'coronal': coronal_slice,
        }

    def apply_lut(self, image_data, lut_type='linear'):
        if lut_type == 'linear':
            return image_data
        elif lut_type == 'log':
            return np.log1p(image_data)
        elif lut_type == 'sqrt':
            return np.sqrt(np.abs(image_data))
        elif lut_type == 'inverse':
            max_val = np.max(image_data)
            return max_val - image_data
        else:
            return image_data


class ImageCache:
    """Simple image caching system"""

    def __init__(self, max_size=200):
        self.cache = {}
        self.max_size = max_size
        self.access_order = []

    def _make_key(self, image_id, window_width, window_level, invert):
        return f"{image_id}_{window_width}_{window_level}_{invert}"

    def get(self, image_id, window_width, window_level, invert=False):
        key = self._make_key(image_id, window_width, window_level, invert)
        if key in self.cache:
            if key in self.access_order:
                self.access_order.remove(key)
            self.access_order.append(key)
            return self.cache[key]
        return None

    def put(self, image_id, window_width, window_level, image_data, invert=False):
        key = self._make_key(image_id, window_width, window_level, invert)
        if len(self.cache) >= self.max_size and key not in self.cache:
            oldest_key = self.access_order.pop(0)
            del self.cache[oldest_key]
        self.cache[key] = image_data
        if key in self.access_order:
            self.access_order.remove(key)
        self.access_order.append(key)

    def clear(self):
        self.cache.clear()
        self.access_order.clear()


image_cache = ImageCache(max_size=200)