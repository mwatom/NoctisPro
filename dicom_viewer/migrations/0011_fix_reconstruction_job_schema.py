# Fix ReconstructionJob schema mismatch

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('worklist', '0002_alter_studyattachment_options_and_more'),
        ('dicom_viewer', '0010_ensure_model_sync'),
    ]

    operations = [
        # Add study field to ReconstructionJob if it doesn't exist
        migrations.RunSQL(
            """
            -- Check if study_id column exists, if not add it
            SELECT CASE 
                WHEN COUNT(*) = 0 THEN 
                    'ALTER TABLE dicom_viewer_reconstructionjob ADD COLUMN study_id bigint REFERENCES worklist_study(id) DEFERRABLE INITIALLY DEFERRED'
                ELSE 
                    'SELECT 1' 
            END as sql_to_run
            FROM pragma_table_info('dicom_viewer_reconstructionjob') 
            WHERE name = 'study_id';
            """,
            reverse_sql="-- Cannot reverse schema fix"
        ),
        
        # Create index on study_id if it doesn't exist
        migrations.RunSQL(
            """
            CREATE INDEX IF NOT EXISTS dicom_viewer_reconstructionjob_study_id_idx 
            ON dicom_viewer_reconstructionjob(study_id);
            """,
            reverse_sql="DROP INDEX IF EXISTS dicom_viewer_reconstructionjob_study_id_idx;"
        ),
    ]