from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from apps.markets.models import Market, Price, Product

User = get_user_model()

class MarketsAppTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.farmer = User.objects.create_user(
            username='+221772000001',
            phone='+221772000001',
            password='password123',
            first_name='Abdoulaye',
            role='farmer',
            location='Thiès, Sénégal'
        )

        self.market_castors = Market.objects.create(
            name='Marché Castors',
            region='Dakar',
            rating=4.5
        )
        self.market_kaolack = Market.objects.create(
            name='Marché Central de Kaolack',
            region='Kaolack',
            rating=4.2
        )

        self.product_onion = Product.objects.create(
            name='Oignon Local Galmi',
            category='LÉGUME',
            current_price='600.00',
            trend_percentage=5.0,
            image_asset='assets/images/onion.png',
            is_trending=True
        )

        self.product_rice = Product.objects.create(
            name='Riz Vallée Parfumé',
            category='CÉRÉALE',
            current_price='450.00',
            trend_percentage=0.0,
            image_asset='assets/images/rice.png',
            is_trending=False
        )

        self.price_onion_castors = Price.objects.create(
            market=self.market_castors,
            product_name='Oignon Local Galmi',
            price='600.00',
            date=timezone.now().date()
        )
        self.price_onion_kaolack = Price.objects.create(
            market=self.market_kaolack,
            product_name='Oignon Local Galmi',
            price='550.00',
            date=timezone.now().date()
        )

    def test_products_list_and_filter(self):
        """Vérifie le listing des produits avec filtre catégorie et recherche."""
        self.client.force_authenticate(user=self.farmer)
        url = reverse('markets:product-list')

        # Liste complète
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)

        # Filtre par catégorie
        response_legume = self.client.get(url, {'category': 'LÉGUME'})
        self.assertEqual(response_legume.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response_legume.data), 1)
        self.assertEqual(response_legume.data[0]['name'], 'Oignon Local Galmi')

        # Filtre par recherche textuelle
        response_search = self.client.get(url, {'search': 'Riz'})
        self.assertEqual(response_search.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response_search.data), 1)
        self.assertEqual(response_search.data[0]['name'], 'Riz Vallée Parfumé')

        # Filtre tendance
        response_trending = self.client.get(url, {'is_trending': 'true'})
        self.assertEqual(response_trending.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response_trending.data), 1)
        self.assertEqual(response_trending.data[0]['name'], 'Oignon Local Galmi')

    def test_markets_list(self):
        """Vérifie le listing des marchés agricoles régionaux."""
        self.client.force_authenticate(user=self.farmer)
        url = reverse('markets:market-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)

    def test_prices_list_and_filter(self):
        """Vérifie le listing et le filtrage des cotations des prix selon le marché et le produit."""
        self.client.force_authenticate(user=self.farmer)
        url = reverse('markets:price-list')

        # Tous les prix
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data['results'] if isinstance(response.data, dict) else response.data
        self.assertEqual(len(results), 2)

        # Filtrer par marché
        response_market = self.client.get(url, {'market': str(self.market_castors.id)})
        self.assertEqual(response_market.status_code, status.HTTP_200_OK)
        results_market = response_market.data['results'] if isinstance(response_market.data, dict) else response_market.data
        self.assertEqual(len(results_market), 1)
        self.assertEqual(float(results_market[0]['price']), 600.0)

        # Filtrer par nom de produit
        response_prod = self.client.get(url, {'product': 'Oignon'})
        self.assertEqual(response_prod.status_code, status.HTTP_200_OK)
        results_prod = response_prod.data['results'] if isinstance(response_prod.data, dict) else response_prod.data
        self.assertEqual(len(results_prod), 2)

    def test_prices_pagination_structure(self):
        """Vérifie la pagination par défaut de PriceViewSet."""
        url = reverse('markets:price-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('count', response.data)
        self.assertIn('results', response.data)
        self.assertEqual(response.data['count'], 2)

    def test_unauthenticated_read_is_allowed(self):
        """Vérifie que les observatoires de prix et marchés sont consultables publiquement en lecture seule."""
        url = reverse('markets:market-list')
        response = APIClient().get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)


class PriceSummaryEndpointsTests(TestCase):
    """Routes légères pour la carte : dernier prix par marché et historique journalier."""

    def setUp(self):
        self.client = APIClient()
        self.today = timezone.now().date()
        self.m1 = Market.objects.create(name='Marché A', region='Thiès', location_gps='14.79,-16.93')
        self.m2 = Market.objects.create(name='Marché B', region='Dakar')
        day = lambda n: self.today - timezone.timedelta(days=n)
        Price.objects.create(market=self.m1, product_name='Oignon', price=400, date=day(2))
        Price.objects.create(market=self.m1, product_name='Oignon', price=420, date=day(0))
        Price.objects.create(market=self.m2, product_name='Oignon', price=380, date=day(1))
        Price.objects.create(market=self.m1, product_name='Riz', price=999, date=day(0))

    def test_latest_requires_product(self):
        self.assertEqual(self.client.get('/api/markets/prices/latest/').status_code, status.HTTP_400_BAD_REQUEST)

    def test_latest_returns_one_row_per_market_with_the_newest_price(self):
        rows = self.client.get('/api/markets/prices/latest/?product=Oignon').json()
        by_name = {r['market_name']: r for r in rows}
        self.assertEqual(set(by_name), {'Marché A', 'Marché B'})
        self.assertEqual(by_name['Marché A']['price'], 420.0)
        self.assertEqual(by_name['Marché B']['price'], 380.0)
        self.assertEqual(by_name['Marché A']['location_gps'], '14.79,-16.93')
        self.assertNotIn('Riz', [r['product_name'] for r in rows])

    def test_history_averages_all_markets_per_day(self):
        series = self.client.get('/api/markets/prices/history/?product=Oignon&days=30').json()
        self.assertEqual([p['price'] for p in series], [400.0, 380.0, 420.0])
        self.assertEqual(series[-1]['markets'], 1)

    def test_history_can_be_limited_to_one_market(self):
        series = self.client.get(f'/api/markets/prices/history/?product=Oignon&market={self.m1.id}').json()
        self.assertEqual([p['price'] for p in series], [400.0, 420.0])

    def test_history_is_empty_without_data(self):
        self.assertEqual(self.client.get('/api/markets/prices/history/?product=Inconnu').json(), [])

