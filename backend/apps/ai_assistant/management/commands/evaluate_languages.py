"""
Mesure le français et le wolof de l'assistant.

    python manage.py evaluate_languages              # hors ligne : langue et intentions reconnues sur le corpus
    python manage.py evaluate_languages --live       # + vraies réponses du modèle (consomme du quota, nécessite les clés)
    python manage.py evaluate_languages --live --report ../docs/evaluation_langues.md

Le corpus est écrit par l'équipe, sans relecture par un locuteur natif : ces chiffres ne valent pas validation du wolof.
"""
import time

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.ai_assistant import language, llm
from apps.ai_assistant.evaluation.langues import CORPUS, HARD_CORPUS, WO, evaluate
from apps.ai_assistant.services import answer_question

LIVE_PROMPTS = (
    ("Naka lañuy fajee soble ?", WO),
    ("Naka laay def ngir sama tomaat yi baax ?", WO),
    ("Ndox bi dafa tuuti, lan laay def ?", WO),
    ("Sama nebbe yi dafa feebar", WO),
    ("Bëgg naa xam kañ laay jëmbët sama tool", WO),
    ("Naka laay traiter le mildiou sur ma tomate ?", 'mixed'),
    ("Comment traiter le mildiou sur la tomate ?", 'fr'),
    ("Quand semer l'oignon à Saint-Louis ?", 'fr'),
)


def _rate(stats):
    return ", ".join(f"{lang} {s['ok']}/{s['total']} ({s['rate']:.0%})" for lang, s in sorted(stats.items()))


class Command(BaseCommand):
    help = "Évalue la détection de langue, la compréhension des demandes et (--live) les réponses du modèle en wolof."

    def add_arguments(self, parser):
        parser.add_argument('--live', action='store_true', help="interroge réellement le modèle (quota consommé)")
        parser.add_argument('--report', help="écrit le rapport Markdown à ce chemin")

    def handle(self, *args, **options):
        user = get_user_model()(pk=0)  # utilisateur inexistant : aucune donnée d'exploitation n'entre dans la mesure
        lines = [f"# Évaluation français / wolof — {timezone.localdate().isoformat()}", "",
                 "Corpus écrit par l'équipe de développement, **non relu par un locuteur natif** : ces mesures décrivent la "
                 "tenue du code, pas la qualité du wolof auprès de producteurs réels.", ""]
        for title, corpus in (("Corpus principal", CORPUS), ("Variantes difficiles (SMS, sans accents)", HARD_CORPUS)):
            report = evaluate(user, corpus)
            lines += [f"## {title} ({report['cases']} phrases)", "",
                      f"- Langue reconnue : {_rate(report['language'])}",
                      f"- Demande comprise (action ou analyse) : {_rate(report['intent'])}", ""]
            for failure in report['failures']:
                lines.append(f"  - ÉCHEC {failure['what']} : « {failure['text']} » → attendu {failure['expected']}, obtenu {failure['got']}")
            lines.append("")

        if options['live']:
            lines += ["## Réponses réelles du modèle", "",
                      "| Question | Langue posée | Langue de la réponse (détecteur) | Mots wolof / mots français | Durée | Fournisseur |",
                      "|---|---|---|---|---|---|"]
            for text, asked in LIVE_PROMPTS:
                started = time.monotonic()
                answer = answer_question(text, 'general', user=None)
                elapsed = time.monotonic() - started
                reply = language.detect(answer['answer'])
                result = llm.last_result()
                provider = getattr(result, 'provider', '') if result else ''
                ok = ("oui" if reply.language != language.FRENCH else "NON (réponse en français)") if asked == WO else reply.language
                lines.append(f"| {text} | {asked} | {ok} | {reply.wolof_score:g} / {reply.french_score:g} | {elapsed:.1f} s | {provider} |")
                lines.append(f"|  | ↳ extrait | {answer['answer'][:160].replace(chr(10), ' ').replace('|', '/')} | | | |")
            lines += ["",
                      "Le détecteur de langue est lui-même une heuristique par lexique : une réponse jugée « wolof » n'est pas "
                      "forcément correcte ni naturelle. Seule la relecture par un locuteur natif peut valider la qualité."]

        text = "\n".join(lines)
        self.stdout.write(text)
        if options['report']:
            with open(options['report'], 'w', encoding='utf8') as handle:
                handle.write(text + "\n")
            self.stdout.write(self.style.SUCCESS(f"\nRapport écrit : {options['report']}"))
