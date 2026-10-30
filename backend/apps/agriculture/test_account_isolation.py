"""Étanchéité des comptes : un compte ne voit, ne modifie et ne supprime jamais les données d'un autre compte."""
import datetime

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient, APITestCase

from apps.agriculture.models import Crop
from apps.finances.models import Sale, Transaction
from apps.inventory.services import create_stock_item
from apps.notifications.models import Notification


class AccountIsolationTests(APITestCase):
    def setUp(self):
        User = get_user_model()
        self.alice = User.objects.create_user(username='alice', password='x')
        self.bob = User.objects.create_user(username='bob', password='x')
        today = datetime.date.today()
        self.crop = Crop.objects.create(user=self.alice, name='Yèbè', crop_type='Yèbè', planting_date=today,
                                        expected_harvest_date=today, area_size=1, location='Thiès')
        create_stock_item(self.alice, 'Mil', 50, 'sac', reason='manual')
        Transaction.objects.create(user=self.alice, transaction_type='expense', amount=1000, date=today, description='Engrais')
        Notification.objects.create(user=self.alice, type='reminder', message='Arroser')
        self.sale = Sale.objects.create(user=self.alice, product_name='Mil', quantity_sold=1, price_per_unit=100, date=today)
        self.bob_client = APIClient()
        self.bob_client.force_authenticate(self.bob)

    def results(self, response):
        data = response.data
        return data['results'] if isinstance(data, dict) and 'results' in data else data

    def test_a_new_account_starts_completely_empty(self):
        for url in ('/api/agriculture/crops/', '/api/inventory/', '/api/finances/sales/', '/api/finances/transactions/',
                    '/api/notifications/', '/api/ai/conversations/'):
            response = self.bob_client.get(url)
            self.assertEqual(response.status_code, 200, url)
            self.assertEqual(len(self.results(response)), 0, f"{url} montre des données d'un autre compte")

    def test_the_finance_summary_of_a_new_account_is_zero(self):
        response = self.bob_client.get('/api/finances/summary/')
        self.assertEqual(response.status_code, 200)
        self.assertFalse(any(float(v or 0) for k, v in response.data.items() if k.startswith('total')), response.data)

    def test_another_accounts_records_cannot_be_read_changed_or_deleted(self):
        urls = [f'/api/agriculture/crops/{self.crop.id}/', f'/api/finances/sales/{self.sale.id}/']
        for url in urls:
            self.assertEqual(self.bob_client.get(url).status_code, 404, url)
            self.assertEqual(self.bob_client.patch(url, {'name': 'x'}, format='json').status_code, 404, url)
            self.assertEqual(self.bob_client.delete(url).status_code, 404, url)
        self.assertTrue(Crop.objects.filter(pk=self.crop.pk).exists())
        self.assertTrue(Sale.objects.filter(pk=self.sale.pk).exists())

    def test_a_profile_never_exposes_another_accounts_crops(self):
        response = self.bob_client.get('/api/users/me/')
        self.assertEqual(response.status_code, 200)
        self.assertNotIn('Yèbè', str(response.data))
