"""Rattrapage du conseil de stockage : un conseil perdu (serveur arrêté, IA indisponible) est régénéré, sans harceler l'IA."""
import datetime
import io
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase
from django.utils import timezone

from apps.inventory import advice
from apps.inventory.models import StockItem

User = get_user_model()
CALL = 'apps.inventory.advice.call_llm'
MINUTE = datetime.timedelta(minutes=1)


class CatchUpTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='cu1', phone='+221770990001', password='Motdepasse#2026')
        self.now = timezone.now()

    def item(self, name='Mil', created_ago=10 * MINUTE, attempted_ago=None, advice_text=None):
        item = StockItem.objects.create(user=self.user, name=name, quantity=10, unit='kg', ai_storage_advice=advice_text)
        StockItem.objects.filter(pk=item.pk).update(
            created_at=self.now - created_ago,
            advice_attempted_at=self.now - attempted_ago if attempted_ago is not None else None)
        return item

    def pending(self):
        return [i.name for i in advice.items_awaiting_advice(self.now)]

    def test_item_without_advice_and_never_attempted_is_picked_up(self):
        self.item('Mil')
        self.assertEqual(self.pending(), ['Mil'])

    def test_recent_item_is_left_to_the_immediate_thread(self):
        self.item('Neuf', created_ago=datetime.timedelta(seconds=30))
        self.assertEqual(self.pending(), [])

    def test_item_that_already_has_advice_is_ignored(self):
        self.item('Avec', advice_text='Au sec.')
        self.assertEqual(self.pending(), [])

    def test_blank_advice_counts_as_missing(self):
        self.item('Vide', advice_text='')
        self.assertEqual(self.pending(), ['Vide'])

    def test_attempts_are_spaced_by_thirty_minutes(self):
        self.item('Récent', attempted_ago=5 * MINUTE)
        self.item('Ancien', attempted_ago=45 * MINUTE)
        self.assertEqual(self.pending(), ['Ancien'])

    def test_old_items_are_abandoned_after_three_days(self):
        self.item('Trop vieux', created_ago=datetime.timedelta(days=4))
        self.item('Encore bon', created_ago=datetime.timedelta(days=2))
        self.assertEqual(self.pending(), ['Encore bon'])

    def test_oldest_first(self):
        self.item('B', created_ago=20 * MINUTE)
        self.item('A', created_ago=60 * MINUTE)
        self.assertEqual(self.pending(), ['A', 'B'])

    def test_every_generation_notes_its_attempt_even_when_the_ai_is_down(self):
        item = self.item('Mil')
        with patch(CALL, return_value=None):
            self.assertIsNone(advice.generate_storage_advice(item.pk))
        item.refresh_from_db()
        self.assertIsNotNone(item.advice_attempted_at)
        self.assertEqual([i.name for i in advice.items_awaiting_advice()], [])  # pas de nouvelle tentative avant 30 minutes

    def test_command_fills_missing_advice_within_its_limit(self):
        for name in ('A', 'B', 'C', 'D'):
            self.item(name)
        out = io.StringIO()
        with patch(CALL, return_value='Stockez au sec.') as llm_call:
            call_command('fill_storage_advice', '--limit', '2', stdout=out)
        self.assertEqual(llm_call.call_count, 2)
        self.assertIn('2/2 conseil(s)', out.getvalue())
        self.assertEqual(StockItem.objects.filter(ai_storage_advice='Stockez au sec.').count(), 2)

    def test_command_with_the_ai_down_does_not_loop_on_the_same_items(self):
        self.item('Mil')
        out = io.StringIO()
        with patch(CALL, return_value=None) as llm_call:
            call_command('fill_storage_advice', stdout=out)
            call_command('fill_storage_advice', stdout=out)  # la minute suivante
        self.assertEqual(llm_call.call_count, 1)  # une seule tentative : la 2e exécution respecte le délai de 30 min
