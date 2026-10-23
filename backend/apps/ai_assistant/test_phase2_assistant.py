"""
Phase 2 — l'assistant exploite les données manquantes : catégories de dépenses, correction de stock et historique des
mouvements, rappels consultables / modifiables / annulables. Les réponses de consultation viennent de la base, jamais du LLM.
"""
import datetime
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from apps.agriculture.models import Crop
from apps.ai_assistant.actions import detect_action_intent
from apps.ai_assistant.models import AIConversation
from apps.finances.models import Transaction
from apps.inventory.models import StockItem, StockMovement
from apps.inventory.services import create_stock_item
from apps.notifications.models import Notification

User = get_user_model()
HOUR = datetime.timedelta(hours=1)


class AssistantPhase2Base(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='p2a', phone='+221770600001', password='Motdepasse#2026')
        self.other = User.objects.create_user(username='p2b', phone='+221770600002', password='Motdepasse#2026')
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.conv = AIConversation.objects.create(user=self.user, title="Phase 2")

    def ask(self, text):
        return self.client.post('/api/ai/ask/', {'query': text, 'conversation_id': str(self.conv.id)}, format='json')

    def confirm(self, proposal):
        return self.client.post('/api/ai/actions/execute/',
                                {'interaction_id': proposal.data['id'], 'decision': 'confirm'}, format='json')

    def reminder(self, message, delta, user=None):
        return Notification.objects.create(
            user=user or self.user, type='reminder', message=message, scheduled_for=timezone.now() + delta)

    def crop(self, name):
        today = datetime.date.today()
        return Crop.objects.create(user=self.user, name=name, crop_type='Céréale', planting_date=today,
                                   expected_harvest_date=today, area_size=1.0, location='Thiès')


class ExpenseCategoryTests(AssistantPhase2Base):
    def test_proposal_shows_the_category_and_execution_stores_it(self):
        proposal = self.ask("J'ai dépensé 15000 FCFA pour de l'engrais urée")
        self.assertEqual(proposal.data['action_data']['parameters']['category'], 'engrais')
        self.assertIn("Engrais et amendements", proposal.data['response'])
        self.assertEqual(Transaction.objects.count(), 0)

        done = self.confirm(proposal)
        self.assertEqual(done.data['action_data']['status'], 'executed')
        self.assertIn("catégorie", done.data['response'])
        self.assertEqual(Transaction.objects.get().category, 'engrais')

    def test_unrecognised_label_is_flagged_not_guessed(self):
        proposal = self.ask("J'ai dépensé 8000 FCFA pour un cadeau")
        self.assertEqual(proposal.data['action_data']['parameters']['category'], 'autre')
        self.assertIn("Catégorie non identifiée", proposal.data['response'])
        self.assertTrue(proposal.data['action_data']['warnings'])

    def test_expense_is_linked_to_the_crop_named_in_the_label(self):
        mil = self.crop('Mil')
        proposal = self.ask("J'ai dépensé 12000 FCFA pour de l'engrais sur le mil")
        params = proposal.data['action_data']['parameters']
        self.assertEqual(params['crop_id'], str(mil.pk))
        self.assertIn("culture : Mil", proposal.data['response'])
        self.confirm(proposal)
        self.assertEqual(Transaction.objects.get().crop, mil)

    def test_a_crop_of_another_user_is_never_linked(self):
        Crop.objects.create(user=self.other, name='Riz', crop_type='Céréale', planting_date=datetime.date.today(),
                            expected_harvest_date=datetime.date.today(), area_size=1.0, location='Saint-Louis')
        proposal = self.ask("J'ai dépensé 12000 FCFA pour de l'engrais sur le riz")
        self.assertNotIn('crop_id', proposal.data['action_data']['parameters'])

    def test_ambiguous_crop_mention_links_nothing(self):
        self.crop('Mil')
        self.crop('Maïs')
        proposal = self.ask("J'ai dépensé 12000 FCFA pour de l'engrais pour le mil et le maïs")
        self.assertNotIn('crop_id', proposal.data['action_data']['parameters'])


class StockCorrectionTests(AssistantPhase2Base):
    def test_correction_summary_shows_before_and_after(self):
        create_stock_item(self.user, 'Mil', 50, 'sacs', reason='manual')
        proposal = self.ask("Mets le stock de mil à 40 sacs")
        action = proposal.data['action_data']
        self.assertEqual((action['action_type'], action['parameters']['operation']), ('update_stock', 'set'))
        self.assertIn("50 → 40", proposal.data['response'])
        self.assertEqual(StockItem.objects.get().quantity, 50.0)

    def test_confirmed_correction_is_logged_with_its_reason(self):
        create_stock_item(self.user, 'Mil', 50, 'sacs', reason='manual')
        self.confirm(self.ask("Corrige le stock de mil à 40 sacs"))
        self.assertEqual(StockItem.objects.get().quantity, 40.0)
        movement = StockMovement.objects.filter(reason='correction').get()
        self.assertEqual((movement.movement_type, movement.quantity, movement.balance_after), ('adjustment', 10.0, 40.0))

    def test_correction_can_bring_the_stock_to_zero(self):
        create_stock_item(self.user, 'Mil', 50, 'sacs', reason='manual')
        done = self.confirm(self.ask("Mets le stock de mil à 0 sacs"))
        self.assertEqual(done.data['action_data']['status'], 'executed')
        self.assertEqual(StockItem.objects.get().quantity, 0.0)

    def test_correction_of_an_unknown_item_creates_it_and_says_so(self):
        proposal = self.ask("Mets le stock de niébé à 12 sacs")
        self.assertIn("Création du stock", proposal.data['response'])
        self.confirm(proposal)
        self.assertEqual(StockItem.objects.get().name, 'Niébé')
        self.assertEqual(StockMovement.objects.get().reason, 'manual')

    def test_adding_stock_is_logged_as_a_purchase(self):
        create_stock_item(self.user, 'Mil', 10, 'sacs', reason='manual')
        self.confirm(self.ask("J'ai reçu 20 sacs de mil en stock"))
        self.assertEqual(StockItem.objects.get().quantity, 30.0)
        self.assertEqual(StockMovement.objects.filter(reason='purchase').get().quantity, 20.0)

    def test_sale_is_logged_with_the_sale_that_explains_it(self):
        create_stock_item(self.user, 'Riz', 100, 'sacs', reason='manual')
        self.confirm(self.ask("J'ai vendu 25 sacs de riz à 12000 FCFA"))
        movement = StockMovement.objects.filter(reason='sale').get()
        self.assertEqual((movement.quantity, movement.balance_after), (25.0, 75.0))
        self.assertIsNotNone(movement.sale)


class StockHistoryQueryTests(AssistantPhase2Base):
    @patch('apps.ai_assistant.views.answer_question')
    def test_history_is_answered_from_the_database_without_the_llm(self, llm):
        item = create_stock_item(self.user, 'Mil', 50, 'sacs', reason='harvest', note='Récolte')
        from apps.inventory.services import change_stock
        change_stock(item, 40, reason='sale')

        response = self.ask("Montre-moi l'historique des mouvements de stock")

        llm.assert_not_called()
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['origin'], 'database')
        self.assertIn("−10 sacs", response.data['response'])
        self.assertIn("+50 sacs", response.data['response'])
        self.assertIn("solde 40 sacs", response.data['response'])

    @patch('apps.ai_assistant.views.answer_question')
    def test_history_can_be_filtered_by_product(self, llm):
        create_stock_item(self.user, 'Mil', 50, 'sacs', reason='manual')
        create_stock_item(self.user, 'Riz', 7, 'sacs', reason='manual')
        response = self.ask("historique du stock de riz")
        self.assertIn("Riz", response.data['response'])
        self.assertNotIn("Mil", response.data['response'])

    @patch('apps.ai_assistant.views.answer_question')
    def test_history_never_shows_another_users_movements(self, llm):
        create_stock_item(self.other, 'Secret', 999, 'kg', reason='manual')
        response = self.ask("mouvements de stock")
        self.assertNotIn("Secret", response.data['response'])
        self.assertIn("Aucun mouvement", response.data['response'])

    @patch('apps.ai_assistant.views.answer_question')
    def test_unrelated_questions_still_reach_the_llm(self, llm):
        llm.return_value = {'answer': 'Réponse du modèle', 'origin': 'general', 'sources': [], 'suggestions': []}
        response = self.ask("Comment traiter le mildiou sur la tomate ?")
        llm.assert_called_once()
        self.assertEqual(response.data['response'], 'Réponse du modèle')


class ReminderCreationTests(AssistantPhase2Base):
    def test_explicit_time_creates_a_proposal_without_warning(self):
        proposal = self.ask("Rappelle-moi d'arroser les piments demain à 7h")
        action = proposal.data['action_data']
        self.assertEqual(action['status'], 'pending_confirmation')
        self.assertFalse(action['parameters']['time_defaulted'])
        self.assertEqual(action['warnings'], [])
        self.assertEqual(Notification.objects.count(), 0)

    def test_missing_time_is_declared_not_hidden(self):
        proposal = self.ask("Rappelle-moi d'arroser les piments demain")
        action = proposal.data['action_data']
        self.assertTrue(action['parameters']['time_defaulted'])
        self.assertIn("Aucune heure précisée", proposal.data['response'])

    def test_no_schedule_at_all_triggers_a_question_not_a_guess(self):
        question = self.ask("Rappelle-moi d'arroser les piments")
        self.assertEqual(question.data['action_data'], {'kind': 'question'})
        self.assertIn("Pour quand", question.data['response'])
        self.assertEqual(Notification.objects.count(), 0)
        proposal = self.ask("demain à 7h")
        action = proposal.data['action_data']
        self.assertEqual(action['status'], 'pending_confirmation')
        self.assertFalse(action['parameters']['time_defaulted'])
        self.assertEqual(Notification.objects.count(), 0)

    def test_past_time_is_refused_with_an_explanation(self):
        past = (timezone.now() - 3 * HOUR)
        with patch('apps.ai_assistant.actions.parse_schedule') as parse:
            from apps.ai_assistant.scheduling import Schedule
            parse.return_value = Schedule(past, time_defaulted=False)
            response = self.ask("Rappelle-moi d'arroser aujourd'hui à 13h")
        self.assertFalse(response.data['action_data'])
        self.assertIn("déjà passée", response.data['response'])
        self.assertEqual(Notification.objects.count(), 0)

    def test_confirmed_reminder_is_scheduled_not_sent(self):
        done = self.confirm(self.ask("Rappelle-moi d'arroser les piments demain à 7h"))
        self.assertEqual(done.data['action_data']['status'], 'executed')
        reminder = Notification.objects.get()
        self.assertFalse(reminder.is_sent)
        self.assertEqual(timezone.localtime(reminder.scheduled_for).hour, 7)
        self.assertEqual(reminder.message, "Arroser les piments")

    def test_asking_for_a_reminder_does_not_trigger_expense_or_sale_parsing(self):
        intent = detect_action_intent("Rappelle-moi d'acheter 3 sacs d'engrais à 15000 FCFA demain")
        self.assertEqual(intent['action_type'], 'create_reminder')


class ReminderConsultCancelUpdateTests(AssistantPhase2Base):
    @patch('apps.ai_assistant.views.answer_question')
    def test_listing_shows_only_my_upcoming_reminders(self, llm):
        self.reminder("Arroser les piments", 20 * HOUR)
        self.reminder("Traiter les tomates", 30 * HOUR)
        self.reminder("Secret d'un autre", 5 * HOUR, user=self.other)
        done = self.reminder("Déjà passé", -HOUR)
        Notification.objects.filter(pk=done.pk).update(is_sent=True)

        response = self.ask("Quels sont mes rappels ?")

        llm.assert_not_called()
        text = response.data['response']
        self.assertIn("Arroser les piments", text)
        self.assertIn("Traiter les tomates", text)
        self.assertNotIn("Secret", text)
        self.assertNotIn("Déjà passé", text)

    @patch('apps.ai_assistant.views.answer_question')
    def test_listing_with_no_reminder_says_so(self, llm):
        response = self.ask("mes rappels")
        self.assertIn("aucun rappel", response.data['response'].lower())

    def test_single_match_is_cancelled_after_confirmation(self):
        target = self.reminder("Arroser les piments", 20 * HOUR)
        other_reminder = self.reminder("Traiter les tomates", 30 * HOUR)

        proposal = self.ask("Annule mon rappel d'arroser les piments")
        self.assertEqual(proposal.data['action_data']['action_type'], 'cancel_reminder')
        self.assertIn("Arroser les piments", proposal.data['response'])
        target.refresh_from_db()
        self.assertIsNone(target.cancelled_at)  # rien n'est annulé avant confirmation

        done = self.confirm(proposal)
        self.assertEqual(done.data['action_data']['status'], 'executed')
        target.refresh_from_db()
        other_reminder.refresh_from_db()
        self.assertIsNotNone(target.cancelled_at)
        self.assertIsNone(other_reminder.cancelled_at)

    def test_several_matches_ask_for_precision_and_cancel_nothing(self):
        first = self.reminder("Arroser les piments", 20 * HOUR)
        second = self.reminder("Arroser les tomates", 30 * HOUR)
        response = self.ask("Annule mon rappel d'arroser")
        self.assertFalse(response.data['action_data'])
        self.assertIn("Plusieurs rappels", response.data['response'])
        self.assertIn("1. Arroser les piments", response.data['response'])
        self.assertIn("2. Arroser les tomates", response.data['response'])
        first.refresh_from_db()
        second.refresh_from_db()
        self.assertIsNone(first.cancelled_at)
        self.assertIsNone(second.cancelled_at)

    def test_no_match_is_reported(self):
        self.reminder("Arroser les piments", 20 * HOUR)
        response = self.ask("Annule mon rappel de récolter le maïs")
        self.assertIn("Aucun rappel à venir ne correspond", response.data['response'])

    def test_another_users_reminder_is_invisible_to_cancellation(self):
        theirs = self.reminder("Arroser les piments", 20 * HOUR, user=self.other)
        response = self.ask("Annule mon rappel d'arroser les piments")
        self.assertIn("Aucun rappel à venir ne correspond", response.data['response'])
        theirs.refresh_from_db()
        self.assertIsNone(theirs.cancelled_at)

    def test_reminder_changed_between_proposal_and_confirmation_is_not_cancelled_twice(self):
        target = self.reminder("Arroser les piments", 20 * HOUR)
        proposal = self.ask("Annule mon rappel d'arroser les piments")
        Notification.objects.filter(pk=target.pk).update(is_sent=True)  # délivré entre-temps
        done = self.confirm(proposal)
        self.assertEqual(done.data['action_data']['status'], 'failed')
        self.assertEqual(done.data['action_data']['result']['error_code'], 'reminder_not_pending')
        target.refresh_from_db()
        self.assertIsNone(target.cancelled_at)

    def test_update_moves_the_reminder_after_confirmation(self):
        target = self.reminder("Arroser les piments", 20 * HOUR)
        proposal = self.ask("Décale mon rappel d'arroser les piments à après-demain 6h")
        self.assertEqual(proposal.data['action_data']['action_type'], 'update_reminder')
        self.assertIn("→", proposal.data['response'])
        target.refresh_from_db()
        old_time = target.scheduled_for

        done = self.confirm(proposal)
        self.assertEqual(done.data['action_data']['status'], 'executed')
        target.refresh_from_db()
        self.assertNotEqual(target.scheduled_for, old_time)
        self.assertEqual(timezone.localtime(target.scheduled_for).hour, 6)
        self.assertFalse(target.is_sent)

    def test_update_without_understandable_time_asks_for_it(self):
        target = self.reminder("Arroser les piments", 20 * HOUR)
        response = self.ask("Décale mon rappel d'arroser les piments à plus tard")
        self.assertFalse(response.data['action_data'])
        self.assertIn("nouvelle échéance", response.data['response'])
        target.refresh_from_db()
        self.assertEqual(Notification.objects.get().scheduled_for, target.scheduled_for)

    def test_update_to_a_past_time_is_refused(self):
        self.reminder("Arroser les piments", 20 * HOUR)
        from apps.ai_assistant.scheduling import Schedule
        with patch('apps.ai_assistant.actions.parse_schedule',
                   return_value=Schedule(timezone.now() - 2 * HOUR, time_defaulted=False)):
            response = self.ask("Décale mon rappel d'arroser les piments à hier 7h")
        self.assertFalse(response.data['action_data'])
        self.assertIn("déjà passée", response.data['response'])

    def test_listing_phrase_is_not_mistaken_for_a_reminder_creation(self):
        intent = detect_action_intent("Montre mon rappel d'arroser", user=self.user)
        self.assertFalse(intent.get('has_intent'))
