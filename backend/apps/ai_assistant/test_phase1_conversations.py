import uuid
from unittest.mock import patch
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from apps.ai_assistant.models import AIConversation, AIInteraction

User = get_user_model()
LLM = 'apps.ai_assistant.services.call_llm'


class Phase1ConversationTests(TestCase):
    def setUp(self):
        self.user_ali = User.objects.create_user(
            username='+221770000001',
            phone='+221770000001',
            password='Password123#',
            first_name='Ali'
        )
        self.user_binta = User.objects.create_user(
            username='+221770000002',
            phone='+221770000002',
            password='Password123#',
            first_name='Binta'
        )
        self.client_ali = APIClient()
        self.client_ali.force_authenticate(self.user_ali)

        self.client_binta = APIClient()
        self.client_binta.force_authenticate(self.user_binta)

    def test_create_conversation_endpoint(self):
        """Vérifie la création explicite d'une conversation."""
        response = self.client_ali.post('/api/ai/conversations/', {'title': 'Diagnostic Tomates Niayes'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['title'], 'Diagnostic Tomates Niayes')
        self.assertIn('id', response.data)
        self.assertEqual(response.data['interactions'], [])

    def test_list_conversations_isolated(self):
        """Vérifie que chaque utilisateur ne voit QUE ses propres conversations."""
        conv_ali = AIConversation.objects.create(user=self.user_ali, title="Cultures Ali")
        conv_binta = AIConversation.objects.create(user=self.user_binta, title="Cultures Binta")

        res_ali = self.client_ali.get('/api/ai/conversations/')
        self.assertEqual(res_ali.status_code, status.HTTP_200_OK)
        ids_ali = [c['id'] for c in res_ali.data]
        self.assertIn(str(conv_ali.id), ids_ali)
        self.assertNotIn(str(conv_binta.id), ids_ali)

        res_binta = self.client_binta.get('/api/ai/conversations/')
        self.assertEqual(res_binta.status_code, status.HTTP_200_OK)
        ids_binta = [c['id'] for c in res_binta.data]
        self.assertIn(str(conv_binta.id), ids_binta)
        self.assertNotIn(str(conv_ali.id), ids_binta)

    def test_conversation_detail_and_multi_tenant_protection(self):
        """Vérifie qu'un utilisateur ne peut pas lire la conversation d'un autre."""
        conv_ali = AIConversation.objects.create(user=self.user_ali, title="Secret Ali")

        # Ali peut lire sa conversation
        res_ok = self.client_ali.get(f'/api/ai/conversations/{conv_ali.id}/')
        self.assertEqual(res_ok.status_code, status.HTTP_200_OK)

        # Binta reçoit un 404
        res_forbidden = self.client_binta.get(f'/api/ai/conversations/{conv_ali.id}/')
        self.assertEqual(res_forbidden.status_code, status.HTTP_404_NOT_FOUND)

    def test_conversation_rename(self):
        """Vérifie le renommage d'une conversation par son propriétaire."""
        conv = AIConversation.objects.create(user=self.user_ali, title="Ancien titre")
        response = self.client_ali.patch(f'/api/ai/conversations/{conv.id}/', {'title': 'Nouveau titre'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['title'], 'Nouveau titre')
        conv.refresh_from_db()
        self.assertEqual(conv.title, 'Nouveau titre')

        # Binta ne peut pas renommer la conversation d'Ali
        res_binta = self.client_binta.patch(f'/api/ai/conversations/{conv.id}/', {'title': 'Piratage'}, format='json')
        self.assertEqual(res_binta.status_code, status.HTTP_404_NOT_FOUND)

    def test_conversation_delete_cascade(self):
        """Vérifie la suppression d'une conversation et de toutes ses interactions associées."""
        conv = AIConversation.objects.create(user=self.user_ali, title="À supprimer")
        AIInteraction.objects.create(
            user=self.user_ali,
            conversation=conv,
            query="Question 1",
            response="Réponse 1"
        )
        self.assertEqual(conv.interactions.count(), 1)

        response = self.client_ali.delete(f'/api/ai/conversations/{conv.id}/')
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(AIConversation.objects.filter(id=conv.id).exists())
        self.assertFalse(AIInteraction.objects.filter(query="Question 1").exists())

    def test_ask_ai_with_conversation_id(self):
        """Vérifie qu'un message envoyé avec un conversation_id est rattaché au fil."""
        conv = AIConversation.objects.create(user=self.user_ali, title="Discussion Riz")
        with patch(LLM, return_value="Pour le riz, irriguez régulièrement [1].\nSUGGESTIONS: Quand récolter ? | Quel engrais ?"):
            response = self.client_ali.post('/api/ai/ask/', {
                'query': 'Comment arroser le riz ?',
                'conversation_id': str(conv.id)
            }, format='json')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(str(response.data['conversation']), str(conv.id))
        self.assertEqual(conv.interactions.count(), 1)
        conv.refresh_from_db()
        # Le titre reste "Discussion Riz" car il n'était pas par défaut
        self.assertEqual(conv.title, "Discussion Riz")

    def test_ask_ai_without_conversation_id_creates_auto_conversation(self):
        """Vérifie qu'un message sans conversation_id génère automatiquement une nouvelle session."""
        with patch(LLM, return_value="La tomate demande un sol bien drainé.\nSUGGESTIONS: Quel engrais ?"):
            response = self.client_ali.post('/api/ai/ask/', {
                'query': 'Quel sol pour la tomate dans les Niayes ?',
            }, format='json')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIsNotNone(response.data['conversation'])
        conv = AIConversation.objects.get(id=response.data['conversation'])
        self.assertEqual(conv.user, self.user_ali)
        self.assertIn('Quel sol pour la tomate', conv.title)

    def test_ask_ai_with_foreign_conversation_id_is_rejected(self):
        """Vérifie qu'un utilisateur ne peut pas poster dans la conversation d'un autre."""
        conv_ali = AIConversation.objects.create(user=self.user_ali, title="Ali Privé")
        with patch(LLM, return_value="Réponse"):
            response = self.client_binta.post('/api/ai/ask/', {
                'query': 'Tentative intrusion',
                'conversation_id': str(conv_ali.id)
            }, format='json')

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(conv_ali.interactions.count(), 0)

    def test_invalid_uuid_handling(self):
        """Vérifie qu'un UUID malformé renvoie 400 Bad Request et ne crash pas."""
        res_get = self.client_ali.get('/api/ai/conversations/not-a-valid-uuid/')
        self.assertEqual(res_get.status_code, status.HTTP_400_BAD_REQUEST)

        res_post = self.client_ali.post('/api/ai/ask/', {
            'query': 'Test',
            'conversation_id': 'bad-uuid-format'
        }, format='json')
        self.assertEqual(res_post.status_code, status.HTTP_400_BAD_REQUEST)

    def test_get_ask_ai_with_conversation_id_filter(self):
        """Vérifie la récupération ciblée d'interactions par conversation_id."""
        conv1 = AIConversation.objects.create(user=self.user_ali, title="Fil 1")
        conv2 = AIConversation.objects.create(user=self.user_ali, title="Fil 2")
        AIInteraction.objects.create(user=self.user_ali, conversation=conv1, query="Q1", response="R1")
        AIInteraction.objects.create(user=self.user_ali, conversation=conv2, query="Q2", response="R2")

        # Récupération spécifique du fil 1
        res1 = self.client_ali.get(f'/api/ai/ask/?conversation_id={conv1.id}')
        self.assertEqual(res1.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res1.data), 1)
        self.assertEqual(res1.data[0]['query'], 'Q1')

        # Binta ne peut pas filtrer sur le fil d'Ali (404)
        res_foreign = self.client_binta.get(f'/api/ai/ask/?conversation_id={conv1.id}')
        self.assertEqual(res_foreign.status_code, status.HTTP_404_NOT_FOUND)
