from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from apps.agriculture.models import Crop

User = get_user_model()


class OptionalPaginationTests(TestCase):
    """La pagination est à la demande : sans paramètre, le format historique (tableau) est conservé."""

    def setUp(self):
        self.user = User.objects.create_user(username='+221770600001', phone='+221770600001', password='Motdepasse#2026')
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        for i in range(5):
            Crop.objects.create(
                user=self.user, name=f'Culture {i}', crop_type='Mil', planting_date='2026-06-01',
                expected_harvest_date='2026-10-01', area_size=1.0, location='Thiès',
            )

    def test_without_parameters_returns_plain_list(self):
        data = self.client.get('/api/agriculture/crops/').json()
        self.assertIsInstance(data, list)
        self.assertEqual(len(data), 5)

    def test_page_size_returns_paginated_envelope(self):
        data = self.client.get('/api/agriculture/crops/', {'page_size': 2}).json()
        self.assertEqual(data['count'], 5)
        self.assertEqual(len(data['results']), 2)
        self.assertIsNotNone(data['next'])
        self.assertIsNone(data['previous'])

    def test_pages_do_not_overlap_and_cover_everything(self):
        seen = []
        page = 1
        while True:
            data = self.client.get('/api/agriculture/crops/', {'page': page, 'page_size': 2}).json()
            seen += [crop['id'] for crop in data['results']]
            if not data['next']:
                break
            page += 1
        self.assertEqual(len(seen), 5)
        self.assertEqual(len(set(seen)), 5)

    def test_page_size_is_capped(self):
        data = self.client.get('/api/agriculture/crops/', {'page_size': 10000}).json()
        self.assertEqual(data['count'], 5)
        self.assertLessEqual(len(data['results']), 100)

    def test_page_out_of_range_returns_404(self):
        response = self.client.get('/api/agriculture/crops/', {'page': 99, 'page_size': 2})
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_pagination_keeps_user_isolation(self):
        other = User.objects.create_user(username='+221770600002', phone='+221770600002', password='Motdepasse#2026')
        Crop.objects.create(
            user=other, name='Autre', crop_type='Riz', planting_date='2026-06-01',
            expected_harvest_date='2026-10-01', area_size=1.0, location='Podor',
        )
        data = self.client.get('/api/agriculture/crops/', {'page_size': 50}).json()
        self.assertEqual(data['count'], 5)
