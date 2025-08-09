from django.db import models
from django.utils import timezone
from accounts.models import User, Facility
import os

class Patient(models.Model):
    """Patient information model"""
    patient_id = models.CharField(max_length=50, unique=True)
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    date_of_birth = models.DateField()
    gender = models.CharField(max_length=1, choices=[('M', 'Male'), ('F', 'Female'), ('O', 'Other')])
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True)
    address = models.TextField(blank=True)
    emergency_contact = models.CharField(max_length=200, blank=True)
    medical_record_number = models.CharField(max_length=50, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.patient_id})"

    @property
    def full_name(self):
        return f"{self.first_name} {self.last_name}"

class Modality(models.Model):
    """Imaging modality types"""
    code = models.CharField(max_length=10, unique=True)  # CT, MR, XR, etc.
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name_plural = "Modalities"

    def __str__(self):
        return f"{self.code} - {self.name}"

class Study(models.Model):
    """Medical study/examination model"""
    STUDY_STATUS_CHOICES = [
        ('scheduled', 'Scheduled'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('suspended', 'Suspended'),
        ('cancelled', 'Cancelled'),
    ]

    PRIORITY_CHOICES = [
        ('low', 'Low'),
        ('normal', 'Normal'),
        ('high', 'High'),
        ('urgent', 'Urgent'),
    ]

    study_instance_uid = models.CharField(max_length=100, unique=True)
    accession_number = models.CharField(max_length=50, unique=True)
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE)
    facility = models.ForeignKey(Facility, on_delete=models.CASCADE)
    modality = models.ForeignKey(Modality, on_delete=models.CASCADE)
    study_description = models.CharField(max_length=200)
    study_date = models.DateTimeField()
    referring_physician = models.CharField(max_length=100)
    radiologist = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, 
                                   related_name='assigned_studies')
    status = models.CharField(max_length=20, choices=STUDY_STATUS_CHOICES, default='scheduled')
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='normal')
    body_part = models.CharField(max_length=100, blank=True)
    clinical_info = models.TextField(blank=True)
    study_comments = models.TextField(blank=True)
    uploaded_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, 
                                   related_name='uploaded_studies')
    upload_date = models.DateTimeField(auto_now_add=True)
    last_updated = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-study_date']

    def __str__(self):
        return f"{self.accession_number} - {self.patient.full_name} ({self.modality.code})"

    def get_series_count(self):
        return self.series_set.count()

    def get_image_count(self):
        return sum(series.images.count() for series in self.series_set.all())

class Series(models.Model):
    """DICOM Series model"""
    series_instance_uid = models.CharField(max_length=100, unique=True)
    study = models.ForeignKey(Study, on_delete=models.CASCADE)
    series_number = models.IntegerField()
    series_description = models.CharField(max_length=200, blank=True)
    modality = models.CharField(max_length=10)
    body_part = models.CharField(max_length=100, blank=True)
    slice_thickness = models.FloatField(null=True, blank=True)
    pixel_spacing = models.CharField(max_length=50, blank=True)
    image_orientation = models.CharField(max_length=100, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = "Series"
        ordering = ['series_number']

    def __str__(self):
        return f"Series {self.series_number} - {self.series_description}"

class DicomImage(models.Model):
    """Individual DICOM image model"""
    sop_instance_uid = models.CharField(max_length=100, unique=True)
    series = models.ForeignKey(Series, on_delete=models.CASCADE, related_name='images')
    instance_number = models.IntegerField()
    image_position = models.CharField(max_length=100, blank=True)
    slice_location = models.FloatField(null=True, blank=True)
    file_path = models.FileField(upload_to='dicom/images/')
    file_size = models.BigIntegerField()
    thumbnail = models.ImageField(upload_to='dicom/thumbnails/', null=True, blank=True)
    processed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['instance_number']

    def __str__(self):
        return f"Image {self.instance_number} - {self.sop_instance_uid}"

    def get_file_name(self):
        return os.path.basename(self.file_path.name) if self.file_path else ''

class StudyAttachment(models.Model):
    """Additional files attached to studies (reports, etc.)"""
    ATTACHMENT_TYPES = [
        ('report', 'Report'),
        ('image', 'Image'),
        ('document', 'Document'),
        ('other', 'Other'),
    ]

    study = models.ForeignKey(Study, on_delete=models.CASCADE, related_name='attachments')
    file = models.FileField(upload_to='study_attachments/')
    file_type = models.CharField(max_length=20, choices=ATTACHMENT_TYPES)
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    uploaded_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    upload_date = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} - {self.study.accession_number}"

    def get_file_extension(self):
        return os.path.splitext(self.file.name)[1].lower()

class StudyNote(models.Model):
    """Notes and comments on studies"""
    study = models.ForeignKey(Study, on_delete=models.CASCADE, related_name='notes')
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    note = models.TextField()
    is_private = models.BooleanField(default=False)  # Private to facility/radiologist
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Note by {self.user.username} on {self.study.accession_number}"
