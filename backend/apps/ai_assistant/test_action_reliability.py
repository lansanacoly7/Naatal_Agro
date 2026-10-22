"""
Fiabilité des actions métier de Naatal IA (cahier des charges §4.C et §7) :
confirmation unique, idempotence, aucune exécution de paramètres fournis par le client,
confirmation stricte, atomicité, avertissement de stock, aucune fuite de détail technique.
"""
import datetime
from unittest import mock

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from apps.ai_assistant import proposals
from apps.ai_assistant.actions import (
    TECHNICAL_ERROR_MESSAGE,
    check_action,
    classify_reply,
    execute_action,
)
from apps.ai_assistant.models import AIConversation, AIInteraction
from apps.finances.models import Sale, Transaction
from apps.inventory.models import StockItem

User = get_user_model()

EXPENSE = "J'ai dépensé 25000 FCFA pour du compost biologique"
SALE = "J'ai vendu 25 sacs de riz à 12000 FCFA"


class ClassifyReplyTests(TestCase):
    def test_pure_confirmations(self):
        for text in ("oui", "Oui", "Oui, confirme", "Oui, valider", "ok", "OK !", "d'accord", "D'accord.",
                     "c'est bon", "confirme", "Valide", "waaw", "Baax na", "oui merci", "oui, s'il vous plaît",
                     "Oui je confirme", "yes"):
            with self.subTest(text=text):
                self.assertEqual(classify_reply(text), 'confirm')

    def test_pure_cancellations(self):
        for text in ("non", "Non", "Non, annule", "Non, annuler", "annule", "laisse tomber", "ne fais rien",
                     "non merci", "stop", "deedet"):
            with self.subTest(text=text):
                self.assertEqual(classify_reply(text), 'cancel')

    def test_confirmation_with_extra_content_is_ambiguous_never_a_confirmation(self):
        for text in ("ok mais mets 5000", "oui mais pas 25000", "Oui et quel est mon solde ?",
                     "non, j'ai dépensé 7000 FCFA pour du sel", "d'accord, change le prix"):
            with self.subTest(text=text):
                self.assertEqual(classify_reply(text), 'ambiguous')

    def test_mixed_confirm_and_cancel_is_ambiguous(self):
        self.assertEqual(classify_reply("non c'est bon"), 'ambiguous')
        self.assertEqual(classify_reply("oui non"), 'ambiguous')

    def test_unrelated_messages_are_not_replies(self):
        for text in ("Quel est mon solde ?", "Combien de sacs de mil me reste-t-il", "", "   ", "merci", "bonjour"):
            with self.subTest(text=text):
                self.assertIsNone(classify_reply(text))


class ActionReliabilityTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='+221770001111', phone='+221770001111', password='Password123#')
        self.other = User.objects.create_user(username='+221770002222', phone='+221770002222', password='Password123#')
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.conv = AIConversation.objects.create(user=self.user, title="Compta")

    # --- utilitaires -------------------------------------------------------------------------------------------
    def ask(self, query, client=None, conv=None):
        return (client or self.client).post(
            '/api/ai/ask/', {'query': query, 'conversation_id': str((conv or self.conv).id)}, format='json')

    def execute(self, interaction_id, decision, client=None, **extra):
        return (client or self.client).post(
            '/api/ai/actions/execute/', {'interaction_id': interaction_id, 'decision': decision, **extra}, format='json')

    def expenses(self, amount=None):
        qs = Transaction.objects.filter(user=self.user, transaction_type='expense')
        return qs.filter(amount=amount) if amount else qs

    # --- une seule exécution -----------------------------------------------------------------------------------
    def test_double_text_confirmation_writes_once(self):
        self.ask(EXPENSE)
        first = self.ask("Oui, confirme")
        second = self.ask("Oui, confirme")

        self.assertEqual(first.data['action_data']['status'], 'executed')
        self.assertEqual(self.expenses(25000).count(), 1)
        self.assertEqual(second.status_code, status.HTTP_201_CREATED)
        self.assertIn("déjà été traitée", second.data['response'])
        self.assertEqual(self.expenses().count(), 1)

    def test_double_button_confirmation_is_idempotent(self):
        proposal = self.ask(EXPENSE)
        first = self.execute(proposal.data['id'], 'confirm')
        second = self.execute(proposal.data['id'], 'confirm')

        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second.status_code, status.HTTP_200_OK)
        self.assertEqual(first.data['id'], second.data['id'])
        self.assertEqual(second.data['action_data']['status'], 'executed')
        self.assertEqual(self.expenses(25000).count(), 1)

    def test_stale_instance_cannot_win_the_compare_and_set(self):
        """Simule la course : un second appel a lu la proposition « en attente » avant que le premier l'exécute."""
        proposal = self.ask(EXPENSE)
        stale = AIInteraction.objects.get(pk=proposal.data['id'])

        self.execute(proposal.data['id'], 'confirm')

        self.assertFalse(proposals._claim(stale, proposals.PROCESSING))
        self.assertEqual(self.expenses(25000).count(), 1)

    def test_confirm_then_cancel_keeps_the_executed_result(self):
        proposal = self.ask(EXPENSE)
        self.execute(proposal.data['id'], 'confirm')
        late_cancel = self.execute(proposal.data['id'], 'cancel')

        self.assertEqual(late_cancel.status_code, status.HTTP_200_OK)
        self.assertEqual(late_cancel.data['action_data']['status'], 'executed')
        self.assertEqual(self.expenses(25000).count(), 1)

    def test_cancel_then_confirm_never_writes(self):
        proposal = self.ask(EXPENSE)
        cancelled = self.execute(proposal.data['id'], 'cancel')
        late_confirm = self.execute(proposal.data['id'], 'confirm')

        self.assertEqual(cancelled.data['action_data']['status'], 'cancelled')
        self.assertEqual(late_confirm.status_code, status.HTTP_200_OK)
        self.assertEqual(late_confirm.data['action_data']['status'], 'cancelled')
        self.assertEqual(self.expenses().count(), 0)

    # --- le client ne peut pas imposer une opération -----------------------------------------------------------
    def test_free_form_action_payload_is_rejected(self):
        response = self.client.post('/api/ai/actions/execute/', {
            'action_type': 'record_expense',
            'parameters': {'amount': 999999, 'description': 'Falsifié'},
        }, format='json')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data['code'], 'proposal_required')
        self.assertEqual(self.expenses().count(), 0)

    def test_tampered_parameters_are_ignored_in_favour_of_stored_ones(self):
        proposal = self.ask(EXPENSE)
        response = self.execute(
            proposal.data['id'], 'confirm',
            action_type='record_expense', parameters={'amount': 999999, 'description': 'Falsifié'})

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.expenses(25000).count(), 1)
        self.assertFalse(Transaction.objects.filter(amount=999999).exists())

    def test_other_users_proposal_is_not_found_and_stays_pending(self):
        proposal = self.ask(EXPENSE)
        intruder = APIClient()
        intruder.force_authenticate(self.other)

        response = self.execute(proposal.data['id'], 'confirm', client=intruder)

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(Transaction.objects.count(), 0)
        self.assertEqual(AIInteraction.objects.get(pk=proposal.data['id']).action_data['status'], 'pending_confirmation')

    def test_invalid_identifiers_and_decisions(self):
        proposal = self.ask(EXPENSE)
        self.assertEqual(self.execute('pas-un-uuid', 'confirm').status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(self.execute(proposal.data['id'], 'peut-etre').status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(self.execute('00000000-0000-0000-0000-000000000000', 'confirm').status_code,
                         status.HTTP_404_NOT_FOUND)
        self.assertEqual(self.expenses().count(), 0)

    def test_outcome_interaction_is_not_a_proposal(self):
        outcome = self.execute(self.ask(EXPENSE).data['id'], 'confirm')
        again = self.execute(outcome.data['id'], 'confirm')
        self.assertEqual(again.status_code, status.HTTP_404_NOT_FOUND)

    # --- confirmation stricte ----------------------------------------------------------------------------------
    def test_modified_confirmation_writes_nothing_and_proposal_stays_confirmable(self):
        proposal = self.ask(EXPENSE)
        reply = self.ask("ok mais mets 5000")

        self.assertEqual(reply.status_code, status.HTTP_201_CREATED)
        self.assertIn("Je n'ai rien enregistré", reply.data['response'])
        self.assertEqual(self.expenses().count(), 0)
        self.assertEqual(AIInteraction.objects.get(pk=proposal.data['id']).action_data['status'], 'pending_confirmation')

        confirmed = self.ask("oui")
        self.assertEqual(confirmed.data['action_data']['status'], 'executed')
        self.assertEqual(self.expenses(25000).count(), 1)

    def test_new_operation_supersedes_the_pending_one(self):
        old = self.ask(EXPENSE)
        new = self.ask("Non, j'ai dépensé 7000 FCFA pour du sel")

        self.assertEqual(new.data['action_data']['status'], 'pending_confirmation')
        self.assertEqual(AIInteraction.objects.get(pk=old.data['id']).action_data['status'], 'superseded')

        stale = self.execute(old.data['id'], 'confirm')
        self.assertEqual(stale.status_code, status.HTTP_409_CONFLICT)
        self.assertEqual(stale.data['code'], 'superseded')
        self.assertEqual(self.expenses().count(), 0)

        self.ask("oui")
        self.assertEqual(self.expenses(7000).count(), 1)
        self.assertEqual(self.expenses(25000).count(), 0)

    def test_expired_proposal_is_never_executed(self):
        proposal = self.ask(EXPENSE)
        interaction = AIInteraction.objects.get(pk=proposal.data['id'])
        data = dict(interaction.action_data, expires_at=(timezone.now() - datetime.timedelta(minutes=1)).isoformat())
        AIInteraction.objects.filter(pk=interaction.pk).update(action_data=data)

        response = self.ask("oui")

        self.assertEqual(response.data['action_data']['status'], 'expired')
        self.assertIn("expiré", response.data['response'])
        self.assertEqual(self.expenses().count(), 0)

    # --- atomicité et erreurs ----------------------------------------------------------------------------------
    def test_failure_rolls_everything_back_and_hides_technical_details(self):
        StockItem.objects.create(user=self.user, name='Riz', quantity=100.0, unit='sacs')
        proposal = self.ask(SALE)

        with mock.patch.object(Transaction.objects, 'update_or_create', side_effect=RuntimeError('boom-secret-detail')):
            response = self.execute(proposal.data['id'], 'confirm')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['action_data']['status'], 'failed')
        self.assertNotIn('boom-secret-detail', response.data['response'])
        self.assertNotIn('boom-secret-detail', str(response.data['action_data']))
        self.assertIn(TECHNICAL_ERROR_MESSAGE, response.data['response'])
        # Vente, stock et recette : tout annulé en bloc
        self.assertEqual(Sale.objects.filter(user=self.user).count(), 0)
        self.assertEqual(StockItem.objects.get(user=self.user, name='Riz').quantity, 100.0)
        self.assertEqual(Transaction.objects.filter(user=self.user).count(), 0)

    def test_failed_outcome_is_replayed_not_retried(self):
        proposal = self.ask(SALE)
        with mock.patch.object(Transaction.objects, 'update_or_create', side_effect=RuntimeError('x')):
            self.execute(proposal.data['id'], 'confirm')
        again = self.execute(proposal.data['id'], 'confirm')

        self.assertEqual(again.status_code, status.HTTP_200_OK)
        self.assertEqual(again.data['action_data']['status'], 'failed')
        self.assertEqual(Sale.objects.count(), 0)

    # --- stock insuffisant : même règle que l'API des ventes ----------------------------------------------------
    def test_sale_above_stock_is_refused_before_any_proposal(self):
        StockItem.objects.create(user=self.user, name='Riz', quantity=10.0, unit='sacs')

        response = self.ask(SALE)

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertFalse(response.data['action_data'])  # pas de proposition à confirmer
        self.assertIn("Stock insuffisant", response.data['response'])
        self.assertIn("Aucune donnée n'a été modifiée", response.data['response'])
        self.assertEqual(Sale.objects.count(), 0)
        self.assertEqual(StockItem.objects.get(user=self.user, name='Riz').quantity, 10.0)

    def test_stock_checked_again_at_execution_time(self):
        """Le stock a pu baisser entre la proposition et la confirmation : l'exécution refuse aussi."""
        stock = StockItem.objects.create(user=self.user, name='Riz', quantity=100.0, unit='sacs')
        proposal = self.ask(SALE)
        self.assertEqual(proposal.data['action_data']['status'], 'pending_confirmation')
        StockItem.objects.filter(pk=stock.pk).update(quantity=5.0)

        done = self.execute(proposal.data['id'], 'confirm')

        self.assertEqual(done.data['action_data']['status'], 'failed')
        self.assertEqual(done.data['action_data']['result']['error_code'], 'insufficient_stock')
        self.assertEqual(Sale.objects.count(), 0)
        self.assertEqual(StockItem.objects.get(pk=stock.pk).quantity, 5.0)

    def test_sale_within_stock_has_no_warning_and_decrements(self):
        StockItem.objects.create(user=self.user, name='Riz', quantity=100.0, unit='sacs')
        proposal = self.ask(SALE)
        self.assertEqual(proposal.data['action_data']['warnings'], [])
        self.assertEqual(check_action(self.user, 'record_expense', {'category': 'engrais'}), ([], []))
        self.execute(proposal.data['id'], 'confirm')
        self.assertEqual(StockItem.objects.get(user=self.user, name='Riz').quantity, 75.0)


class ExecuteActionValidationTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='+221770003333', phone='+221770003333', password='Password123#')

    def test_invalid_amounts_are_rejected_without_writing(self):
        for amount in ('abc', None, 0, -5, float('inf'), float('nan'), 10 ** 12, '1e999'):
            with self.subTest(amount=amount):
                result = execute_action(self.user, 'record_expense', {'amount': amount, 'description': 'x'})
                self.assertFalse(result['success'])
                self.assertEqual(result['error_code'], 'invalid_amount')
        self.assertEqual(Transaction.objects.count(), 0)

    def test_invalid_date_is_rejected(self):
        result = execute_action(self.user, 'record_expense', {'amount': 1000, 'date': '31/02/pas-une-date'})
        self.assertFalse(result['success'])
        self.assertEqual(result['error_code'], 'invalid_date')

    def test_sale_total_above_database_limit_is_rejected(self):
        result = execute_action(self.user, 'record_sale', {
            'product_name': 'Riz', 'quantity': 900_000_000, 'price_per_unit': 90_000_000})
        self.assertFalse(result['success'])
        self.assertEqual(Sale.objects.count(), 0)

    def test_malformed_parameters_never_leak_internals(self):
        result = execute_action(self.user, 'record_sale', {'product_name': ['liste'], 'quantity': 1, 'price_per_unit': 1})
        self.assertFalse(result['success'])
        for forbidden in ('Traceback', 'AttributeError', 'object has no attribute'):
            self.assertNotIn(forbidden, result['message'])
        self.assertFalse(execute_action(self.user, 'record_expense', 'pas un dict')['success'])
        self.assertEqual(execute_action(self.user, 'drop_database', {})['error_code'], 'unsupported_action')

    def test_reminder_with_unreadable_or_past_date_is_refused(self):
        unreadable = execute_action(self.user, 'create_reminder', {'message': 'Arroser', 'scheduled_for': 'demain-ish'})
        self.assertEqual(unreadable['error_code'], 'invalid_date')
        past = (timezone.now() - datetime.timedelta(days=1)).isoformat()
        refused = execute_action(self.user, 'create_reminder', {'message': 'Arroser', 'scheduled_for': past})
        self.assertEqual(refused['error_code'], 'past_schedule')

    def test_reminder_in_the_future_is_created(self):
        future = (timezone.now() + datetime.timedelta(hours=3)).isoformat()
        result = execute_action(self.user, 'create_reminder', {'message': 'Arroser', 'scheduled_for': future})
        self.assertTrue(result['success'])
