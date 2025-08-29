# Generated manually to add database indexes for performance

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('dicom_viewer', '0007_create_missing_models'),
    ]

    operations = [
        # Add indexes for ViewerSession
        migrations.AddIndex(
            model_name='viewersession',
            index=models.Index(fields=['user', 'study'], name='dicom_viewer_user_study_idx'),
        ),
        migrations.AddIndex(
            model_name='viewersession',
            index=models.Index(fields=['-updated_at'], name='dicom_viewer_session_updated_idx'),
        ),

        # Add indexes for Measurement
        migrations.AddIndex(
            model_name='measurement',
            index=models.Index(fields=['user', 'study'], name='dicom_viewer_meas_user_study_idx'),
        ),
        migrations.AddIndex(
            model_name='measurement',
            index=models.Index(fields=['study', 'measurement_type'], name='dicom_viewer_meas_study_type_idx'),
        ),
        migrations.AddIndex(
            model_name='measurement',
            index=models.Index(fields=['image', '-created_at'], name='dicom_viewer_meas_image_created_idx'),
        ),
        migrations.AddIndex(
            model_name='measurement',
            index=models.Index(fields=['-created_at'], name='dicom_viewer_meas_created_idx'),
        ),

        # Add indexes for Annotation
        migrations.AddIndex(
            model_name='annotation',
            index=models.Index(fields=['user', 'study'], name='dicom_viewer_annot_user_study_idx'),
        ),
        migrations.AddIndex(
            model_name='annotation',
            index=models.Index(fields=['image', '-created_at'], name='dicom_viewer_annot_image_created_idx'),
        ),
        migrations.AddIndex(
            model_name='annotation',
            index=models.Index(fields=['study', 'annotation_type'], name='dicom_viewer_annot_study_type_idx'),
        ),
        migrations.AddIndex(
            model_name='annotation',
            index=models.Index(fields=['-created_at'], name='dicom_viewer_annot_created_idx'),
        ),

        # Add indexes for ViewerPerformanceMetrics
        migrations.AddIndex(
            model_name='viewerperformancemetrics',
            index=models.Index(fields=['user', 'operation_type', '-timestamp'], name='dicom_viewer_perf_user_op_time_idx'),
        ),
        migrations.AddIndex(
            model_name='viewerperformancemetrics',
            index=models.Index(fields=['operation_type', '-timestamp'], name='dicom_viewer_perf_op_time_idx'),
        ),
        migrations.AddIndex(
            model_name='viewerperformancemetrics',
            index=models.Index(fields=['-timestamp'], name='dicom_viewer_perf_timestamp_idx'),
        ),
        migrations.AddIndex(
            model_name='viewerperformancemetrics',
            index=models.Index(fields=['success', 'operation_type'], name='dicom_viewer_perf_success_op_idx'),
        ),

        # Add indexes for DicomImageCache
        migrations.AddIndex(
            model_name='dicomimagecache',
            index=models.Index(fields=['image', 'window_width', 'window_level'], name='dicom_viewer_cache_img_win_idx'),
        ),
        migrations.AddIndex(
            model_name='dicomimagecache',
            index=models.Index(fields=['-last_accessed'], name='dicom_viewer_cache_accessed_idx'),
        ),
        migrations.AddIndex(
            model_name='dicomimagecache',
            index=models.Index(fields=['cache_key'], name='dicom_viewer_cache_key_idx'),
        ),
    ]