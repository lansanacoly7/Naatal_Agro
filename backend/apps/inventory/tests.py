from unittest.mock import patch
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from apps.inventory.models import StockItem

User = get_user_model()


class InventoryTests(TestCase):
    def setUp(self):
        self.ali = User.objects.create_user(username='+221770200001', phone='+221770200001', password='Motdepasse#2026')
        self.binta = User.objects.create_user(username='+221770200002', phone='+221770200002', password='Motdepasse#2026')
        self.client = APIClient()
        self.client.force_authenticate(self.ali)
        self.payload = {'name': 'Arachide', 'quantity': 50, 'unit': 'kg'}

    def test_requires_authentication(self):
        self.assertEqual(APIClient().get('/api/inventory/').status_code, status.HTTP_401_UNAUTHORIZED)

    @patch('apps.inventory.views.call_llm', return_value='Stockez au sec.')
    def test_create_stores_ai_advice(self, _llm):
        response = self.client.post('/api/inventory/', self.payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        item = StockItem.objects.get()
        self.assertEqual(item.user, self.ali)
        self.assertEqual(item.ai_storage_advice, 'Stockez au sec.')

    @patch('apps.inventory.views.call_llm', return_value=None)
    def test_create_works_when_ai_is_unavailable(self, _llm):
        response = self.client.post('/api/inventory/', self.payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertFalse(StockItem.objects.get().ai_storage_advice)

    @patch('apps.inventory.views.call_llm', return_value=None)
    def test_ai_fields_are_read_only(self, _llm):
        payload = {**self.payload, 'alert_status': True, 'ai_storage_advice': 'piraté'}
        response = self.client.post('/api/inventory/', payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        item = StockItem.objects.get()
        self.assertFalse(item.alert_status)
        self.assertFalse(item.ai_storage_advice)

    def test_list_and_detail_are_isolated(self):
        mine = StockItem.objects.create(user=self.ali, name='Mil', quantity=1, unit='kg')
        theirs = StockItem.objects.create(user=self.binta, name='Riz', quantity=1, unit='kg')
        names = [i['name'] for i in self.client.get('/api/inventory/').json()]
        self.assertEqual(names, ['Mil'])
        self.assertEqual(self.client.get(f'/api/inventory/{mine.id}/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.get(f'/api/inventory/{theirs.id}/').status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(self.client.delete(f'/api/inventory/{theirs.id}/').status_code, status.HTTP_404_NOT_FOUND)
