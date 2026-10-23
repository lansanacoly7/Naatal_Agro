from django.core.management.base import BaseCommand

from apps.inventory.advice import generate_storage_advice, items_awaiting_advice


class Command(BaseCommand):
    help = (
        "Génère le conseil de stockage des articles restés sans conseil (serveur arrêté avant la fin du thread, IA "
        "indisponible à ce moment-là). Espace les tentatives de 30 min et abandonne après 3 jours. "
        "À planifier avec les rappels (voir le service « scheduler » de docker-compose.yml)."
    )

    def add_arguments(self, parser):
        parser.add_argument('--limit', type=int, default=3, help="Nombre maximal d'articles traités par exécution (3 par défaut)")

    def handle(self, *args, **options):
        items = list(items_awaiting_advice()[:max(1, options['limit'])])
        generated = sum(1 for item in items if generate_storage_advice(item.pk))
        self.stdout.write(self.style.SUCCESS(f"{generated}/{len(items)} conseil(s) de stockage généré(s)."))
