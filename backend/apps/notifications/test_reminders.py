"""Cycle de vie des rappels : programmation, livraison unique, annulation, report, visibilité dans l'API."""
import datetime
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from apps.notifications import services
from apps.notifications.models import Notification

User = get_user_model()
HOUR = datetime.timedelta(hours=1)


def rows(response):
    data = response.json()
    return data['results'] if isinstance(data, dict) and 'results' in data else data


class ReminderServiceTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='rm1', phone='+221770500001', password='Motdepasse#2026')
        self.other = User.objects.create_user(username='rm2', phone='+221770500002', password='Motdepasse#2026')

    def reminder(self, delta, user=None, message='Arroser'):
        return Notification.objects.create(
            user=user or self.user, type='reminder', message=message, scheduled_for=timezone.now() + delta)

    def test_future_reminder_waits_and_is_not_delivered_early(self):
        reminder = self.reminder(2 * HOUR)
        self.assertFalse(reminder.is_sent)
        self.assertEqual(services.deliver_due_reminders(), 0)
        reminder.refresh_from_db()
        self.assertFalse(reminder.is_sent)

    def test_due_reminder_is_delivered_exactly_once(self):
        reminder = self.reminder(-5 * HOUR / 60)
        Notification.objects.filter(pk=reminder.pk).update(is_sent=False)
        with patch('apps.notifications.services.send_push_notification') as push:
            self.user.fcm_token = 'token'
            self.user.save()
            first = services.deliver_due_reminders()
            second = services.deliver_due_reminders()
        self.assertEqual((first, second), (1, 0))
        self.assertEqual(push.call_count, 1)
        reminder.refresh_from_db()
        self.assertTrue(reminder.is_sent)
        self.assertIsNotNone(reminder.sent_at)

    def test_cancelled_reminder_is_never_delivered(self):
        reminder = self.reminder(2 * HOUR)
        self.assertTrue(services.cancel_reminder(reminder))
        Notification.objects.filter(pk=reminder.pk).update(scheduled_for=timezone.now() - HOUR)
        self.assertEqual(services.deliver_due_reminders(), 0)
        reminder.refresh_from_db()
        self.assertFalse(reminder.is_sent)
        self.assertIsNotNone(reminder.cancelled_at)

    def test_cancel_is_refused_once_delivered_or_cancelled(self):
        reminder = self.reminder(2 * HOUR)
        self.assertTrue(services.cancel_reminder(reminder))
        self.assertFalse(services.cancel_reminder(reminder))
        delivered = self.reminder(2 * HOUR)
        Notification.objects.filter(pk=delivered.pk).update(is_sent=True)
        self.assertFalse(services.cancel_reminder(delivered))

    def test_reschedule_moves_a_pending_reminder_only_to_the_future(self):
        reminder = self.reminder(2 * HOUR)
        new_time = timezone.now() + 5 * HOUR
        self.assertTrue(services.reschedule_reminder(reminder, new_time))
        reminder.refresh_from_db()
        self.assertEqual(reminder.scheduled_for, new_time)
        self.assertFalse(services.reschedule_reminder(reminder, timezone.now() - HOUR))
        services.cancel_reminder(reminder)
        self.assertFalse(services.reschedule_reminder(reminder, new_time))

    def test_pending_reminders_are_scoped_to_the_user_and_ordered(self):
        later = self.reminder(5 * HOUR, message='Plus tard')
        sooner = self.reminder(1 * HOUR, message='Bientôt')
        self.reminder(3 * HOUR, user=self.other, message='Autre')
        cancelled = self.reminder(2 * HOUR, message='Annulé')
        services.cancel_reminder(cancelled)
        self.assertEqual(list(services.pending_reminders(self.user)), [sooner, later])

    def test_a_reminder_of_another_user_cannot_be_cancelled_through_a_stale_object(self):
        theirs = self.reminder(2 * HOUR, user=self.other)
        forged = Notification(pk=theirs.pk, user=self.user, type='reminder')
        self.assertFalse(services.cancel_reminder(forged))
        theirs.refresh_from_db()
        self.assertIsNone(theirs.cancelled_at)

    def test_management_command_delivers_due_reminders(self):
        due = self.reminder(-HOUR)
        Notification.objects.filter(pk=due.pk).update(is_sent=False)
        call_command('send_scheduled_reminders')
        due.refresh_from_db()
        self.assertTrue(due.is_sent)


class ReminderApiTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='ra1', phone='+221770500003', password='Motdepasse#2026')
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def test_list_hides_scheduled_and_cancelled_reminders(self):
        delivered = Notification.objects.create(user=self.user, type='info', message='Bienvenue')
        scheduled = Notification.objects.create(
            user=self.user, type='reminder', message='Demain', scheduled_for=timezone.now() + 10 * HOUR)
        cancelled = Notification.objects.create(
            user=self.user, type='reminder', message='Annulé', scheduled_for=timezone.now() + 10 * HOUR)
        services.cancel_reminder(cancelled)

        ids = {r['id'] for r in rows(self.client.get('/api/notifications/'))}
        self.assertEqual(ids, {str(delivered.pk)})

        scheduled_ids = {r['id'] for r in rows(self.client.get('/api/notifications/?scope=scheduled'))}
        self.assertEqual(scheduled_ids, {str(scheduled.pk)})

    def test_listing_delivers_what_is_due_without_any_scheduler(self):
        due = Notification.objects.create(
            user=self.user, type='reminder', message='Échu', scheduled_for=timezone.now() + HOUR)
        Notification.objects.filter(pk=due.pk).update(scheduled_for=timezone.now() - HOUR)

        ids = {r['id'] for r in rows(self.client.get('/api/notifications/'))}

        self.assertIn(str(due.pk), ids)
        due.refresh_from_db()
        self.assertTrue(due.is_sent)

    def test_mark_all_read_ignores_reminders_not_yet_delivered(self):
        scheduled = Notification.objects.create(
            user=self.user, type='reminder', message='Plus tard', scheduled_for=timezone.now() + 10 * HOUR)
        delivered = Notification.objects.create(user=self.user, type='info', message='Info')
        self.client.post('/api/notifications/mark-all-read/')
        scheduled.refresh_from_db()
        delivered.refresh_from_db()
        self.assertFalse(scheduled.is_read)
        self.assertTrue(delivered.is_read)

    def test_client_cannot_force_delivery_or_cancellation_fields(self):
        response = self.client.post('/api/notifications/', {
            'type': 'reminder', 'message': 'Piraté', 'scheduled_for': (timezone.now() + HOUR).isoformat(),
            'is_sent': True, 'cancelled_at': timezone.now().isoformat(),
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        created = Notification.objects.get(message='Piraté')
        self.assertFalse(created.is_sent)
        self.assertIsNone(created.cancelled_at)
