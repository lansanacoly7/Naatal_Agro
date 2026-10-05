from django.core.management.base import BaseCommand

from apps.agriculture.guides_loader import load_guides
from apps.agriculture.models import AgronomicGuide


class Command(BaseCommand):
    help = "Charge ou met à jour les fiches agronomiques depuis apps/agriculture/data/agronomic_guides.json."

    def add_arguments(self, parser):
        parser.add_argument(
            '--force', action='store_true',
            help="Écrase aussi les fiches modifiées depuis l'administration (informations validées comprises).")

    def handle(self, *args, **options):
        processed, skipped = load_guides(AgronomicGuide, force=options['force'])
        self.stdout.write(self.style.SUCCESS(f'{processed} fiche(s) agronomique(s) chargée(s).'))
        if skipped:
            self.stdout.write(self.style.WARNING(
                f"{skipped} fiche(s) modifiée(s) depuis l'administration conservée(s) telles quelles (utiliser --force pour les écraser)."))
