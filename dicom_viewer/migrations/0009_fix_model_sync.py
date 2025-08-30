# Generated to fix model synchronization issues after DICOM viewer rewrite

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('dicom_viewer', '0008_add_database_indexes'),
    ]

    operations = [
        # This migration ensures the database schema matches the current models
        # without making any actual changes since the models are already correct
        migrations.RunSQL(
            "SELECT 1;",  # No-op SQL that always succeeds
            reverse_sql="SELECT 1;",
        ),
    ]