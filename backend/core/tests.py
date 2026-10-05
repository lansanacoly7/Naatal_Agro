from django.test import TestCase
from django.urls import reverse
from rest_framework import status

class HealthCheckTests(TestCase):
    def test_api_health_check_endpoint(self):
        """Vérifie que /api/health/ renvoie 200 OK avec le statut de la base de données."""
        url = reverse('api_health_check')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['status'], 'healthy')
        self.assertEqual(response.data['database'], 'connected')
        self.assertEqual(response.data['service'], 'Naatal Agro API')

    def test_root_health_check_endpoint(self):
        """Vérifie que /health/ est accessible pour les sondes d'orchestration."""
        url = reverse('health_check')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['status'], 'healthy')
