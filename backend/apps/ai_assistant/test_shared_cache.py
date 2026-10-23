"""Cache partagé entre workers (CACHE_BACKEND=db) : disjoncteurs et limites de débit ne sont plus comptés par processus."""
from django.core.cache import cache
from django.core.management import call_command
from django.db import connection
from django.test import SimpleTestCase, TestCase, override_settings

from apps.ai_assistant import llm
from apps.ai_assistant.test_llm_orchestration import FakeProvider, orchestrator, request
from core.settings.base import cache_settings

DB_CACHE = cache_settings('db')


class CacheSettingsTests(SimpleTestCase):
    def test_default_is_in_memory(self):
        for value in ('locmem', '', None):
            self.assertTrue(cache_settings(value)['default']['BACKEND'].endswith('LocMemCache'))

    def test_db_backend_uses_a_table_of_the_shared_database(self):
        config = cache_settings('DB')['default']  # insensible à la casse
        self.assertTrue(config['BACKEND'].endswith('DatabaseCache'))
        self.assertEqual(config['LOCATION'], 'naatal_cache')


@override_settings(CACHES=DB_CACHE, AI_PROVIDER_ORDER='alpha,beta', AI_MAX_ATTEMPTS=4, AI_TOTAL_BUDGET_SECONDS=40.0,
                   AI_ATTEMPT_TIMEOUT_SECONDS=14.0, AI_DAILY_CALLS_PER_USER=0)
class SharedBreakerTests(TestCase):
    def setUp(self):
        call_command('createcachetable', verbosity=0)
        cache.clear()

    def rows(self):
        with connection.cursor() as cursor:
            cursor.execute('SELECT COUNT(*) FROM naatal_cache')
            return cursor.fetchone()[0]

    def test_a_provider_set_aside_by_one_worker_is_set_aside_for_all(self):
        """Deux « workers » = deux orchestrateurs et deux jeux de fournisseurs, sans mémoire commune : seul le cache partagé les relie."""
        worker_1_alpha = FakeProvider('alpha', [llm.ProviderError(llm.RATE_LIMITED, retry_after=120)])
        orchestrator(worker_1_alpha, FakeProvider('beta', ['b1'])).generate(request())

        worker_2_alpha, worker_2_beta = FakeProvider('alpha', ['jamais appelé']), FakeProvider('beta', ['b2'])
        result = orchestrator(worker_2_alpha, worker_2_beta).generate(request())

        self.assertEqual(worker_2_alpha.calls, [])  # le worker 2 sait que alpha est en quota, sans l'avoir constaté lui-même
        self.assertEqual(result.text, 'b2')
        self.assertGreater(self.rows(), 0)  # et l'information est bien dans la base commune

    def test_failure_counts_are_shared_too(self):
        for _ in range(3):  # trois pannes constatées par trois workers différents
            orchestrator(FakeProvider('alpha', [llm.ProviderError(llm.SERVER)]), FakeProvider('beta', ['ok'])).generate(request())
        fourth = FakeProvider('alpha', ['jamais'])
        orchestrator(fourth, FakeProvider('beta', ['ok'])).generate(request())
        self.assertEqual(fourth.calls, [])  # disjoncteur ouvert pour tous

    def test_throttle_counters_live_in_the_same_shared_cache(self):
        cache.set('probe', 1, 60)
        self.assertGreaterEqual(self.rows(), 1)
