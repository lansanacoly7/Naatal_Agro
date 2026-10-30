"""Opérations sur les ventes partagées par l'API et par l'assistant."""
from django.db import transaction as db_transaction


def delete_sale(sale, user):
    """
    Supprime une vente et rend la quantité au stock d'où elle est sortie (journalisé), en une seule transaction.
    L'article restitué est celui que le journal des mouvements a débité ; à défaut, celui du produit vendu.
    """
    from apps.inventory.models import StockMovement
    from apps.inventory.services import change_stock, stock_for_sale

    with db_transaction.atomic():
        movement = StockMovement.objects.filter(sale=sale).select_related('stock_item').first()
        stock_item = movement.stock_item if movement and movement.stock_item else stock_for_sale(
            user, sale.product_name, sale.crop.name if sale.crop else '')
        if stock_item:
            change_stock(
                stock_item, stock_item.quantity + float(sale.quantity_sold),
                reason='sale_reversal', note=f"Annulation de la vente du {sale.date}",
            )
        sale.delete()
