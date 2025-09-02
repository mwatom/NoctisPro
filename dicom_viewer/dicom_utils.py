"""
DICOM Utilities - Completely Rewritten
Advanced DICOM image processing, analysis, and quality assurance utilities.

Features:
- Optimized pixel data processing with NumPy
- Comprehensive Hounsfield Unit calibration and validation
- Advanced windowing and display transformations
- Geometric calculations for measurements
- DICOM metadata extraction and validation
- Quality assurance phantoms and protocols
- Memory-efficient image caching
- Multi-threaded processing support
"""

import numpy as np
import pydicom
from PIL import Image, ImageEnhance
import os
import json
import logging
import time
from typing import Dict, List, Tuple, Optional, Any, Union
from pathlib import Path
from dataclasses import dataclass
from enum import Enum
import threading
from concurrent.futures import ThreadPoolExecutor
import warnings

from django.conf import settings
from django.utils import timezone
from django.core.cache import cache

# Suppress specific warnings
warnings.filterwarnings("ignore", category=DeprecationWarning, module="pydicom")

logger = logging.getLogger(__name__)


def safe_dicom_str(value):
    """Safely convert DICOM values to string, handling MultiValue objects."""
    if value is None or value == "":
        return ""
    
    # Handle MultiValue objects (like PixelSpacing, WindowCenter, WindowWidth)
    if hasattr(value, '__iter__') and not isinstance(value, str):
        try:
            # Convert to list and join with backslash (DICOM standard separator)
            return '\\'.join(map(str, value))
        except Exception:
            return str(value)
    
    return str(value)


class ModalityType(Enum):
    """DICOM modality types with specific processing requirements"""
    # Core modalities
    CT = "CT"           # Computed Tomography
    MR = "MR"           # Magnetic Resonance
    XR = "XR"           # X-Ray
    US = "US"           # Ultrasound
    NM = "NM"           # Nuclear Medicine
    PT = "PT"           # Positron Emission Tomography
    RF = "RF"           # Radio Fluoroscopy
    MG = "MG"           # Mammography
    
    # Digital radiography
    CR = "CR"           # Computed Radiography
    DX = "DX"           # Digital Radiography
    IO = "IO"           # Intraoral Radiography
    PX = "PX"           # Panoramic X-Ray
    
    # Specialized imaging
    GM = "GM"           # General Microscopy
    SM = "SM"           # Slide Microscopy
    XC = "XC"           # External Camera Photography
    ECG = "ECG"         # Electrocardiography
    EPS = "EPS"         # Cardiac Electrophysiology
    HD = "HD"           # Hemodynamic Waveform
    
    # Radiotherapy
    RTIMAGE = "RTIMAGE" # Radiotherapy Image
    RTDOSE = "RTDOSE"   # Radiotherapy Dose
    RTSTRUCT = "RTSTRUCT" # Radiotherapy Structure Set
    RTPLAN = "RTPLAN"   # Radiotherapy Plan
    
    # Advanced imaging
    SPECT = "SPECT"     # Single Photon Emission Computed Tomography
    PET_CT = "PET/CT"   # Combined PET/CT
    MRA = "MRA"         # MR Angiography
    CTA = "CTA"         # CT Angiography
    
    # Functional imaging
    FMRI = "fMRI"       # Functional MRI
    DTI = "DTI"         # Diffusion Tensor Imaging
    PERFUSION = "PERF"  # Perfusion Imaging
    
    # Other
    OT = "OT"           # Other


class WindowPreset(Enum):
    """Predefined window/level presets for different anatomical regions"""
    # CT presets
    LUNG = {"ww": 1500, "wl": -600, "name": "Lung"}
    BONE = {"ww": 2000, "wl": 300, "name": "Bone"}
    SOFT_TISSUE = {"ww": 400, "wl": 40, "name": "Soft Tissue"}
    BRAIN = {"ww": 100, "wl": 50, "name": "Brain"}
    ABDOMEN = {"ww": 350, "wl": 50, "name": "Abdomen"}
    LIVER = {"ww": 150, "wl": 30, "name": "Liver"}
    MEDIASTINUM = {"ww": 350, "wl": 50, "name": "Mediastinum"}
    SPINE = {"ww": 400, "wl": 50, "name": "Spine"}
    PELVIS = {"ww": 400, "wl": 50, "name": "Pelvis"}
    
    # MR presets
    MR_T1 = {"ww": 600, "wl": 300, "name": "MR T1"}
    MR_T2 = {"ww": 4000, "wl": 2000, "name": "MR T2"}
    MR_FLAIR = {"ww": 2000, "wl": 1000, "name": "MR FLAIR"}
    
    # General presets
    DEFAULT = {"ww": 2000, "wl": 1000, "name": "Default"}
    FULL_DYNAMIC = {"ww": 4096, "wl": 2048, "name": "Full Dynamic Range"}


@dataclass
class HounsfieldReference:
    """Reference Hounsfield Unit values based on NIST standards"""
    material: str
    hu_value: float
    tolerance: float
    description: str


class DicomProcessor:
    """Advanced DICOM image processing utilities with optimization"""

    def __init__(self):
        self.window_presets = {preset.name.lower().replace(' ', '_'): preset.value 
                              for preset in WindowPreset}
        
        # Thread pool for parallel processing
        self._thread_pool = ThreadPoolExecutor(max_workers=4)
        
        # Cache for frequently used computations
        self._cache_lock = threading.Lock()
        self._computation_cache = {}
        
        # Standard Hounsfield Unit reference values (NIST recommendations)
        self.hu_reference_values = {
            'air': -1000,
            'lung': -500,
            'fat': -100,
            'water': 0,
            'blood': 40,
            'muscle': 50,
            'grey_matter': 40,
            'white_matter': 25,
            'liver': 60,
            'bone_spongy': 300,
            'bone_cortical': 1000,
            'metal': 3000
        }
        
        # Quality assurance thresholds
        self.qa_thresholds = {
            'water_tolerance': 5,  # HU units
            'air_tolerance': 50,   # HU units
            'linearity_tolerance': 0.02,  # 2%
            'noise_threshold': 10  # HU units standard deviation
        }

    def apply_windowing(self, pixel_array: np.ndarray, window_width: float, 
                       window_level: float, invert: bool = False, 
                       output_range: Tuple[int, int] = (0, 255)) -> np.ndarray:
        """
        Apply optimized windowing to DICOM pixel array
        
        Args:
            pixel_array: Input pixel data
            window_width: Window width value
            window_level: Window center/level value
            invert: Whether to invert the image
            output_range: Output intensity range (min, max)
        
        Returns:
            Windowed image array
        """
        try:
            # Ensure input is float for precision
            image_data = pixel_array.astype(np.float32)
            
            # Calculate window bounds
            min_val = window_level - window_width / 2
            max_val = window_level + window_width / 2
            
            # Apply windowing with clipping
            image_data = np.clip(image_data, min_val, max_val)
            
            # Normalize to output range
            out_min, out_max = output_range
            if max_val > min_val:
                image_data = (image_data - min_val) / (max_val - min_val) * (out_max - out_min) + out_min
            else:
                image_data = np.full_like(image_data, out_min)
            
            # Apply inversion if requested
            if invert:
                image_data = out_max + out_min - image_data
            
            # Convert to appropriate output type
            if output_range == (0, 255):
                return image_data.astype(np.uint8)
            elif output_range == (0, 65535):
                return image_data.astype(np.uint16)
            else:
                return image_data
                
        except Exception as e:
            logger.error(f"Error applying windowing: {str(e)}")
            # Return safe fallback
            return np.zeros_like(pixel_array, dtype=np.uint8)
    
    def get_optimal_window_level(self, pixel_array: np.ndarray, 
                                modality: str = 'CT') -> Tuple[float, float]:
        """
        Calculate optimal window/level values based on image statistics
        
        Args:
            pixel_array: Input pixel data
            modality: DICOM modality type
        
        Returns:
            Tuple of (window_width, window_level)
        """
        try:
            if modality.upper() == 'CT':
                # For CT, use statistical approach
                mean_val = np.mean(pixel_array)
                std_val = np.std(pixel_array)
                
                # Use 2-3 standard deviations for window width
                window_width = min(3 * std_val, 2000)  # Cap at reasonable value
                window_level = mean_val
                
            else:
                # For other modalities, use percentile-based approach
                p5 = np.percentile(pixel_array, 5)
                p95 = np.percentile(pixel_array, 95)
                
                window_width = p95 - p5
                window_level = (p95 + p5) / 2
            
            return float(window_width), float(window_level)
            
        except Exception as e:
            logger.error(f"Error calculating optimal window/level: {str(e)}")
            return 2000.0, 1000.0  # Safe defaults

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

    def process_dicom_image_comprehensive(self, dicom_data, enhance_for_modality=True):
        """
        Comprehensive DICOM image processing that handles all modality types
        with optimized display parameters and enhancements.
        """
        try:
            # Get modality
            modality = getattr(dicom_data, 'Modality', 'OT')
            
            # Get pixel array
            pixel_array = dicom_data.pixel_array.copy()
            
            # Handle different photometric interpretations
            photometric = getattr(dicom_data, 'PhotometricInterpretation', 'MONOCHROME2')
            
            # Apply modality-specific processing
            if enhance_for_modality:
                pixel_array = self._apply_modality_specific_processing(pixel_array, dicom_data, modality)
            
            # Apply appropriate windowing based on modality
            windowed_array = self._apply_modality_windowing(pixel_array, dicom_data, modality)
            
            # Handle color images
            if photometric in ['RGB', 'YBR_FULL', 'YBR_FULL_422', 'YBR_PARTIAL_422']:
                return self._process_color_image(windowed_array, photometric)
            
            # Handle monochrome images
            return self._process_monochrome_image(windowed_array, photometric)
            
        except Exception as e:
            logger.error(f"Error in comprehensive DICOM processing: {str(e)}")
            # Fallback to basic processing
            return self._basic_image_processing(dicom_data)
    
    def _apply_modality_specific_processing(self, pixel_array, dicom_data, modality):
        """Apply modality-specific image processing enhancements"""
        try:
            if modality in ['CT']:
                # CT-specific processing
                return self._process_ct_image(pixel_array, dicom_data)
            elif modality in ['MR', 'MRA', 'FMRI', 'DTI']:
                # MR-specific processing
                return self._process_mr_image(pixel_array, dicom_data)
            elif modality in ['XR', 'CR', 'DX', 'RF']:
                # X-Ray specific processing
                return self._process_xray_image(pixel_array, dicom_data)
            elif modality in ['US']:
                # Ultrasound specific processing
                return self._process_ultrasound_image(pixel_array, dicom_data)
            elif modality in ['MG']:
                # Mammography specific processing
                return self._process_mammography_image(pixel_array, dicom_data)
            elif modality in ['NM', 'PT', 'SPECT']:
                # Nuclear medicine specific processing
                return self._process_nuclear_image(pixel_array, dicom_data)
            else:
                # Generic processing for other modalities
                return self._process_generic_image(pixel_array, dicom_data)
                
        except Exception as e:
            logger.warning(f"Modality-specific processing failed for {modality}: {str(e)}")
            return pixel_array
    
    def _process_ct_image(self, pixel_array, dicom_data):
        """CT-specific image processing"""
        # Apply Hounsfield unit conversion
        if hasattr(dicom_data, 'RescaleSlope') and hasattr(dicom_data, 'RescaleIntercept'):
            slope = float(dicom_data.RescaleSlope)
            intercept = float(dicom_data.RescaleIntercept)
            pixel_array = pixel_array * slope + intercept
        
        # Noise reduction for CT
        pixel_array = self._apply_noise_reduction(pixel_array, method='gaussian')
        return pixel_array
    
    def _process_mr_image(self, pixel_array, dicom_data):
        """MR-specific image processing"""
        # Normalize MR intensity
        pixel_array = self._normalize_intensity(pixel_array)
        
        # Apply bias field correction if needed
        pixel_array = self._apply_bias_correction(pixel_array)
        
        # Enhance contrast for MR
        pixel_array = self._enhance_contrast(pixel_array, method='adaptive')
        return pixel_array
    
    def _process_xray_image(self, pixel_array, dicom_data):
        """X-Ray specific image processing"""
        # Apply logarithmic transformation for X-Ray
        pixel_array = self._apply_log_transform(pixel_array)
        
        # Enhance edges for X-Ray
        pixel_array = self._enhance_edges(pixel_array)
        
        # Apply histogram equalization
        pixel_array = self._apply_histogram_equalization(pixel_array)
        return pixel_array
    
    def _process_ultrasound_image(self, pixel_array, dicom_data):
        """Ultrasound specific image processing"""
        # Speckle reduction
        pixel_array = self._apply_speckle_reduction(pixel_array)
        
        # Enhance contrast for ultrasound
        pixel_array = self._enhance_contrast(pixel_array, method='ultrasound')
        return pixel_array
    
    def _process_mammography_image(self, pixel_array, dicom_data):
        """Mammography specific image processing"""
        # Apply specialized mammography enhancement
        pixel_array = self._apply_mammography_enhancement(pixel_array)
        
        # Enhance microcalcifications
        pixel_array = self._enhance_microcalcifications(pixel_array)
        return pixel_array
    
    def _process_nuclear_image(self, pixel_array, dicom_data):
        """Nuclear medicine specific image processing"""
        # Apply nuclear medicine specific normalization
        pixel_array = self._normalize_nuclear_image(pixel_array)
        
        # Apply smoothing for nuclear images
        pixel_array = self._apply_nuclear_smoothing(pixel_array)
        return pixel_array
    
    def _process_generic_image(self, pixel_array, dicom_data):
        """Generic image processing for other modalities"""
        # Basic normalization
        pixel_array = self._normalize_intensity(pixel_array)
        
        # Basic contrast enhancement
        pixel_array = self._enhance_contrast(pixel_array, method='basic')
        return pixel_array

    def calculate_angle(self, point1, point2, point3):
        v1 = np.array([point1[0] - point2[0], point1[1] - point2[1]])
        v2 = np.array([point3[0] - point2[0], point3[1] - point2[1]])
        denom = (np.linalg.norm(v1) * np.linalg.norm(v2))
        if denom == 0:
            return 0.0
        cos_angle = np.dot(v1, v2) / denom
        angle = np.arccos(np.clip(cos_angle, -1.0, 1.0))
        return float(np.degrees(angle))

    def convert_to_hounsfield_units(self, pixel_array, dicom_data):
        """Convert pixel values to Hounsfield Units using DICOM rescale parameters"""
        try:
            # Get rescale parameters
            slope = float(getattr(dicom_data, 'RescaleSlope', 1.0))
            intercept = float(getattr(dicom_data, 'RescaleIntercept', 0.0))
            
            # Convert to HU
            hu_array = pixel_array.astype(np.float32) * slope + intercept
            
            return hu_array
        except Exception as e:
            logger.error(f"Error converting to Hounsfield units: {str(e)}")
            return pixel_array.astype(np.float32)

    def validate_hounsfield_calibration(self, dicom_data, pixel_array=None):
        """Validate Hounsfield unit calibration according to international standards"""
        validation_results = {
            'is_valid': True,
            'issues': [],
            'warnings': [],
            'calibration_status': 'unknown',
            'water_hu': None,
            'air_hu': None,
            'noise_level': None
        }
        
        try:
            # Check if CT modality
            modality = getattr(dicom_data, 'Modality', '')
            if modality != 'CT':
                validation_results['calibration_status'] = 'not_applicable'
                validation_results['warnings'].append('Hounsfield units only applicable to CT images')
                return validation_results
            
            # Check rescale parameters
            slope = getattr(dicom_data, 'RescaleSlope', None)
            intercept = getattr(dicom_data, 'RescaleIntercept', None)
            
            if slope is None or intercept is None:
                validation_results['is_valid'] = False
                validation_results['issues'].append('Missing rescale parameters (slope/intercept)')
                validation_results['calibration_status'] = 'invalid'
                return validation_results
            
            # Validate rescale parameters
            slope = float(slope)
            intercept = float(intercept)
            
            if abs(slope - 1.0) > 0.01:  # Slope should typically be 1.0 for CT
                validation_results['warnings'].append(f'Unusual rescale slope: {slope}')
            
            # Check rescale type
            rescale_type = getattr(dicom_data, 'RescaleType', '')
            if rescale_type and rescale_type != 'HU':
                validation_results['warnings'].append(f'Rescale type is "{rescale_type}", not "HU"')
            
            # If pixel array provided, perform phantom validation
            if pixel_array is not None:
                hu_array = self.convert_to_hounsfield_units(pixel_array, dicom_data)
                
                # Estimate water and air HU values (simplified approach)
                # This would need actual phantom ROI coordinates in practice
                water_hu = self._estimate_water_hu(hu_array)
                air_hu = self._estimate_air_hu(hu_array)
                noise_level = self._calculate_noise_level(hu_array)
                
                validation_results['water_hu'] = water_hu
                validation_results['air_hu'] = air_hu
                validation_results['noise_level'] = noise_level
                
                # Validate against reference values
                if water_hu is not None:
                    water_deviation = abs(water_hu - self.hu_reference_values['water'])
                    if water_deviation > self.qa_thresholds['water_tolerance']:
                        validation_results['is_valid'] = False
                        validation_results['issues'].append(
                            f'Water HU deviation too high: {water_deviation:.1f} HU '
                            f'(expected: 0 ± {self.qa_thresholds["water_tolerance"]} HU)'
                        )
                
                if air_hu is not None:
                    air_deviation = abs(air_hu - self.hu_reference_values['air'])
                    if air_deviation > self.qa_thresholds['air_tolerance']:
                        validation_results['is_valid'] = False
                        validation_results['issues'].append(
                            f'Air HU deviation too high: {air_deviation:.1f} HU '
                            f'(expected: -1000 ± {self.qa_thresholds["air_tolerance"]} HU)'
                        )
                
                if noise_level is not None and noise_level > self.qa_thresholds['noise_threshold']:
                    validation_results['warnings'].append(
                        f'High noise level detected: {noise_level:.1f} HU std dev'
                    )
            
            # Set calibration status
            if validation_results['is_valid']:
                validation_results['calibration_status'] = 'valid'
            else:
                validation_results['calibration_status'] = 'invalid'
                
        except Exception as e:
            logger.error(f"Error validating Hounsfield calibration: {str(e)}")
            validation_results['is_valid'] = False
            validation_results['issues'].append(f'Validation error: {str(e)}')
            validation_results['calibration_status'] = 'error'
        
        return validation_results

    def _estimate_water_hu(self, hu_array):
        """Estimate water HU value from image (simplified approach)"""
        try:
            # Look for values near water HU (0)
            water_candidates = hu_array[(hu_array > -50) & (hu_array < 50)]
            if len(water_candidates) > 100:  # Need sufficient samples
                return float(np.median(water_candidates))
        except:
            pass
        return None

    def _estimate_air_hu(self, hu_array):
        """Estimate air HU value from image (simplified approach)"""
        try:
            # Look for values near air HU (-1000)
            air_candidates = hu_array[hu_array < -900]
            if len(air_candidates) > 100:  # Need sufficient samples
                return float(np.median(air_candidates))
        except:
            pass
        return None

    def _calculate_noise_level(self, hu_array):
        """Calculate noise level in Hounsfield units"""
        try:
            # Use standard deviation of a uniform region (simplified)
            # In practice, this would use a specific phantom ROI
            center_region = self._get_center_region(hu_array)
            if center_region is not None and len(center_region) > 100:
                return float(np.std(center_region))
        except:
            pass
        return None

    def _get_center_region(self, hu_array, fraction=0.1):
        """Get center region of image for noise analysis"""
        try:
            h, w = hu_array.shape[:2]
            center_h, center_w = h // 2, w // 2
            region_h, region_w = int(h * fraction), int(w * fraction)
            
            start_h = center_h - region_h // 2
            end_h = center_h + region_h // 2
            start_w = center_w - region_w // 2
            end_w = center_w + region_w // 2
            
            return hu_array[start_h:end_h, start_w:end_w].flatten()
        except:
            return None

    def generate_hu_calibration_report(self, dicom_data, pixel_array=None):
        """Generate comprehensive HU calibration report"""
        validation = self.validate_hounsfield_calibration(dicom_data, pixel_array)
        
        report = {
            'timestamp': timezone.now().isoformat(),
            'modality': getattr(dicom_data, 'Modality', 'Unknown'),
            'manufacturer': getattr(dicom_data, 'Manufacturer', 'Unknown'),
            'model': getattr(dicom_data, 'ManufacturerModelName', 'Unknown'),
            'station_name': getattr(dicom_data, 'StationName', 'Unknown'),
            'calibration_date': getattr(dicom_data, 'CalibrationDate', 'Unknown'),
            'validation_results': validation,
            'recommendations': []
        }
        
        # Add recommendations based on validation results
        if not validation['is_valid']:
            report['recommendations'].append(
                'Recalibrate CT scanner using appropriate phantom'
            )
            report['recommendations'].append(
                'Contact service engineer for calibration verification'
            )
        
        if validation['warnings']:
            report['recommendations'].append(
                'Monitor calibration stability with regular QA measurements'
            )
        
        if validation['noise_level'] and validation['noise_level'] > self.qa_thresholds['noise_threshold']:
            report['recommendations'].append(
                'Consider increasing reconstruction parameters to reduce noise'
            )
        
        return report

    # Helper methods for modality-specific processing
    def _apply_modality_windowing(self, pixel_array, dicom_data, modality):
        """Apply modality-specific windowing"""
        try:
            if modality == 'CT':
                # Use appropriate CT window
                return self.apply_windowing(pixel_array, 400, 40)  # Soft tissue
            elif modality in ['MR', 'MRA', 'FMRI', 'DTI']:
                # MR auto-windowing
                ww, wl = self.get_optimal_window_level(pixel_array, 'MR')
                return self.apply_windowing(pixel_array, ww, wl)
            elif modality in ['XR', 'CR', 'DX']:
                # X-Ray windowing
                ww, wl = self.get_optimal_window_level(pixel_array, 'XR')
                return self.apply_windowing(pixel_array, ww, wl)
            else:
                # Auto-windowing for other modalities
                ww, wl = self.get_optimal_window_level(pixel_array, modality)
                return self.apply_windowing(pixel_array, ww, wl)
        except Exception:
            return pixel_array

    def _process_color_image(self, image_array, photometric):
        """Process color DICOM images"""
        if photometric == 'RGB':
            return image_array
        elif photometric in ['YBR_FULL', 'YBR_FULL_422', 'YBR_PARTIAL_422']:
            # Convert YBR to RGB
            return self._convert_ybr_to_rgb(image_array)
        return image_array

    def _process_monochrome_image(self, image_array, photometric):
        """Process monochrome DICOM images"""
        if photometric == 'MONOCHROME1':
            # Invert for MONOCHROME1
            return np.max(image_array) - image_array
        return image_array

    def _basic_image_processing(self, dicom_data):
        """Fallback basic image processing"""
        try:
            pixel_array = dicom_data.pixel_array
            return self.apply_windowing(pixel_array, 400, 40)
        except Exception:
            return np.zeros((512, 512), dtype=np.uint8)

    def _normalize_intensity(self, pixel_array):
        """Normalize image intensity"""
        try:
            min_val = np.min(pixel_array)
            max_val = np.max(pixel_array)
            if max_val > min_val:
                return (pixel_array - min_val) / (max_val - min_val) * 255.0
            return pixel_array
        except Exception:
            return pixel_array

    def _apply_noise_reduction(self, pixel_array, method='gaussian'):
        """Apply noise reduction"""
        try:
            from scipy import ndimage
            if method == 'gaussian':
                return ndimage.gaussian_filter(pixel_array, sigma=0.8)
            elif method == 'median':
                return ndimage.median_filter(pixel_array, size=3)
            return pixel_array
        except ImportError:
            return pixel_array
        except Exception:
            return pixel_array

    def _apply_bias_correction(self, pixel_array):
        """Apply bias field correction (simplified)"""
        try:
            # Simple bias correction using low-pass filtering
            from scipy import ndimage
            bias_field = ndimage.gaussian_filter(pixel_array, sigma=50)
            bias_field[bias_field == 0] = 1  # Avoid division by zero
            return pixel_array / bias_field * np.mean(bias_field)
        except (ImportError, Exception):
            return pixel_array

    def _enhance_contrast(self, pixel_array, method='adaptive'):
        """Enhance image contrast"""
        try:
            if method == 'adaptive':
                # Adaptive histogram equalization
                return self._apply_adaptive_histogram_equalization(pixel_array)
            elif method == 'basic':
                # Simple contrast stretching
                return self._apply_contrast_stretching(pixel_array)
            elif method == 'ultrasound':
                # Ultrasound-specific contrast enhancement
                return self._apply_ultrasound_contrast(pixel_array)
            return pixel_array
        except Exception:
            return pixel_array

    def _apply_log_transform(self, pixel_array):
        """Apply logarithmic transformation"""
        try:
            # Ensure positive values
            pixel_array = pixel_array - np.min(pixel_array) + 1
            return np.log(pixel_array + 1)
        except Exception:
            return pixel_array

    def _enhance_edges(self, pixel_array):
        """Enhance edges in the image"""
        try:
            from scipy import ndimage
            # Sobel edge detection
            edge_x = ndimage.sobel(pixel_array, axis=0)
            edge_y = ndimage.sobel(pixel_array, axis=1)
            edges = np.sqrt(edge_x**2 + edge_y**2)
            # Combine with original
            return pixel_array + 0.3 * edges
        except (ImportError, Exception):
            return pixel_array

    def _apply_histogram_equalization(self, pixel_array):
        """Apply histogram equalization"""
        try:
            # Flatten and get histogram
            flat = pixel_array.flatten()
            hist, bins = np.histogram(flat, bins=256, range=(flat.min(), flat.max()))
            
            # Calculate CDF
            cdf = hist.cumsum()
            cdf = cdf / cdf.max()
            
            # Interpolate
            equalized = np.interp(flat, bins[:-1], cdf * 255)
            return equalized.reshape(pixel_array.shape)
        except Exception:
            return pixel_array

    def _apply_speckle_reduction(self, pixel_array):
        """Apply speckle reduction for ultrasound"""
        try:
            from scipy import ndimage
            # Anisotropic diffusion-like filtering
            return ndimage.gaussian_filter(pixel_array, sigma=1.2)
        except (ImportError, Exception):
            return pixel_array

    def _apply_mammography_enhancement(self, pixel_array):
        """Apply mammography-specific enhancement"""
        try:
            # Enhance contrast for mammography
            enhanced = self._apply_contrast_stretching(pixel_array)
            # Apply unsharp masking
            return self._apply_unsharp_masking(enhanced)
        except Exception:
            return pixel_array

    def _enhance_microcalcifications(self, pixel_array):
        """Enhance microcalcifications in mammography"""
        try:
            from scipy import ndimage
            # High-pass filtering to enhance small features
            low_pass = ndimage.gaussian_filter(pixel_array, sigma=3)
            high_pass = pixel_array - low_pass
            return pixel_array + 0.5 * high_pass
        except (ImportError, Exception):
            return pixel_array

    def _normalize_nuclear_image(self, pixel_array):
        """Normalize nuclear medicine images"""
        try:
            # Apply square root normalization for nuclear images
            return np.sqrt(pixel_array - np.min(pixel_array) + 1)
        except Exception:
            return pixel_array

    def _apply_nuclear_smoothing(self, pixel_array):
        """Apply smoothing for nuclear images"""
        try:
            from scipy import ndimage
            return ndimage.gaussian_filter(pixel_array, sigma=1.5)
        except (ImportError, Exception):
            return pixel_array

    def _convert_ybr_to_rgb(self, image_array):
        """Convert YBR color space to RGB"""
        try:
            if len(image_array.shape) == 3 and image_array.shape[2] == 3:
                # YBR to RGB conversion matrix
                y, cb, cr = image_array[:,:,0], image_array[:,:,1], image_array[:,:,2]
                r = y + 1.402 * (cr - 128)
                g = y - 0.344 * (cb - 128) - 0.714 * (cr - 128)
                b = y + 1.772 * (cb - 128)
                
                # Clip values
                r = np.clip(r, 0, 255)
                g = np.clip(g, 0, 255)
                b = np.clip(b, 0, 255)
                
                return np.stack([r, g, b], axis=2)
            return image_array
        except Exception:
            return image_array

    def _apply_adaptive_histogram_equalization(self, pixel_array):
        """Apply adaptive histogram equalization"""
        try:
            # Simple adaptive histogram equalization
            h, w = pixel_array.shape
            result = np.zeros_like(pixel_array)
            
            # Process in 64x64 blocks
            block_size = 64
            for i in range(0, h, block_size):
                for j in range(0, w, block_size):
                    block = pixel_array[i:i+block_size, j:j+block_size]
                    result[i:i+block_size, j:j+block_size] = self._apply_histogram_equalization(block)
            
            return result
        except Exception:
            return pixel_array

    def _apply_contrast_stretching(self, pixel_array):
        """Apply contrast stretching"""
        try:
            # Percentile-based contrast stretching
            p2, p98 = np.percentile(pixel_array, (2, 98))
            return np.clip((pixel_array - p2) * 255 / (p98 - p2), 0, 255)
        except Exception:
            return pixel_array

    def _apply_ultrasound_contrast(self, pixel_array):
        """Apply ultrasound-specific contrast enhancement"""
        try:
            # Log compression for ultrasound
            return 20 * np.log10(pixel_array + 1)
        except Exception:
            return pixel_array

    def _apply_unsharp_masking(self, pixel_array):
        """Apply unsharp masking"""
        try:
            from scipy import ndimage
            blurred = ndimage.gaussian_filter(pixel_array, sigma=2)
            mask = pixel_array - blurred
            return pixel_array + 0.5 * mask
        except (ImportError, Exception):
            return pixel_array


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


# Global instances
image_cache = ImageCache(max_size=2000)
dicom_processor = DicomProcessor()

# Enhanced Hounsfield calibration validator
class HounsfieldCalibrationValidator:
    """Comprehensive Hounsfield Unit calibration validation system"""
    
    def __init__(self):
        self.qa_thresholds = {
            'water_tolerance': 5,      # HU units
            'air_tolerance': 50,       # HU units
            'noise_threshold': 10,     # HU units standard deviation
        }
    
    def validate_calibration(self, dicom_dataset, pixel_array=None):
        """Comprehensive Hounsfield calibration validation"""
        validation_results = {
            'is_valid': True,
            'issues': [],
            'warnings': [],
            'calibration_status': 'unknown',
            'measurements': {},
        }
        
        try:
            # Check if CT modality
            modality = getattr(dicom_dataset, 'Modality', '')
            if modality != 'CT':
                validation_results['calibration_status'] = 'not_applicable'
                validation_results['warnings'].append('Hounsfield units only applicable to CT images')
                return validation_results
            
            # Check rescale parameters
            slope = getattr(dicom_dataset, 'RescaleSlope', None)
            intercept = getattr(dicom_dataset, 'RescaleIntercept', None)
            
            if slope is None or intercept is None:
                validation_results['is_valid'] = False
                validation_results['issues'].append('Missing rescale parameters (RescaleSlope/RescaleIntercept)')
                validation_results['calibration_status'] = 'invalid'
                return validation_results
            
            # Validate rescale slope (should typically be 1.0 for CT)
            slope = float(slope)
            if abs(slope - 1.0) > 0.01:
                validation_results['warnings'].append(f'Unusual rescale slope: {slope} (expected: 1.0)')
            
            # If pixel array provided, perform image-based validation
            if pixel_array is not None:
                hu_array = self._convert_to_hu(pixel_array, dicom_dataset)
                
                # Estimate water and air HU values
                water_hu = self._estimate_water_hu(hu_array)
                air_hu = self._estimate_air_hu(hu_array)
                
                if water_hu is not None:
                    validation_results['measurements']['water_hu'] = water_hu
                    water_deviation = abs(water_hu - 0.0)
                    
                    if water_deviation > self.qa_thresholds['water_tolerance']:
                        validation_results['is_valid'] = False
                        validation_results['issues'].append(
                            f'Water HU deviation too high: {water_deviation:.1f} HU '
                            f'(expected: 0 ± {self.qa_thresholds["water_tolerance"]} HU)'
                        )
                
                if air_hu is not None:
                    validation_results['measurements']['air_hu'] = air_hu
                    air_deviation = abs(air_hu - (-1000.0))
                    
                    if air_deviation > self.qa_thresholds['air_tolerance']:
                        validation_results['is_valid'] = False
                        validation_results['issues'].append(
                            f'Air HU deviation too high: {air_deviation:.1f} HU '
                            f'(expected: -1000 ± {self.qa_thresholds["air_tolerance"]} HU)'
                        )
            
            # Set final calibration status
            if validation_results['is_valid']:
                validation_results['calibration_status'] = 'valid' if not validation_results['warnings'] else 'warning'
            else:
                validation_results['calibration_status'] = 'invalid'
                
        except Exception as e:
            logger.error(f"Error validating Hounsfield calibration: {str(e)}")
            validation_results['is_valid'] = False
            validation_results['issues'].append(f'Validation error: {str(e)}')
            validation_results['calibration_status'] = 'error'
        
        return validation_results
    
    def _convert_to_hu(self, pixel_array, dicom_dataset):
        """Convert pixel values to Hounsfield Units"""
        slope = float(getattr(dicom_dataset, 'RescaleSlope', 1.0))
        intercept = float(getattr(dicom_dataset, 'RescaleIntercept', 0.0))
        return pixel_array.astype(np.float32) * slope + intercept
    
    def _estimate_water_hu(self, hu_array):
        """Estimate water HU value from image"""
        try:
            water_candidates = hu_array[(hu_array > -50) & (hu_array < 100)]
            if len(water_candidates) > 1000:
                return float(np.median(water_candidates))
        except:
            pass
        return None
    
    def _estimate_air_hu(self, hu_array):
        """Estimate air HU value from image"""
        try:
            air_candidates = hu_array[hu_array < -800]
            if len(air_candidates) > 100:
                return float(np.median(air_candidates))
        except:
            pass
        return None

hu_validator = HounsfieldCalibrationValidator()