"""
Une vente touche le stock du produit VENDU, pas celui d'une culture au nom voisin.
Cas réel : stock « Arachide » (800 kg) et stock « Arachide 73-33 » (200 kg), culture « Arachide 73-33 » de type Arachide.
"""
import datetime

from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

from apps.agriculture.models import Crop
from apps.finances.models import Sale
from apps.inventory.models import StockItem
from apps.inventory.services import create_stock_item


class SaleStockChoiceTests(APITestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username='vendeur', password='x')
        self.client.force_authenticate(self.user)
        today = datetime.date.today()
        Crop.objects.create(user=self.user, name='Arachide 73-33', crop_type='Arachide', planting_date=today,
                            expected_harvest_date=today, area_size=1, location='Thiès')
        create_stock_item(self.user, 'Arachide', 800, 'kg', reason='manual')
        create_stock_item(self.user, 'Arachide 73-33', 200, 'kg', reason='manual')

    def sell(self, name, quantity, price=400):
        today = datetime.date.today().isoformat()
        return self.client.post('/api/finances/sales/', {
            'product_name': name, 'quantity': quantity, 'quantity_sold': quantity, 'unit_price': price,
            'price_per_unit': price, 'date': today, 'sale_date': today,
        }, format='json')

    def quantity(self, name):
        return StockItem.objects.get(user=self.user, name=name).quantity

    def test_selling_more_than_the_neighbour_stock_but_less_than_the_chosen_one_works(self):
        response = self.sell('Arachide', 300)
        self.assertEqual(response.status_code, 201, response.content)
        self.assertEqual(self.quantity('Arachide'), 500)
        self.assertEqual(self.quantity('Arachide 73-33'), 200)

    def test_overselling_the_chosen_stock_is_still_refused_with_its_own_name(self):
        response = self.sell('Arachide', 900)
        self.assertEqual(response.status_code, 400)
        self.assertIn('800', str(response.data))
        self.assertEqual(self.quantity('Arachide'), 800)

    def test_deleting_the_sale_gives_the_quantity_back_to_the_same_stock(self):
        sale_id = self.sell('Arachide', 300).data['id']
        self.assertEqual(self.client.delete(f'/api/finances/sales/{sale_id}/').status_code, 204)
        self.assertEqual(self.quantity('Arachide'), 800)
        self.assertEqual(self.quantity('Arachide 73-33'), 200)
        self.assertFalse(Sale.objects.filter(pk=sale_id).exists())

    def test_the_crop_stock_is_used_when_the_product_has_no_stock_of_its_own(self):
        response = self.sell('Arachide 73-33', 50)
        self.assertEqual(response.status_code, 201, response.content)
        self.assertEqual(self.quantity('Arachide 73-33'), 150)
        self.assertEqual(self.quantity('Arachide'), 800)
