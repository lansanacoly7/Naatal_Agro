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
        self.assertEqual(len(response.data), 2)

        # Filtrer par marché
        response_market = self.client.get(url, {'market': str(self.market_castors.id)})
        self.assertEqual(response_market.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response_market.data), 1)
        self.assertEqual(float(response_market.data[0]['price']), 600.0)

        # Filtrer par nom de produit
        response_prod = self.client.get(url, {'product': 'Oignon'})
        self.assertEqual(response_prod.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response_prod.data), 2)

    def test_unauthenticated_access_rejected(self):
        """Vérifie que l'accès aux endpoints de marché requiert une authentification."""
        url = reverse('markets:market-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
