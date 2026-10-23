from django.test import TestCase, override_settings
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient, APITestCase
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
        self.admin_user = User.objects.create_user(
            username='+221779876543',
            phone='+221779876543',
            password='securepassword123',
            first_name='Awa',
            last_name='Ndiaye',
            role='admin',
            location='Dakar, Sénégal'
        )

    def test_user_creation_and_attributes(self):
        """Vérifie la création correcte de l'utilisateur avec ses attributs métier."""
        self.assertEqual(self.farmer_user.role, 'farmer')
        self.assertEqual(self.farmer_user.phone, '+221771234567')
        self.assertEqual(len(self.farmer_user.main_crops), 2)
        self.assertEqual(self.admin_user.role, 'admin')

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

    def test_patch_me_profile_with_full_name(self):
        """Vérifie que l'envoi de full_name par le mobile met bien à jour first_name et last_name."""
        self.client.force_authenticate(user=self.farmer_user)
        url = reverse('users:user_me')
        response = self.client.patch(url, {'full_name': 'Amath Diop', 'language': 'WO'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.farmer_user.refresh_from_db()
        self.assertEqual(self.farmer_user.first_name, 'Amath')
        self.assertEqual(self.farmer_user.last_name, 'Diop')
        self.assertEqual(self.farmer_user.language, 'wo')
        self.assertEqual(response.data['full_name'], 'Amath Diop')

    def test_update_fcm_token(self):
        """Vérifie la mise à jour du token Firebase FCM."""
        self.client.force_authenticate(user=self.farmer_user)
        url = reverse('users:update_fcm_token')
        response = self.client.post(url, {'fcm_token': 'fcm_sample_token_xyz_123'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.farmer_user.refresh_from_db()
        self.assertEqual(self.farmer_user.fcm_token, 'fcm_sample_token_xyz_123')

    def test_register_duplicate_phone_returns_400(self):
        """Vérifie qu'un numéro déjà enregistré renvoie une 400 Bad Request et non un crash 500."""
        url = reverse('users:register')
        payload = {
            'phone_number': '+221771234567',  # Déjà existant (farmer_user)
            'full_name': 'Doublon Test',
            'password': 'passwordSenegal2026',
            'location': 'Dakar',
            'role': 'farmer'
        }
        response = self.client.post(url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('phone_number', response.data)

    @override_settings(OTP_DEMO_MODE=True)
    def test_send_and_verify_otp(self):
        """Teste la génération et la vérification réussie d'un code OTP."""
        send_url = reverse('users:send_otp')
        payload = {'phone_number': '+221773334455', 'purpose': 'register'}
        send_res = self.client.post(send_url, payload, format='json')
        self.assertEqual(send_res.status_code, status.HTTP_200_OK)
        code = send_res.data.get('code')
        self.assertIsNotNone(code)

        verify_url = reverse('users:verify_otp')
        verify_res = self.client.post(verify_url, {
            'phone_number': '+221773334455',
            'code': code,
            'purpose': 'register'
        }, format='json')
        self.assertEqual(verify_res.status_code, status.HTTP_200_OK)
        self.assertTrue(verify_res.data.get('valid'))

    def test_verify_otp_invalid_code(self):
        """Vérifie le rejet d'un mauvais code OTP."""
        verify_url = reverse('users:verify_otp')
        verify_res = self.client.post(verify_url, {
            'phone_number': '+221773334455',
            'code': '0000',
            'purpose': 'register'
        }, format='json')
        self.assertEqual(verify_res.status_code, status.HTTP_400_BAD_REQUEST)

    @override_settings(OTP_DEMO_MODE=True)
    def test_reset_password_flow(self):
        """Teste le flux complet de réinitialisation de mot de passe par SMS/OTP."""
        send_url = reverse('users:send_otp')
        send_res = self.client.post(send_url, {
            'phone_number': '+221771234567',
            'purpose': 'password_reset'
        }, format='json')
        self.assertEqual(send_res.status_code, status.HTTP_200_OK)
        otp = send_res.data.get('code')

        reset_url = reverse('users:reset_password')
        reset_res = self.client.post(reset_url, {
            'phone_number': '+221771234567',
            'otp_code': otp,
            'new_password': 'NewSecurePassword2026!'
        }, format='json')
        self.assertEqual(reset_res.status_code, status.HTTP_200_OK)

        # Vérifie qu'on peut se connecter avec le nouveau mot de passe
        login_url = reverse('users:token_obtain_pair')
        login_res = self.client.post(login_url, {
            'phone_number': '+221771234567',
            'password': 'NewSecurePassword2026!'
        }, format='json')
        self.assertEqual(login_res.status_code, status.HTTP_200_OK)



class OTPSecurityTests(APITestCase):
    """Le code ne fuit qu'en mode demonstration et les essais sont limites."""

    def setUp(self):
        self.phone = '+221779998877'

    @override_settings(OTP_DEMO_MODE=False, OTP_REGISTER_FIXED_CODE='')
    def test_code_hidden_outside_demo_mode(self):
        res = self.client.post(reverse('users:send_otp'), {'phone_number': self.phone, 'purpose': 'register'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertNotIn('code', res.data)

    @override_settings(OTP_DEMO_MODE=False, OTP_REGISTER_FIXED_CODE='1234')
    def test_register_uses_fixed_code_by_default(self):
        res = self.client.post(reverse('users:send_otp'), {'phone_number': self.phone, 'purpose': 'register'}, format='json')
        self.assertEqual(res.data['code'], '1234')
        self.assertTrue(res.data['demo'])

    @override_settings(OTP_DEMO_MODE=False, OTP_REGISTER_FIXED_CODE='1234')
    def test_fixed_code_never_applies_to_password_reset(self):
        """Un code connu de tous ne doit jamais permettre de réinitialiser un mot de passe."""
        get_user_model().objects.create_user(username=self.phone, phone=self.phone, password='Sup3r-Secret-2026!')
        res = self.client.post(reverse('users:send_otp'), {'phone_number': self.phone, 'purpose': 'password_reset'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertNotIn('code', res.data)
        reset = self.client.post(reverse('users:reset_password'), {'phone_number': self.phone, 'otp_code': '1234', 'new_password': 'Autre-Secret-2026!'}, format='json')
        self.assertEqual(reset.status_code, status.HTTP_400_BAD_REQUEST)

    @override_settings(OTP_REQUIRED_FOR_REGISTER=False)
    def test_register_never_blocks_on_otp_when_not_required(self):
        payload = {'phone_number': self.phone, 'full_name': 'Test Libre', 'password': 'Sup3r-Secret-2026!', 'language': 'fr'}
        for code in ('', '0000', '1234'):
            res = self.client.post(reverse('users:register'), {**payload, 'phone_number': f'+22177999{9000 + len(code) + int(code or 0) % 7:04d}', 'otp_code': code}, format='json')
            self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)

    @override_settings(OTP_DEMO_MODE=True)
    def test_code_returned_in_demo_mode(self):
        res = self.client.post(reverse('users:send_otp'), {'phone_number': self.phone, 'purpose': 'register'}, format='json')
        self.assertIn('code', res.data)
        self.assertTrue(res.data['demo'])

    @override_settings(OTP_DEMO_MODE=True, OTP_MAX_ATTEMPTS=3)
    def test_code_locked_after_too_many_wrong_attempts(self):
        res = self.client.post(reverse('users:send_otp'), {'phone_number': self.phone, 'purpose': 'register'}, format='json')
        good = res.data['code']
        wrong = '0000' if good != '0000' else '1111'
        for _ in range(3):
            bad = self.client.post(reverse('users:verify_otp'), {'phone_number': self.phone, 'code': wrong, 'purpose': 'register'}, format='json')
            self.assertEqual(bad.status_code, status.HTTP_400_BAD_REQUEST)
        late = self.client.post(reverse('users:verify_otp'), {'phone_number': self.phone, 'code': good, 'purpose': 'register'}, format='json')
        self.assertEqual(late.status_code, status.HTTP_400_BAD_REQUEST)

    @override_settings(OTP_DEMO_MODE=True, OTP_REQUIRED_FOR_REGISTER=True)
    def test_register_requires_valid_otp_when_enabled(self):
        payload = {'phone_number': self.phone, 'full_name': 'Test Otp', 'password': 'Sup3r-Secret-2026!', 'language': 'fr'}
        denied = self.client.post(reverse('users:register'), payload, format='json')
        self.assertEqual(denied.status_code, status.HTTP_400_BAD_REQUEST)
        code = self.client.post(reverse('users:send_otp'), {'phone_number': self.phone, 'purpose': 'register'}, format='json').data['code']
        ok = self.client.post(reverse('users:register'), {**payload, 'otp_code': code}, format='json')
        self.assertEqual(ok.status_code, status.HTTP_201_CREATED)


class DemoUserCommandTests(TestCase):
    def test_refuses_without_demo_mode(self):
        from django.core.management import call_command
        from django.core.management.base import CommandError
        with override_settings(DEBUG=False, OTP_DEMO_MODE=False):
            with self.assertRaises(CommandError):
                call_command('setup_demo', stdout=open('NUL' if __import__('os').name == 'nt' else '/dev/null', 'w'))

    @override_settings(OTP_DEMO_MODE=True)
    def test_builds_a_linked_demo_account(self):
        import io
        from django.core.management import call_command
        from apps.agriculture.models import Crop
        from apps.finances.models import Transaction
        call_command('setup_demo', stdout=io.StringIO())
        user = get_user_model().objects.get(username='+221770000000')
        self.assertEqual(Crop.objects.filter(user=user).count(), 3)
        self.assertTrue(Transaction.objects.filter(user=user, sale__isnull=False).exists())
