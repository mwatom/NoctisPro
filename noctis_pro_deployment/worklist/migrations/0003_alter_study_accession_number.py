from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('worklist', '0002_alter_studyattachment_options_and_more'),
    ]

    operations = [
        migrations.AlterField(
            model_name='study',
            name='accession_number',
            field=models.CharField(max_length=50, db_index=True),
        ),
    ]