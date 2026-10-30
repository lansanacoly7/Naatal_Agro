"""
L'assistant agit comme une deuxième personne dans l'application : activités, récoltes, cultures, annulations, profil.
Le modèle de langage est simulé (il ne fait que remplir les champs) ; tout le reste est le vrai code.
"""
import datetime
import json
from unittest.mock import patch

from apps.agriculture.models import Activity, Crop, Harvest
from apps.ai_assistant import llm
from apps.ai_assistant.test_phase5_dialogue import DialogueBase
from apps.finances.models import Sale, Transaction
from apps.inventory.models import StockItem
from apps.inventory.services import create_stock_item
from apps.notifications.models import Notification

TODAY = datetime.date.today()
YESTERDAY = TODAY - datetime.timedelta(days=1)


def planner(tool, **params):
    """Réponse du modèle de langage : l'outil choisi et ses champs."""
    return llm.LLMResult(text=json.dumps({'tool': tool, 'params': params}), reason='ok')


class AgentBase(DialogueBase):
    def say(self, text, *replies):
        """Envoie ``text`` ; ``replies`` = ce que répond le modèle de langage (un par appel)."""
        queue = list(replies)

        def fake(*args, **kwargs):  # au-delà des réponses prévues, le service est « indisponible » (jamais un vrai appel)
            return queue.pop(0) if queue else llm.LLMResult(text=None, reason='unavailable')

        with patch('apps.ai_assistant.farm_agent.llm.generate', side_effect=fake) as generate:
            response = self.ask(text)
        self.calls = sum(1 for c in generate.call_args_list if c.args[0].system.startswith('Tu es le planificateur'))
        return response

    def status(self, response):
        return (response.data.get('action_data') or {}).get('status')

    def crop_named(self, name, **extra):
        return Crop.objects.create(user=self.user, name=name, crop_type=name, planting_date=TODAY, expected_harvest_date=TODAY,
                                   area_size=1.0, location='Thiès', **extra)


class ActivityTests(AgentBase):
    def test_a_sentence_becomes_a_proposal_then_an_activity_after_confirmation(self):
        mil = self.crop_named('Mil')
        proposal = self.say("J'ai arrosé le mil hier", planner('create_activity', crop='mil', activity_type='arrosage', date=YESTERDAY.isoformat()))
        self.assertEqual(self.status(proposal), 'pending_confirmation')
        self.assertIn('Arrosage', proposal.data['response'])
        self.assertEqual(Activity.objects.count(), 0)  # rien n'est écrit avant « oui »

        done = self.confirm(proposal)
        self.assertEqual(self.status(done), 'executed')
        activity = Activity.objects.get()
        self.assertEqual((activity.crop, activity.activity_type, activity.date), (mil, 'Arrosage', YESTERDAY))

    def test_a_cost_creates_the_linked_expense(self):
        self.crop_named('Mil')
        proposal = self.say("J'ai mis de l'engrais sur le mil pour 15000", planner('create_activity', crop='Mil', activity_type='engrais', cost=15000))
        self.confirm(proposal)
        expense = Transaction.objects.get(transaction_type='expense')
        self.assertEqual(float(expense.amount), 15000.0)
        self.assertEqual(Activity.objects.get().activity_type, 'Fertilisation')

    def test_with_two_crops_it_asks_which_one_then_understands_a_short_answer(self):
        self.crop_named('Mil')
        self.crop_named('Arachide')
        question = self.say("Ajoute une activité d'arrosage", planner('create_activity', activity_type='arrosage'))
        self.assertEqual(self.reply_kind(question), 'question')
        self.assertIn('Sur quelle culture', question.data['response'])
        self.assertEqual(set(question.data['suggestions']), {'Mil', 'Arachide'})

        proposal = self.say('le mil')  # réponse nue : aucun appel au modèle de langage
        self.assertEqual(self.calls, 0)
        self.assertEqual(self.status(proposal), 'pending_confirmation')
        self.assertIn('Mil', proposal.data['response'])

    def test_with_a_single_crop_it_does_not_ask_which(self):
        self.crop_named('Mil')
        proposal = self.say("Note un désherbage", planner('create_activity', activity_type='désherbage'))
        self.assertEqual(self.status(proposal), 'pending_confirmation')

    def test_another_accounts_crop_is_never_used(self):
        Crop.objects.create(user=self.other, name='Yèbè', crop_type='Yèbè', planting_date=TODAY, expected_harvest_date=TODAY,
                            area_size=1, location='Thiès')
        reply = self.say("J'ai arrosé le Yèbè", planner('create_activity', crop='Yèbè', activity_type='arrosage'))
        self.assertIn("aucune culture", reply.data['response'])
        self.assertEqual(Activity.objects.count(), 0)

    def test_cancelling_a_question_drops_the_draft(self):
        self.crop_named('Mil')
        self.crop_named('Arachide')
        self.say("Ajoute une activité d'arrosage", planner('create_activity', activity_type='arrosage'))
        reply = self.say('annule')
        self.assertIn("j'abandonne", reply.data['response'])


class HarvestTests(AgentBase):
    def test_a_harvest_updates_the_stock_and_the_crop(self):
        mil = self.crop_named('Mil')
        proposal = self.say("J'ai récolté 300 kg de mil", planner('record_harvest', crop='mil', quantity=300, unit='kg'))
        self.assertIn('300 kg', proposal.data['response'])
        self.confirm(proposal)
        self.assertEqual(Harvest.objects.get().quantity, 300)
        self.assertEqual(StockItem.objects.get(user=self.user, name='Mil').quantity, 300)
        mil.refresh_from_db()
        self.assertEqual(mil.status, 'harvested')

    def test_a_missing_quantity_is_asked_never_guessed(self):
        self.crop_named('Mil')
        question = self.say("J'ai récolté le mil", planner('record_harvest', crop='mil'))
        self.assertIn('Quelle quantité', question.data['response'])
        proposal = self.say('250')
        self.assertEqual(self.status(proposal), 'pending_confirmation')


class CropTests(AgentBase):
    def test_a_new_crop_asks_for_the_area_then_proposes(self):
        question = self.say("Ajoute une culture de mil", planner('create_crop', name='Mil', expected_harvest_date=(TODAY + datetime.timedelta(days=90)).isoformat()))
        self.assertIn('hectares', question.data['response'])
        proposal = self.say('2')
        self.assertEqual(self.status(proposal), 'pending_confirmation')
        self.confirm(proposal)
        crop = Crop.objects.get(user=self.user)
        self.assertEqual((crop.name, crop.area_size), ('Mil', 2.0))

    def test_a_crop_can_be_modified(self):
        mil = self.crop_named('Mil')
        proposal = self.say("Change la surface du mil à 3 hectares", planner('update_crop', crop='mil', area_size=3))
        self.confirm(proposal)
        mil.refresh_from_db()
        self.assertEqual(mil.area_size, 3.0)

    def test_deleting_a_crop_warns_and_waits_for_confirmation(self):
        mil = self.crop_named('Mil')
        Activity.objects.create(crop=mil, activity_type='Arrosage', date=TODAY)
        proposal = self.say("Supprime la culture mil", planner('delete_crop', crop='mil'))
        self.assertIn('définitive', proposal.data['response'])
        self.assertIn('1 activité', proposal.data['response'])
        self.assertTrue(Crop.objects.filter(pk=mil.pk).exists())
        self.confirm(proposal)
        self.assertFalse(Crop.objects.filter(pk=mil.pk).exists())


class UndoTests(AgentBase):
    def test_cancelling_the_last_sale_gives_the_stock_back(self):
        create_stock_item(self.user, 'Mil', 100, 'sac', reason='manual')
        sale = self.client.post('/api/finances/sales/', {'product_name': 'Mil', 'quantity_sold': 10, 'price_per_unit': 500,
                                                         'date': TODAY.isoformat()}, format='json')
        self.assertEqual(sale.status_code, 201)
        proposal = self.say("Annule ma dernière vente", planner('cancel_sale'))
        self.assertIn('Annuler la vente', proposal.data['response'])
        self.confirm(proposal)
        self.assertEqual(Sale.objects.count(), 0)
        self.assertEqual(StockItem.objects.get(user=self.user, name='Mil').quantity, 100)

    def test_deleting_the_last_activity(self):
        mil = self.crop_named('Mil')
        Activity.objects.create(crop=mil, activity_type='Arrosage', date=TODAY)
        proposal = self.say("Supprime ma dernière activité", planner('delete_activity'))
        self.confirm(proposal)
        self.assertEqual(Activity.objects.count(), 0)

    def test_nothing_to_cancel_is_said_plainly(self):
        reply = self.say("Annule ma dernière vente", planner('cancel_sale'))
        self.assertIn('aucune vente', reply.data['response'])


class MiscTests(AgentBase):
    def test_the_profile_location_can_be_changed(self):
        proposal = self.say("Je suis maintenant à Kaolack", planner('update_profile', location='Kaolack'))
        self.confirm(proposal)
        self.user.refresh_from_db()
        self.assertEqual(self.user.location, 'Kaolack')

    def test_notifications_can_be_marked_read(self):
        Notification.objects.create(user=self.user, type='info', message='Bonjour')
        proposal = self.say("Marque mes notifications comme lues", planner('mark_notifications_read'))
        self.confirm(proposal)
        self.assertFalse(Notification.objects.filter(user=self.user, is_read=False).exists())


class SafetyTests(AgentBase):
    def test_a_plain_question_never_reaches_the_planner(self):
        self.crop_named('Mil')
        self.say("Quand semer le mil ?")
        self.assertEqual(self.calls, 0)

    def test_an_unknown_tool_from_the_model_is_ignored(self):
        reply = self.say("Supprime tout mon compte", planner('drop_database'))
        self.assertNotEqual(self.status(reply), 'pending_confirmation')

    def test_when_the_model_is_unavailable_nothing_is_written(self):
        self.crop_named('Mil')
        down = llm.LLMResult(text=None, reason='unavailable')
        self.say("J'ai arrosé le mil", down)
        self.assertEqual(Activity.objects.count(), 0)

    def test_a_confirmation_cannot_touch_another_accounts_data(self):
        theirs = Crop.objects.create(user=self.other, name='Mil', crop_type='Mil', planting_date=TODAY, expected_harvest_date=TODAY,
                                     area_size=1, location='Thiès')
        from apps.ai_assistant.actions import execute_action
        result = execute_action(self.user, 'delete_crop', {'crop_id': str(theirs.pk)})
        self.assertFalse(result['success'])
        self.assertTrue(Crop.objects.filter(pk=theirs.pk).exists())


class ProgramTests(AgentBase):
    def guide(self, **extra):
        from apps.agriculture.models import AgronomicGuide
        return AgronomicGuide.objects.create(slug='mil-test', name='Mil test', category='cereale', summary='Mil.', cycle_days_max=90,
                                             fertilization='Compost au semis ; urée 30 jours après le semis.', **extra)

    def tasks(self, *items):
        return llm.LLMResult(text=json.dumps({'tasks': [
            {'activity_type': kind, 'days_after_planting': days, 'detail': f'{kind} selon la fiche'} for kind, days in items]}), reason='ok')

    def test_a_program_is_built_from_the_sheet_and_added_after_confirmation(self):
        mil = self.crop_named('Mil')
        mil.guide = self.guide()
        mil.save()
        proposal = self.say("Aide-moi à créer des activités pour mon mil", planner('plan_activities', crop='mil'),
                            self.tasks(('Fertilisation de fond', 0), ('Urée', 30), ('Récolte', 90)))
        self.assertEqual(self.status(proposal), 'pending_confirmation')
        self.assertIn('Programme de travail pour Mil', proposal.data['response'])
        self.assertEqual(Activity.objects.count(), 0)

        done = self.confirm(proposal)
        self.assertEqual(self.status(done), 'executed')
        dates = sorted(a.date for a in Activity.objects.all())
        self.assertEqual(dates, [TODAY, TODAY + datetime.timedelta(days=30), TODAY + datetime.timedelta(days=90)])

    def test_confirming_twice_never_duplicates_the_program(self):
        mil = self.crop_named('Mil')
        mil.guide = self.guide()
        mil.save()
        first = self.say("Crée le programme du mil", planner('plan_activities', crop='mil'), self.tasks(('Semis', 0), ('Urée', 30)))
        self.confirm(first)
        second = self.say("Crée le programme du mil", planner('plan_activities', crop='mil'), self.tasks(('Semis', 0), ('Urée', 30)))
        self.assertIn('existent déjà', second.data['response'])
        self.confirm(second)
        self.assertEqual(Activity.objects.count(), 2)

    def test_a_task_the_sheet_does_not_date_is_not_invented(self):
        mil = self.crop_named('Mil')
        mil.guide = self.guide()
        mil.save()
        reply = self.say("Crée des activités pour le mil", planner('plan_activities', crop='mil'), self.tasks(('Arrosage', 400)))
        self.assertIn('pas assez d\'étapes datées', reply.data['response'])
        self.assertEqual(Activity.objects.count(), 0)

    def test_without_a_technical_sheet_it_says_so(self):
        self.crop_named('Fonio rare')
        reply = self.say("Crée des activités pour le fonio rare", planner('plan_activities', crop='fonio rare'))
        self.assertIn("pas de fiche technique", reply.data['response'])


class ConsultationTests(AgentBase):
    def test_the_assistant_lists_crops_activities_harvests_and_next_harvest(self):
        mil = self.crop_named('Mil')
        Activity.objects.create(crop=mil, activity_type='Arrosage', date=TODAY)
        Harvest.objects.create(crop=mil, user=self.user, date=TODAY, quantity=120, unit='kg')
        self.assertIn('Mil', self.ask('Mes cultures').data['response'])
        self.assertIn('Arrosage sur Mil', self.ask('Mes activités').data['response'])
        self.assertIn('120 kg de Mil', self.ask('Mes récoltes').data['response'])
        self.assertIn('Vos prochaines récoltes', self.ask('Quand dois-je récolter ?').data['response'])

    def test_a_new_account_sees_nothing_of_another_accounts_data(self):
        Crop.objects.create(user=self.other, name='Yèbè', crop_type='Yèbè', planting_date=TODAY, expected_harvest_date=TODAY,
                            area_size=1, location='Thiès')
        reply = self.ask('Mes cultures')
        self.assertNotIn('Yèbè', reply.data['response'])
        self.assertIn('pas encore de culture', reply.data['response'])
