from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from apps.markets.models import Market, Price, Product, PreSaleOffer, PreSaleReservation

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
        self.buyer = User.objects.create_user(
            username='+221772000002',
            phone='+221772000002',
            password='password123',
            first_name='Mariama',
            role='buyer',
            location='Dakar, Sénégal'
        )

        self.market = Market.objects.create(
            name='Marché Castors',
            region='Dakar',
            rating=4.5
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

    def test_products_list_and_filter(self):
        """Vérifie le listing des produits avec filtre catégorie et recherche."""
        self.client.force_authenticate(user=self.buyer)
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

    def test_b2b_offer_creation_by_farmer(self):
        """Vérifie la création d'une offre B2B par un producteur."""
        self.client.force_authenticate(user=self.farmer)
        url = reverse('markets:presale-offer-list')
        offer_data = {
            'product_name': 'Oignon Violet',
            'quantity_kg': 1500.0,
            'price_per_kg': '450.00',
            'availability_date': '2026-04-01',
            'location': 'Thiès, Sénégal',
            'status': 'open'
        }
        response = self.client.post(url, offer_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(PreSaleOffer.objects.filter(product_name='Oignon Violet').exists())

    def test_b2b_offer_reservation_flow(self):
        """Vérifie le cycle complet de réservation B2B avec calcul des stocks."""
        offer = PreSaleOffer.objects.create(
            farmer=self.farmer,
            product_name='Tomate Industrielle',
            quantity_kg=1000.0,
            price_per_kg='300.00',
            availability_date='2026-05-01',
            location='Podor, Sénégal',
            status='open'
        )

        self.client.force_authenticate(user=self.buyer)
        reserve_url = reverse('markets:presale-offer-reserve', kwargs={'pk': str(offer.id)})

        # 1. Réservation impossible si quantité excessive
        excess_response = self.client.post(reserve_url, {'quantity_reserved': 1200}, format='json')
        self.assertEqual(excess_response.status_code, status.HTTP_400_BAD_REQUEST)

        # 2. Réservation partielle valide (400 kg)
        valid_response = self.client.post(reserve_url, {'quantity_reserved': 400}, format='json')
        self.assertEqual(valid_response.status_code, status.HTTP_201_CREATED)
        offer.refresh_from_db()
        self.assertEqual(offer.quantity_kg, 600.0)
        self.assertEqual(offer.status, 'open')
        self.assertEqual(PreSaleReservation.objects.filter(offer=offer).count(), 1)

        # 3. Réservation du solde restant (600 kg) -> l'offre passe à "reserved"
        final_response = self.client.post(reserve_url, {'quantity_reserved': 600}, format='json')
        self.assertEqual(final_response.status_code, status.HTTP_201_CREATED)
        offer.refresh_from_db()
        self.assertEqual(offer.quantity_kg, 0.0)
        self.assertEqual(offer.status, 'reserved')

        # 4. Tentative de réservation sur une offre fermée / réservée -> refusée
        closed_response = self.client.post(reserve_url, {'quantity_reserved': 50}, format='json')
        self.assertEqual(closed_response.status_code, status.HTTP_400_BAD_REQUEST)
