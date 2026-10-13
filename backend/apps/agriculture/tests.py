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

    def test_crop_creation_with_agronomic_guide_autocalculates_harvest_date(self):
        """Vérifie que lier un guide agronomique calcule automatiquement la date prévisionnelle de récolte."""
        from apps.agriculture.models import AgronomicGuide
        guide = AgronomicGuide.objects.filter(cycle_days_max__isnull=False).first()
        self.assertIsNotNone(guide, "Un guide avec cycle_days_max doit être présent")

        self.client.force_authenticate(user=self.user1)
        url = reverse('agriculture:crop-list')
        crop_data = {
            'name': guide.name,
            'crop_type': guide.name,
            'planting_date': '2026-06-01',
            'guide': str(guide.id),
            'area_size': 1.5,
            'location': 'Thiès, Sénégal'
        }
        response = self.client.post(url, crop_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        data = response.json()
        self.assertEqual(data['guide_slug'], guide.slug)
        self.assertEqual(data['guide_name'], guide.name)
        # La date attendue doit être 2026-06-01 + cycle_days_max
        expected = datetime.date(2026, 6, 1) + datetime.timedelta(days=guide.cycle_days_max)
        self.assertEqual(data['expected_harvest_date'], expected.isoformat())

    def test_record_harvest_updates_crop_and_increments_stock_and_notification(self):
        """Vérifie que l'enregistrement d'une récolte passe la culture en 'harvested' et incrémente le stock."""
        from apps.inventory.models import StockItem
        from apps.agriculture.models import Harvest

        crop = Crop.objects.create(
            user=self.user1,
            name='Oignon Violet',
            crop_type='Oignon',
            planting_date='2026-01-01',
            expected_harvest_date='2026-04-01',
            area_size=2.0,
            location='Thiès'
        )

        self.client.force_authenticate(user=self.user1)
        url = reverse('agriculture:crop-record-harvest', kwargs={'pk': str(crop.id)})
        
        # Première récolte de 200 kg
        res1 = self.client.post(url, {'quantity': 200, 'unit': 'kg', 'notes': 'Première coupe'}, format='json')
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)
        
        crop.refresh_from_db()
        self.assertEqual(crop.status, 'harvested')
        self.assertEqual(Harvest.objects.filter(crop=crop).count(), 1)

        stock = StockItem.objects.get(user=self.user1, name='Oignon Violet')
        self.assertEqual(stock.quantity, 200.0)
        self.assertEqual(stock.unit, 'kg')

        # Seconde récolte supplémentaire de 150 kg
        res2 = self.client.post(url, {'quantity': 150, 'unit': 'kg'}, format='json')
        self.assertEqual(res2.status_code, status.HTTP_201_CREATED)
        
        stock.refresh_from_db()
        self.assertEqual(stock.quantity, 350.0)
        self.assertTrue(Notification.objects.filter(user=self.user1, message__icontains='Oignon Violet').exists())

    def test_activity_with_cost_syncs_financial_transaction(self):
        """Vérifie qu'une activité avec un coût > 0 crée et synchronise automatiquement une transaction financière."""
        from apps.finances.models import Transaction

        crop = Crop.objects.create(
            user=self.user1,
            name='Manioc',
            crop_type='Manioc',
            planting_date='2026-01-01',
            expected_harvest_date='2026-09-01',
            area_size=1.0,
            location='Kolda'
        )
        self.client.force_authenticate(user=self.user1)
        url = reverse('agriculture:activity-list')

        # Création d'une activité avec un coût de 12 500 CFA
        res = self.client.post(url, {
            'crop': str(crop.id),
            'activity_type': 'Fertilisation NPK',
            'description': 'Achat et application 2 sacs engrais',
            'date': '2026-02-15',
            'cost': '12500.00'
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

        activity_id = res.json()['id']
        t = Transaction.objects.filter(activity_id=activity_id).first()
        self.assertIsNotNone(t)
        self.assertEqual(float(t.amount), 12500.0)
        self.assertEqual(t.transaction_type, 'expense')
        self.assertEqual(t.user, self.user1)

        # Suppression de l'activité => la transaction financière liée disparaît
        del_res = self.client.delete(reverse('agriculture:activity-detail', kwargs={'pk': activity_id}))
        self.assertEqual(del_res.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Transaction.objects.filter(activity_id=activity_id).exists())


