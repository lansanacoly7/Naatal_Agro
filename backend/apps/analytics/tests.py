from datetime import timedelta
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from apps.agriculture.models import Activity, Crop
from apps.inventory.models import StockItem
from apps.markets.models import Product
from apps.notifications.models import Notification
from apps.weather.models import WeatherData

User = get_user_model()


class DashboardTests(TestCase):
    def setUp(self):
        self.ali = User.objects.create_user(
            username='+221770500001', phone='+221770500001', password='Motdepasse#2026', location='Thiès, Sénégal')
        self.binta = User.objects.create_user(username='+221770500002', phone='+221770500002', password='Motdepasse#2026')
        self.client = APIClient()
        self.client.force_authenticate(self.ali)

    def _crop(self, user, area, crop_status='active'):
        return Crop.objects.create(
            user=user, name='Mil', crop_type='Mil', planting_date='2026-06-01',
            expected_harvest_date='2026-10-01', area_size=area, location='Thiès', status=crop_status)

    def test_requires_authentication(self):
        self.assertEqual(APIClient().get('/api/dashboard/').status_code, status.HTTP_401_UNAUTHORIZED)

    def test_empty_dashboard_has_expected_shape(self):
        data = self.client.get('/api/dashboard/').json()
        for key in ('agriculture', 'markets', 'weather', 'alerts', 'stockItems', 'calendarEvents', 'featuredProducts'):
            self.assertIn(key, data)
        self.assertEqual(data['agriculture']['active_crops_count'], 0)
        self.assertEqual(data['agriculture']['total_area_size'], 0)

    def test_crop_counts_and_area_are_scoped_to_user(self):
        self._crop(self.ali, 2.5)
        self._crop(self.ali, 1.5, crop_status='harvested')
        self._crop(self.binta, 100)
        agriculture = self.client.get('/api/dashboard/').json()['agriculture']
        self.assertEqual(agriculture['active_crops_count'], 1)
        self.assertEqual(agriculture['total_area_size'], 4.0)

    def test_stock_and_alerts_are_scoped_to_user(self):
        StockItem.objects.create(user=self.ali, name='Mil', quantity=10, unit='kg')
        StockItem.objects.create(user=self.binta, name='Riz', quantity=10, unit='kg')
        Notification.objects.create(user=self.ali, type='alert', message='Pour Ali')
        Notification.objects.create(user=self.binta, type='alert', message='Pour Binta')
        data = self.client.get('/api/dashboard/').json()
        self.assertEqual([s['name'] for s in data['stockItems']], ['Mil'])
        self.assertEqual([a['message'] for a in data['alerts']], ['Pour Ali'])

    def test_calendar_only_lists_upcoming_activities_of_user(self):
        crop = self._crop(self.ali, 1)
        other = self._crop(self.binta, 1)
        today = timezone.now().date()
        Activity.objects.create(crop=crop, activity_type='Semis', description='', date=today + timedelta(days=2))
        Activity.objects.create(crop=crop, activity_type='Passé', description='', date=today - timedelta(days=2))
        Activity.objects.create(crop=other, activity_type='Autre', description='', date=today + timedelta(days=2))
        titles = [e['title'] for e in self.client.get('/api/dashboard/').json()['calendarEvents']]
        self.assertEqual(titles, ['Semis'])

    def test_weather_prefers_user_region(self):
        today = timezone.now().date()
        WeatherData.objects.create(location='Dakar', temperature=25, humidity=70, rainfall=0, forecast_date=today)
        WeatherData.objects.create(location='Thiès', temperature=33, humidity=40, rainfall=0, forecast_date=today - timedelta(days=1))
        self.assertEqual(self.client.get('/api/dashboard/').json()['weather']['location'], 'Thiès')

    def test_featured_products_come_from_database(self):
        Product.objects.create(name='Oignon', category='LÉGUME', current_price=400, is_trending=True, image_asset='x.png')
        featured = self.client.get('/api/dashboard/').json()['featuredProducts']
        self.assertEqual(featured[0]['name'], 'Oignon')
