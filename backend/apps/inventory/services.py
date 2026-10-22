"""
Point d'entrée UNIQUE pour modifier une quantité de stock.

Toute variation (vente, récolte, saisie manuelle, correction, assistant IA) passe par ``change_stock`` :
la quantité de l'article et le journal des mouvements sont mis à jour ensemble, dans la transaction appelante,
avec le motif de la variation. Aucune erreur n'est avalée : si l'écriture échoue, l'opération entière échoue.
"""
from django.db import transaction

from .models import StockItem, StockMovement

# Seuil historique de l'application : en dessous (ou égal), l'article est signalé comme bas
LOW_STOCK_THRESHOLD = 5


def _movement_type(reason, delta):
    if reason == 'correction':
        return 'adjustment'
    return 'in' if delta > 0 else 'out'


@transaction.atomic
def record_quantity_change(stock_item, old_quantity, *, reason, note='', sale=None):
    """
    Journalise l'écart entre ``old_quantity`` et la quantité actuelle de ``stock_item`` (déjà enregistrée) et
    recalcule son état d'alerte. Renvoie le ``StockMovement``, ou ``None`` si la quantité n'a pas changé.
    """
    delta = round(float(stock_item.quantity) - round(float(old_quantity), 2), 2)
    low = stock_item.quantity <= LOW_STOCK_THRESHOLD
    if stock_item.alert_status != low:
        stock_item.alert_status = low
        stock_item.save(update_fields=['alert_status', 'updated_at'])
    if delta == 0:
        return None
    return StockMovement.objects.create(
        user=stock_item.user,
        stock_item=stock_item,
        product_name=stock_item.name,
        movement_type=_movement_type(reason, delta),
        quantity=abs(delta),
        unit=stock_item.unit,
        balance_after=stock_item.quantity,
        reason=reason,
        note=note[:255],
        sale=sale,
    )


@transaction.atomic
def change_stock(stock_item, new_quantity, *, reason, note='', sale=None):
    """
    Fixe ``stock_item.quantity`` à ``new_quantity`` (jamais négative) et journalise l'écart.

    Renvoie le ``StockMovement`` créé, ou ``None`` si la quantité n'a pas changé.
    """
    old_quantity = stock_item.quantity
    stock_item.quantity = round(max(0.0, float(new_quantity)), 2)
    stock_item.save(update_fields=['quantity', 'updated_at'])
    return record_quantity_change(stock_item, old_quantity, reason=reason, note=note, sale=sale)


@transaction.atomic
def create_stock_item(user, name, quantity, unit, *, reason, note='', **extra):
    """Crée un article de stock et ouvre son journal avec le mouvement d'entrée correspondant."""
    quantity = round(max(0.0, float(quantity)), 2)
    item = StockItem.objects.create(
        user=user, name=name, quantity=quantity, unit=unit,
        alert_status=quantity <= LOW_STOCK_THRESHOLD, **extra,
    )
    if quantity > 0:
        StockMovement.objects.create(
            user=user, stock_item=item, product_name=item.name, movement_type='in', quantity=quantity,
            unit=item.unit, balance_after=quantity, reason=reason, note=note[:255],
        )
    return item


@transaction.atomic
def remove_stock_item(stock_item):
    """Supprime un article en conservant la trace de sa sortie dans le journal."""
    if stock_item.quantity > 0:
        StockMovement.objects.create(
            user=stock_item.user, stock_item=stock_item, product_name=stock_item.name, movement_type='out',
            quantity=stock_item.quantity, unit=stock_item.unit, balance_after=0.0, reason='removed',
            note="Article supprimé du stock",
        )
    stock_item.delete()
