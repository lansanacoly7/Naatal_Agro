from django.core.management.base import BaseCommand

from apps.agriculture.guides_loader import load_guides
from apps.agriculture.models import AgronomicGuide


class Command(BaseCommand):
    help = "Charge ou met à jour les fiches agronomiques depuis apps/agriculture/data/agronomic_guides.json."

    def handle(self, *args, **options):
        count = load_guides(AgronomicGuide)
        self.stdout.write(self.style.SUCCESS(f'{count} fiche(s) agronomique(s) chargée(s).'))
