from django.core.management.base import BaseCommand

from apps.notifications.services import deliver_due_reminders


class Command(BaseCommand):
    help = (
        "Délivre les rappels et alertes programmés arrivés à échéance (et envoie le push Firebase si disponible). "
        "À planifier toutes les minutes (voir le service « scheduler » de docker-compose.yml)."
    )

    def handle(self, *args, **options):
        count = deliver_due_reminders()
        self.stdout.write(self.style.SUCCESS(f"{count} rappel(s) programmé(s) délivré(s)."))
