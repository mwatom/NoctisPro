# Generated to ensure model synchronization

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('dicom_viewer', '0009_fix_model_sync'),
    ]

    operations = [
        # Run a simple SQL statement to mark migration as applied
        migrations.RunSQL(
            "-- Ensure model sync completed",
            reverse_sql="-- Reverse model sync",
        ),
    ]