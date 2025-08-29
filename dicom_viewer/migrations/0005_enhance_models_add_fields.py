# Generated manually to enhance models with new fields

from django.db import migrations, models
import django.core.validators
import uuid


class Migration(migrations.Migration):

    dependencies = [
        ('dicom_viewer', '0004_add_annotation_fields'),
        ('worklist', '0001_initial'),  # Make sure worklist is migrated first
    ]

    operations = [
        # Fix layer field type in annotation
        migrations.AlterField(
            model_name='annotation',
            name='layer',
            field=models.PositiveIntegerField(default=0),
        ),
        
        # Add previous_version field to annotation with proper related_name
        migrations.AlterField(
            model_name='annotation',
            name='previous_version',
            field=models.ForeignKey(
                null=True,
                blank=True,
                on_delete=models.SET_NULL,
                to='dicom_viewer.annotation'
            ),
        ),

        # Add missing fields to ViewerSession
        migrations.AddField(
            model_name='viewersession',
            name='viewport_settings',
            field=models.JSONField(default=dict, blank=True),
        ),
        migrations.AddField(
            model_name='viewersession',
            name='measurement_tools',
            field=models.JSONField(default=dict, blank=True),
        ),
        migrations.AddField(
            model_name='viewersession',
            name='window_level_presets',
            field=models.JSONField(default=list, blank=True),
        ),
        migrations.AddField(
            model_name='viewersession',
            name='layout_config',
            field=models.JSONField(default=dict, blank=True),
        ),
        migrations.AddField(
            model_name='viewersession',
            name='access_count',
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.AddField(
            model_name='viewersession',
            name='session_duration',
            field=models.DurationField(null=True, blank=True),
        ),

        # Add new fields to Measurement model
        migrations.AddField(
            model_name='measurement',
            name='series',
            field=models.ForeignKey(
                'worklist.Series',
                on_delete=models.CASCADE,
                db_index=True,
                null=True,  # Temporarily allow null
                blank=True
            ),
        ),
        migrations.AddField(
            model_name='measurement',
            name='study',
            field=models.ForeignKey(
                'worklist.Study',
                on_delete=models.CASCADE,
                db_index=True,
                null=True,  # Temporarily allow null
                blank=True
            ),
        ),
        migrations.AddField(
            model_name='measurement',
            name='notes',
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name='measurement',
            name='accuracy',
            field=models.FloatField(null=True, blank=True, help_text="Measurement accuracy/confidence"),
        ),
        migrations.AddField(
            model_name='measurement',
            name='is_validated',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='measurement',
            name='validated_by',
            field=models.ForeignKey(
                'auth.User',
                on_delete=models.SET_NULL,
                null=True,
                blank=True,
                related_name='validated_measurements'
            ),
        ),
        migrations.AddField(
            model_name='measurement',
            name='pixel_spacing',
            field=models.JSONField(default=list, help_text="Pixel spacing at time of measurement"),
        ),
        migrations.AddField(
            model_name='measurement',
            name='slice_thickness',
            field=models.FloatField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='measurement',
            name='window_level',
            field=models.FloatField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='measurement',
            name='window_width',
            field=models.FloatField(null=True, blank=True),
        ),
        migrations.AddField(
            model_name='measurement',
            name='version',
            field=models.PositiveIntegerField(default=1),
        ),
        migrations.AddField(
            model_name='measurement',
            name='previous_version',
            field=models.ForeignKey(
                'dicom_viewer.Measurement',
                on_delete=models.SET_NULL,
                null=True,
                blank=True
            ),
        ),
    ]