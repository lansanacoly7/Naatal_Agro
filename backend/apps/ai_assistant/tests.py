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


class AIEndpointGuardTests(TestCase):
    """Validation des entrées et limitation de débit de /api/ai/ask/."""

    def setUp(self):
        from django.core.cache import cache
        cache.clear()
        self.user = User.objects.create_user(username='+221773000009', phone='+221773000009', password='Motdepasse#2026')
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def test_requires_authentication(self):
        self.assertEqual(APIClient().post('/api/ai/ask/', {'query': 'x'}, format='json').status_code, status.HTTP_401_UNAUTHORIZED)

    def test_rejects_empty_request(self):
        self.assertEqual(self.client.post('/api/ai/ask/', {}, format='json').status_code, status.HTTP_400_BAD_REQUEST)

    def test_rejects_overlong_query(self):
        response = self.client.post('/api/ai/ask/', {'query': 'a' * 1001}, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_rejects_non_text_query(self):
        response = self.client.post('/api/ai/ask/', {'query': {'sql': 'SELECT 1'}}, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_rejects_oversized_image(self):
        response = self.client.post('/api/ai/ask/', {'image_base64': 'a' * 7_000_001}, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_ai_scope_is_throttled(self):
        from unittest.mock import patch
        from rest_framework.throttling import ScopedRateThrottle
        with patch.dict(ScopedRateThrottle.THROTTLE_RATES, {'ai': '2/hour'}),                 patch('apps.ai_assistant.views.answer_question', return_value={'answer': 'ok', 'origin': 'general', 'sources': []}):
            codes = [self.client.post('/api/ai/ask/', {'query': 'bonjour'}, format='json').status_code for _ in range(3)]
        self.assertEqual(codes, [status.HTTP_201_CREATED, status.HTTP_201_CREATED, status.HTTP_429_TOO_MANY_REQUESTS])

    def test_login_is_throttled(self):
        from unittest.mock import patch
        from rest_framework.throttling import ScopedRateThrottle
        with patch.dict(ScopedRateThrottle.THROTTLE_RATES, {'auth': '3/minute'}):
            codes = [APIClient().post('/api/users/auth/login/', {'phone_number': '+221000', 'password': 'x'}, format='json').status_code
                     for _ in range(4)]
        self.assertEqual(codes[-1], status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertNotIn(status.HTTP_429_TOO_MANY_REQUESTS, codes[:3])
