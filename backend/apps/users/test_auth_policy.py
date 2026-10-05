from django.contrib.auth import get_user_model
from django.test import SimpleTestCase, TestCase
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.users.phone import clean_phone, normalize_phone

User = get_user_model()

REGISTER = '/api/users/auth/register/'
LOGIN = '/api/users/auth/login/'
REFRESH = '/api/users/auth/refresh/'
CHANGE_PASSWORD = '/api/users/auth/password/change/'
STRONG = 'Motdepasse#2026'


def register_payload(**overrides):
    payload = {'phone_number': '+221775556677', 'full_name': 'Fatou Sow', 'password': STRONG}
    payload.update(overrides)
    return payload


class PhoneNormalizationTests(SimpleTestCase):
    def test_accepts_international_format_with_separators(self):
        self.assertEqual(normalize_phone('+221 77 555 66 77'), '+221775556677')
        self.assertEqual(normalize_phone('+221-77-555-66-77'), '+221775556677')

    def test_rejects_non_international_or_malformed_numbers(self):
        for bad in ['771234567', '00221771234567', 'abc', '', '+0771234567', '+22177', '+2217712345678901234']:
            with self.subTest(number=bad):
                with self.assertRaises(ValueError):
                    normalize_phone(bad)

    def test_clean_phone_only_strips_separators(self):
        self.assertEqual(clean_phone(' +221 77.123-45 (67) '), '+221771234567')


class RegistrationPolicyTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_valid_registration_normalizes_the_phone(self):
        response = self.client.post(REGISTER, register_payload(phone_number='+221 77 555 66 77'), format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(User.objects.filter(phone='+221775556677', username='+221775556677').exists())

    def test_invalid_phone_is_rejected(self):
        for bad in ['771234567', 'abc', '+22177']:
            with self.subTest(number=bad):
                response = self.client.post(REGISTER, register_payload(phone_number=bad), format='json')
                self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
                self.assertIn('phone_number', response.json())
        self.assertEqual(User.objects.count(), 0)

    def test_same_number_with_different_spacing_is_a_duplicate(self):
        self.client.post(REGISTER, register_payload(), format='json')
        response = self.client.post(REGISTER, register_payload(phone_number='+221 77 555 66 77'), format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(User.objects.count(), 1)

    def test_cannot_self_register_as_admin(self):
        response = self.client.post(REGISTER, register_payload(role='admin'), format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(User.objects.count(), 0)

    def test_role_defaults_to_farmer(self):
        self.client.post(REGISTER, register_payload(), format='json')
        self.assertEqual(User.objects.get().role, 'farmer')

    def test_weak_passwords_are_rejected(self):
        weak = {
            'trop court': 'Ab1#xy',
            'uniquement numérique': '2026741852963',
            'mot de passe courant': 'password',
            'proche du nom': 'fatousow',
        }
        for label, password in weak.items():
            with self.subTest(case=label):
                response = self.client.post(REGISTER, register_payload(password=password), format='json')
                self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
                self.assertIn('password', response.json())
        self.assertEqual(User.objects.count(), 0)

    def test_login_accepts_number_typed_with_separators(self):
        self.client.post(REGISTER, register_payload(), format='json')
        response = self.client.post(LOGIN, {'phone_number': '+221 77 555 66 77', 'password': STRONG}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.json())


class ChangePasswordTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='+221770800001', phone='+221770800001', password=STRONG, first_name='Ali')
        self.client = APIClient()
        self.refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.refresh.access_token}')

    def test_requires_authentication(self):
        response = APIClient().post(CHANGE_PASSWORD, {'old_password': STRONG, 'new_password': 'Autre#Mdp2027'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_wrong_current_password_is_rejected(self):
        response = self.client.post(CHANGE_PASSWORD, {'old_password': 'mauvais', 'new_password': 'Autre#Mdp2027'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('old_password', response.json())

    def test_weak_new_password_is_rejected(self):
        response = self.client.post(CHANGE_PASSWORD, {'old_password': STRONG, 'new_password': '12345678'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('new_password', response.json())

    def test_new_password_must_differ(self):
        response = self.client.post(CHANGE_PASSWORD, {'old_password': STRONG, 'new_password': STRONG}, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_success_changes_password_and_closes_every_session(self):
        other_session = RefreshToken.for_user(self.user)
        response = self.client.post(CHANGE_PASSWORD, {'old_password': STRONG, 'new_password': 'Autre#Mdp2027'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)

        anonymous = APIClient()
        old_login = anonymous.post(LOGIN, {'phone_number': '+221770800001', 'password': STRONG}, format='json')
        self.assertEqual(old_login.status_code, status.HTTP_401_UNAUTHORIZED)
        new_login = anonymous.post(LOGIN, {'phone_number': '+221770800001', 'password': 'Autre#Mdp2027'}, format='json')
        self.assertEqual(new_login.status_code, status.HTTP_200_OK)

        for token in (self.refresh, other_session):
            reuse = anonymous.post(REFRESH, {'refresh': str(token)}, format='json')
            self.assertEqual(reuse.status_code, status.HTTP_401_UNAUTHORIZED)


class ProfileIdentityTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='+221770900001', phone='+221770900001', password=STRONG, first_name='Ali', location='Thiès')
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def test_profile_patch_cannot_change_phone_or_role(self):
        response = self.client.patch('/api/users/me/', {'phone': '+221770999999', 'role': 'admin', 'location': 'Podor'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertEqual(self.user.phone, '+221770900001')
        self.assertEqual(self.user.role, 'farmer')
        self.assertEqual(self.user.location, 'Podor')
