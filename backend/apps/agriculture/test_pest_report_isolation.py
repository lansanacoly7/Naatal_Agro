"""Les signalements de ravageurs (lieu, description) ne sont lisibles que par leur auteur."""
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from apps.agriculture.models import PestReport

User = get_user_model()
URL = '/api/agriculture/pest-reports/'


class PestReportIsolationTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(username='pr1', phone='+221770700001', password='Motdepasse#2026')
        self.other = User.objects.create_user(username='pr2', phone='+221770700002', password='Motdepasse#2026')
        self.report = PestReport.objects.create(user=self.owner, pest_name='Chenille légionnaire', location='Thiès',
                                                description='Champ de mil derrière la mosquée')
        self.client = APIClient()
        self.client.force_authenticate(self.other)

    def results(self, response):
        data = response.data
        return data['results'] if isinstance(data, dict) and 'results' in data else data

    def test_list_only_returns_own_reports(self):
        mine = PestReport.objects.create(user=self.other, pest_name='Criquet', location='Kaolack')
        response = self.client.get(URL)
        self.assertEqual(response.status_code, 200)
        self.assertEqual([r['id'] for r in self.results(response)], [str(mine.id)])
        self.assertNotIn('mosquée', str(response.data))

    def test_detail_of_someone_elses_report_is_not_found(self):
        self.assertEqual(self.client.get(f'{URL}{self.report.id}/').status_code, 404)

    def test_other_users_cannot_modify_or_delete_it(self):
        self.assertEqual(self.client.patch(f'{URL}{self.report.id}/', {'location': 'Dakar'}, format='json').status_code, 404)
        self.assertEqual(self.client.delete(f'{URL}{self.report.id}/').status_code, 404)
        self.report.refresh_from_db()
        self.assertEqual(self.report.location, 'Thiès')

    def test_owner_keeps_full_access(self):
        owner = APIClient()
        owner.force_authenticate(self.owner)
        self.assertEqual(owner.get(f'{URL}{self.report.id}/').status_code, 200)
        created = owner.post(URL, {'pest_name': 'Mouche blanche', 'location': 'Thiès'}, format='json')
        self.assertEqual(created.status_code, 201)
        self.assertEqual(PestReport.objects.get(pk=created.data['id']).user, self.owner)

    def test_anonymous_gets_nothing(self):
        self.assertEqual(APIClient().get(URL).status_code, 401)
