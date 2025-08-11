from django.conf import settings
from django.db import models

# Use existing Study/Series/DicomImage from worklist app
from worklist.models import Study, Series, DicomImage
import json


class ViewerSession(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    study = models.ForeignKey(Study, on_delete=models.CASCADE)
    session_data = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def set_session_data(self, data):
        self.session_data = json.dumps(data)

    def get_session_data(self):
        return json.loads(self.session_data) if self.session_data else {}


class Measurement(models.Model):
    MEASUREMENT_TYPES = [
        ("length", "Length"),
        ("area", "Area"),
        ("angle", "Angle"),
        ("cobb_angle", "Cobb Angle"),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    image = models.ForeignKey(DicomImage, on_delete=models.CASCADE)
    measurement_type = models.CharField(max_length=20, choices=MEASUREMENT_TYPES)
    points = models.TextField()  # JSON array of points
    value = models.FloatField(null=True, blank=True)
    unit = models.CharField(max_length=16, default="mm")
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def set_points(self, points_list):
        self.points = json.dumps(points_list)

    def get_points(self):
        return json.loads(self.points) if self.points else []


class Annotation(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    image = models.ForeignKey(DicomImage, on_delete=models.CASCADE)
    position_x = models.FloatField()
    position_y = models.FloatField()
    text = models.TextField()
    color = models.CharField(max_length=7, default="#FFFF00")  # Hex color
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Annotation: {self.text[:50]}"


class ReconstructionJob(models.Model):
    JOB_TYPES = [
        ("mpr", "Multiplanar Reconstruction"),
        ("mip", "Maximum Intensity Projection"),
        ("bone_3d", "Bone 3D Reconstruction"),
        ("mri_3d", "MRI 3D Reconstruction"),
    ]

    STATUS_CHOICES = [
        ("pending", "Pending"),
        ("processing", "Processing"),
        ("completed", "Completed"),
        ("failed", "Failed"),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    series = models.ForeignKey(Series, on_delete=models.CASCADE)
    job_type = models.CharField(max_length=20, choices=JOB_TYPES)
    parameters = models.TextField(blank=True)  # JSON
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="pending")
    result_path = models.CharField(max_length=500, blank=True)
    error_message = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    def set_parameters(self, params):
        self.parameters = json.dumps(params)

    def get_parameters(self):
        return json.loads(self.parameters) if self.parameters else {}
