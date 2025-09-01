from django.db import models
from worklist.models import Study
import os

class DicomImage(models.Model):
    """DICOM Image model for storing individual DICOM files"""
    study = models.ForeignKey(Study, on_delete=models.CASCADE, related_name='dicom_images')
    
    # DICOM file information
    dicom_file = models.FileField(upload_to='dicom/')
    instance_number = models.IntegerField(default=1)
    slice_location = models.FloatField(null=True, blank=True)
    
    # Image properties
    rows = models.IntegerField(default=512)
    columns = models.IntegerField(default=512)
    pixel_spacing = models.CharField(max_length=50, blank=True)
    slice_thickness = models.FloatField(null=True, blank=True)
    
    # Window/Level defaults
    window_width = models.IntegerField(default=400)
    window_center = models.IntegerField(default=40)
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['instance_number']
    
    def __str__(self):
        return f"{self.study.patient_name} - Slice {self.instance_number}"
    
    def get_file_path(self):
        """Get the full file path for the DICOM file"""
        if self.dicom_file:
            return self.dicom_file.path
        return None