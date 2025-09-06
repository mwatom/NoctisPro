from django.db import models
from django.conf import settings
from apps.worklist.models import Study, Series, DicomImage


class ViewerSession(models.Model):
    """Viewer session tracking"""
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    study = models.ForeignKey(Study, on_delete=models.CASCADE)
    started_at = models.DateTimeField(auto_now_add=True)
    last_activity = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)
    
    def __str__(self):
        return f"{self.user.username} - {self.study.patient.patient_name}"


class Measurement(models.Model):
    """DICOM measurements"""
    MEASUREMENT_TYPES = [
        ('distance', 'Distance'),
        ('area', 'Area'),
        ('angle', 'Angle'),
        ('hu', 'Hounsfield Unit'),
    ]
    
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    image = models.ForeignKey(DicomImage, on_delete=models.CASCADE)
    measurement_type = models.CharField(max_length=20, choices=MEASUREMENT_TYPES)
    value = models.FloatField()
    unit = models.CharField(max_length=10)
    coordinates = models.JSONField()  # Store measurement coordinates
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.measurement_type}: {self.value} {self.unit}"


class Annotation(models.Model):
    """DICOM annotations"""
    ANNOTATION_TYPES = [
        ('arrow', 'Arrow'),
        ('text', 'Text'),
        ('rectangle', 'Rectangle'),
        ('circle', 'Circle'),
        ('freehand', 'Freehand'),
    ]
    
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    image = models.ForeignKey(DicomImage, on_delete=models.CASCADE)
    annotation_type = models.CharField(max_length=20, choices=ANNOTATION_TYPES)
    coordinates = models.JSONField()  # Store annotation coordinates
    text = models.TextField(blank=True)
    color = models.CharField(max_length=7, default='#FF0000')  # Hex color
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.annotation_type} on {self.image}"