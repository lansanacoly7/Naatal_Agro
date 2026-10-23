import io

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase

from apps.ai_assistant.models import LLMUsage

User = get_user_model()


class UsageReportTests(TestCase):
    def report(self, **options):
        out = io.StringIO()
        call_command('ai_usage_report', stdout=out, **options)
        return out.getvalue()

    def test_empty_period(self):
        self.assertIn("Aucun appel enregistré", self.report())

    def test_report_summarises_calls_failures_latency_and_tokens(self):
        user = User.objects.create_user(username='ur1', phone='+221770980001', password='Motdepasse#2026')
        LLMUsage.objects.create(user=user, provider='groq', model='qwen', ok=True, latency_ms=1000, prompt_tokens=100, completion_tokens=20)
        LLMUsage.objects.create(user=user, provider='groq', model='qwen', ok=True, latency_ms=3000, prompt_tokens=50, completion_tokens=10, feature='vision')
        LLMUsage.objects.create(user=user, provider='groq', model='qwen', ok=False, error_kind='rate_limited', latency_ms=200)
        LLMUsage.objects.create(user=None, provider='gemini', model='flash', ok=True, latency_ms=2000)
        text = self.report()
        self.assertIn("Appels : 4 (réussis : 3, échecs : 1)", text)
        self.assertIn("1 utilisateur(s) distinct(s)", text)
        self.assertIn("groq/qwen : 3 appel(s), 33 % d'échec, latence moyenne 2000 ms, jetons 150 entrants / 30 sortants", text)
        self.assertIn("gemini/flash : 1 appel(s), 0 % d'échec", text)
        self.assertIn("rate_limited (1)", text)
        self.assertIn("Analyse de photo (1)", text)

    def test_old_calls_are_outside_the_period(self):
        import datetime
        from django.utils import timezone
        row = LLMUsage.objects.create(provider='groq', model='qwen', ok=True)
        LLMUsage.objects.filter(pk=row.pk).update(created_at=timezone.now() - datetime.timedelta(days=30))
        self.assertIn("Aucun appel enregistré", self.report(days=7))
        self.assertIn("Appels : 1", self.report(days=60))

    def test_report_never_exposes_message_content_or_user_names(self):
        user = User.objects.create_user(username='nom-secret-ur2', phone='+221770980002', password='Motdepasse#2026')
        LLMUsage.objects.create(user=user, provider='groq', model='qwen', ok=True)
        text = self.report()
        self.assertNotIn('nom-secret-ur2', text)
        self.assertNotIn('221770980002', text)
