import logging

from django.apps import AppConfig
from django.db import DatabaseError
from django.db.models.signals import post_migrate

logger = logging.getLogger(__name__)


def sync_agronomic_guides(sender, **kwargs):
    """
    Après chaque `migrate`, aligne la base sur les fiches du dépôt (idempotent). Les fiches modifiées
    depuis l'administration sont conservées. Évite de devoir écrire une migration à chaque ajout de fiche.
    """
    from .guides_loader import load_guides
    from .models import AgronomicGuide

    try:
        processed, skipped = load_guides(AgronomicGuide)
    except DatabaseError as error:
        # Migration partielle (table ou colonne pas encore créée) : la synchro se fera au prochain migrate complet
        logger.warning("Synchronisation des fiches agronomiques reportée : %s", error)
        return
    logger.info("Fiches agronomiques synchronisées : %s chargée(s), %s conservée(s).", processed, skipped)


class AgricultureConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.agriculture"

    def ready(self):
        post_migrate.connect(sync_agronomic_guides, sender=self, dispatch_uid='sync_agronomic_guides')
