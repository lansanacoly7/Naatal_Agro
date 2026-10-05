import json

from django.core.management.base import BaseCommand

from apps.agriculture.guides_loader import GUIDES_FILE, GUIDE_FIELDS
from apps.agriculture.models import AgronomicGuide


class Command(BaseCommand):
    help = (
        "Écrit les fiches de la base dans apps/agriculture/data/agronomic_guides.json, pour versionner dans le dépôt "
        "les informations approuvées depuis l'administration."
    )

    def handle(self, *args, **options):
        guides = []
        for guide in AgronomicGuide.objects.order_by('name'):
            data = {'slug': guide.slug}
            data.update({field: getattr(guide, field) for field in GUIDE_FIELDS})
            guides.append(data)
        GUIDES_FILE.write_text(json.dumps(guides, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        self.stdout.write(self.style.SUCCESS(f'{len(guides)} fiche(s) exportée(s) vers {GUIDES_FILE.name}.'))
