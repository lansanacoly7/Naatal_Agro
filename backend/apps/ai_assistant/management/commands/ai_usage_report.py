import datetime

from django.core.management.base import BaseCommand
from django.db.models import Avg, Count, Q, Sum
from django.utils import timezone

from apps.ai_assistant.models import LLMUsage


class Command(BaseCommand):
    help = (
        "Rapport d'usage des modèles de langage sur les N derniers jours : appels, taux d'échec, latence, volumes. "
        "Sert à suivre les coûts et à repérer un fournisseur défaillant. Aucun contenu échangé n'est stocké ni affiché."
    )

    def add_arguments(self, parser):
        parser.add_argument('--days', type=int, default=7, help="Période analysée, en jours (7 par défaut)")

    def handle(self, *args, **options):
        days = max(1, options['days'])
        rows = LLMUsage.objects.filter(created_at__gte=timezone.now() - datetime.timedelta(days=days))
        total = rows.count()
        self.stdout.write(f"Usage des modèles de langage — {days} derniers jours")
        if not total:
            self.stdout.write("Aucun appel enregistré sur la période.")
            return

        ok = rows.filter(ok=True).count()
        self.stdout.write(f"Appels : {total} (réussis : {ok}, échecs : {total - ok}) — "
                          f"{rows.exclude(user=None).values('user').distinct().count()} utilisateur(s) distinct(s)")

        self.stdout.write("\nPar fournisseur et modèle :")
        by_model = rows.values('provider', 'model').annotate(
            calls=Count('id'), failures=Count('id', filter=Q(ok=False)), latency=Avg('latency_ms', filter=Q(ok=True)),
            tokens_in=Sum('prompt_tokens'), tokens_out=Sum('completion_tokens'),
        ).order_by('-calls')
        for row in by_model:
            rate = row['failures'] / row['calls'] * 100
            latency = f"{row['latency']:.0f} ms" if row['latency'] is not None else "n/a"
            self.stdout.write(
                f"  {row['provider']}/{row['model']} : {row['calls']} appel(s), {rate:.0f} % d'échec, latence moyenne {latency}, "
                f"jetons {row['tokens_in'] or 0} entrants / {row['tokens_out'] or 0} sortants")

        failures = rows.filter(ok=False).values('error_kind').annotate(n=Count('id')).order_by('-n')
        if failures:
            self.stdout.write("\nÉchecs par cause : " + ", ".join(f"{f['error_kind']} ({f['n']})" for f in failures))

        self.stdout.write("\nPar usage : " + ", ".join(
            f"{dict(LLMUsage.FEATURE_CHOICES).get(f['feature'], f['feature'])} ({f['n']})"
            for f in rows.filter(ok=True).values('feature').annotate(n=Count('id')).order_by('-n')))
