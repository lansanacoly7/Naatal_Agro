from django.db import migrations

from apps.agriculture.crop_calendar_loader import load_crop_calendar


def load_initial_calendar(apps, schema_editor):
    load_crop_calendar(apps.get_model('agriculture', 'CropCalendarEntry'))


class Migration(migrations.Migration):
    """Charge le calendrier agricole du dépôt ; relancer `load_crop_calendar` pour le mettre à jour."""

    dependencies = [
        ('agriculture', '0011_crop_calendar'),
    ]

    operations = [
        migrations.RunPython(load_initial_calendar, migrations.RunPython.noop),
    ]
