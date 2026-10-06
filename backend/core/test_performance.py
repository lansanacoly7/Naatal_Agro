"""
Garde-fou de performance : le nombre de requêtes SQL d'un point d'accès ne doit pas grandir avec la quantité
de données de l'utilisateur (problème dit « N+1 »).

Chaque point d'accès est mesuré avec peu de données (SMALL), puis avec dix fois plus (LARGE). Le nombre de
requêtes doit rester identique (à une requête près pour la pagination ou un cache).
"""
import os
from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TestCase
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from rest_framework.test import APIClient

from apps.agriculture.models import Activity, Crop, PestReport
from apps.ai_assistant.models import AIInteraction
from apps.finances.models import Sale, Transaction
from apps.inventory.models import StockItem
from apps.markets.models import Market, Price, Product
from apps.notifications.models import Notification
from apps.weather.models import WeatherData

User = get_user_model()

SMALL, LARGE = 3, 30
TOLERANCE = 1  # une requête de plus est admise (comptage, cache)

# Réglable : PERF_REPORT=1 python manage.py test core.test_performance affiche le tableau des mesures
PRINT_REPORT = os.environ.get('PERF_REPORT') == '1'

ENDPOINTS = [
    '/api/agriculture/crops/',
    '/api/agriculture/activities/',
    '/api/agriculture/pest-reports/',
    '/api/agriculture/guides/',
    '/api/finances/sales/',
    '/api/finances/transactions/',
    '/api/finances/summary/',
    '/api/inventory/',
    '/api/notifications/',
    '/api/markets/',
    '/api/markets/prices/',
    '/api/markets/products/',
    '/api/weather/',
    '/api/dashboard/',
    '/api/ai/ask/',
    '/api/privacy/export/',
    '/api/users/me/',
]


def populate(user, n):
    """Crée n éléments de chaque type rattachés à l'utilisateur (3 activités par culture)."""
    today = date.today()
    for i in range(n):
        crop = Crop.objects.create(
            user=user, name=f'Culture {i}', crop_type='Mil', planting_date=today, area_size=1.0, location='Thiès',
            expected_harvest_date=today + timedelta(days=90))
        for j in range(3):
            Activity.objects.create(crop=crop, activity_type='Semis', description='', date=today + timedelta(days=j))
        Sale.objects.create(crop=crop, quantity_sold=10, price_per_unit=100, date=today)
        Transaction.objects.create(user=user, transaction_type='expense', amount=1000, date=today, description=f'Dépense {i}')
        StockItem.objects.create(user=user, name=f'Stock {i}', quantity=5, unit='kg')
        Notification.objects.create(user=user, type='info', message=f'Message {i}')
        PestReport.objects.create(user=user, pest_name=f'Ravageur {i}', location='Thiès')
        AIInteraction.objects.create(user=user, query='q', response='r', origin='general', sources=[])


class QueryCountScalingTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        # Données publiques partagées (marchés, prix, produits, météo) : elles grossissent aussi
        for i in range(LARGE):
            market = Market.objects.create(name=f'Marché {i}', region='Dakar')
            Price.objects.create(market=market, product_name=f'Produit {i}', price=500, date=date.today())
            Product.objects.create(name=f'Produit {i}', category='LÉGUME', current_price=500, image_asset='x.png')
            WeatherData.objects.create(location=f'Ville {i}', temperature=30, humidity=50, rainfall=0,
                                       forecast_date=date.today() - timedelta(days=i))

    def _queries(self, user, url):
        client = APIClient()
        client.force_authenticate(user)
        with CaptureQueriesContext(connection) as context:
            response = client.get(url)
        self.assertEqual(response.status_code, 200, f'{url} : {response.status_code}')
        return len(context)

    def test_query_count_does_not_grow_with_data(self):
        small_user = User.objects.create_user(username='+221771300001', phone='+221771300001', password='x', location='Thiès')
        large_user = User.objects.create_user(username='+221771300002', phone='+221771300002', password='x', location='Thiès')
        populate(small_user, SMALL)
        populate(large_user, LARGE)

        rows, failures = [], []
        for url in ENDPOINTS:
            small, large = self._queries(small_user, url), self._queries(large_user, url)
            rows.append((url, small, large))
            if large > small + TOLERANCE:
                failures.append(f'{url} : {small} requêtes avec {SMALL} éléments, {large} avec {LARGE}')

        if PRINT_REPORT:
            print('\n' + f"{'Point d accès':<34}{'petit':>7}{'grand':>7}")
            for url, small, large in rows:
                print(f'{url:<34}{small:>7}{large:>7}')
        self.assertEqual(failures, [], 'Requêtes N+1 détectées :\n' + '\n'.join(failures))


class ResponseTimeReport(TestCase):
    """Mesure indicative des temps de réponse sur un gros volume ; affichée seulement avec PERF_REPORT=1."""
    VOLUME = 300
    REPEATS = 5

    def test_response_time_report(self):
        if not PRINT_REPORT:
            self.skipTest('Rapport de temps : définir PERF_REPORT=1')
        import statistics
        import time
        user = User.objects.create_user(username='+221771300003', phone='+221771300003', password='x', location='Thiès')
        populate(user, self.VOLUME)
        client = APIClient()
        client.force_authenticate(user)
        print(f"\nTemps médian sur {self.REPEATS} appels, {self.VOLUME} cultures (x3 activités), ventes, dépenses, stocks, notifications")
        print(f"{'Point d accès':<34}{'requêtes':>9}{'ms':>8}")
        paginated = ['/api/agriculture/crops/?page_size=20', '/api/agriculture/activities/?page_size=20',
                     '/api/finances/transactions/?page_size=20']
        for url in ENDPOINTS + paginated:
            durations = []
            for _ in range(self.REPEATS):
                with CaptureQueriesContext(connection) as context:
                    start = time.perf_counter()
                    response = client.get(url)
                    durations.append((time.perf_counter() - start) * 1000)
                self.assertEqual(response.status_code, 200)
            print(f'{url:<34}{len(context):>9}{statistics.median(durations):>8.0f}')
