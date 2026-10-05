from datetime import date
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from apps.agriculture.models import Crop
from apps.finances.models import Sale, Transaction

User = get_user_model()


def make_user(phone):
    return User.objects.create_user(username=phone, phone=phone, password='Motdepasse#2026', first_name='Test')


def make_crop(user, name='Mil'):
    return Crop.objects.create(
        user=user, name=name, crop_type=name, planting_date='2026-06-01',
        expected_harvest_date='2026-10-01', area_size=2.0, location='Thiès',
    )


class FinancesTests(TestCase):
    def setUp(self):
        self.ali = make_user('+221770100001')
        self.binta = make_user('+221770100002')
        self.client = APIClient()
        self.client.force_authenticate(self.ali)

    def test_endpoints_require_authentication(self):
        anonymous = APIClient()
        self.assertEqual(anonymous.get('/api/finances/summary/').status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertEqual(anonymous.get('/api/finances/transactions/').status_code, status.HTTP_401_UNAUTHORIZED)

    def test_summary_combines_sales_and_transactions(self):
        crop = make_crop(self.ali)
        Sale.objects.create(crop=crop, quantity_sold=100, price_per_unit=500, date=date.today())  # 50 000
        Transaction.objects.create(user=self.ali, transaction_type='income', amount=10000, date=date.today(), description='Aide')
        Transaction.objects.create(user=self.ali, transaction_type='expense', amount=15000, date=date.today(), description='Engrais')

        data = self.client.get('/api/finances/summary/').json()
        self.assertEqual(data['total_revenue'], 60000)
        self.assertEqual(data['total_expenses'], 15000)
        self.assertEqual(data['balance'], 45000)

    def test_summary_ignores_other_users_data(self):
        Transaction.objects.create(user=self.binta, transaction_type='income', amount=999999, date=date.today(), description='Secret')
        Sale.objects.create(crop=make_crop(self.binta), quantity_sold=10, price_per_unit=10, date=date.today())
        data = self.client.get('/api/finances/summary/').json()
        self.assertEqual(data['total_revenue'], 0)
        self.assertEqual(data['balance'], 0)

    def test_transaction_is_attached_to_current_user(self):
        response = self.client.post('/api/finances/transactions/', {
            'transaction_type': 'expense', 'amount': '2500.00', 'date': '2026-10-01', 'description': 'Semences',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Transaction.objects.get().user, self.ali)

    def test_cannot_read_or_delete_foreign_transaction(self):
        foreign = Transaction.objects.create(user=self.binta, transaction_type='income', amount=1, date=date.today(), description='x')
        self.assertEqual(self.client.get(f'/api/finances/transactions/{foreign.id}/').status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(self.client.delete(f'/api/finances/transactions/{foreign.id}/').status_code, status.HTTP_404_NOT_FOUND)
        self.assertTrue(Transaction.objects.filter(id=foreign.id).exists())

    def test_cannot_create_sale_on_foreign_crop(self):
        response = self.client.post('/api/finances/sales/', {
            'crop': str(make_crop(self.binta).id), 'quantity_sold': 5, 'price_per_unit': '100.00', 'date': '2026-10-01',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(Sale.objects.count(), 0)

    def test_can_create_sale_on_own_crop(self):
        response = self.client.post('/api/finances/sales/', {
            'crop': str(make_crop(self.ali).id), 'quantity_sold': 5, 'price_per_unit': '100.00', 'date': '2026-10-01',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.json()['total_revenue'], 500)
