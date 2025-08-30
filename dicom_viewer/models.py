"""
DICOM Viewer Models - Optimized and Enhanced
Enhanced models for DICOM viewing, measurements, annotations, and quality assurance.

Features:
- Optimized database queries with proper indexing
- Enhanced measurement and annotation capabilities
- Advanced reconstruction job management
- Comprehensive Hounsfield Unit calibration tracking
- User preferences and hanging protocols
- Performance monitoring and caching
"""

from django.conf import settings
from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
# Remove PostgreSQL-specific import - using Django's built-in JSONField
import json
import uuid

# Use existing Study/Series/DicomImage from worklist app
from worklist.models import Study, Series, DicomImage


class ViewerSession(models.Model):
    """Enhanced viewer session with performance optimizations"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, db_index=True)
    study = models.ForeignKey(Study, on_delete=models.CASCADE, db_index=True)
    session_data = models.JSONField(default=dict, blank=True)
    
    # Enhanced session tracking
    viewport_settings = models.JSONField(default=dict, blank=True)
    measurement_tools = models.JSONField(default=dict, blank=True)
    window_level_presets = models.JSONField(default=list, blank=True)
    layout_config = models.JSONField(default=dict, blank=True)
    
    # Performance tracking
    last_accessed = models.DateTimeField(auto_now=True)
    access_count = models.PositiveIntegerField(default=0)
    session_duration = models.DurationField(null=True, blank=True)
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['user', 'study']),
            models.Index(fields=['user', '-last_accessed']),
            models.Index(fields=['-updated_at']),
        ]
        unique_together = ['user', 'study']
    
    def __str__(self):
        return f"Session: {self.user.username} - {self.study.accession_number}"
    
    def increment_access(self):
        """Increment access count and update timestamp"""
        self.access_count += 1
        self.last_accessed = timezone.now()
        self.save(update_fields=['access_count', 'last_accessed'])
    
    def set_session_data(self, data):
        """Legacy compatibility method"""
        self.session_data = data
    
    def get_session_data(self):
        """Legacy compatibility method"""
        return self.session_data


class Measurement(models.Model):
    """Enhanced measurement model with validation and performance optimizations"""
    MEASUREMENT_TYPES = [
        ("length", "Length"),
        ("area", "Area"),
        ("angle", "Angle"),
        ("cobb_angle", "Cobb Angle"),
        ("volume", "Volume"),
        ("density", "Density (HU)"),
        ("distance_3d", "3D Distance"),
        ("ellipse", "Ellipse"),
        ("rectangle", "Rectangle"),
        ("circle", "Circle"),
        ("polyline", "Polyline"),
        ("spline", "Spline Curve"),
    ]
    
    MEASUREMENT_UNITS = [
        ("mm", "Millimeters"),
        ("cm", "Centimeters"),
        ("px", "Pixels"),
        ("mm2", "Square Millimeters"),
        ("cm2", "Square Centimeters"),
        ("mm3", "Cubic Millimeters"),
        ("cm3", "Cubic Centimeters"),
        ("deg", "Degrees"),
        ("rad", "Radians"),
        ("hu", "Hounsfield Units"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, db_index=True)
    image = models.ForeignKey(DicomImage, on_delete=models.CASCADE, db_index=True)
    series = models.ForeignKey(Series, on_delete=models.CASCADE, db_index=True)
    study = models.ForeignKey(Study, on_delete=models.CASCADE, db_index=True)
    
    measurement_type = models.CharField(max_length=20, choices=MEASUREMENT_TYPES, db_index=True)
    points = models.JSONField(default=list)  # Array of points
    value = models.FloatField(null=True, blank=True, validators=[MinValueValidator(0)])
    unit = models.CharField(max_length=16, choices=MEASUREMENT_UNITS, default="mm")
    
    # Enhanced metadata
    notes = models.TextField(blank=True)
    accuracy = models.FloatField(null=True, blank=True, help_text="Measurement accuracy/confidence")
    is_validated = models.BooleanField(default=False)
    validated_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, 
                                   null=True, blank=True, related_name='validated_measurements')
    
    # Geometric properties
    pixel_spacing = models.JSONField(default=list, help_text="Pixel spacing at time of measurement")
    slice_thickness = models.FloatField(null=True, blank=True)
    window_level = models.FloatField(null=True, blank=True)
    window_width = models.FloatField(null=True, blank=True)
    
    # Version control
    version = models.PositiveIntegerField(default=1)
    previous_version = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['user', 'study']),
            models.Index(fields=['study', 'measurement_type']),
            models.Index(fields=['image', '-created_at']),
            models.Index(fields=['-created_at']),
        ]
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.get_measurement_type_display()}: {self.value} {self.unit}"
    
    def set_points(self, points_list):
        """Legacy compatibility method"""
        self.points = points_list
    
    def get_points(self):
        """Legacy compatibility method"""
        return self.points
    
    def save(self, *args, **kwargs):
        # Auto-populate series and study if not set
        if not self.series_id and self.image:
            self.series = self.image.series
        if not self.study_id and self.series:
            self.study = self.series.study
        super().save(*args, **kwargs)


class Annotation(models.Model):
    """Enhanced annotation model with rich features"""
    ANNOTATION_TYPES = [
        ("text", "Text Annotation"),
        ("arrow", "Arrow"),
        ("circle", "Circle"),
        ("rectangle", "Rectangle"),
        ("freehand", "Freehand Drawing"),
        ("ruler", "Ruler"),
        ("protractor", "Protractor"),
        ("roi", "Region of Interest"),
    ]
    
    id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, db_index=True)
    image = models.ForeignKey(DicomImage, on_delete=models.CASCADE, db_index=True)
    series = models.ForeignKey(Series, on_delete=models.CASCADE, db_index=True)
    study = models.ForeignKey(Study, on_delete=models.CASCADE, db_index=True)
    
    annotation_type = models.CharField(max_length=20, choices=ANNOTATION_TYPES, default="text")
    position_x = models.FloatField()
    position_y = models.FloatField()
    
    # Enhanced content
    text = models.TextField()
    color = models.CharField(max_length=7, default="#FFFF00")  # Hex color
    font_size = models.PositiveIntegerField(default=12, validators=[MinValueValidator(8), MaxValueValidator(72)])
    opacity = models.FloatField(default=1.0, validators=[MinValueValidator(0.0), MaxValueValidator(1.0)])
    
    # Geometric data for complex annotations
    geometry = models.JSONField(default=dict, help_text="Additional geometric data")
    style = models.JSONField(default=dict, help_text="Style properties")
    
    # Metadata
    is_visible = models.BooleanField(default=True)
    is_locked = models.BooleanField(default=False)
    layer = models.PositiveIntegerField(default=0)
    
    # Version control
    version = models.PositiveIntegerField(default=1)
    previous_version = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['user', 'study']),
            models.Index(fields=['image', '-created_at']),
            models.Index(fields=['study', 'annotation_type']),
            models.Index(fields=['-created_at']),
        ]
        ordering = ['layer', '-created_at']
    
    def __str__(self):
        return f"{self.get_annotation_type_display()}: {self.text[:50]}"
    
    def save(self, *args, **kwargs):
        # Auto-populate series and study if not set
        if not self.series_id and self.image:
            self.series = self.image.series
        if not self.study_id and self.series:
            self.study = self.series.study
        super().save(*args, **kwargs)


class ReconstructionJob(models.Model):
    """Enhanced reconstruction job management with performance tracking"""
    JOB_TYPES = [
        ("mpr", "Multiplanar Reconstruction"),
        ("mip", "Maximum Intensity Projection"),
        ("minip", "Minimum Intensity Projection"),
        ("bone_3d", "Bone 3D Reconstruction"),
        ("mri_3d", "MRI 3D Reconstruction"),
        ("vr", "Volume Rendering"),
        ("curved_mpr", "Curved MPR"),
        ("thick_slab", "Thick Slab"),
        ("vessel_analysis", "Vessel Analysis"),
        ("perfusion", "Perfusion Analysis"),
    ]

    STATUS_CHOICES = [
        ("pending", "Pending"),
        ("queued", "Queued"),
        ("processing", "Processing"),
        ("completed", "Completed"),
        ("failed", "Failed"),
        ("cancelled", "Cancelled"),
        ("paused", "Paused"),
    ]
    
    PRIORITY_CHOICES = [
        ("low", "Low"),
        ("normal", "Normal"),
        ("high", "High"),
        ("urgent", "Urgent"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, db_index=True)
    series = models.ForeignKey(Series, on_delete=models.CASCADE, db_index=True)
    study = models.ForeignKey(Study, on_delete=models.CASCADE, db_index=True)
    
    job_type = models.CharField(max_length=20, choices=JOB_TYPES, db_index=True)
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default="normal")
    parameters = models.JSONField(default=dict)
    
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="pending", db_index=True)
    progress = models.PositiveIntegerField(default=0, validators=[MaxValueValidator(100)])
    
    # Results
    result_path = models.CharField(max_length=500, blank=True)
    result_metadata = models.JSONField(default=dict)
    result_size = models.BigIntegerField(null=True, blank=True)
    
    # Error handling
    error_message = models.TextField(blank=True)
    error_code = models.CharField(max_length=50, blank=True)
    retry_count = models.PositiveIntegerField(default=0)
    max_retries = models.PositiveIntegerField(default=3)
    
    # Performance metrics
    estimated_duration = models.DurationField(null=True, blank=True)
    actual_duration = models.DurationField(null=True, blank=True)
    memory_usage = models.BigIntegerField(null=True, blank=True, help_text="Peak memory usage in bytes")
    cpu_time = models.DurationField(null=True, blank=True)
    
    # Processing details
    worker_id = models.CharField(max_length=100, blank=True)
    processing_node = models.CharField(max_length=100, blank=True)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    started_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['series', 'job_type']),
            models.Index(fields=['status', 'priority', '-created_at']),
            models.Index(fields=['-created_at']),
        ]
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.get_job_type_display()} - {self.status}"
    
    def set_parameters(self, params):
        """Legacy compatibility method"""
        self.parameters = params
    
    def get_parameters(self):
        """Legacy compatibility method"""
        return self.parameters
    
    def start_processing(self, worker_id=None, node=None):
        """Mark job as started"""
        self.status = 'processing'
        self.started_at = timezone.now()
        if worker_id:
            self.worker_id = worker_id
        if node:
            self.processing_node = node
        self.save(update_fields=['status', 'started_at', 'worker_id', 'processing_node'])
    
    def update_progress(self, progress):
        """Update job progress"""
        self.progress = min(max(progress, 0), 100)
        self.save(update_fields=['progress'])
    
    def complete(self, result_path=None, metadata=None):
        """Mark job as completed"""
        self.status = 'completed'
        self.progress = 100
        self.completed_at = timezone.now()
        if result_path:
            self.result_path = result_path
        if metadata:
            self.result_metadata = metadata
        
        # Calculate actual duration
        if self.started_at:
            self.actual_duration = self.completed_at - self.started_at
        
        self.save()
    
    def fail(self, error_message, error_code=None):
        """Mark job as failed"""
        self.status = 'failed'
        self.error_message = error_message
        if error_code:
            self.error_code = error_code
        self.completed_at = timezone.now()
        
        # Calculate actual duration even for failed jobs
        if self.started_at:
            self.actual_duration = self.completed_at - self.started_at
        
        self.save()
    
    def can_retry(self):
        """Check if job can be retried"""
        return self.retry_count < self.max_retries and self.status == 'failed'
    
    def retry(self):
        """Retry failed job"""
        if self.can_retry():
            self.retry_count += 1
            self.status = 'pending'
            self.progress = 0
            self.error_message = ''
            self.error_code = ''
            self.save()
            return True
        return False
    
    def save(self, *args, **kwargs):
        # Auto-populate study if not set
        if not self.study_id and self.series:
            self.study = self.series.study
        super().save(*args, **kwargs)


class HangingProtocol(models.Model):
    """Simple hanging protocol definition per modality/body part.
    Defines default layout for the web viewer (e.g., 1x1, 2x2, tri-planar).
    """
    modality = models.CharField(max_length=16, blank=True)  # CT, MR, XR, etc.
    body_part = models.CharField(max_length=64, blank=True)
    name = models.CharField(max_length=128)
    layout = models.CharField(max_length=32, default="1x1")  # e.g., '1x1', '2x2', 'mpr-3plane'
    is_default = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.modality or '*'} {self.body_part or '*'} - {self.name} ({self.layout})"


class WindowLevelPreset(models.Model):
    """Per-user window/level presets optionally scoped by modality/body part."""
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    name = models.CharField(max_length=64)
    modality = models.CharField(max_length=16, blank=True)
    body_part = models.CharField(max_length=64, blank=True)
    window_width = models.FloatField()
    window_level = models.FloatField()
    inverted = models.BooleanField(default=False)

    class Meta:
        unique_together = ("user", "name", "modality", "body_part")

    def __str__(self):
        return f"{self.user_id}:{self.name} ({self.modality or '*'})"


class HounsfieldCalibration(models.Model):
    """Track Hounsfield Unit calibration for CT scanners"""
    CALIBRATION_STATUS = [
        ('valid', 'Valid'),
        ('invalid', 'Invalid'),
        ('warning', 'Warning'),
        ('not_applicable', 'Not Applicable'),
        ('error', 'Error'),
    ]
    
    # Scanner identification
    manufacturer = models.CharField(max_length=100, blank=True)
    model = models.CharField(max_length=100, blank=True)
    station_name = models.CharField(max_length=100, blank=True)
    device_serial_number = models.CharField(max_length=100, blank=True)
    
    # Study reference
    study = models.ForeignKey(Study, on_delete=models.CASCADE, related_name='hu_calibrations')
    series = models.ForeignKey(Series, on_delete=models.CASCADE, null=True, blank=True)
    
    # Calibration parameters
    rescale_slope = models.FloatField()
    rescale_intercept = models.FloatField()
    rescale_type = models.CharField(max_length=20, blank=True)
    
    # Measured values
    water_hu = models.FloatField(null=True, blank=True)
    air_hu = models.FloatField(null=True, blank=True)
    noise_level = models.FloatField(null=True, blank=True)
    
    # Validation results
    calibration_status = models.CharField(max_length=20, choices=CALIBRATION_STATUS)
    is_valid = models.BooleanField(default=False)
    validation_issues = models.JSONField(default=list, blank=True)
    validation_warnings = models.JSONField(default=list, blank=True)
    
    # Quality metrics
    water_deviation = models.FloatField(null=True, blank=True)
    air_deviation = models.FloatField(null=True, blank=True)
    linearity_check = models.FloatField(null=True, blank=True)
    
    # Metadata
    calibration_date = models.DateField(null=True, blank=True)
    phantom_type = models.CharField(max_length=100, blank=True)
    notes = models.TextField(blank=True)
    
    # Tracking
    validated_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return f"HU Calibration for {self.station_name or 'Unknown'} - {self.calibration_status}"
    
    def get_status_color(self):
        """Get color for status display"""
        status_colors = {
            'valid': 'success',
            'invalid': 'danger',
            'warning': 'warning',
            'not_applicable': 'secondary',
            'error': 'danger'
        }
        return status_colors.get(self.calibration_status, 'secondary')
    
    def calculate_deviations(self):
        """Calculate deviations from reference values"""
        if self.water_hu is not None:
            self.water_deviation = abs(self.water_hu - 0.0)  # Water reference is 0 HU
        
        if self.air_hu is not None:
            self.air_deviation = abs(self.air_hu - (-1000.0))  # Air reference is -1000 HU


class HounsfieldQAPhantom(models.Model):
    """Define QA phantoms for Hounsfield unit calibration"""
    name = models.CharField(max_length=100)
    manufacturer = models.CharField(max_length=100)
    model = models.CharField(max_length=100)
    
    # Phantom specifications
    water_roi_coordinates = models.JSONField(help_text="ROI coordinates for water measurement")
    air_roi_coordinates = models.JSONField(help_text="ROI coordinates for air measurement")
    material_rois = models.JSONField(default=dict, help_text="Additional material ROI coordinates")
    
    # Reference values
    expected_water_hu = models.FloatField(default=0.0)
    expected_air_hu = models.FloatField(default=-1000.0)
    expected_materials = models.JSONField(default=dict, help_text="Expected HU values for materials")
    
    # Tolerances
    water_tolerance = models.FloatField(default=5.0)
    air_tolerance = models.FloatField(default=50.0)
    material_tolerances = models.JSONField(default=dict)
    
    # Metadata
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.name} ({self.manufacturer})"


class ViewerPerformanceMetrics(models.Model):
    """Performance monitoring for DICOM viewer operations"""
    OPERATION_TYPES = [
        ("image_load", "Image Load"),
        ("windowing", "Window/Level Change"),
        ("measurement", "Measurement Creation"),
        ("annotation", "Annotation Creation"),
        ("reconstruction", "3D Reconstruction"),
        ("series_load", "Series Load"),
        ("study_load", "Study Load"),
        ("export", "Image Export"),
        ("print", "Image Print"),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, db_index=True)
    session = models.ForeignKey(ViewerSession, on_delete=models.CASCADE, null=True, blank=True)
    
    operation_type = models.CharField(max_length=20, choices=OPERATION_TYPES, db_index=True)
    operation_details = models.JSONField(default=dict)
    
    # Performance metrics
    duration_ms = models.PositiveIntegerField(help_text="Operation duration in milliseconds")
    memory_usage_mb = models.FloatField(null=True, blank=True)
    network_bytes = models.BigIntegerField(null=True, blank=True)
    cache_hit = models.BooleanField(default=False)
    
    # Context
    study_id = models.PositiveIntegerField(null=True, blank=True)
    series_id = models.PositiveIntegerField(null=True, blank=True)
    image_id = models.PositiveIntegerField(null=True, blank=True)
    
    # Client info
    browser_info = models.JSONField(default=dict)
    screen_resolution = models.CharField(max_length=20, blank=True)
    connection_speed = models.CharField(max_length=20, blank=True)
    
    # Error tracking
    success = models.BooleanField(default=True)
    error_message = models.TextField(blank=True)
    
    timestamp = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['user', 'operation_type', '-timestamp']),
            models.Index(fields=['operation_type', '-timestamp']),
            models.Index(fields=['-timestamp']),
            models.Index(fields=['success', 'operation_type']),
        ]
        ordering = ['-timestamp']
    
    def __str__(self):
        return f"{self.get_operation_type_display()} - {self.duration_ms}ms"


class DicomImageCache(models.Model):
    """Track cached DICOM images for cache management"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    image = models.ForeignKey(DicomImage, on_delete=models.CASCADE, db_index=True)
    
    # Cache key parameters
    window_width = models.FloatField()
    window_level = models.FloatField()
    inverted = models.BooleanField(default=False)
    enhancement = models.CharField(max_length=20, default='none')
    
    # Cache metadata
    cache_key = models.CharField(max_length=255, unique=True, db_index=True)
    file_path = models.CharField(max_length=500)
    file_size = models.BigIntegerField()
    format = models.CharField(max_length=10, default='JPEG')
    quality = models.PositiveIntegerField(default=85)
    
    # Usage tracking
    access_count = models.PositiveIntegerField(default=0)
    last_accessed = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['image', 'window_width', 'window_level']),
            models.Index(fields=['-last_accessed']),
            models.Index(fields=['cache_key']),
        ]
        ordering = ['-last_accessed']
    
    def __str__(self):
        return f"Cache: {self.image.sop_instance_uid} - {self.cache_key}"
    
    def increment_access(self):
        """Increment access count"""
        self.access_count += 1
        self.save(update_fields=['access_count', 'last_accessed'])


class UserPreferences(models.Model):
    """User-specific viewer preferences"""
    LAYOUT_CHOICES = [
        ("1x1", "Single Image"),
        ("1x2", "1 x 2 Grid"),
        ("2x1", "2 x 1 Grid"),
        ("2x2", "2 x 2 Grid"),
        ("2x3", "2 x 3 Grid"),
        ("3x3", "3 x 3 Grid"),
        ("mpr", "MPR (3-plane)"),
        ("custom", "Custom Layout"),
    ]
    
    MOUSE_BEHAVIOR_CHOICES = [
        ("window_level", "Window/Level"),
        ("zoom", "Zoom"),
        ("pan", "Pan"),
        ("measurement", "Measurement"),
    ]
    
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, 
                               related_name='viewer_preferences')
    
    # Display preferences
    default_layout = models.CharField(max_length=20, choices=LAYOUT_CHOICES, default="1x1")
    auto_window_level = models.BooleanField(default=True)
    invert_grayscale = models.BooleanField(default=False)
    smooth_zoom = models.BooleanField(default=True)
    
    # Mouse behavior
    left_mouse_action = models.CharField(max_length=20, choices=MOUSE_BEHAVIOR_CHOICES, default="window_level")
    middle_mouse_action = models.CharField(max_length=20, choices=MOUSE_BEHAVIOR_CHOICES, default="pan")
    right_mouse_action = models.CharField(max_length=20, choices=MOUSE_BEHAVIOR_CHOICES, default="zoom")
    
    # Measurement preferences
    measurement_units = models.CharField(max_length=10, default="mm")
    show_measurement_labels = models.BooleanField(default=True)
    measurement_precision = models.PositiveIntegerField(default=2, validators=[MaxValueValidator(6)])
    
    # Advanced preferences
    enable_gpu_acceleration = models.BooleanField(default=True)
    max_texture_size = models.PositiveIntegerField(default=4096)
    preload_adjacent_images = models.BooleanField(default=True)
    cache_size_mb = models.PositiveIntegerField(default=512)
    
    # UI preferences
    toolbar_position = models.CharField(max_length=10, default="top", choices=[("top", "Top"), ("bottom", "Bottom"), ("left", "Left"), ("right", "Right")])
    show_rulers = models.BooleanField(default=False)
    show_orientation_marker = models.BooleanField(default=True)
    dark_theme = models.BooleanField(default=False)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"Preferences: {self.user.username}"
