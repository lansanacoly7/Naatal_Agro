from django.db import migrations

from apps.agriculture.guides_loader import load_guides


def reload_guides(apps, schema_editor):
    load_guides(apps.get_model('agriculture', 'AgronomicGuide'))


class Migration(migrations.Migration):
    """Recharge les fiches pour renseigner les alias de recherche ajoutés par la migration 0006."""

    dependencies = [
        ('agriculture', '0006_guide_aliases_and_knowledge_proposals'),
    ]

    operations = [
        migrations.RunPython(reload_guides, migrations.RunPython.noop),
    ]
