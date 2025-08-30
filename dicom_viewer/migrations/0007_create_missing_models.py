# Generated manually to create missing models

from django.conf import settings
import django.core.validators
from django.db import migrations, models
import uuid


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('dicom_viewer', '0006_populate_measurement_relations'),
        ('worklist', '0001_initial'),
    ]

    operations = [
        # Only create models that don't exist yet
        # HangingProtocol, WindowLevelPreset, HounsfieldQAPhantom, HounsfieldCalibration, and ReconstructionJob
        # already exist from previous migrations

        # Create UserPreferences model
        migrations.CreateModel(
            name='UserPreferences',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('default_layout', models.CharField(choices=[('1x1', 'Single Image'), ('1x2', '1 x 2 Grid'), ('2x1', '2 x 1 Grid'), ('2x2', '2 x 2 Grid'), ('2x3', '2 x 3 Grid'), ('3x3', '3 x 3 Grid'), ('mpr', 'MPR (3-plane)'), ('custom', 'Custom Layout')], default='1x1', max_length=20)),
                ('auto_window_level', models.BooleanField(default=True)),
                ('invert_grayscale', models.BooleanField(default=False)),
                ('smooth_zoom', models.BooleanField(default=True)),
                ('left_mouse_action', models.CharField(choices=[('window_level', 'Window/Level'), ('zoom', 'Zoom'), ('pan', 'Pan'), ('measurement', 'Measurement')], default='window_level', max_length=20)),
                ('middle_mouse_action', models.CharField(choices=[('window_level', 'Window/Level'), ('zoom', 'Zoom'), ('pan', 'Pan'), ('measurement', 'Measurement')], default='pan', max_length=20)),
                ('right_mouse_action', models.CharField(choices=[('window_level', 'Window/Level'), ('zoom', 'Zoom'), ('pan', 'Pan'), ('measurement', 'Measurement')], default='zoom', max_length=20)),
                ('measurement_units', models.CharField(default='mm', max_length=10)),
                ('show_measurement_labels', models.BooleanField(default=True)),
                ('measurement_precision', models.PositiveIntegerField(default=2, validators=[django.core.validators.MaxValueValidator(6)])),
                ('enable_gpu_acceleration', models.BooleanField(default=True)),
                ('max_texture_size', models.PositiveIntegerField(default=4096)),
                ('preload_adjacent_images', models.BooleanField(default=True)),
                ('cache_size_mb', models.PositiveIntegerField(default=512)),
                ('toolbar_position', models.CharField(choices=[('top', 'Top'), ('bottom', 'Bottom'), ('left', 'Left'), ('right', 'Right')], default='top', max_length=10)),
                ('show_rulers', models.BooleanField(default=False)),
                ('show_orientation_marker', models.BooleanField(default=True)),
                ('dark_theme', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.OneToOneField(on_delete=models.CASCADE, related_name='viewer_preferences', to=settings.AUTH_USER_MODEL)),
            ],
        ),

        # Create ViewerPerformanceMetrics model
        migrations.CreateModel(
            name='ViewerPerformanceMetrics',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True)),
                ('operation_type', models.CharField(choices=[('image_load', 'Image Load'), ('windowing', 'Window/Level Change'), ('measurement', 'Measurement Creation'), ('annotation', 'Annotation Creation'), ('reconstruction', '3D Reconstruction'), ('series_load', 'Series Load'), ('study_load', 'Study Load'), ('export', 'Image Export'), ('print', 'Image Print')], db_index=True, max_length=20)),
                ('operation_details', models.JSONField(default=dict)),
                ('duration_ms', models.PositiveIntegerField(help_text='Operation duration in milliseconds')),
                ('memory_usage_mb', models.FloatField(blank=True, null=True)),
                ('network_bytes', models.BigIntegerField(blank=True, null=True)),
                ('cache_hit', models.BooleanField(default=False)),
                ('study_id', models.PositiveIntegerField(blank=True, null=True)),
                ('series_id', models.PositiveIntegerField(blank=True, null=True)),
                ('image_id', models.PositiveIntegerField(blank=True, null=True)),
                ('browser_info', models.JSONField(default=dict)),
                ('screen_resolution', models.CharField(blank=True, max_length=20)),
                ('connection_speed', models.CharField(blank=True, max_length=20)),
                ('success', models.BooleanField(default=True)),
                ('error_message', models.TextField(blank=True)),
                ('timestamp', models.DateTimeField(auto_now_add=True)),
                ('session', models.ForeignKey(blank=True, null=True, on_delete=models.CASCADE, to='dicom_viewer.viewersession')),
                ('user', models.ForeignKey(db_index=True, on_delete=models.CASCADE, to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-timestamp'],
            },
        ),

        # Create DicomImageCache model
        migrations.CreateModel(
            name='DicomImageCache',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True)),
                ('window_width', models.FloatField()),
                ('window_level', models.FloatField()),
                ('inverted', models.BooleanField(default=False)),
                ('enhancement', models.CharField(default='none', max_length=20)),
                ('cache_key', models.CharField(db_index=True, max_length=255, unique=True)),
                ('file_path', models.CharField(max_length=500)),
                ('file_size', models.BigIntegerField()),
                ('format', models.CharField(default='JPEG', max_length=10)),
                ('quality', models.PositiveIntegerField(default=85)),
                ('access_count', models.PositiveIntegerField(default=0)),
                ('last_accessed', models.DateTimeField(auto_now=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('image', models.ForeignKey(db_index=True, on_delete=models.CASCADE, to='worklist.dicomimage')),
            ],
            options={
                'ordering': ['-last_accessed'],
            },
        ),
    ]