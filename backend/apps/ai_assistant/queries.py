"""
Consultations en lecture seule dont la réponse vient directement de la base, sans modèle de langage :
historique des mouvements de stock et liste des rappels à venir.

Un chiffre ou une date affichés ici sont donc toujours ceux des enregistrements de l'utilisateur.
"""
import re

from django.utils import timezone

RE_STOCK_HISTORY = re.compile(
    r"(?:historique|mouvements?)\s+(?:de\s+|du\s+|des\s+|d['’]\s*)?(?:mon\s+|ma\s+|mes\s+|le\s+|les\s+)?stocks?"
    r"(?:\s+(?:de|du|des|d['’])\s*(.+))?",
    re.IGNORECASE,
)
RE_STOCK_FLOW = re.compile(
    r"(?:qu['’]est[- ]ce\s+qui\s+est\s+(?:entr[ée]|sorti)|d['’]o[uù]\s+vient)\s+(?:dans\s+|du\s+|de\s+)?(?:mon\s+)?stock",
    re.IGNORECASE,
)
RE_LIST_REMINDERS = re.compile(
    r"\bmes\s+(?:rappels|alertes)\b"
    r"|\b(?:liste|affiche|montre|consulte|vois|voir)\b.*\b(?:rappels?|alertes?)\b"
    r"|\bquels?\b.*\b(?:rappels?|alertes?)\b",
    re.IGNORECASE,
)

HISTORY_LIMIT = 8
_SIGN = {'in': '+', 'out': '−'}


def detect_query_intent(text):
    """``{'type': 'stock_history', 'product': str | None}``, ``{'type': 'list_reminders'}`` ou ``None``."""
    match = RE_STOCK_HISTORY.search(text)
    if match:
        product = (match.group(1) or '').strip(" .?!")
        return {'type': 'stock_history', 'product': product or None}
    if RE_STOCK_FLOW.search(text):
        return {'type': 'stock_history', 'product': None}
    if RE_LIST_REMINDERS.search(text):
        return {'type': 'list_reminders'}
    return None


def _stock_history(user, product):
    from apps.inventory.models import StockMovement
    movements = StockMovement.objects.filter(user=user)
    if product:
        movements = movements.filter(product_name__icontains=product)
    movements = list(movements.order_by('-created_at')[:HISTORY_LIMIT])

    subject = f" de « {product} »" if product else ""
    if not movements:
        return {
            'text': f"Aucun mouvement de stock enregistré{subject}.",
            'suggestions': ['Vérifier mon stock', 'Analyse mes revenus'],
            'data': [],
        }
    lines = [f"📦 **Derniers mouvements de stock{subject}** :", ""]
    for m in movements:
        when = timezone.localtime(m.created_at).strftime("%d/%m")
        if m.movement_type == 'adjustment':
            change = f"Correction (écart de {m.quantity:g} {m.unit})"
        else:
            change = f"{_SIGN[m.movement_type]}{m.quantity:g} {m.unit}"
        lines.append(f"• {when} — {m.product_name} : {change} ({m.get_reason_display().lower()}) → solde {m.balance_after:g} {m.unit}")
    return {
        'text': "\n".join(lines),
        'suggestions': ['Vérifier mon stock', 'Analyse mes revenus'],
        'data': [str(m.pk) for m in movements],
    }


def _list_reminders(user):
    from apps.notifications.services import pending_reminders
    reminders = list(pending_reminders(user)[:10])
    if not reminders:
        return {
            'text': "Vous n'avez aucun rappel à venir. Dites par exemple « Rappelle-moi d'arroser demain à 7h ».",
            'suggestions': ["Rappelle-moi d'arroser demain à 7h"],
            'data': [],
        }
    lines = ["⏰ **Vos rappels à venir** :", ""]
    for index, reminder in enumerate(reminders, 1):
        when = timezone.localtime(reminder.scheduled_for).strftime("%d/%m/%Y à %H:%M")
        lines.append(f"{index}. {reminder.message} — {when}")
    return {
        'text': "\n".join(lines),
        'suggestions': ["Annule mon rappel", "Décale mon rappel à demain"],
        'data': [str(r.pk) for r in reminders],
    }


def answer_query(user, intent):
    """Réponse ``{'text', 'suggestions', 'data'}`` à une consultation reconnue par ``detect_query_intent``."""
    if intent['type'] == 'stock_history':
        return _stock_history(user, intent.get('product'))
    return _list_reminders(user)
