from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from apps.agriculture.models import Crop
from apps.ai_assistant.services import get_farmer_context

User = get_user_model()

class AIAssistantSecurityTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user_ali = User.objects.create_user(
            username='+221773000001',
            phone='+221773000001',
            password='password123',
            first_name='Ali',
            location='Podor, Sénégal',
            main_crops=['Riz']
        )
        self.user_binta = User.objects.create_user(
            username='+221773000002',
            phone='+221773000002',
            password='password123',
            first_name='Binta',
            location='Ziguinchor, Sénégal',
            main_crops=['Anacarde']
        )

        # Culture de Binta (Confidentielle)
        self.crop_binta = Crop.objects.create(
            user=self.user_binta,
            name='Verger Anacarde Secret',
            crop_type='Anacarde',
            planting_date='2024-01-01',
            expected_harvest_date='2026-12-01',
            area_size=15.0,
            location='Ziguinchor, Sénégal'
        )

        # Culture d'Ali
        self.crop_ali = Crop.objects.create(
            user=self.user_ali,
            name='Rizière Delta',
            crop_type='Riz',
            planting_date='2026-01-01',
            expected_harvest_date='2026-06-01',
            area_size=5.0,
            location='Podor, Sénégal'
        )

    def test_farmer_context_strict_isolation(self):
        """
        Vérifie qu'aucun exploitant ne peut voir les cultures ou données
        d'un autre exploitant dans le contexte transmis à l'IA.
        """
        context_ali = get_farmer_context(self.user_ali)
        
        # Ali ne doit voir que sa propre rizière
        crop_names = [c['nom'] for c in context_ali['crops']]
        self.assertIn('Rizière Delta', crop_names)
        self.assertNotIn('Verger Anacarde Secret', crop_names)
        self.assertEqual(context_ali['name'], 'Ali')
        self.assertEqual(context_ali['location'], 'Podor, Sénégal')

    def test_unauthenticated_context_has_no_crops(self):
        """Vérifie qu'un visiteur non authentifié n'a accès à aucune exploitation."""
        context_anonymous = get_farmer_context(None)
        self.assertFalse(context_anonymous['auth'])
        self.assertNotIn('crops', context_anonymous)

    def test_ask_ai_endpoint_requires_auth(self):
        """Vérifie que l'endpoint IA nécessite une authentification."""
        url = reverse('ai_assistant:ask_ai')
        response = self.client.post(url, {'query': 'Conseille-moi sur le riz.'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
