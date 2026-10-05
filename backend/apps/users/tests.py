from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status

User = get_user_model()

class UserAuthAndProfileTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.farmer_user = User.objects.create_user(
            username='+221771234567',
            phone='+221771234567',
            password='securepassword123',
            first_name='Modou',
            last_name='Diop',
            role='farmer',
            location='Thiès, Sénégal',
            main_crops=['Oignon', 'Tomate']
        )
        self.buyer_user = User.objects.create_user(
            username='+221779876543',
            phone='+221779876543',
            password='securepassword123',
            first_name='Awa',
            last_name='Ndiaye',
            role='buyer',
            location='Dakar, Sénégal'
        )

    def test_user_creation_and_attributes(self):
        """Vérifie la création correcte de l'utilisateur avec ses attributs métier."""
        self.assertEqual(self.farmer_user.role, 'farmer')
        self.assertEqual(self.farmer_user.phone, '+221771234567')
        self.assertEqual(len(self.farmer_user.main_crops), 2)
        self.assertEqual(self.buyer_user.role, 'buyer')

    def test_register_new_farmer(self):
        """Teste l'inscription d'un nouvel utilisateur via l'API."""
        url = reverse('users:register')
        payload = {
            'phone_number': '+221775556677',
            'full_name': 'Fatou Sow',
            'password': 'passwordSenegal2026',
            'location': 'Saint-Louis, Sénégal',
            'role': 'farmer',
            'main_crops': ['Riz']
        }
        response = self.client.post(url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(User.objects.filter(phone='+221775556677').exists())
        created_user = User.objects.get(phone='+221775556677')
        self.assertEqual(created_user.first_name, 'Fatou Sow')
        self.assertEqual(created_user.role, 'farmer')

    def test_login_success(self):
        """Teste la connexion avec phone_number et génération du token JWT."""
        url = reverse('users:token_obtain_pair')
        payload = {
            'phone_number': '+221771234567',
            'password': 'securepassword123'
        }
        response = self.client.post(url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
        self.assertEqual(response.data['role'], 'farmer')

    def test_me_endpoint_unauthenticated(self):
        """Vérifie que /api/users/me/ est refusé sans authentification."""
        url = reverse('users:user_me')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_me_endpoint_authenticated(self):
        """Vérifie que /api/users/me/ renvoie le profil complet de l'utilisateur connecté."""
        self.client.force_authenticate(user=self.farmer_user)
        url = reverse('users:user_me')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['phone'], '+221771234567')
        self.assertEqual(response.data['first_name'], 'Modou')
        self.assertEqual(response.data['role'], 'farmer')
        self.assertEqual(response.data['main_crops'], ['Oignon', 'Tomate'])

    def test_patch_me_profile(self):
        """Vérifie la mise à jour partielle du profil via PATCH /api/users/me/."""
        self.client.force_authenticate(user=self.farmer_user)
        url = reverse('users:user_me')
        update_data = {
            'first_name': 'Mamadou',
            'location': 'Mbour, Sénégal',
            'main_crops': ['Oignon', 'Mangue', 'Arachide']
        }
        response = self.client.patch(url, update_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.farmer_user.refresh_from_db()
        self.assertEqual(self.farmer_user.first_name, 'Mamadou')
        self.assertEqual(self.farmer_user.location, 'Mbour, Sénégal')
        self.assertEqual(len(self.farmer_user.main_crops), 3)

    def test_update_fcm_token(self):
        """Vérifie la mise à jour du token Firebase FCM."""
        self.client.force_authenticate(user=self.farmer_user)
        url = reverse('users:update_fcm_token')
        response = self.client.post(url, {'fcm_token': 'fcm_sample_token_xyz_123'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.farmer_user.refresh_from_db()
        self.assertEqual(self.farmer_user.fcm_token, 'fcm_sample_token_xyz_123')
