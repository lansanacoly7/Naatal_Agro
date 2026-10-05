import re
from io import StringIO

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from apps.agriculture.guides_loader import GUIDE_FIELDS, read_guides
from apps.agriculture.models import AgronomicGuide

User = get_user_model()

LIST_URL = '/api/agriculture/guides/'
TEXT_FIELDS = ('summary', 'zones', 'calendar', 'soil_and_sowing', 'water_needs', 'fertilization',
               'harvest', 'yield_info')
EXPECTED_SLUGS = {'oignon', 'tomate-industrielle', 'arachide', 'mil', 'riz-irrigue'}
MARKER = re.compile(r'\[(\d+)\]')


class GuideContentTests(TestCase):
    """Garde-fous sur le contenu du dépôt : chaque fiche doit être traçable jusqu'à ses sources."""

    def setUp(self):
        self.guides = read_guides()

    def test_the_five_priority_crops_are_present(self):
        self.assertEqual({g['slug'] for g in self.guides}, EXPECTED_SLUGS)

    def test_every_guide_defines_every_field(self):
        for guide in self.guides:
            for field in GUIDE_FIELDS:
                self.assertIn(field, guide, f"{guide['slug']} : champ « {field} » absent")

    def test_every_guide_cites_at_least_one_complete_source(self):
        for guide in self.guides:
            self.assertTrue(guide['sources'], f"{guide['slug']} : aucune source")
            for source in guide['sources']:
                self.assertTrue(source['title'] and source['publisher'], f"{guide['slug']} : source incomplète")
                self.assertTrue(source['url'].startswith('http'), f"{guide['slug']} : URL invalide")

    def test_every_marker_points_to_an_existing_source(self):
        for guide in self.guides:
            texts = [guide[f] for f in TEXT_FIELDS] + [p['advice'] for p in guide['pests_diseases']]
            for text in texts:
                for marker in MARKER.findall(text):
                    self.assertLessEqual(int(marker), len(guide['sources']),
                                         f"{guide['slug']} : repère [{marker}] sans source")

    def test_every_filled_section_carries_a_source_marker(self):
        for guide in self.guides:
            for field in TEXT_FIELDS:
                text = guide[field]
                if text:
                    self.assertTrue(MARKER.search(text), f"{guide['slug']}.{field} : contenu sans repère de source")
            for pest in guide['pests_diseases']:
                self.assertTrue(MARKER.search(pest['advice']), f"{guide['slug']} : {pest['name']} sans repère de source")

    def test_every_guide_states_its_limitations(self):
        for guide in self.guides:
            self.assertTrue(guide['limitations'].strip(), f"{guide['slug']} : limites non précisées")

    def test_cycle_bounds_are_coherent(self):
        for guide in self.guides:
            low, high = guide['cycle_days_min'], guide['cycle_days_max']
            self.assertEqual(low is None, high is None, guide['slug'])
            if low is not None:
                self.assertLessEqual(low, high, guide['slug'])


class GuideLoadingTests(TestCase):
    def test_migration_loads_the_guides(self):
        self.assertEqual(AgronomicGuide.objects.count(), len(EXPECTED_SLUGS))

    def test_command_is_idempotent_and_restores_edits(self):
        AgronomicGuide.objects.filter(slug='mil').update(summary='texte modifié')
        out = StringIO()
        call_command('load_agronomic_guides', stdout=out)
        call_command('load_agronomic_guides', stdout=out)
        self.assertEqual(AgronomicGuide.objects.count(), len(EXPECTED_SLUGS))
        self.assertNotEqual(AgronomicGuide.objects.get(slug='mil').summary, 'texte modifié')
        self.assertIn('fiche(s) agronomique(s) chargée(s)', out.getvalue())


class GuideApiTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='+221770950001', phone='+221770950001', password='Motdepasse#2026')
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def test_requires_authentication(self):
        self.assertEqual(APIClient().get(LIST_URL).status_code, status.HTTP_401_UNAUTHORIZED)

    def test_list_returns_all_guides_with_sources(self):
        data = self.client.get(LIST_URL).json()
        self.assertEqual({g['slug'] for g in data}, EXPECTED_SLUGS)
        self.assertTrue(all(g['sources'] for g in data))

    def test_detail_by_slug(self):
        data = self.client.get(f'{LIST_URL}arachide/').json()
        self.assertEqual(data['name'], 'Arachide')
        self.assertEqual((data['cycle_days_min'], data['cycle_days_max']), (80, 125))
        self.assertTrue(any(p['name'] == 'Rosette' for p in data['pests_diseases']))

    def test_unknown_slug_is_404(self):
        self.assertEqual(self.client.get(f'{LIST_URL}manioc/').status_code, status.HTTP_404_NOT_FOUND)

    def test_filter_by_category(self):
        data = self.client.get(LIST_URL, {'category': 'cereale'}).json()
        self.assertEqual({g['slug'] for g in data}, {'mil', 'riz-irrigue'})

    def test_search_by_name_and_scientific_name(self):
        self.assertEqual([g['slug'] for g in self.client.get(LIST_URL, {'search': 'oignon'}).json()], ['oignon'])
        self.assertEqual([g['slug'] for g in self.client.get(LIST_URL, {'search': 'pennisetum'}).json()], ['mil'])

    def test_guides_are_read_only(self):
        response = self.client.post(LIST_URL, {'slug': 'x', 'name': 'x'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_405_METHOD_NOT_ALLOWED)
        self.assertEqual(self.client.delete(f'{LIST_URL}mil/').status_code, status.HTTP_405_METHOD_NOT_ALLOWED)

    def test_pagination_is_available(self):
        data = self.client.get(LIST_URL, {'page_size': 2}).json()
        self.assertEqual(data['count'], len(EXPECTED_SLUGS))
        self.assertEqual(len(data['results']), 2)
