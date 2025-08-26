from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='facility',
            name='ae_title',
            field=models.CharField(default='', max_length=32, blank=True),
        ),
    ]