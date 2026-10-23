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
        dummy_audio = b"RIFF....WAVEfmt ...." + b"\x00" * 4000
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

    def test_server_side_synthesis_endpoint_is_gone(self):
        """La lecture vocale se fait sur l'appareil : plus aucun texte n'est envoyé à un serveur pour être lu."""
        res = self.client.post('/api/ai/voice/synthesize/', {'text': 'Bonjour'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)


class VoiceTranscriptionHardeningTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='p7', phone='+221770600077', password='Motdepasse#2026')
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def post(self, audio=b"\x00" * 4000):
        return self.client.post('/api/ai/voice/transcribe/', {'audio_base64': base64.b64encode(audio).decode('ascii')},
                                format='json')

    def test_browser_recordings_are_sent_with_their_real_format(self):
        """Le navigateur enregistre en WebM/Ogg : le service ne doit pas recevoir une étiquette « .m4a »."""
        cases = [
            (b'\x1a\x45\xdf\xa3' + b'\x00' * 4000, 'audio.webm', 'audio/webm'),
            (b'OggS' + b'\x00' * 4000, 'audio.ogg', 'audio/ogg'),
            (b'\x00\x00\x00\x20ftypM4A ' + b'\x00' * 4000, 'audio.m4a', 'audio/mp4'),
            (b'\x00' * 4000, 'audio.m4a', 'audio/m4a'),  # format inconnu : comportement d'origine
        ]
        for audio, filename, content_type in cases:
            with patch('apps.ai_assistant.voice.transcribe_audio_bytes', return_value='ok') as service:
                res = self.post(audio)
            self.assertEqual(res.status_code, 200)
            self.assertEqual(service.call_args.kwargs['filename'], filename)
            self.assertEqual(service.call_args.kwargs['content_type'], content_type)

    def test_too_short_recording_is_rejected_without_calling_the_service(self):
        with patch('apps.ai_assistant.voice.transcribe_audio_bytes') as service:
            res = self.post(b"\x00" * 100)
        service.assert_not_called()
        self.assertEqual(res.status_code, 422)
        self.assertEqual(res.data['code'], 'too_short')

    def test_oversized_recording_is_rejected(self):
        with patch('apps.ai_assistant.voice.MAX_AUDIO_BYTES', 3000), patch('apps.ai_assistant.voice.transcribe_audio_bytes') as service:
            res = self.post(b"\x00" * 4000)
        service.assert_not_called()
        self.assertEqual(res.status_code, 413)

    def test_nothing_audible_is_reported_clearly(self):
        with patch('apps.ai_assistant.voice.transcribe_audio_bytes', return_value=''):
            res = self.post()
        self.assertEqual(res.status_code, 422)
        self.assertEqual(res.data['code'], 'no_speech')

    def test_service_outage_suggests_typing(self):
        with patch('apps.ai_assistant.voice.transcribe_audio_bytes', return_value=None):
            res = self.post()
        self.assertEqual(res.status_code, 503)
        self.assertIn("écrire", res.data['error'])

    def test_silence_hallucinations_are_dropped(self):
        from apps.ai_assistant import voice
        self.assertTrue(voice.is_silence_hallucination("Sous-titres réalisés par la communauté d'Amara.org"))
        self.assertFalse(voice.is_silence_hallucination("J'ai vendu dix sacs de mil"))

    def test_service_never_logs_the_provider_body(self):
        from apps.ai_assistant import voice
        reply = type('R', (), {'status_code': 500, 'text': 'SECRET-TRANSCRIPT', 'json': lambda self: {}})()
        with patch('apps.ai_assistant.voice.requests.post', return_value=reply), \
                self.settings(GROQ_API_KEY='k'), self.assertLogs('apps.ai_assistant.voice', 'ERROR') as logs:
            self.assertIsNone(voice.transcribe_audio_bytes(b"\x00" * 4000))
        self.assertNotIn('SECRET-TRANSCRIPT', ''.join(logs.output))
