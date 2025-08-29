# Generated manually to add annotation fields

from django.db import migrations, models
import django.core.validators


class Migration(migrations.Migration):

    dependencies = [
        ('dicom_viewer', '0003_auto_20250829_1631'),
    ]

    operations = [
        # Add missing fields to annotation model with defaults
        migrations.AddField(
            model_name='annotation',
            name='annotation_type',
            field=models.CharField(
                max_length=20,
                choices=[
                    ("text", "Text Annotation"),
                    ("arrow", "Arrow"),
                    ("circle", "Circle"),
                    ("rectangle", "Rectangle"),
                    ("freehand", "Freehand Drawing"),
                    ("ruler", "Ruler"),
                    ("protractor", "Protractor"),
                    ("roi", "Region of Interest"),
                ],
                default="text"
            ),
        ),
        migrations.AddField(
            model_name='annotation',
            name='font_size',
            field=models.PositiveIntegerField(
                default=12,
                validators=[
                    django.core.validators.MinValueValidator(8),
                    django.core.validators.MaxValueValidator(72)
                ]
            ),
        ),
        migrations.AddField(
            model_name='annotation',
            name='opacity',
            field=models.FloatField(
                default=1.0,
                validators=[
                    django.core.validators.MinValueValidator(0.0),
                    django.core.validators.MaxValueValidator(1.0)
                ]
            ),
        ),
        migrations.AddField(
            model_name='annotation',
            name='geometry',
            field=models.JSONField(default=dict, help_text="Additional geometric data"),
        ),
        migrations.AddField(
            model_name='annotation',
            name='style',
            field=models.JSONField(default=dict, help_text="Style properties"),
        ),
        migrations.AddField(
            model_name='annotation',
            name='is_visible',
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name='annotation',
            name='is_locked',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='annotation',
            name='layer',
            field=models.IntegerField(default=0),
        ),
        migrations.AddField(
            model_name='annotation',
            name='version',
            field=models.PositiveIntegerField(default=1),
        ),
        migrations.AddField(
            model_name='annotation',
            name='updated_at',
            field=models.DateTimeField(auto_now=True),
        ),
        migrations.AddField(
            model_name='annotation',
            name='previous_version',
            field=models.ForeignKey(
                null=True,
                blank=True,
                on_delete=models.SET_NULL,
                to='dicom_viewer.annotation',
                related_name='versions'
            ),
        ),
    ]