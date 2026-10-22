"""
Cycle de vie des rappels : création programmée, livraison à l'échéance, annulation, report.

La livraison est idempotente : le passage « programmé -> délivré » est un compare-and-set
(``UPDATE … WHERE is_sent = FALSE``), de sorte qu'un rappel n'est jamais délivré (ni poussé) deux fois,
même si le planificateur et une consultation de l'utilisateur le traitent en même temps.
"""
import logging

from django.db import transaction
from django.utils import timezone

from .firebase_service import send_push_notification
from .models import Notification

logger = logging.getLogger(__name__)


def pending_reminders(user):
    """Rappels de l'utilisateur encore à venir (ni délivrés ni annulés), du plus proche au plus lointain."""
    return Notification.objects.filter(
        user=user, type='reminder', is_sent=False, cancelled_at__isnull=True, scheduled_for__isnull=False,
    ).order_by('scheduled_for')


def deliver_due_reminders(user=None, now=None):
    """
    Délivre les notifications programmées arrivées à échéance (toutes, ou celles d'un utilisateur).
    Renvoie le nombre de notifications délivrées par CET appel.
    """
    now = now or timezone.now()
    due = Notification.objects.filter(scheduled_for__lte=now, is_sent=False, cancelled_at__isnull=True)
    if user is not None:
        due = due.filter(user=user)

    delivered = 0
    for notification in due.select_related('user'):
        claimed = Notification.objects.filter(
            pk=notification.pk, is_sent=False, cancelled_at__isnull=True,
        ).update(is_sent=True, sent_at=now)
        if not claimed:
            continue  # un autre traitement l'a délivrée entre-temps
        delivered += 1
        token = notification.user.fcm_token
        if token:
            send_push_notification(
                fcm_token=token,
                title=f"Rappel Naatal IA : {notification.type.capitalize()}",
                body=notification.message,
                data={'notification_id': str(notification.pk), 'type': notification.type},
            )
    return delivered


@transaction.atomic
def cancel_reminder(notification, now=None):
    """Annule un rappel à venir. Renvoie ``False`` s'il est déjà délivré ou annulé."""
    now = now or timezone.now()
    return Notification.objects.filter(
        pk=notification.pk, user=notification.user, type='reminder', is_sent=False, cancelled_at__isnull=True,
    ).update(cancelled_at=now) == 1


@transaction.atomic
def reschedule_reminder(notification, new_time, now=None):
    """Déplace un rappel à venir. Renvoie ``False`` s'il n'est plus modifiable ou si ``new_time`` est passé."""
    now = now or timezone.now()
    if new_time < now:
        return False
    return Notification.objects.filter(
        pk=notification.pk, user=notification.user, type='reminder', is_sent=False, cancelled_at__isnull=True,
    ).update(scheduled_for=new_time) == 1
