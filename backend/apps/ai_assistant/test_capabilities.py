"""
Ce que l'assistant dit quand on lui demande de FAIRE quelque chose : il crée l'alerte, ou il avoue qu'il ne sait pas,
mais il ne répond jamais par la fiche d'une culture dont on ne parlait pas.
"""
from apps.ai_assistant.test_phase5_dialogue import DialogueBase
from apps.notifications.models import Notification


class AlertRequestTests(DialogueBase):
    def test_polite_alert_request_asks_what_for_instead_of_answering_with_a_crop_sheet(self):
        self.ask("Quand semer l'oignon ?")
        reply = self.ask("D'accord, peux-tu créer une alerte pour moi ?")
        self.assertAsked(reply, 'rappeler')
        self.assertNotIn('Oignon', reply.data['response'])
        self.assertEqual(Notification.objects.count(), 0)

    def test_alert_request_then_answers_lead_to_a_confirmable_alert(self):
        self.ask("Crée-moi une alerte")
        self.ask("d'arroser les tomates")
        proposal = self.ask("demain à 7h")
        action = proposal.data['action_data']
        self.assertEqual(action['status'], 'pending_confirmation')
        self.assertEqual(action['action_type'], 'create_reminder')
        self.assertEqual(Notification.objects.count(), 0)
        done = self.confirm(proposal)
        self.assertEqual(done.data['action_data']['status'], 'executed')
        self.assertEqual(Notification.objects.count(), 1)

    def test_alert_with_object_and_time_goes_straight_to_a_proposal(self):
        proposal = self.ask("Peux-tu me créer une alerte pour arroser demain à 7h ?")
        self.assertEqual(proposal.data['action_data']['status'], 'pending_confirmation')


class UnsupportedRequestTests(DialogueBase):
    def test_an_order_that_cannot_be_understood_right_now_is_said_not_answered_with_a_sheet(self):
        # le modèle de langage n'est pas joignable en test : l'ordre n'est pas traité, et on ne répond pas par une fiche
        reply = self.ask("Crée des activités pour la culture tomate")
        text = reply.data['response']
        self.assertIn('momentanément indisponible', text)
        self.assertIn('Rien n\'a été enregistré', text)
        self.assertNotIn('Tomate industrielle', text)

    def test_sending_a_message_is_refused_and_alternatives_are_suggested(self):
        reply = self.ask("Envoie un SMS à mon fournisseur")
        self.assertIn('Je ne sais pas faire cela', reply.data['response'])
        self.assertTrue(reply.data['suggestions'])

    def test_a_plain_question_about_a_crop_still_gets_the_sheet(self):
        reply = self.ask("Peux-tu me dire quand semer l'oignon ?")
        self.assertNotEqual(self.reply_kind(reply), 'unsupported')
