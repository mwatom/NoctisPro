from django.contrib import admin
from .models import Patient, Modality, Study, Series, DicomImage


@admin.register(Patient)
class PatientAdmin(admin.ModelAdmin):
    list_display = ('patient_name', 'patient_id', 'date_of_birth', 'sex', 'created_at')
    search_fields = ('patient_name', 'patient_id')
    list_filter = ('sex', 'created_at')


@admin.register(Modality)
class ModalityAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('code', 'name')


@admin.register(Study)
class StudyAdmin(admin.ModelAdmin):
    list_display = ('patient', 'study_description', 'study_date', 'modality', 'status', 'priority')
    list_filter = ('status', 'modality', 'study_date', 'priority')
    search_fields = ('patient__patient_name', 'study_description', 'accession_number')
    date_hierarchy = 'study_date'


@admin.register(Series)
class SeriesAdmin(admin.ModelAdmin):
    list_display = ('study', 'series_number', 'series_description', 'modality', 'image_count')
    list_filter = ('modality', 'created_at')
    search_fields = ('series_description', 'study__patient__patient_name')


@admin.register(DicomImage)
class DicomImageAdmin(admin.ModelAdmin):
    list_display = ('series', 'instance_number', 'file_size', 'created_at')
    list_filter = ('created_at',)
    search_fields = ('sop_instance_uid', 'series__study__patient__patient_name')