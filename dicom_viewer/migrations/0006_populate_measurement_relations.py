# Generated manually to populate series and study relations

from django.db import migrations


def populate_measurement_relations(apps, schema_editor):
    """Populate series and study fields in measurements based on image relations"""
    Measurement = apps.get_model('dicom_viewer', 'Measurement')
    DicomImage = apps.get_model('worklist', 'DicomImage')
    
    for measurement in Measurement.objects.filter(series__isnull=True):
        if measurement.image_id:
            try:
                image = DicomImage.objects.get(id=measurement.image_id)
                measurement.series = image.series
                measurement.study = image.series.study if image.series else None
                measurement.save(update_fields=['series', 'study'])
            except DicomImage.DoesNotExist:
                # If image doesn't exist, we'll handle this in next migration
                pass


def reverse_populate_measurement_relations(apps, schema_editor):
    """Reverse operation - clear the populated fields"""
    Measurement = apps.get_model('dicom_viewer', 'Measurement')
    Measurement.objects.update(series=None, study=None)


class Migration(migrations.Migration):

    dependencies = [
        ('dicom_viewer', '0005_enhance_models_add_fields'),
    ]

    operations = [
        migrations.RunPython(
            populate_measurement_relations,
            reverse_populate_measurement_relations
        ),
    ]