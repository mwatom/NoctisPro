from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone

class Study(models.Model):
    """DICOM Study model"""
    MODALITY_CHOICES = [
        ('CT', 'CT Scan'),
        ('MR', 'MRI'),
        ('XR', 'X-Ray'),
        ('US', 'Ultrasound'),
        ('NM', 'Nuclear Medicine'),
        ('PT', 'PET'),
        ('CR', 'Computed Radiography'),
        ('DR', 'Digital Radiography'),
    ]
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('archived', 'Archived'),
    ]
    
    PRIORITY_CHOICES = [
        ('low', 'Low'),
        ('normal', 'Normal'),
        ('high', 'High'),
        ('urgent', 'Urgent'),
    ]
    
    # Patient Information
    patient_name = models.CharField(max_length=200)
    patient_id = models.CharField(max_length=100)
    patient_dob = models.DateField(null=True, blank=True)
    patient_sex = models.CharField(max_length=1, choices=[('M', 'Male'), ('F', 'Female'), ('O', 'Other')], null=True, blank=True)
    
    # Study Information
    study_uid = models.CharField(max_length=200, unique=True)
    study_date = models.DateTimeField(default=timezone.now)
    study_description = models.TextField(blank=True)
    modality = models.CharField(max_length=10, choices=MODALITY_CHOICES)
    referring_physician = models.CharField(max_length=200, blank=True)
    
    # Status and Priority
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='normal')
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    assigned_to = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    
    class Meta:
        ordering = ['-study_date']
    
    def __str__(self):
        return f"{self.patient_name} - {self.modality} ({self.study_date.strftime('%Y-%m-%d')})"