import json

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from apps.agriculture import crop_calendar_sources as sources
from apps.agriculture.crop_calendar_loader import CALENDAR_FILE, load_crop_calendar, read_calendar
from apps.agriculture.models import CropCalendarEntry

User = get_user_model()


class CalendarDataTests(TestCase):
    """Le fichier du dépôt est la référence : on vérifie qu'il est cohérent et entièrement sourcé."""

    def setUp(self):
        self.windows = read_calendar()

    def test_every_window_has_a_known_source(self):
        for window in self.windows:
            self.assertIn(window['source_key'], sources.SOURCES, f"{window['crop_name']} : source inconnue")

    def test_every_window_has_a_known_zone_and_category(self):
        zones = {z['code'] for z in sources.ZONES} | {'all'}
        categories = {value for value, _ in CropCalendarEntry.CATEGORY_CHOICES}
        for window in self.windows:
            self.assertIn(window['zone'], zones)
            self.assertIn(window['category'], categories)

    def test_dates_are_real_calendar_dates(self):
        import calendar
        for window in self.windows:
            for name in ('sow', 'harvest'):
                span = window[name]
                if not span:
                    continue
                for month, day in ((span[0], span[1]), (span[2], span[3])):
                    self.assertTrue(1 <= month <= 12, window)
                    self.assertTrue(1 <= day <= calendar.monthrange(2024, month)[1], f"{window['crop_name']} : {month}/{day}")

    def test_a_window_without_dates_says_so_in_words_or_is_all_year(self):
        """Pas de ligne vide : soit des dates, soit « toute l'année », soit une période en toutes lettres."""
        for window in self.windows:
            has_dates = bool(window['sow'] or window['harvest'])
            self.assertTrue(has_dates or window['all_year'] or window['period_text'], window['crop_name'])

    def test_known_staples_match_the_fao_calendar(self):
        """Contrôle de quelques valeurs publiées par la FAO (mise à jour du 26/02/2021)."""
        def find(key, zone, label=''):
            return next(w for w in self.windows if w['crop_key'] == key and w['zone'] == zone and w['label'] == label)
        groundnut = find('arachide', 'bassin')
        self.assertEqual(groundnut['sow'], [6, 10, 7, 31])
        self.assertEqual(groundnut['harvest'], [9, 20, 11, 20])
        onion = find('oignon', 'niayes', 'Culture hâtive')
        self.assertEqual(onion['sow'], [9, 1, 10, 31])
        self.assertEqual(onion['harvest'], [12, 1, 2, 28])
        self.assertEqual(find('mil', 'bassin')['sow'], [4, 15, 5, 31])

    def test_fruit_trees_have_a_harvest_but_no_sowing(self):
        mango = next(w for w in self.windows if w['crop_key'] == 'mangue')
        self.assertIsNone(mango['sow'])
        self.assertEqual(mango['harvest'][:1], [6])
        self.assertEqual(mango['source_key'], 'cirad_mangue')

    def test_crops_without_a_source_are_not_in_the_file(self):
        keys = {w['crop_key'] for w in self.windows}
        for name in sources.UNDOCUMENTED:
            self.assertNotIn(name.lower(), keys, f"{name} n'a pas de source : il ne doit pas avoir de dates")

    def test_barley_and_black_pepper_are_left_out(self):
        keys = {w['crop_key'] for w in self.windows}
        self.assertFalse({'orge', 'poivre-noir', 'orge-orge'} & keys)

    def test_file_is_valid_json_with_windows(self):
        self.assertGreater(len(json.loads(CALENDAR_FILE.read_text(encoding='utf-8'))['windows']), 100)


class CalendarLoaderTests(TestCase):
    def test_migration_already_loaded_the_calendar(self):
        self.assertEqual(CropCalendarEntry.objects.count(), len(read_calendar()))

    def test_loading_twice_changes_nothing(self):
        before = CropCalendarEntry.objects.count()
        created, updated, skipped = load_crop_calendar(CropCalendarEntry)
        self.assertEqual(created, 0)
        self.assertEqual(CropCalendarEntry.objects.count(), before)

    def test_a_hand_corrected_window_survives_a_reload(self):
        entry = CropCalendarEntry.objects.filter(crop_key='tomate', zone='bassin').first()
        entry.notes = 'Corrigé par un technicien'
        entry.locally_edited = True
        entry.save()
        load_crop_calendar(CropCalendarEntry)
        entry.refresh_from_db()
        self.assertEqual(entry.notes, 'Corrigé par un technicien')
        load_crop_calendar(CropCalendarEntry, force=True)
        entry.refresh_from_db()
        self.assertNotEqual(entry.notes, 'Corrigé par un technicien')


class CalendarApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username='+221770500001', phone='+221770500001', password='Motdepasse#2026')

    def test_requires_authentication(self):
        self.assertEqual(self.client.get('/api/agriculture/calendar/').status_code, status.HTTP_401_UNAUTHORIZED)

    def test_returns_crops_zones_and_sources(self):
        self.client.force_authenticate(self.user)
        res = self.client.get('/api/agriculture/calendar/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual({z['code'] for z in res.data['zones']}, {z['code'] for z in sources.ZONES})
        self.assertGreaterEqual(len(res.data['crops']), 30)
        self.assertIn('fao', res.data['sources'])
        self.assertEqual(res.data['sources']['fao']['updated'], '2021-02-26')
        self.assertIn('Orange', res.data['undocumented'])
        self.assertEqual(res.data['region_zones']['Dakar'], ['niayes'])

    def test_each_crop_carries_windows_with_a_source(self):
        self.client.force_authenticate(self.user)
        crops = {c['key']: c for c in self.client.get('/api/agriculture/calendar/').data['crops']}
        tomato = crops['tomate']
        self.assertTrue(tomato['windows'])
        self.assertTrue(all(w['source'] == 'fao' for w in tomato['windows']))
        self.assertIsNotNone(next(w for w in crops['arachide']['windows'] if w['zone'] == 'bassin')['sow'])

    def test_only_sources_actually_used_are_returned(self):
        self.client.force_authenticate(self.user)
        used = {w['source'] for c in self.client.get('/api/agriculture/calendar/').data['crops'] for w in c['windows']}
        self.assertEqual(set(self.client.get('/api/agriculture/calendar/').data['sources']), used)
