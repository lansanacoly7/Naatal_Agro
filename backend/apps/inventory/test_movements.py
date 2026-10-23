"""Journal des mouvements de stock : chaque variation est tracée, avec son motif, sur tous les chemins d'écriture."""
import datetime
import importlib
from unittest.mock import patch

from django.apps import apps as django_apps
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from apps.agriculture.models import Crop
from apps.finances.models import Sale
from apps.inventory.models import StockItem, StockMovement
from apps.inventory.services import change_stock, create_stock_item, record_quantity_change

User = get_user_model()


def results(response):
    data = response.json()
    return data['results'] if isinstance(data, dict) and 'results' in data else data


@patch('apps.inventory.views.schedule_storage_advice')
class StockMovementApiTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='mv1', phone='+221770400001', password='Motdepasse#2026')
        self.other = User.objects.create_user(username='mv2', phone='+221770400002', password='Motdepasse#2026')
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def movements(self, **filters):
        return list(StockMovement.objects.filter(user=self.user, **filters).order_by('created_at', 'id'))

    def test_creating_an_item_opens_its_journal(self, _llm):
        response = self.client.post('/api/inventory/', {'name': 'Mil', 'quantity': 50, 'unit': 'kg'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        (movement,) = self.movements()
        self.assertEqual((movement.movement_type, movement.reason, movement.quantity, movement.balance_after),
                         ('in', 'manual', 50.0, 50.0))

    def test_empty_item_has_no_movement(self, _llm):
        self.client.post('/api/inventory/', {'name': 'Mil', 'quantity': 0, 'unit': 'kg'}, format='json')
        self.assertEqual(self.movements(), [])

    def test_editing_the_quantity_is_logged_as_a_correction(self, _llm):
        item = create_stock_item(self.user, 'Mil', 50, 'kg', reason='manual')
        response = self.client.patch(f'/api/inventory/{item.id}/', {'quantity': 42}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        correction = self.movements(reason='correction')[0]
        self.assertEqual((correction.movement_type, correction.quantity, correction.balance_after),
                         ('adjustment', 8.0, 42.0))

    def test_renaming_without_quantity_change_logs_nothing(self, _llm):
        item = create_stock_item(self.user, 'Mil', 50, 'kg', reason='manual')
        self.client.patch(f'/api/inventory/{item.id}/', {'name': 'Mil local'}, format='json')
        self.assertEqual(len(self.movements()), 1)

    def test_deleting_an_item_keeps_a_trace(self, _llm):
        item = create_stock_item(self.user, 'Mil', 50, 'kg', reason='manual')
        self.assertEqual(self.client.delete(f'/api/inventory/{item.id}/').status_code, status.HTTP_204_NO_CONTENT)
        removed = self.movements(reason='removed')
        self.assertEqual(len(removed), 1)
        self.assertEqual((removed[0].movement_type, removed[0].quantity, removed[0].balance_after), ('out', 50.0, 0.0))
        self.assertIsNone(removed[0].stock_item)
        self.assertEqual(removed[0].product_name, 'Mil')

    def test_sale_and_its_reversal_are_logged_and_linked(self, _llm):
        create_stock_item(self.user, 'Riz', 100, 'sacs', reason='manual')
        response = self.client.post('/api/finances/sales/', {
            'product_name': 'Riz', 'quantity_sold': 30, 'price_per_unit': 12000, 'date': '2026-10-20',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        sale = Sale.objects.get()
        out = self.movements(reason='sale')[0]
        self.assertEqual((out.movement_type, out.quantity, out.balance_after, out.sale), ('out', 30.0, 70.0, sale))

        self.assertEqual(self.client.delete(f'/api/finances/sales/{sale.id}/').status_code, status.HTTP_204_NO_CONTENT)
        back = self.movements(reason='sale_reversal')[0]
        self.assertEqual((back.movement_type, back.quantity, back.balance_after), ('in', 30.0, 100.0))
        self.assertEqual(StockItem.objects.get().quantity, 100.0)

    def test_harvest_is_logged(self, _llm):
        today = datetime.date.today()
        crop = Crop.objects.create(user=self.user, name='Mil', crop_type='Céréale', planting_date=today,
                                   expected_harvest_date=today, area_size=1.0, location='Thiès')
        response = self.client.post(f'/api/agriculture/crops/{crop.id}/harvest/', {'quantity': 120, 'unit': 'kg'},
                                    format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        (movement,) = self.movements(reason='harvest')
        self.assertEqual((movement.movement_type, movement.quantity, movement.balance_after), ('in', 120.0, 120.0))

    def test_journal_balance_always_matches_the_item(self, _llm):
        item = create_stock_item(self.user, 'Mil', 50, 'kg', reason='manual')
        change_stock(item, 80, reason='purchase')
        change_stock(item, 65, reason='sale')
        change_stock(item, 70, reason='correction')
        last = StockMovement.objects.filter(stock_item=item).order_by('created_at', 'id').last()
        self.assertEqual(last.balance_after, StockItem.objects.get(pk=item.pk).quantity)

    def test_low_stock_flag_follows_the_quantity(self, _llm):
        item = create_stock_item(self.user, 'Mil', 50, 'kg', reason='manual')
        self.assertFalse(item.alert_status)
        change_stock(item, 4, reason='sale')
        item.refresh_from_db()
        self.assertTrue(item.alert_status)
        change_stock(item, 30, reason='purchase')
        item.refresh_from_db()
        self.assertFalse(item.alert_status)

    def test_stock_never_goes_negative(self, _llm):
        item = create_stock_item(self.user, 'Mil', 5, 'kg', reason='manual')
        movement = change_stock(item, -10, reason='sale')
        item.refresh_from_db()
        self.assertEqual(item.quantity, 0.0)
        self.assertEqual(movement.quantity, 5.0)

    def test_unchanged_quantity_logs_nothing(self, _llm):
        item = create_stock_item(self.user, 'Mil', 5, 'kg', reason='manual')
        self.assertIsNone(change_stock(item, 5, reason='correction'))
        self.assertIsNone(record_quantity_change(item, 5, reason='correction'))
        self.assertEqual(StockMovement.objects.count(), 1)

    # --- API de consultation ------------------------------------------------------------------------------------
    def test_movements_endpoint_is_isolated_filterable_and_read_only(self, _llm):
        create_stock_item(self.user, 'Mil', 50, 'kg', reason='manual')
        create_stock_item(self.user, 'Riz', 10, 'sacs', reason='manual')
        create_stock_item(self.other, 'Mil', 999, 'kg', reason='manual')

        all_rows = results(self.client.get('/api/inventory/movements/'))
        self.assertEqual({r['product_name'] for r in all_rows}, {'Mil', 'Riz'})
        self.assertNotIn(999.0, [r['quantity'] for r in all_rows])

        only_rice = results(self.client.get('/api/inventory/movements/?product=riz'))
        self.assertEqual([r['product_name'] for r in only_rice], ['Riz'])
        self.assertTrue(only_rice[0]['reason_label'])

        foreign = StockMovement.objects.get(user=self.other)
        self.assertEqual(self.client.get(f'/api/inventory/movements/{foreign.id}/').status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(self.client.post('/api/inventory/movements/', {}, format='json').status_code,
                         status.HTTP_405_METHOD_NOT_ALLOWED)
        self.assertEqual(APIClient().get('/api/inventory/movements/').status_code, status.HTTP_401_UNAUTHORIZED)


class InitialSnapshotMigrationTests(TestCase):
    def test_existing_stock_gets_an_opening_movement_once(self):
        user = User.objects.create_user(username='mg1', phone='+221770400003', password='Motdepasse#2026')
        full = StockItem.objects.create(user=user, name='Mil', quantity=40, unit='kg')
        StockItem.objects.create(user=user, name='Vide', quantity=0, unit='kg')
        migration = importlib.import_module('apps.inventory.migrations.0004_initial_stock_snapshot')

        migration.snapshot_existing_stock(django_apps, None)
        migration.snapshot_existing_stock(django_apps, None)  # rejouer ne doit rien dupliquer

        (opening,) = StockMovement.objects.all()
        self.assertEqual((opening.stock_item_id, opening.reason, opening.balance_after), (full.pk, 'initial', 40.0))
