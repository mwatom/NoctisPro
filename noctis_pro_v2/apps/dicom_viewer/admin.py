from django.contrib import admin
from .models import ViewerSession, Measurement, Annotation


@admin.register(ViewerSession)
class ViewerSessionAdmin(admin.ModelAdmin):
    list_display = ('user', 'study', 'started_at', 'last_activity', 'is_active')
    list_filter = ('is_active', 'started_at')
    search_fields = ('user__username', 'study__patient__patient_name')


@admin.register(Measurement)
class MeasurementAdmin(admin.ModelAdmin):
    list_display = ('user', 'image', 'measurement_type', 'value', 'unit', 'created_at')
    list_filter = ('measurement_type', 'created_at')
    search_fields = ('user__username', 'image__series__study__patient__patient_name')


@admin.register(Annotation)
class AnnotationAdmin(admin.ModelAdmin):
    list_display = ('user', 'image', 'annotation_type', 'text', 'created_at')
    list_filter = ('annotation_type', 'created_at')
    search_fields = ('user__username', 'text', 'image__series__study__patient__patient_name')