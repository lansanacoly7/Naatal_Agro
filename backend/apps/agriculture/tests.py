import datetime
from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from apps.agriculture.models import Crop, Activity, PestReport
from apps.notifications.models import Notification

User = get_user_model()

class AgricultureAppTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user1 = User.objects.create_user(
            username='+221770000001',
            phone='+221770000001',
            password='password123',
            first_name='Amadou',
            location='Thiès, Sénégal',
            role='farmer'
        )
        self.user2 = User.objects.create_user(
            username='+221770000002',
            phone='+221770000002',
            password='password123',
            first_name='Ibrahima',
            location='Thiès, Sénégal',
            role='farmer'
        )
        self.user3_dakar = User.objects.create_user(
            username='+221770000003',
            phone='+221770000003',
            password='password123',
            first_name='Samba',
            location='Dakar, Sénégal',
            role='farmer'
        )

    def test_crop_creation_and_isolation(self):
        """Vérifie la création d'une culture et l'isolation des données entre agriculteurs."""
        self.client.force_authenticate(user=self.user1)
        url = reverse('agriculture:crop-list')
        crop_data = {
            'name': 'Oignon Violet de Galmi',
            'crop_type': 'Oignon',
            'planting_date': '2026-01-15',
            'expected_harvest_date': '2026-05-15',
            'status': 'active',
            'area_size': 2.5,
            'location': 'Thiès, Sénégal'
        }
        response = self.client.post(url, crop_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Crop.objects.filter(user=self.user1).count(), 1)

        # L'utilisateur 2 ne doit pas voir les cultures de l'utilisateur 1
        self.client.force_authenticate(user=self.user2)
        response_user2 = self.client.get(url)
        self.assertEqual(response_user2.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response_user2.data), 0)

    def test_activity_creation(self):
        """Vérifie l'enregistrement d'une activité agricole liée à une culture."""
        crop = Crop.objects.create(
            user=self.user1,
            name='Tomate Roma',
            crop_type='Tomate',
            planting_date='2026-02-01',
            expected_harvest_date='2026-06-01',
            area_size=1.0,
            location='Thiès, Sénégal'
        )
        self.client.force_authenticate(user=self.user1)
        url = reverse('agriculture:activity-list')
        activity_data = {
            'crop': str(crop.id),
            'activity_type': 'Irrigation',
            'description': 'Irrigation goutte à goutte matin',
            'date': '2026-02-10',
            'cost': '5000.00'
        }
        response = self.client.post(url, activity_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Activity.objects.filter(crop=crop).count(), 1)

    def test_pest_report_threshold_triggers_notification(self):
        """
        Vérifie que le seuil de 10 signalements pour un même ravageur et une même localisation
        déclenche une alerte notification pour les producteurs de cette zone.
        """
        self.client.force_authenticate(user=self.user1)
        url = reverse('agriculture:pest-report-list')

        # Création de 9 signalements
        for i in range(9):
            PestReport.objects.create(
                user=self.user1,
                pest_name='Chenille légionnaire',
                location='Thiès, Sénégal',
                description=f'Signalement mineur #{i+1}'
            )

        # À 9 signalements, aucune alerte ne doit encore être générée
        self.assertEqual(Notification.objects.filter(type='alert').count(), 0)

        # Le 10ème signalement via l'API doit déclencher l'alerte
        post_data = {
            'pest_name': 'Chenille légionnaire',
            'location': 'Thiès, Sénégal',
            'description': 'Invasion détectée'
        }
        response = self.client.post(url, post_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        # Une notification d'alerte doit avoir été créée pour les utilisateurs de Thiès
        alerts_user1 = Notification.objects.filter(user=self.user1, type='alert')
        alerts_user2 = Notification.objects.filter(user=self.user2, type='alert')
        alerts_user3_dakar = Notification.objects.filter(user=self.user3_dakar, type='alert')

        self.assertTrue(alerts_user1.exists())
        self.assertTrue(alerts_user2.exists())
        # L'utilisateur de Dakar ne doit pas être alerté d'un foyer à Thiès
        self.assertFalse(alerts_user3_dakar.exists())

    def test_activity_creation_on_other_user_crop_forbidden(self):
        """Vérifie qu'un utilisateur ne peut pas injecter une activité sur la culture d'un tiers (anti-IDOR)."""
        crop_user1 = Crop.objects.create(
            user=self.user1,
            name='Mangue Kent',
            crop_type='Arbre Fruitier',
            planting_date='2025-06-01',
            expected_harvest_date='2027-06-01',
            area_size=3.0,
            location='Thiès, Sénégal'
        )
        # L'utilisateur 2 tente d'associer une activité à la culture de l'utilisateur 1
        self.client.force_authenticate(user=self.user2)
        url = reverse('agriculture:activity-list')
        attack_data = {
            'crop': str(crop_user1.id),
            'activity_type': 'Élagage non autorisé',
            'description': 'Tentative IDOR',
            'date': '2026-03-01'
        }
        response = self.client.post(url, attack_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(Activity.objects.filter(crop=crop_user1).count(), 0)

    def test_pest_report_modification_by_non_owner_forbidden(self):
        """Vérifie qu'un utilisateur ne peut pas modifier ou supprimer le signalement d'un autre (anti-IDOR)."""
        report_user1 = PestReport.objects.create(
            user=self.user1,
            pest_name='Mouche des fruits',
            location='Thiès, Sénégal',
            description='Attaque sur verger'
        )
        # L'utilisateur 2 tente de modifier le signalement de l'utilisateur 1
        self.client.force_authenticate(user=self.user2)
        url = reverse('agriculture:pest-report-detail', kwargs={'pk': str(report_user1.id)})
        
        # Test modification interdite (403)
        patch_response = self.client.patch(url, {'description': 'Contrefaçon'}, format='json')
        self.assertEqual(patch_response.status_code, status.HTTP_403_FORBIDDEN)
        
        # Test suppression interdite (403)
        delete_response = self.client.delete(url)
        self.assertEqual(delete_response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(PestReport.objects.filter(id=report_user1.id).exists())

