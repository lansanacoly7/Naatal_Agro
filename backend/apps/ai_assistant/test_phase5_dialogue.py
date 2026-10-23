"""
Phase 5 — conversation : questions de précision (remplissage d'un brouillon), mémoire du sujet, suivis courts,
analyses « dernières ventes / ce produit » et calibrage de la longueur. Rien n'est écrit avant la confirmation.
"""
import datetime

from django.utils import timezone

from apps.ai_assistant import dialogue
from apps.ai_assistant.analysis_answers import detect_analysis_intent, memory_of, resolve_followup
from apps.ai_assistant.models import AIConversation
from apps.ai_assistant.services import ANSWER_STYLES, answer_style
from apps.ai_assistant.test_phase2_assistant import AssistantPhase2Base
from apps.finances.models import Sale, Transaction
from apps.inventory.models import StockItem
from apps.inventory.services import create_stock_item
from apps.notifications.models import Notification


class DialogueBase(AssistantPhase2Base):
    def reply_kind(self, response):
        return (response.data.get('action_data') or {}).get('kind')

    def assertAsked(self, response, fragment):
        self.assertEqual(self.reply_kind(response), 'question', response.data['response'])
        self.assertIn(fragment, response.data['response'])

    def assertNothingWritten(self):
        self.assertEqual(Sale.objects.count(), 0)
        self.assertEqual(Transaction.objects.count(), 0)
        self.assertEqual(Notification.objects.count(), 0)


class SaleDraftTests(DialogueBase):
    def test_spec_example_leads_to_questions_then_a_single_proposal(self):
        create_stock_item(self.user, 'Mil', 100, 'sac', reason='manual')
        first = self.ask("J'ai vendu une partie de ma récolte. Aide-moi à mettre mes informations à jour.")
        self.assertEqual(self.reply_kind(first), 'question')
        self.assertNothingWritten()

        second = self.ask("du mil")
        self.assertEqual(self.reply_kind(second), 'question')
        third = self.ask("20 sacs")
        self.assertEqual(self.reply_kind(third), 'question')
        proposal = self.ask("15000 le sac")
        action = proposal.data['action_data']
        self.assertEqual(action['status'], 'pending_confirmation')
        self.assertEqual(action['parameters']['quantity'], 20)
        self.assertEqual(action['parameters']['price_per_unit'], 15000)
        self.assertNothingWritten()

        done = self.confirm(proposal)
        self.assertEqual(done.data['action_data']['status'], 'executed')
        self.assertEqual(Sale.objects.count(), 1)
        self.assertEqual(StockItem.objects.get(user=self.user, name='Mil').quantity, 80)

    def test_complete_sentence_goes_straight_to_a_proposal(self):
        create_stock_item(self.user, 'Mil', 100, 'sac', reason='manual')
        proposal = self.ask("J'ai vendu 10 sacs de mil à 15000")
        self.assertEqual(proposal.data['action_data']['status'], 'pending_confirmation')

    def test_a_topic_change_abandons_the_draft_without_writing(self):
        self.ask("J'ai vendu du mil")
        response = self.ask("Rappelle-moi d'arroser les piments demain à 7h")
        self.assertEqual(response.data['action_data']['action_type'], 'create_reminder')
        self.assertEqual(Sale.objects.count(), 0)

    def test_cancelling_a_draft(self):
        self.ask("J'ai vendu du mil")
        response = self.ask("annule")
        self.assertNotEqual(self.reply_kind(response), 'question')
        self.assertNothingWritten()
        self.assertIsNone(dialogue.active_draft(AIConversation.objects.get(pk=self.conv.pk)))

    def test_repeated_unusable_answers_end_the_dialogue(self):
        self.ask("J'ai vendu du mil")
        self.assertEqual(self.reply_kind(self.ask("hmm")), 'question')
        self.assertEqual(self.reply_kind(self.ask("je ne sais pas")), 'question')
        response = self.ask("euh")
        self.assertNotEqual(self.reply_kind(response), 'question')
        self.assertIn("Rien n'a été enregistré", response.data['response'])
        self.assertNothingWritten()

    def test_an_expired_draft_is_not_resumed(self):
        self.ask("J'ai vendu du mil")
        conversation = AIConversation.objects.get(pk=self.conv.pk)
        state = dict(conversation.state)
        state['draft'] = {**state['draft'], 'expires_at': (timezone.now() - datetime.timedelta(minutes=1)).isoformat()}
        conversation.state = state
        conversation.save(update_fields=['state'])
        self.assertIsNone(dialogue.active_draft(AIConversation.objects.get(pk=self.conv.pk)))


class OtherDraftTests(DialogueBase):
    def test_expense_without_amount_then_amount(self):
        first = self.ask("J'ai payé du carburant")
        self.assertEqual(self.reply_kind(first), 'question')
        proposal = self.ask("quinze mille")
        action = proposal.data['action_data']
        self.assertEqual(action['status'], 'pending_confirmation')
        self.assertEqual(action['parameters']['amount'], 15000)
        self.assertEqual(Transaction.objects.count(), 0)

    def test_stock_addition_reuses_the_known_unit(self):
        create_stock_item(self.user, 'Mil', 10, 'sac', reason='manual')
        first = self.ask("J'ai reçu du mil en stock")
        self.assertEqual(self.reply_kind(first), 'question')
        proposal = self.ask("30")
        action = proposal.data['action_data']
        self.assertEqual(action['status'], 'pending_confirmation')
        self.assertEqual(action['parameters']['unit'], 'sac')

    def test_reminder_without_time_asks_when(self):
        question = self.ask("Rappelle-moi d'arroser les piments")
        self.assertAsked(question, "Pour quand")
        proposal = self.ask("demain à 7h")
        self.assertEqual(proposal.data['action_data']['status'], 'pending_confirmation')
        self.assertNothingWritten()


class FollowUpTests(DialogueBase):
    def sale(self, name, quantity, price, days_ago=0):
        return Sale.objects.create(user=self.user, product_name=name, quantity_sold=quantity, price_per_unit=price,
                                   date=timezone.localdate() - datetime.timedelta(days=days_ago))

    def test_period_followup_reuses_the_previous_analysis(self):
        self.sale('Mil', 5, 1000)
        self.sale('Mil', 3, 1000, days_ago=35)
        first = self.ask("Quel est mon bilan ce mois ?")
        self.assertIn("Bilan", first.data['response'])
        follow = self.ask("Et le mois dernier ?")
        self.assertIn("Bilan", follow.data['response'])
        self.assertIn("mois dernier", follow.data['response'].lower())

    def test_product_followup_for_stock(self):
        create_stock_item(self.user, 'Mil', 40, 'sac', reason='manual')
        create_stock_item(self.user, 'Arachide', 12, 'sac', reason='manual')
        self.ask("Combien il me reste de mil ?")
        follow = self.ask("Et l'arachide ?")
        self.assertIn("Arachide", follow.data['response'])

    def test_this_product_refers_to_the_last_one(self):
        create_stock_item(self.user, 'Mil', 40, 'sac', reason='manual')
        self.ask("Combien il me reste de mil ?")
        follow = self.ask("Combien il m'en reste ?")
        self.assertIn("Mil", follow.data['response'])

    def test_this_product_without_context_asks_which_one(self):
        response = self.ask("Combien j'ai vendu de ce produit ?")
        self.assertIn("De quel produit", response.data['response'])

    def test_recent_sales_and_expenses(self):
        self.sale('Mil', 5, 1000)
        Transaction.objects.create(user=self.user, transaction_type='expense', amount=5000, description='Carburant',
                                   category='carburant', date=timezone.localdate())
        sales = self.ask("Montre mes dernières ventes")
        self.assertIn("Mil", sales.data['response'])
        expenses = self.ask("Mes dernières dépenses")
        self.assertIn("Carburant", expenses.data['response'])


class IntentUnitTests(DialogueBase):
    def test_followup_needs_a_previous_analysis(self):
        self.assertIsNone(resolve_followup("Et le mois dernier ?", self.user, {}))

    def test_followup_ignores_long_or_advice_sentences(self):
        last = {'analysis': {'kind': 'finance', 'period_code': 'current_month', 'explicit_period': True}}
        self.assertIsNone(resolve_followup("Comment améliorer mes marges le mois dernier ?", self.user, last))

    def test_memory_of_keeps_kind_and_period(self):
        intent = {'kind': 'finance', 'period_code': 'last_month', 'explicit_period': True}
        self.assertEqual(memory_of(intent, {})['analysis']['period_code'], 'last_month')
        self.assertEqual(memory_of({'kind': 'ask_product'}, {}), {})

    def test_advice_is_never_intercepted(self):
        self.assertIsNone(detect_analysis_intent("Comment augmenter mes ventes de mil ?", self.user))


class StyleTests(DialogueBase):
    def test_style_detection(self):
        self.assertEqual(answer_style("Dis-moi vite, quand semer le mil ?"), 'brief')
        self.assertEqual(answer_style("Explique-moi en détail le compostage"), 'detailed')
        self.assertEqual(answer_style("Comment traiter le mildiou ?"), 'normal')

    def test_longer_answers_get_more_room(self):
        self.assertLess(ANSWER_STYLES['brief'][1], ANSWER_STYLES['normal'][1])
        self.assertLess(ANSWER_STYLES['normal'][1], ANSWER_STYLES['detailed'][1])


class AmbiguityTests(DialogueBase):
    def test_ambiguous_product_lists_candidates_and_a_pick_resolves_it(self):
        create_stock_item(self.user, 'Mil local', 50, 'sac', reason='manual')
        create_stock_item(self.user, 'Mil amélioré', 30, 'sac', reason='manual')
        first = self.ask("J'ai vendu du mil")
        self.assertEqual(self.reply_kind(first), 'question')
        self.assertIn("local", first.data['response'])
        self.assertIn("amélioré", first.data['response'])
        self.assertNothingWritten()
        second = self.ask("le local")
        self.assertEqual(self.reply_kind(second), 'question')
        self.assertNothingWritten()
