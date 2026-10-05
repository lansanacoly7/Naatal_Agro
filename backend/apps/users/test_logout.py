from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

User = get_user_model()

LOGOUT_URL = '/api/users/auth/logout/'
REFRESH_URL = '/api/users/auth/refresh/'


class LogoutAndRotationTests(TestCase):
    def setUp(self):
        self.ali = User.objects.create_user(username='+221770700001', phone='+221770700001', password='Motdepasse#2026')
        self.binta = User.objects.create_user(username='+221770700002', phone='+221770700002', password='Motdepasse#2026')
        self.refresh = RefreshToken.for_user(self.ali)
        self.client = APIClient()
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.refresh.access_token}')

    def test_logout_requires_authentication(self):
        response = APIClient().post(LOGOUT_URL, {'refresh': str(self.refresh)}, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_logout_invalidates_refresh_token(self):
        response = self.client.post(LOGOUT_URL, {'refresh': str(self.refresh)}, format='json')
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)

        reuse = APIClient().post(REFRESH_URL, {'refresh': str(self.refresh)}, format='json')
        self.assertEqual(reuse.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_logout_without_refresh_is_rejected(self):
        self.assertEqual(self.client.post(LOGOUT_URL, {}, format='json').status_code, status.HTTP_400_BAD_REQUEST)

    def test_logout_with_garbage_token_is_rejected(self):
        response = self.client.post(LOGOUT_URL, {'refresh': 'pas-un-jeton'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_cannot_logout_someone_elses_token(self):
        binta_refresh = RefreshToken.for_user(self.binta)
        response = self.client.post(LOGOUT_URL, {'refresh': str(binta_refresh)}, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        # Le jeton de Binta reste utilisable
        ok = APIClient().post(REFRESH_URL, {'refresh': str(binta_refresh)}, format='json')
        self.assertEqual(ok.status_code, status.HTTP_200_OK)

    def test_refresh_rotation_blacklists_the_previous_token(self):
        first = APIClient().post(REFRESH_URL, {'refresh': str(self.refresh)}, format='json')
        self.assertEqual(first.status_code, status.HTTP_200_OK)
        self.assertIn('refresh', first.json())

        replay = APIClient().post(REFRESH_URL, {'refresh': str(self.refresh)}, format='json')
        self.assertEqual(replay.status_code, status.HTTP_401_UNAUTHORIZED)
