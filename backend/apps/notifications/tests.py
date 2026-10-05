from unittest.mock import patch
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from apps.notifications.models import Notification

User = get_user_model()


class NotificationTests(TestCase):
    def setUp(self):
        self.ali = User.objects.create_user(username='+221770300001', phone='+221770300001', password='Motdepasse#2026')
        self.binta = User.objects.create_user(username='+221770300002', phone='+221770300002', password='Motdepasse#2026')
        self.client = APIClient()
        self.client.force_authenticate(self.ali)

    def test_requires_authentication(self):
        self.assertEqual(APIClient().get('/api/notifications/').status_code, status.HTTP_401_UNAUTHORIZED)

    def test_list_only_returns_own_notifications(self):
        Notification.objects.create(user=self.ali, type='weather', message='Pluie demain')
        Notification.objects.create(user=self.binta, type='alert', message='Privé')
        messages = [n['message'] for n in self.client.get('/api/notifications/').json()]
        self.assertEqual(messages, ['Pluie demain'])

    def test_mark_as_read(self):
        notif = Notification.objects.create(user=self.ali, type='crop', message='Arroser')
        response = self.client.post(f'/api/notifications/{notif.id}/read/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        notif.refresh_from_db()
        self.assertTrue(notif.is_read)

    def test_cannot_mark_foreign_notification_as_read(self):
        notif = Notification.objects.create(user=self.binta, type='crop', message='Privé')
        self.assertEqual(self.client.post(f'/api/notifications/{notif.id}/read/').status_code, status.HTTP_404_NOT_FOUND)
        notif.refresh_from_db()
        self.assertFalse(notif.is_read)

    @patch('apps.notifications.models.send_push_notification')
    def test_push_is_sent_only_when_user_has_fcm_token(self, push):
        Notification.objects.create(user=self.ali, type='alert', message='Sans token')
        push.assert_not_called()
        self.ali.fcm_token = 'token-abc'
        self.ali.save()
        notif = Notification.objects.create(user=self.ali, type='alert', message='Avec token')
        push.assert_called_once()
        self.assertEqual(push.call_args.kwargs['fcm_token'], 'token-abc')
        self.assertEqual(push.call_args.kwargs['data']['notification_id'], str(notif.id))
