from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from apps.ai_assistant.models import AIInteraction
from apps.ai_assistant.services import answer_question, split_suggestions

User = get_user_model()
LLM = 'apps.ai_assistant.services.call_llm'


class SplitSuggestionsTests(TestCase):
    def test_extracts_the_suggestions_line_and_removes_it_from_the_text(self):
        text, suggestions = split_suggestions('Semez en octobre [1].\n\nSUGGESTIONS: Quel engrais ? | Quelles maladies ? | Quand récolter ?')
        self.assertEqual(text, 'Semez en octobre [1].')
        self.assertEqual(suggestions, ['Quel engrais ?', 'Quelles maladies ?', 'Quand récolter ?'])

    def test_no_suggestions_line(self):
        self.assertEqual(split_suggestions('Bonjour'), ('Bonjour', []))

    def test_at_most_three_suggestions(self):
        _, suggestions = split_suggestions('Ok.\nSUGGESTIONS: a | b | c | d | e')
        self.assertEqual(len(suggestions), 3)


class ConversationalAnswerTests(TestCase):
    def test_suggestions_of_the_model_are_returned_and_hidden_from_the_answer(self):
        raw = 'Semez en pépinière [1].\nSUGGESTIONS: Quel engrais ? | Combien de jours ?'
        with patch(LLM, return_value=raw):
            result = answer_question('Comment semer les tomates ?')
        self.assertNotIn('SUGGESTIONS', result['answer'])
        self.assertEqual(result['suggestions'], ['Quel engrais ?', 'Combien de jours ?'])

    def test_without_llm_a_broad_question_gets_a_short_answer_and_follow_ups(self):
        with patch(LLM, return_value=None):
            result = answer_question('je veux cultiver les patates douces')
        self.assertLess(len(result['answer']), 700)
        self.assertIn('Que voulez-vous savoir', result['answer'])
        self.assertTrue(result['suggestions'])

    def test_follow_up_question_uses_the_previous_crop(self):
        history = [{'role': 'user', 'content': 'je veux cultiver les patates douces'},
                   {'role': 'assistant', 'content': 'La patate douce est rustique.'}]
        with patch(LLM, return_value=None):
            result = answer_question("et pour l'engrais ?", history=history)
        self.assertEqual(result['origin'], 'database')
        self.assertIn('Fertilisation', result['answer'])

    def test_history_is_given_to_the_model(self):
        history = [{'role': 'user', 'content': 'je veux cultiver les patates douces'},
                   {'role': 'assistant', 'content': 'Très bien.'}]
        with patch(LLM, return_value='Fumure [1].') as llm:
            answer_question("et pour l'engrais ?", history=history)
        prompt = llm.call_args[0][0]
        self.assertIn('CONVERSATION EN COURS', prompt)
        self.assertIn('je veux cultiver les patates douces', prompt)


class AskEndpointConversationTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='+221771400001', phone='+221771400001', password='x')
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def test_recent_exchanges_are_used_as_memory_when_the_app_sends_no_history(self):
        AIInteraction.objects.create(user=self.user, query='je veux cultiver les patates douces', response='Ok.')
        with patch(LLM, return_value=None) as llm:
            response = self.client.post('/api/ai/ask/', {'query': "et pour l'engrais ?"}, format='json')
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['origin'], 'database')
        self.assertIn('suggestions', response.data)

    def test_history_sent_by_the_app_is_used(self):
        body = {'query': "et l'engrais ?", 'history': [{'role': 'user', 'content': 'je cultive la tomate'}]}
        with patch(LLM, return_value=None):
            response = self.client.post('/api/ai/ask/', body, format='json')
        self.assertEqual(response.data['origin'], 'database')

    def test_invalid_history_is_ignored(self):
        with patch(LLM, return_value='Bonjour !'):
            response = self.client.post('/api/ai/ask/', {'query': 'bonjour', 'history': 'n importe quoi'}, format='json')
        self.assertEqual(response.status_code, 201)
