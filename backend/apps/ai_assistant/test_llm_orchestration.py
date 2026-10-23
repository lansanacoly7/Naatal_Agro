"""
Orchestration des modèles de langage : repli, budget de temps, disjoncteurs, rotation des clés, quota quotidien,
journal sans contenu, absence de repli vers un modèle sans vision. Faux fournisseurs + horloge simulée : aucun appel réseau.
"""
from unittest.mock import MagicMock, patch

import requests
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import SimpleTestCase, TestCase, override_settings

from apps.ai_assistant import llm
from apps.ai_assistant.models import LLMUsage

User = get_user_model()

SECRET_PROMPT = "PROMPT-CONFIDENTIEL-solde-de-Moussa-482000"


class FakeClock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now


class FakeProvider(llm.Provider):
    """Fournisseur scripté : chaque appel consomme une issue (texte ou ``ProviderError``) et fait avancer l'horloge."""

    def __init__(self, name, outcomes, clock=None, cost=0.0, keys=('k',), models=('m',), vision=True):
        self.name = name
        self.supports_vision = vision
        self.outcomes = list(outcomes)
        self.clock = clock
        self.cost = cost
        self._keys = list(keys)
        self._models = list(models)
        self.calls = []  # (clé, modèle, délai accordé)

    def credentials(self):
        return self._keys

    def models(self, request):
        return self._models

    def complete(self, unit, request, timeout):
        self.calls.append((unit.credential, unit.model, timeout))
        if self.clock:
            self.clock.now += min(self.cost, timeout) if self.cost else 0.0
        outcome = self.outcomes.pop(0) if self.outcomes else llm.ProviderError(llm.SERVER, 'épuisé')
        if isinstance(outcome, llm.ProviderError):
            raise outcome
        return llm.Completion(outcome, 11, 7)


def request(**overrides):
    return llm.LLMRequest(system="système", prompt=overrides.pop('prompt', SECRET_PROMPT), **overrides)


def orchestrator(*providers, clock=None):
    return llm.LLMOrchestrator({p.name: p for p in providers}, clock=clock or FakeClock())


@override_settings(AI_PROVIDER_ORDER='alpha,beta', AI_VISION_PROVIDER_ORDER='alpha,beta', AI_MAX_ATTEMPTS=4,
                   AI_TOTAL_BUDGET_SECONDS=40.0, AI_ATTEMPT_TIMEOUT_SECONDS=14.0, AI_VISION_ATTEMPT_TIMEOUT_SECONDS=20.0,
                   AI_DAILY_CALLS_PER_USER=150)
class OrchestratorTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user(username='llm1', phone='+221770950001', password='Motdepasse#2026')

    # --- repli ------------------------------------------------------------------------------------------------
    def test_first_provider_answers(self):
        alpha, beta = FakeProvider('alpha', ['Bonjour']), FakeProvider('beta', ['inutilisé'])
        result = orchestrator(alpha, beta).generate(request(), user=self.user)
        self.assertEqual((result.text, result.reason, result.provider), ('Bonjour', llm.OK, 'alpha'))
        self.assertEqual(len(alpha.calls), 1)
        self.assertEqual(beta.calls, [])

    def test_failover_to_the_next_provider(self):
        alpha = FakeProvider('alpha', [llm.ProviderError(llm.SERVER)])
        beta = FakeProvider('beta', ['Secours'])
        result = orchestrator(alpha, beta).generate(request(), user=self.user)
        self.assertEqual((result.text, result.provider), ('Secours', 'beta'))
        self.assertEqual([(a.unit, a.ok, a.kind) for a in result.attempts], [('alpha#0/m', False, 'server'), ('beta#0/m', True, '')])

    def test_every_provider_failing_gives_unavailable_without_raising(self):
        alpha = FakeProvider('alpha', [llm.ProviderError(llm.TIMEOUT)])
        beta = FakeProvider('beta', [llm.ProviderError(llm.NETWORK)])
        result = orchestrator(alpha, beta).generate(request(), user=self.user)
        self.assertIsNone(result.text)
        self.assertFalse(result.ok)
        self.assertEqual(result.reason, llm.UNAVAILABLE)

    def test_no_configured_provider(self):
        result = orchestrator(FakeProvider('alpha', [], keys=()), FakeProvider('beta', [], keys=())).generate(request())
        self.assertEqual(result.reason, llm.NOT_CONFIGURED)
        self.assertEqual(result.attempts, [])

    def test_unknown_names_in_the_order_are_ignored(self):
        with override_settings(AI_PROVIDER_ORDER='fantome,alpha'):
            result = orchestrator(FakeProvider('alpha', ['ok'])).generate(request())
        self.assertEqual(result.text, 'ok')

    def test_empty_answer_counts_as_a_failure_and_falls_over(self):
        alpha, beta = FakeProvider('alpha', ['   ']), FakeProvider('beta', ['Réponse'])
        result = orchestrator(alpha, beta).generate(request())
        self.assertEqual((result.text, result.provider), ('Réponse', 'beta'))
        self.assertEqual(result.attempts[0].kind, llm.BAD_RESPONSE)

    def test_reasoning_blocks_are_removed(self):
        result = orchestrator(FakeProvider('alpha', ['<think>je réfléchis…</think>Réponse nette'])).generate(request())
        self.assertEqual(result.text, 'Réponse nette')

    # --- budget de temps --------------------------------------------------------------------------------------
    def test_total_duration_never_exceeds_the_budget_whatever_the_providers_do(self):
        """Tous les appels consomment leur délai complet puis échouent : le total doit rester dans le budget."""
        clock = FakeClock()
        timeouts = [llm.ProviderError(llm.TIMEOUT)] * 10
        alpha = FakeProvider('alpha', timeouts, clock, cost=99, models=('m1', 'm2'))
        beta = FakeProvider('beta', timeouts, clock, cost=99, models=('m1', 'm2'))
        result = orchestrator(alpha, beta, clock=clock).generate(request())
        self.assertIsNone(result.text)
        self.assertLessEqual(clock.now, 40.0)               # budget global respecté
        self.assertLessEqual(len(result.attempts), 4)       # et nombre de tentatives borné
        granted = [t for p in (alpha, beta) for (_, _, t) in p.calls]
        self.assertTrue(all(t <= 14.0 for t in granted))    # aucune tentative au-delà de son délai propre

    def test_remaining_budget_caps_the_last_attempt_and_then_stops(self):
        clock = FakeClock()
        with override_settings(AI_TOTAL_BUDGET_SECONDS=20.0, AI_MAX_ATTEMPTS=10):
            alpha = FakeProvider('alpha', [llm.ProviderError(llm.TIMEOUT)] * 10, clock, cost=99, models=('a', 'b', 'c', 'd'))
            result = orchestrator(alpha, clock=clock).generate(request())
        self.assertEqual([t for (_, _, t) in alpha.calls], [14.0, 6.0])  # 20 s - 14 s = 6 s pour la dernière
        self.assertEqual(result.reason, llm.BUDGET_EXHAUSTED)
        self.assertLessEqual(clock.now, 20.0)

    def test_the_default_budget_leaves_room_before_the_server_timeout(self):
        from django.conf import settings
        self.assertLess(settings.AI_TOTAL_BUDGET_SECONDS, 60)  # gunicorn et nginx coupent à 60 s

    def test_attempt_cap(self):
        alpha = FakeProvider('alpha', [llm.ProviderError(llm.SERVER)] * 10, models=('a', 'b', 'c'))
        beta = FakeProvider('beta', [llm.ProviderError(llm.SERVER)] * 10, models=('a', 'b', 'c'))
        with override_settings(AI_MAX_ATTEMPTS=2):
            result = orchestrator(alpha, beta).generate(request())
        self.assertEqual(len(result.attempts), 2)

    # --- disjoncteurs -----------------------------------------------------------------------------------------
    def test_rate_limited_provider_is_set_aside_for_following_requests(self):
        alpha = FakeProvider('alpha', [llm.ProviderError(llm.RATE_LIMITED, retry_after=90)])
        beta = FakeProvider('beta', ['un', 'deux'])
        orch = orchestrator(alpha, beta)
        orch.generate(request())
        second = orch.generate(request())
        self.assertEqual(len(alpha.calls), 1)  # pas rappelé à la deuxième demande
        self.assertEqual(second.text, 'deux')
        self.assertEqual(len(second.attempts), 1)

    def test_auth_error_sets_the_whole_key_aside_but_not_the_other_keys(self):
        alpha = FakeProvider('alpha', [llm.ProviderError(llm.AUTH), 'avec la 2e clé'], keys=('bad', 'good'), models=('m1', 'm2'))
        result = orchestrator(alpha).generate(request())
        # unités : (m1, clé0) (m1, clé1) (m2, clé0) (m2, clé1) ; la clé 0 est écartée entièrement après l'erreur d'authentification
        self.assertEqual([(c, m) for c, m, _ in alpha.calls], [(0, 'm1'), (1, 'm1')])
        self.assertEqual(result.text, 'avec la 2e clé')

    def test_missing_model_is_not_retried_for_a_while(self):
        alpha = FakeProvider('alpha', [llm.ProviderError(llm.BAD_RESPONSE, permanent=True), 'ok', 'ok2'], models=('absent', 'présent'))
        orch = orchestrator(alpha)
        orch.generate(request())
        orch.generate(request())
        self.assertEqual([m for _, m, _ in alpha.calls], ['absent', 'présent', 'présent'])

    def test_three_consecutive_server_failures_open_the_breaker(self):
        alpha = FakeProvider('alpha', [llm.ProviderError(llm.SERVER)] * 3 + ['récupéré'])
        beta = FakeProvider('beta', ['b1', 'b2', 'b3', 'b4'])
        orch = orchestrator(alpha, beta)
        for _ in range(3):
            orch.generate(request())
        self.assertEqual(len(alpha.calls), 3)
        orch.generate(request())
        self.assertEqual(len(alpha.calls), 3)  # disjoncteur ouvert : alpha n'est plus appelé

    def test_a_success_resets_the_failure_count(self):
        alpha = FakeProvider('alpha', [llm.ProviderError(llm.SERVER), llm.ProviderError(llm.SERVER), 'ok',
                                       llm.ProviderError(llm.SERVER), llm.ProviderError(llm.SERVER), 'ok2'])
        beta = FakeProvider('beta', ['b'] * 10)
        orch = orchestrator(alpha, beta)
        for _ in range(6):
            orch.generate(request())
        self.assertEqual(len(alpha.calls), 6)  # jamais 3 échecs d'affilée : jamais écarté

    # --- vision -----------------------------------------------------------------------------------------------
    def test_photo_analysis_never_falls_back_to_a_model_without_vision(self):
        blind = FakeProvider('alpha', ['je « vois » une image que je ne vois pas'], vision=False)
        result = orchestrator(blind).generate(request(image_base64='AAAA'))
        self.assertEqual(result.reason, llm.NOT_CONFIGURED)
        self.assertEqual(blind.calls, [])  # le modèle aveugle n'est jamais interrogé

    def test_photo_analysis_uses_the_next_vision_provider(self):
        alpha = FakeProvider('alpha', [llm.ProviderError(llm.SERVER)])
        beta = FakeProvider('beta', ['Mildiou probable'])
        result = orchestrator(alpha, beta).generate(request(image_base64='AAAA'))
        self.assertEqual((result.text, result.provider), ('Mildiou probable', 'beta'))

    def test_photo_attempts_get_the_longer_timeout(self):
        alpha = FakeProvider('alpha', ['ok'])
        orchestrator(alpha).generate(request(image_base64='AAAA'))
        self.assertEqual(alpha.calls[0][2], 20.0)

    # --- quota quotidien --------------------------------------------------------------------------------------
    def test_daily_limit_blocks_before_any_call(self):
        alpha = FakeProvider('alpha', ['jamais'])
        for _ in range(3):
            LLMUsage.objects.create(user=self.user, provider='alpha', model='m', ok=True)
        with override_settings(AI_DAILY_CALLS_PER_USER=3):
            result = orchestrator(alpha).generate(request(), user=self.user)
        self.assertEqual(result.reason, llm.DAILY_LIMIT)
        self.assertEqual(alpha.calls, [])

    def test_failed_attempts_and_other_users_do_not_count_toward_the_limit(self):
        other = User.objects.create_user(username='llm2', phone='+221770950002', password='Motdepasse#2026')
        for _ in range(5):
            LLMUsage.objects.create(user=self.user, provider='alpha', model='m', ok=False, error_kind='server')
            LLMUsage.objects.create(user=other, provider='alpha', model='m', ok=True)
        with override_settings(AI_DAILY_CALLS_PER_USER=3):
            result = orchestrator(FakeProvider('alpha', ['ok'])).generate(request(), user=self.user)
        self.assertEqual(result.text, 'ok')

    def test_anonymous_calls_are_not_limited(self):
        with override_settings(AI_DAILY_CALLS_PER_USER=1):
            self.assertEqual(orchestrator(FakeProvider('alpha', ['ok'])).generate(request(), user=None).text, 'ok')

    # --- journal d'usage --------------------------------------------------------------------------------------
    def test_every_attempt_is_logged_without_any_content(self):
        alpha = FakeProvider('alpha', [llm.ProviderError(llm.SERVER)])
        beta = FakeProvider('beta', ['Réponse privée sur le solde'])
        orchestrator(alpha, beta).generate(request(), user=self.user)
        rows = list(LLMUsage.objects.order_by('created_at'))
        self.assertEqual([(r.provider, r.ok, r.error_kind) for r in rows], [('alpha', False, 'server'), ('beta', True, '')])
        ok_row = rows[1]
        self.assertEqual((ok_row.user, ok_row.model, ok_row.feature), (self.user, 'm', 'chat'))
        self.assertEqual((ok_row.prompt_tokens, ok_row.completion_tokens), (11, 7))
        self.assertEqual(ok_row.completion_chars, len('Réponse privée sur le solde'))
        for row in rows:  # ni le prompt, ni la réponse, ne sont conservés
            self.assertNotIn('482000', repr(row.__dict__))
            self.assertNotIn('solde', repr(row.__dict__))

    def test_logging_failure_never_breaks_the_answer(self):
        with patch('apps.ai_assistant.models.LLMUsage.objects.create', side_effect=RuntimeError('base indisponible')):
            result = orchestrator(FakeProvider('alpha', ['Réponse'])).generate(request(), user=self.user)
        self.assertEqual(result.text, 'Réponse')

    def test_last_result_is_exposed_and_resettable(self):
        orchestrator(FakeProvider('alpha', [llm.ProviderError(llm.SERVER)])).generate(request())
        self.assertEqual(llm.last_result().reason, llm.UNAVAILABLE)
        llm.reset_last_result()
        self.assertIsNone(llm.last_result())

    def test_module_level_generate_uses_the_replaceable_orchestrator(self):
        llm.set_orchestrator(orchestrator(FakeProvider('alpha', ['via le module'])))
        try:
            self.assertEqual(llm.generate(request()).text, 'via le module')
        finally:
            llm.set_orchestrator(None)


def response(status=200, body=None, headers=None, json_error=False):
    mock = MagicMock()
    mock.status_code = status
    mock.headers = headers or {}
    if json_error:
        mock.json.side_effect = ValueError('pas du JSON')
    else:
        mock.json.return_value = body if body is not None else {}
    return mock


GROQ_OK = {'choices': [{'message': {'content': 'Arrosez le soir.'}}], 'usage': {'prompt_tokens': 120, 'completion_tokens': 30}}
GEMINI_OK = {'candidates': [{'content': {'parts': [{'text': 'Arrosez '}, {'text': 'le soir.'}]}}],
             'usageMetadata': {'promptTokenCount': 99, 'candidatesTokenCount': 21}}


@override_settings(GROQ_API_KEY='groq-secret', GROQ_MODEL='qwen/test', GROQ_VISION_MODEL='vision/test',
                   AI_GROQ_FALLBACK_MODELS='openai/secours', GEMINI_API_KEYS=['gem-1', 'gem-2'], GEMINI_MODEL='gemini-test',
                   AI_GEMINI_FALLBACK_MODELS='gemini-secours')
class HttpProviderTests(SimpleTestCase):
    def call(self, provider, reply, req=None, unit_index=0):
        unit = provider.units(req or request())[unit_index]
        with patch('apps.ai_assistant.llm.requests.post', return_value=reply) as post:
            completion = provider.complete(unit, req or request(), 9.0)
        return completion, post

    def fails(self, provider, reply=None, side_effect=None):
        unit = provider.units(request())[0]
        with patch('apps.ai_assistant.llm.requests.post', return_value=reply, side_effect=side_effect):
            with self.assertRaises(llm.ProviderError) as ctx:
                provider.complete(unit, request(), 9.0)
        return ctx.exception

    # --- Groq -------------------------------------------------------------------------------------------------
    def test_groq_request_shape_and_parsing(self):
        completion, post = self.call(llm.GroqProvider(), response(body=GROQ_OK))
        self.assertEqual((completion.text, completion.prompt_tokens, completion.completion_tokens), ('Arrosez le soir.', 120, 30))
        args, kwargs = post.call_args
        self.assertEqual(kwargs['headers']['Authorization'], 'Bearer groq-secret')
        self.assertEqual(kwargs['timeout'], (llm.CONNECT_TIMEOUT, 9.0))
        payload = kwargs['json']
        self.assertEqual(payload['model'], 'qwen/test')
        self.assertEqual([m['role'] for m in payload['messages']], ['system', 'user'])
        self.assertEqual(payload['messages'][0]['content'], 'système')

    def test_groq_models_text_fallback_and_vision(self):
        provider = llm.GroqProvider()
        self.assertEqual([u.model for u in provider.units(request())], ['qwen/test', 'openai/secours'])
        vision = provider.units(request(image_base64='AAAA'))
        self.assertEqual([u.model for u in vision], ['vision/test'])

    def test_groq_vision_payload_carries_the_image(self):
        req = request(image_base64='QUJD', image_mime='image/png')
        _, post = self.call(llm.GroqProvider(), response(body=GROQ_OK), req)
        content = post.call_args.kwargs['json']['messages'][1]['content']
        self.assertEqual(content[0], {'type': 'text', 'text': SECRET_PROMPT})
        self.assertEqual(content[1]['image_url']['url'], 'data:image/png;base64,QUJD')

    # --- Gemini -----------------------------------------------------------------------------------------------
    def test_gemini_request_shape_and_parsing(self):
        completion, post = self.call(llm.GeminiProvider(), response(body=GEMINI_OK))
        self.assertEqual((completion.text, completion.prompt_tokens, completion.completion_tokens), ('Arrosez le soir.', 99, 21))
        args, kwargs = post.call_args
        self.assertIn('/models/gemini-test:generateContent', args[0])
        self.assertEqual(kwargs['headers']['x-goog-api-key'], 'gem-1')
        self.assertNotIn('key=', args[0])  # la clé n'apparaît jamais dans l'URL (et donc jamais dans les journaux)
        payload = kwargs['json']
        self.assertEqual(payload['systemInstruction']['parts'][0]['text'], 'système')  # les consignes ne sont pas mêlées à la question
        self.assertEqual(payload['contents'][0]['parts'], [{'text': SECRET_PROMPT}])

    def test_gemini_image_and_key_rotation_order(self):
        provider = llm.GeminiProvider()
        units = provider.units(request())
        # le modèle prioritaire est essayé avec chaque clé AVANT de passer au modèle de repli
        self.assertEqual([(u.credential, u.model) for u in units],
                         [(0, 'gemini-test'), (1, 'gemini-test'), (0, 'gemini-secours'), (1, 'gemini-secours')])
        req = request(image_base64='QUJD')
        _, post = self.call(provider, response(body=GEMINI_OK), req, unit_index=1)
        self.assertEqual(post.call_args.kwargs['headers']['x-goog-api-key'], 'gem-2')
        self.assertEqual(post.call_args.kwargs['json']['contents'][0]['parts'][1], {'inline_data': {'mime_type': 'image/jpeg', 'data': 'QUJD'}})

    def test_gemini_blocked_prompt_is_a_failure_not_an_empty_answer(self):
        error = self.fails(llm.GeminiProvider(), response(body={'promptFeedback': {'blockReason': 'SAFETY'}}))
        self.assertEqual(error.kind, llm.BAD_RESPONSE)

    # --- erreurs communes -------------------------------------------------------------------------------------
    def test_http_errors_are_classified(self):
        provider = llm.GroqProvider()
        cases = [(429, llm.RATE_LIMITED), (401, llm.AUTH), (403, llm.AUTH), (404, llm.BAD_RESPONSE), (408, llm.TIMEOUT),
                 (500, llm.SERVER), (503, llm.SERVER), (400, llm.BAD_RESPONSE)]
        for status, kind in cases:
            with self.subTest(status=status):
                self.assertEqual(self.fails(provider, response(status=status)).kind, kind)

    def test_rate_limit_reads_retry_after_and_missing_model_is_permanent(self):
        self.assertEqual(self.fails(llm.GroqProvider(), response(status=429, headers={'retry-after': '42'})).retry_after, 42.0)
        self.assertIsNone(self.fails(llm.GroqProvider(), response(status=429, headers={'retry-after': 'bientôt'})).retry_after)
        self.assertTrue(self.fails(llm.GroqProvider(), response(status=404)).permanent)

    def test_network_problems_are_classified(self):
        provider = llm.GeminiProvider()
        self.assertEqual(self.fails(provider, side_effect=requests.Timeout()).kind, llm.TIMEOUT)
        self.assertEqual(self.fails(provider, side_effect=requests.ConnectionError()).kind, llm.NETWORK)
        self.assertEqual(self.fails(provider, side_effect=requests.exceptions.SSLError()).kind, llm.NETWORK)

    def test_malformed_responses_are_failures(self):
        for provider, body in ((llm.GroqProvider(), {'choices': []}), (llm.GroqProvider(), {'nope': 1}),
                               (llm.GeminiProvider(), {'candidates': []}), (llm.GeminiProvider(), {})):
            with self.subTest(provider=provider.name, body=body):
                self.assertEqual(self.fails(provider, response(body=body)).kind, llm.BAD_RESPONSE)
        self.assertEqual(self.fails(llm.GroqProvider(), response(json_error=True)).kind, llm.BAD_RESPONSE)

    def test_error_messages_never_contain_keys_or_prompt(self):
        for status in (401, 429, 500):
            error = self.fails(llm.GroqProvider(), response(status=status, body={'error': SECRET_PROMPT}))
            self.assertNotIn('groq-secret', str(error))
            self.assertNotIn('482000', str(error))

    # --- configuration ----------------------------------------------------------------------------------------
    def test_unconfigured_providers_report_it(self):
        with override_settings(GROQ_API_KEY=None, GEMINI_API_KEYS=[]):
            self.assertFalse(llm.GroqProvider().configured())
            self.assertFalse(llm.GeminiProvider().configured())

    def test_gemini_key_list_merges_list_and_single_key_without_duplicates(self):
        """GEMINI_API_KEYS (liste) et GEMINI_API_KEY (clé unique) sont fusionnés : la rotation de clés est réellement active."""
        from core.settings.base import unique_keys
        self.assertEqual(unique_keys('a, b,a', 'c'), ['a', 'b', 'c'])
        self.assertEqual(unique_keys(None, 'seule'), ['seule'])
        self.assertEqual(unique_keys('', None, ' , '), [])

    def test_real_gemini_rotation_through_the_orchestrator(self):
        """Un quota (429) sur la 1re clé fait passer à la 2e clé SANS changer de modèle."""
        cache.clear()
        orch = llm.LLMOrchestrator({'gemini': llm.GeminiProvider()}, clock=FakeClock())
        replies = [response(status=429, headers={'retry-after': '30'}), response(body=GEMINI_OK)]
        with override_settings(AI_PROVIDER_ORDER='gemini', AI_MAX_ATTEMPTS=4, AI_TOTAL_BUDGET_SECONDS=40.0,
                               AI_ATTEMPT_TIMEOUT_SECONDS=14.0, AI_DAILY_CALLS_PER_USER=0):
            with patch('apps.ai_assistant.llm.requests.post', side_effect=replies) as post:
                result = orch.generate(request())
        self.assertEqual(result.text, 'Arrosez le soir.')
        self.assertEqual([c.kwargs['headers']['x-goog-api-key'] for c in post.call_args_list], ['gem-1', 'gem-2'])
        self.assertEqual({c.args[0] for c in post.call_args_list}, {post.call_args_list[0].args[0]})  # même modèle
