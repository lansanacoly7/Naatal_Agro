"""
Phase 6 — français / wolof : détection de langue, compréhension des demandes, langue conservée dans la conversation,
et rejet des réponses inexploitables du modèle (brouillon interne, répétitions en boucle).
Le corpus est écrit par l'équipe, non relu par un locuteur natif : ces tests protègent contre les régressions, ils ne
valident pas la qualité du wolof.
"""
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import SimpleTestCase, TestCase
from rest_framework.test import APIClient

from apps.ai_assistant import dialogue, language, llm
from apps.ai_assistant.evaluation.langues import CORPUS, HARD_CORPUS, evaluate
from apps.ai_assistant.models import AIConversation
from apps.ai_assistant.prompt_safety import unusable_reason
from apps.ai_assistant.services import call_llm, unavailable_notice

User = get_user_model()


class DetectionTests(SimpleTestCase):
    def test_french_is_not_taken_for_wolof(self):
        for text in ("Comment traiter le mildiou sur la tomate ?", "J'ai vendu 10 sacs de mil", "Merci beaucoup",
                     "Quel est mon bilan ce mois ?", "ma culture de piment a des taches"):
            with self.subTest(text=text):
                self.assertEqual(language.detect(text).language, language.FRENCH)

    def test_wolof_is_recognised(self):
        for text in ("Naka lañuy fajee soble ?", "Jaay naa 10 sac ceeb ci 15000", "Ndox bi dafa tuuti, lan laay def ?"):
            with self.subTest(text=text):
                self.assertEqual(language.detect(text).language, language.WOLOF)

    def test_mixture(self):
        self.assertEqual(language.detect("Naka laay traiter le mildiou sur ma tomate ?").language, language.MIXED)
        self.assertFalse(language.is_wolof("Naka laay traiter le mildiou sur ma tomate ?"))

    def test_loan_words_alone_do_not_make_a_mixture(self):
        self.assertEqual(language.detect("Ñaata dugub laa am ci sama stock ?").language, language.WOLOF)

    def test_short_message_keeps_the_previous_language(self):
        self.assertEqual(language.detect("oui", previous=language.WOLOF).language, language.WOLOF)
        self.assertEqual(language.detect("15000", previous=language.WOLOF).language, language.WOLOF)
        self.assertEqual(language.detect("oui").language, language.FRENCH)

    def test_a_clearly_french_sentence_overrides_the_previous_language(self):
        self.assertEqual(language.detect("Quel est mon solde du mois ?", previous=language.WOLOF).language, language.FRENCH)

    def test_empty_text(self):
        self.assertEqual(language.detect("").language, language.FRENCH)
        self.assertEqual(language.detect(None).language, language.FRENCH)


class CorpusTests(TestCase):
    """Seuils de non-régression sur le corpus de l'équipe (pas une validation par des locuteurs natifs)."""

    def setUp(self):
        self.user = User.objects.create_user(username='p6', phone='+221770600066', password='Motdepasse#2026')

    def test_main_corpus_is_fully_handled(self):
        report = evaluate(self.user, CORPUS)
        self.assertEqual(report['failures'], [])

    def test_hard_variants_stay_above_threshold(self):
        report = evaluate(self.user, HARD_CORPUS)
        for bucket in ('language', 'intent'):
            for lang, stats in report[bucket].items():
                with self.subTest(bucket=bucket, lang=lang):
                    self.assertGreaterEqual(stats['rate'], 0.9, report['failures'])


class UnusableOutputTests(SimpleTestCase):
    def test_scratchpad_is_detected(self):
        leaked = "/Formatting: Max one **bold** word (\"**jëmbët**\"). Let's use this."
        self.assertEqual(unusable_reason(leaked), 'scratchpad')
        self.assertEqual(unusable_reason("Thinking: l'utilisateur veut savoir"), 'scratchpad')

    def test_loops_are_detected(self):
        looped = ("Duñu am ay xibaar yu leer ci sama tool, ndax duñu am ay xibaar yu leer ci sama tool, "
                  "ndax duñu am ay xibaar yu leer ci sama tool.")
        self.assertEqual(unusable_reason(looped), 'degenerate')

    def test_normal_answers_pass(self):
        for text in ("Arrosez tôt le matin, 2 fois par semaine, et paillez le sol [1].",
                     "- Semez en octobre\n- Repiquez après 30 jours\n- Surveillez les thrips",
                     "Ndox bi dafa tuuti, jëfandikoo ndox bu bari ci suba.", "", None):
            with self.subTest(text=text):
                self.assertIsNone(unusable_reason(text))


class UnusableAnswerFlowTests(SimpleTestCase):
    def fake(self, text):
        return llm.LLMResult(text=text, reason=llm.OK, provider='groq', model='m')

    def test_a_leaked_scratchpad_is_not_shown(self):
        with patch('apps.ai_assistant.services.llm.generate', return_value=self.fake("Let's use this format. Réponse")):
            llm._local.last = self.fake("x")
            self.assertIsNone(call_llm("question"))
        self.assertEqual(llm.last_result().reason, llm.UNUSABLE)

    def test_a_good_answer_is_returned(self):
        with patch('apps.ai_assistant.services.llm.generate', return_value=self.fake("Arrosez le matin.")):
            self.assertEqual(call_llm("question"), "Arrosez le matin.")

    def test_the_notice_is_honest_about_an_unreliable_answer(self):
        self.assertIn("pas réussi", unavailable_notice(llm.UNUSABLE))
        self.assertIn("mon solde", unavailable_notice(llm.UNUSABLE))


class ConversationLanguageTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='p6b', phone='+221770600067', password='Motdepasse#2026')
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.conv = AIConversation.objects.create(user=self.user, title="Langues")

    def ask(self, text):
        return self.client.post('/api/ai/ask/', {'query': text, 'conversation_id': str(self.conv.id)}, format='json')

    def lang(self):
        return dialogue.last_facts(AIConversation.objects.get(pk=self.conv.pk)).get('lang')

    @patch('apps.ai_assistant.views.answer_question')
    def test_language_is_passed_to_the_model_and_remembered(self, answer):
        answer.return_value = {'answer': 'Waaw', 'origin': 'general', 'sources': [], 'suggestions': []}
        self.ask("Naka lañuy fajee soble ?")
        self.assertEqual(answer.call_args.kwargs['language'], 'wo')
        self.assertEqual(self.lang(), language.WOLOF)

        self.ask("Comment traiter le mildiou sur la tomate ?")
        self.assertIsNone(answer.call_args.kwargs['language'])
        self.assertEqual(self.lang(), language.FRENCH)

    @patch('apps.ai_assistant.views.answer_question')
    def test_a_short_followup_stays_in_wolof(self, answer):
        answer.return_value = {'answer': 'Waaw', 'origin': 'general', 'sources': [], 'suggestions': []}
        self.ask("Naka lañuy fajee soble ?")
        self.ask("ndax dina baax")
        self.assertEqual(self.lang(), language.WOLOF)
        self.assertEqual(answer.call_args.kwargs['language'], 'wo')


class WolofFallbackTests(TestCase):
    def test_french_sheet_fallback_says_so_when_asked_in_wolof(self):
        from apps.ai_assistant.services import WOLOF_FALLBACK_NOTICE, answer_question
        from apps.agriculture.models import AgronomicGuide
        AgronomicGuide.objects.get_or_create(name="Oignon Local", defaults={
            'aliases': ['oignon', 'soble'], 'scientific_name': 'Allium cepa', 'category': 'legume'})
        with patch('apps.ai_assistant.services.call_llm', return_value=None):
            wolof = answer_question("Naka lañuy fajee soble ?")
            french = answer_question("Comment traiter les maladies de l'oignon ?")
        if wolof['origin'] == 'database':
            self.assertIn(WOLOF_FALLBACK_NOTICE, wolof['answer'])
        self.assertNotIn(WOLOF_FALLBACK_NOTICE, french['answer'])
