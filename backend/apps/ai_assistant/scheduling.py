"""
Analyse des échéances exprimées en langage naturel (français, avec quelques termes wolof).

Fonctions pures : ``parse_schedule(texte, now)`` ne lit ni la base ni l'horloge si ``now`` est fourni, ce qui
les rend testables. Elles ne devinent jamais en silence : quand l'heure manque, le résultat l'indique
(``time_defaulted``) pour que l'assistant le dise à l'utilisateur ; quand rien ne ressemble à une échéance,
elles renvoient ``None``.
"""
import datetime
import re
import unicodedata
from dataclasses import dataclass

from django.utils import timezone

DEFAULT_HOUR = 8  # heure retenue quand seule la date est précisée sans moment de la journée
# « apres midi » avant « midi » : le premier moment reconnu l'emporte
_DAY_PARTS = {'apres midi': 15, 'matin': 8, 'suba': 8, 'midi': 12, 'soir': 18, 'ngoon': 18, 'nuit': 21}
_WEEKDAYS = {'lundi': 0, 'mardi': 1, 'mercredi': 2, 'jeudi': 3, 'vendredi': 4, 'samedi': 5, 'dimanche': 6}
_UNIT_SECONDS = {'h': 3600, 'heure': 3600, 'heures': 3600, 'mn': 60, 'min': 60, 'minute': 60, 'minutes': 60,
                 'jour': 86400, 'jours': 86400, 'semaine': 604800, 'semaines': 604800}


@dataclass(frozen=True)
class Schedule:
    when: datetime.datetime
    time_defaulted: bool  # vrai si l'heure a été choisie par défaut faute d'indication


def _normalize(text):
    decomposed = unicodedata.normalize('NFD', str(text or '').lower())
    plain = ''.join(ch for ch in decomposed if unicodedata.category(ch) != 'Mn')
    return ' ' + ' '.join(re.sub(r"[^a-z0-9:]+", ' ', plain).split()) + ' '


def _at(day, hour, minute=0):
    return timezone.make_aware(datetime.datetime.combine(day, datetime.time(hour, minute)))


def parse_schedule(text, now=None):
    """
    Échéance contenue dans ``text`` ou ``None``.

    Reconnaît : « dans 2 heures / 30 min / 3 jours », « demain », « après-demain », « ce soir », « aujourd'hui »,
    un jour de semaine (prochaine occurrence), une heure (« 7h », « 7h30 », « 19:30 »), un moment de la journée
    (matin, midi, après-midi, soir) ; wolof : ëllëk (demain), suba (matin), ngoon (soir), tey (aujourd'hui).
    Une heure seule (« à 7h ») désigne sa prochaine occurrence.
    """
    now = now or timezone.now()
    n = _normalize(text)
    today = timezone.localtime(now).date()

    relative = re.search(r'\bdans (\d+) ?(h|heures?|mn|min|minutes?|jours?|semaines?)\b', n)
    if relative:
        seconds = int(relative.group(1)) * _UNIT_SECONDS[relative.group(2)]
        return Schedule(now + datetime.timedelta(seconds=seconds), time_defaulted=False)

    day = None
    explicit_day = True
    if re.search(r'\bapres demain\b', n):
        day = today + datetime.timedelta(days=2)
    elif re.search(r'\b(demain|ellek|ellech)\b', n):
        day = today + datetime.timedelta(days=1)
    elif re.search(r'\b(aujourd hui|ce soir|ce matin|tey)\b', n):
        day = today
    else:
        for name, weekday in _WEEKDAYS.items():
            if re.search(rf'\b{name}\b', n):
                day = today + datetime.timedelta(days=(weekday - today.weekday()) % 7 or 7)
                break
    if day is None:
        explicit_day = False

    part_hour = None
    for label, hour in _DAY_PARTS.items():
        if re.search(rf'\b{label}\b', n):
            part_hour = hour
            break
    if part_hour is None and re.search(r'\bce soir\b', n):
        part_hour = _DAY_PARTS['soir']

    hour = minute = None
    match = re.search(r'\b(\d{1,2}) ?(?:h|heures?|:) ?(\d{2})?\b', n)
    if match and 0 <= int(match.group(1)) <= 23 and (match.group(2) is None or int(match.group(2)) <= 59):
        hour, minute = int(match.group(1)), int(match.group(2) or 0)
        # « 7h du soir » / « 3h de l'après-midi » : l'indication de moment lève l'ambiguïté 12h/24h
        if hour < 12 and re.search(r'\b(soir|apres midi|ngoon)\b', n):
            hour += 12

    if day is None and hour is None and part_hour is None:
        return None

    if hour is None:
        # Date (et éventuellement moment de la journée) sans heure précise
        return Schedule(_at(day or today, part_hour if part_hour is not None else DEFAULT_HOUR), time_defaulted=True)

    when = _at(day or today, hour, minute)
    if not explicit_day and when <= now:
        when += datetime.timedelta(days=1)  # « à 7h » seul : prochaine occurrence
    return Schedule(when, time_defaulted=False)


_TIME_EXPRESSIONS = re.compile(
    r"\bdans\s+\d+\s*(?:h|heures?|mn|min|minutes?|jours?|semaines?)\b"
    r"|\b(?:apr[èe]s)[- ]demain\b"
    r"|\b(?:demain|[ëe]ll[ëe][kgh]|aujourd[’']hui|tey)\b"
    r"|\bce\s+(?:soir|matin)\b"
    r"|\b(?:lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)(?:\s+prochain)?\b"
    r"|\b(?:[àa]\s*)?\d{1,2}\s*(?:h(?:\s*\d{2})?|:\d{2}|heures?(?:\s*\d{2})?)(?=\W|$)"
    r"|\b(?:du|de\s+l[’']|de\s+la|en|le|ci)?\s*(?:apr[èe]s[- ]midi|matin|soir|midi|suba|ngoon)\b",
    re.IGNORECASE,
)


def strip_time_expressions(text):
    """Texte du rappel sans ses indications d'échéance (« arroser demain à 7h » -> « arroser »)."""
    cleaned = _TIME_EXPRESSIONS.sub(' ', text or '')
    cleaned = re.sub(r'\s+[àa]\s*$', '', cleaned.strip())
    cleaned = re.sub(r'\s{2,}', ' ', cleaned).strip(" .,!?;:-")
    return cleaned
