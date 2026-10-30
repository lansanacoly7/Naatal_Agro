from django.core.management.base import BaseCommand

from apps.agriculture.crop_calendar_loader import load_crop_calendar
from apps.agriculture.models import CropCalendarEntry


class Command(BaseCommand):
    help = 'Charge ou met à jour le calendrier agricole depuis le fichier du dépôt (les corrections faites à la main sont gardées).'

    def add_arguments(self, parser):
        parser.add_argument('--force', action='store_true', help='Écrase aussi les périodes corrigées à la main.')

    def handle(self, *args, **options):
        created, updated, skipped = load_crop_calendar(CropCalendarEntry, force=options['force'])
        self.stdout.write(self.style.SUCCESS(f'Calendrier agricole : {created} créées, {updated} mises à jour, {skipped} corrigées à la main (gardées).'))
