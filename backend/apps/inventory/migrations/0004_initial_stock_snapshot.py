from django.db import migrations


def snapshot_existing_stock(apps, schema_editor):
    """Ouvre le journal : un mouvement « stock initial » par article existant, pour que les soldes du journal
    correspondent aux quantités déjà en base."""
    StockItem = apps.get_model('inventory', 'StockItem')
    StockMovement = apps.get_model('inventory', 'StockMovement')
    for item in StockItem.objects.all():
        if item.quantity > 0 and not StockMovement.objects.filter(stock_item_id=item.pk).exists():
            StockMovement.objects.create(
                user_id=item.user_id,
                stock_item_id=item.pk,
                product_name=item.name,
                movement_type='in',
                quantity=item.quantity,
                unit=item.unit,
                balance_after=item.quantity,
                reason='initial',
                note="Stock existant au démarrage du journal",
            )


class Migration(migrations.Migration):

    dependencies = [
        ('inventory', '0003_phase2_data_model'),
    ]

    operations = [
        migrations.RunPython(snapshot_existing_stock, migrations.RunPython.noop),
    ]
