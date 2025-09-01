from django.db import models
from django.conf import settings
from django.utils import timezone


class Patient(models.Model):
    """Patient information model"""
    patient_id = models.CharField(max_length=100, unique=True)
    patient_name = models.CharField(max_length=200)
    date_of_birth = models.DateField(null=True, blank=True)
    sex = models.CharField(max_length=1, choices=[('M', 'Male'), ('F', 'Female'), ('O', 'Other')], blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.patient_name} ({self.patient_id})"


class Modality(models.Model):
    """Imaging modality model"""
    code = models.CharField(max_length=10, unique=True)
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    
    class Meta:
        verbose_name_plural = "Modalities"
    
    def __str__(self):
        return f"{self.code} - {self.name}"


class Study(models.Model):
    """DICOM Study model"""
    STATUS_CHOICES = [
        ('scheduled', 'Scheduled'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
        ('urgent', 'Urgent'),
    ]
    
    study_instance_uid = models.CharField(max_length=255, unique=True)
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name='studies')
    study_date = models.DateField()
    study_time = models.TimeField(null=True, blank=True)
    study_description = models.CharField(max_length=500, blank=True)
    accession_number = models.CharField(max_length=100, blank=True)
    referring_physician = models.CharField(max_length=200, blank=True)
    modality = models.ForeignKey(Modality, on_delete=models.SET_NULL, null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='scheduled')
    priority = models.IntegerField(default=5)  # 1=highest, 5=normal, 10=lowest
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-study_date', '-created_at']
    
    def __str__(self):
        return f"{self.patient.patient_name} - {self.study_description} ({self.study_date})"


class Series(models.Model):
    """DICOM Series model"""
    series_instance_uid = models.CharField(max_length=255, unique=True)
    study = models.ForeignKey(Study, on_delete=models.CASCADE, related_name='series')
    series_number = models.IntegerField()
    series_description = models.CharField(max_length=500, blank=True)
    modality = models.CharField(max_length=10, blank=True)
    body_part_examined = models.CharField(max_length=100, blank=True)
    image_count = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['series_number']
        verbose_name_plural = "Series"
    
    def __str__(self):
        return f"Series {self.series_number} - {self.series_description}"


class DicomImage(models.Model):
    """DICOM Image model"""
    sop_instance_uid = models.CharField(max_length=255, unique=True)
    series = models.ForeignKey(Series, on_delete=models.CASCADE, related_name='images')
    instance_number = models.IntegerField()
    file_path = models.FileField(upload_to='dicom/', null=True, blank=True)
    file_size = models.BigIntegerField(default=0)
    image_position = models.CharField(max_length=100, blank=True)
    image_orientation = models.CharField(max_length=100, blank=True)
    pixel_spacing = models.CharField(max_length=50, blank=True)
    slice_thickness = models.FloatField(null=True, blank=True)
    window_center = models.IntegerField(null=True, blank=True)
    window_width = models.IntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['instance_number']
    
    def __str__(self):
        return f"Image {self.instance_number} - {self.sop_instance_uid}"