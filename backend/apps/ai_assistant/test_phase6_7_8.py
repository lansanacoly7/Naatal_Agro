import base64
from unittest.mock import patch
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from apps.notifications.models import Notification
from apps.ai_assistant.models import AIConversation
from apps.ai_assistant.actions import detect_action_intent

User = get_user_model()


class Phase678Tests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='+221775550000',
            phone='+221775550000',
            password='Password123#',
            first_name='Fatou'
        )
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def test_reminder_intent_and_execution_phase6(self):
        """Vérifie la création d'un rappel / alerte avec notification (Phase 6)."""
        intent = detect_action_intent("Rappelle-moi d'arroser les oignons demain matin")
        self.assertTrue(intent['has_intent'])
        self.assertEqual(intent['action_type'], 'create_reminder')
        self.assertIn("arroser les oignons", intent['params']['message'].lower())

        conv = AIConversation.objects.create(user=self.user, title="Rappels")
        
        # Demande
        res1 = self.client.post('/api/ai/ask/', {
            'query': "Rappelle-moi d'arroser les piments demain à 7h",
            'conversation_id': str(conv.id)
        }, format='json')
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res1.data['action_data']['status'], 'pending_confirmation')

        # Confirmation
        res2 = self.client.post('/api/ai/ask/', {
            'query': "Oui, confirme",
            'conversation_id': str(conv.id)
        }, format='json')
        self.assertEqual(res2.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res2.data['action_data']['status'], 'executed')

        # Vérifier la notification créée
        notif = Notification.objects.filter(user=self.user, type='reminder').first()
        self.assertIsNotNone(notif)
        self.assertIn("arroser les piments", notif.message.lower())
        self.assertIsNotNone(notif.scheduled_for)
        # Comme l'échéance est demain matin, le rappel n'est PAS envoyé immédiatement
        self.assertFalse(notif.is_sent)

    def test_send_scheduled_reminders_command(self):
        """Vérifie le déclenchement des rappels arrivés à échéance par la commande de gestion."""
        from django.core.management import call_command
        from django.utils import timezone
        import datetime

        # 1. Rappel échu (programmé il y a 10 minutes)
        past_time = timezone.now() - datetime.timedelta(minutes=10)
        notif_due = Notification.objects.create(
            user=self.user,
            type='reminder',
            message='Traiter les chenilles légionnaires',
            scheduled_for=past_time
        )
        notif_due.is_sent = False
        notif_due.save(update_fields=['is_sent'])

        # 2. Rappel futur (programmé dans 2 heures)
        future_time = timezone.now() + datetime.timedelta(hours=2)
        notif_future = Notification.objects.create(
            user=self.user,
            type='reminder',
            message='Vérifier irrigation',
            scheduled_for=future_time
        )

        self.assertFalse(notif_due.is_sent)
        self.assertFalse(notif_future.is_sent)

        # Exécuter la commande de gestion
        call_command('send_scheduled_reminders')

        notif_due.refresh_from_db()
        notif_future.refresh_from_db()

        # Le rappel échu doit être envoyé
        self.assertTrue(notif_due.is_sent)
        self.assertIsNotNone(notif_due.sent_at)

        # Le rappel futur reste en attente
        self.assertFalse(notif_future.is_sent)

    def test_wolof_intent_detection_phase7(self):
        """Vérifie la compréhension des requêtes en wolof agricole (Phase 7)."""
        # Dépense en Wolof
        intent_dep = detect_action_intent("Depaase naa 15000 cfa ci kompoos")
        self.assertTrue(intent_dep['has_intent'])
        self.assertEqual(intent_dep['action_type'], 'record_expense')
        self.assertEqual(intent_dep['params']['amount'], 15000.0)

        # Vente en Wolof
        intent_sale = detect_action_intent("Jaay naa 10 sac ceeb à 15000 f")
        self.assertTrue(intent_sale['has_intent'])
        self.assertEqual(intent_sale['action_type'], 'record_sale')
        self.assertEqual(intent_sale['params']['quantity'], 10.0)
        self.assertEqual(intent_sale['params']['price_per_unit'], 15000.0)

        # Rappel en Wolof
        intent_rem = detect_action_intent("Fattali ma ma suuxat samay tomato")
        self.assertTrue(intent_rem['has_intent'])
        self.assertEqual(intent_rem['action_type'], 'create_reminder')

        # Test RAG Wolof : "Naka lañuy fajee soble ?" doit cibler la fiche Oignon et la section maladies/ravageurs
        from apps.ai_assistant.knowledge import retrieve, is_wolof_text
        self.assertTrue(is_wolof_text("Naka lañuy fajee soble ?"))
        self.assertTrue(is_wolof_text("Naka lañuy jiyee ceeb ?"))
        self.assertFalse(is_wolof_text("Comment traiter le mildiou sur la tomate ?"))

        # Vérifier la RAG avec fiches de test
        from apps.agriculture.models import AgronomicGuide
        AgronomicGuide.objects.get_or_create(
            name="Oignon Local",
            defaults={
                'scientific_name': 'Allium cepa',
                'aliases': ['Oignon', 'Soble'],
                'pests_diseases': [{'name': 'Thrips et alternariose', 'advice': 'Lutte avec purin de neem [1].'}],
                'sources': [{'number': 1, 'title': 'Guide Maraîchage ISRA', 'publisher': 'ISRA', 'year': 2021, 'scope': 'senegal'}]
            }
        )
        res_rag = retrieve("Naka lañuy fajee soble ?")
        self.assertTrue(len(res_rag.guides) > 0)
        self.assertTrue("Oignon" in res_rag.guides[0].name)
        self.assertTrue(any(s.label == "Maladies et ravageurs" for s in res_rag.sections))

    def test_voice_transcribe_endpoint_phase8(self):
        """Vérifie l'endpoint de transcription vocale (Phase 8)."""
        dummy_audio = b"RIFF....WAVEfmt ...."
        dummy_b64 = base64.b64encode(dummy_audio).decode('ascii')

        with patch('apps.ai_assistant.voice.transcribe_audio_bytes', return_value="Comment traiter le mildiou sur la tomate ?"):
            response = self.client.post('/api/ai/voice/transcribe/', {
                'audio_base64': dummy_b64
            }, format='json')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['text'], "Comment traiter le mildiou sur la tomate ?")

    def test_voice_transcribe_invalid_payload(self):
        """Vérifie la validation des données sur l'endpoint vocal."""
        res_empty = self.client.post('/api/ai/voice/transcribe/', {}, format='json')
        self.assertEqual(res_empty.status_code, status.HTTP_400_BAD_REQUEST)

        res_bad_b64 = self.client.post('/api/ai/voice/transcribe/', {'audio_base64': '!!!notb64'}, format='json')
        self.assertEqual(res_bad_b64.status_code, status.HTTP_400_BAD_REQUEST)

    def test_voice_synthesize_endpoint_phase8(self):
        """Vérifie l'endpoint de synthèse vocale TTS (Phase 8)."""
        with patch('apps.ai_assistant.voice.synthesize_speech_bytes', return_value=b"ID3...FAKE_MP3_BYTES..."):
            response = self.client.post('/api/ai/voice/synthesize/', {
                'text': "Arrosez les oignons tôt le matin pour éviter l'évaporation.",
                'lang': 'fr'
            }, format='json')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('audio_base64', response.data)
        self.assertEqual(response.data['content_type'], 'audio/mp3')

    def test_voice_synthesize_empty_payload(self):
        """Vérifie le rejet d'un texte vide en synthèse vocale."""
        res = self.client.post('/api/ai/voice/synthesize/', {'text': '   '}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

