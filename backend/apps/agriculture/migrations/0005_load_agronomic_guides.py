from django.db import migrations

from apps.agriculture.guides_loader import load_guides


def load_initial_guides(apps, schema_editor):
    load_guides(apps.get_model('agriculture', 'AgronomicGuide'))


class Migration(migrations.Migration):
    """Charge les fiches agronomiques du dépôt ; relancer `load_agronomic_guides` pour les mettre à jour."""

    dependencies = [
        ('agriculture', '0004_agronomicguide'),
    ]

    operations = [
        # Aucune action au retour arrière : les fiches sont rechargeables à tout moment
        migrations.RunPython(load_initial_guides, migrations.RunPython.noop),
    ]
