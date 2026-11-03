from unittest import mock

from django.test import TestCase


class HealthCheckTests(TestCase):
    def test_database_error_is_not_leaked(self):
        with mock.patch('core.views.connection.cursor', side_effect=Exception('secret host db.internal:5432')):
            response = self.client.get('/api/health/')
        self.assertEqual(response.status_code, 503)
        self.assertNotIn('secret', response.content.decode())
        self.assertEqual(response.json()['database'], 'error')
