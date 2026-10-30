"""
Consultations en lecture seule dont la réponse vient directement de la base, sans modèle de langage :
historique des mouvements de stock et liste des rappels à venir.

Un chiffre ou une date affichés ici sont donc toujours ceux des enregistrements de l'utilisateur.
"""
import re

from django.utils import timezone

RE_STOCK_HISTORY = re.compile(
    r"(?:historique|mouvements?)\s+(?:de\s+|du\s+|des\s+|d['’]\s*)?(?:mon\s+|ma\s+|mes\s+|le\s+|les\s+)?stocks?"
    r"(?:\s+(?:de|du|des|d['’])\s*(.+))?",
    re.IGNORECASE,
)
RE_STOCK_FLOW = re.compile(
    r"(?:qu['’]est[- ]ce\s+qui\s+est\s+(?:entr[ée]|sorti)|d['’]o[uù]\s+vient)\s+(?:dans\s+|du\s+|de\s+)?(?:mon\s+)?stock",
    re.IGNORECASE,
)
RE_LIST_REMINDERS = re.compile(
    r"\bmes\s+(?:rappels|alertes)\b"
    r"|\b(?:liste|affiche|montre|consulte|vois|voir)\b.*\b(?:rappels?|alertes?)\b"
    r"|\bquels?\b.*\b(?:rappels?|alertes?)\b",
    re.IGNORECASE,
)

RE_WEATHER = re.compile(
    r"\bm[ée]t[ée]o\b|\bva[- ]t[- ]il\s+pleuvoir\b|\bil\s+va\s+pleuvoir\b|\bquel\s+temps\s+fait[- ]il\b"
    r"|\bfait[- ]il\s+(?:chaud|froid)\b",
    re.IGNORECASE,
)
RE_WEATHER_PLACE = re.compile(r"\b(?:[àa]|de|du|pour|sur|au|en|chez)\s+([A-ZÀ-Ý][\w'’ -]{1,40}?)(?=\s*(?:[?.!,]|$))")
# Mots qui suivent « météo de/à » sans désigner un lieu
_NOT_A_PLACE = frozenset(
    "aujourd demain maintenant ce cette ma mon mes ici moi vous semaine soir matin demain lundi mardi mercredi jeudi "
    "vendredi samedi dimanche".split())

# Une consultation est une demande COURTE de liste (« mes cultures », « montre-moi mes récoltes ») : une question de conseil
# qui contient « mes cultures » (« comment protéger mes cultures ? ») n'en est pas une.
_ASK_LIST = r"^\W*(?:(?:peux[- ]tu\s+|pouvez[- ]vous\s+)?(?:me\s+)?(?:montrer|montre|affiche|afficher|liste|lister|voir|vois|donne)(?:[- ]moi)?\s+)?"
RE_LIST_CROPS = re.compile(_ASK_LIST + r"(?:toutes\s+)?(?:mes|les)\s+cultures\W*$|\bquelles?\s+cultures?\s+(?:ai[- ]je|j['’]ai)\b", re.IGNORECASE)
RE_LIST_ACTIVITIES = re.compile(
    _ASK_LIST + r"(?:toutes\s+)?(?:mes|les)\s+(?:derni[èe]res\s+)?(?:activit[ée]s|travaux)\W*$"
    r"|\bqu['’]ai[- ]je\s+fait\b|\bqu['’]est[- ]ce\s+que\s+j['’]ai\s+fait\b", re.IGNORECASE)
RE_LIST_HARVESTS = re.compile(_ASK_LIST + r"(?:toutes\s+)?(?:mes|les)\s+(?:derni[èe]res\s+)?r[ée]coltes\W*$", re.IGNORECASE)
RE_NEXT_HARVEST = re.compile(
    r"\bquand\s+(?:dois[- ]je|vais[- ]je|puis[- ]je|faut[- ]il)\s+r[ée]colter\b|\bprochaine\s+r[ée]colte\b", re.IGNORECASE)

HISTORY_LIMIT = 8
_SIGN = {'in': '+', 'out': '−'}


def detect_query_intent(text):
    """``{'type': 'stock_history', 'product': str | None}``, ``{'type': 'list_reminders'}`` ou ``None``."""
    match = RE_STOCK_HISTORY.search(text)
    if match:
        product = (match.group(1) or '').strip(" .?!")
        return {'type': 'stock_history', 'product': product or None}
    if RE_STOCK_FLOW.search(text):
        return {'type': 'stock_history', 'product': None}
    if RE_LIST_REMINDERS.search(text):
        return {'type': 'list_reminders'}
    if RE_WEATHER.search(text):
        return {'type': 'weather', 'place': _weather_place(text)}
    if RE_NEXT_HARVEST.search(text):
        return {'type': 'next_harvest'}
    if RE_LIST_HARVESTS.search(text):
        return {'type': 'list_harvests'}
    if RE_LIST_ACTIVITIES.search(text):
        return {'type': 'list_activities'}
    if RE_LIST_CROPS.search(text):
        return {'type': 'list_crops'}
    return None


def _weather_place(text):
    """Lieu demandé (« météo à Kaolack »), ou ``None`` : on prend alors la zone de la personne."""
    for match in RE_WEATHER_PLACE.finditer(text):
        place = match.group(1).strip(" .?!,")
        first = re.split(r"[\s'’-]+", place.lower())[0]
        if place and first not in _NOT_A_PLACE:
            return place
    return None


def _stock_history(user, product):
    from apps.inventory.models import StockMovement
    movements = StockMovement.objects.filter(user=user)
    if product:
        movements = movements.filter(product_name__icontains=product)
    movements = list(movements.order_by('-created_at')[:HISTORY_LIMIT])

    subject = f" de « {product} »" if product else ""
    if not movements:
        return {
            'text': f"Aucun mouvement de stock enregistré{subject}.",
            'suggestions': ['Vérifier mon stock', 'Analyse mes revenus'],
            'data': [],
        }
    lines = [f"📦 **Derniers mouvements de stock{subject}** :", ""]
    for m in movements:
        when = timezone.localtime(m.created_at).strftime("%d/%m")
        if m.movement_type == 'adjustment':
            change = f"Correction (écart de {m.quantity:g} {m.unit})"
        else:
            change = f"{_SIGN[m.movement_type]}{m.quantity:g} {m.unit}"
        lines.append(f"• {when} — {m.product_name} : {change} ({m.get_reason_display().lower()}) → solde {m.balance_after:g} {m.unit}")
    return {
        'text': "\n".join(lines),
        'suggestions': ['Vérifier mon stock', 'Analyse mes revenus'],
        'data': [str(m.pk) for m in movements],
    }


def _list_reminders(user):
    from apps.notifications.services import pending_reminders
    reminders = list(pending_reminders(user)[:10])
    if not reminders:
        return {
            'text': "Vous n'avez aucun rappel à venir. Dites par exemple « Rappelle-moi d'arroser demain à 7h ».",
            'suggestions': ["Rappelle-moi d'arroser demain à 7h"],
            'data': [],
        }
    lines = ["⏰ **Vos rappels à venir** :", ""]
    for index, reminder in enumerate(reminders, 1):
        when = timezone.localtime(reminder.scheduled_for).strftime("%d/%m/%Y à %H:%M")
        lines.append(f"{index}. {reminder.message} — {when}")
    return {
        'text': "\n".join(lines),
        'suggestions': ["Annule mon rappel", "Décale mon rappel à demain"],
        'data': [str(r.pk) for r in reminders],
    }


def _weather(user, place):
    """
    Météo réelle (source Open-Meteo) du lieu demandé, sinon de la zone de la personne. Jamais la météo d'une autre zone :
    si la source ne répond pas, on le dit.
    """
    from apps.weather import services as weather
    from apps.weather.words import report_in_words

    zone = place or (getattr(user, 'location', '') or '').split(',')[0].strip()
    if not zone or zone.lower() == 'sénégal':
        return {
            'text': "Dites-moi où vous êtes pour que je cherche la météo de votre zone, par exemple « météo à Thiès ».",
            'suggestions': ['Météo à Thiès', 'Météo à Kaolack', 'Météo à Dakar'],
            'data': [],
        }
    try:
        report = weather.weather_for_place(zone)
    except weather.AmbiguousPlace as exc:
        choices = [c['label'] for c in exc.candidates[:4]]
        return {
            'text': f"Plusieurs endroits s'appellent « {zone} ». Lequel est le vôtre ?",
            'suggestions': [f"Météo à {label}" for label in choices],
            'data': [],
        }
    except weather.UnknownPlace:
        return {
            'text': f"Je ne trouve pas « {zone} » au Sénégal. Dites-moi le nom d'une ville ou d'un village proche.",
            'suggestions': ['Météo à Thiès', 'Météo à Kaolack'],
            'data': [],
        }
    except (weather.WeatherUnavailable, weather.OutsideSenegal):
        return {
            'text': (f"La météo de {zone} n'est pas disponible pour le moment. "
                     "Je ne vous donne pas la météo d'un autre endroit : elle serait fausse pour vous. Réessayez un peu plus tard."),
            'suggestions': ['Météo à ' + zone],
            'data': [],
        }
    lines = [f"🌤️ **Météo de {report['place']['name']}**", ''] + report_in_words(report)
    return {'text': "\n".join(lines), 'suggestions': ['Que faire avec cette météo ?', 'Rappelle-moi d\'arroser demain à 7h'], 'data': []}


def _fmt(day):
    return day.strftime('%d/%m/%Y')


def _list_crops(user):
    from apps.agriculture.models import Crop
    crops = list(Crop.objects.filter(user=user).order_by('-created_at')[:12])
    if not crops:
        return {'text': "Vous n'avez pas encore de culture. Dites par exemple « ajoute une culture de mil ».",
                'suggestions': ['Ajoute une culture de mil'], 'data': []}
    lines = ["🌱 **Vos cultures** :", ""]
    for crop in crops:
        state = 'récoltée' if crop.status == 'harvested' else f"récolte prévue le {_fmt(crop.expected_harvest_date)}"
        lines.append(f"• {crop.name} : {crop.area_size:g} ha, {state}")
    return {'text': "\n".join(lines), 'suggestions': ['Mes activités', 'Quand dois-je récolter ?'], 'data': [str(c.pk) for c in crops]}


def _list_activities(user):
    from apps.agriculture.models import Activity
    activities = list(Activity.objects.filter(crop__user=user).select_related('crop').order_by('-date', '-created_at')[:HISTORY_LIMIT])
    if not activities:
        return {'text': "Aucune activité enregistrée. Dites par exemple « j'ai arrosé le mil hier ».",
                'suggestions': ["J'ai arrosé mon champ aujourd'hui"], 'data': []}
    lines = ["📋 **Vos dernières activités** :", ""]
    for a in activities:
        cost = f", {int(a.cost):,} FCFA".replace(',', ' ') if a.cost else ''
        lines.append(f"• {_fmt(a.date)} : {a.activity_type} sur {a.crop.name}{cost}")
    return {'text': "\n".join(lines), 'suggestions': ['Mes cultures', 'Ajoute une activité'], 'data': [str(a.pk) for a in activities]}


def _list_harvests(user):
    from apps.agriculture.models import Harvest
    harvests = list(Harvest.objects.filter(user=user).select_related('crop').order_by('-date', '-created_at')[:HISTORY_LIMIT])
    if not harvests:
        return {'text': "Aucune récolte enregistrée. Dites par exemple « j'ai récolté 300 kg de mil ».",
                'suggestions': ["J'ai récolté 300 kg de mil"], 'data': []}
    lines = ["🧺 **Vos dernières récoltes** :", ""]
    lines += [f"• {_fmt(h.date)} : {h.quantity:g} {h.unit} de {h.crop.name}" for h in harvests]
    return {'text': "\n".join(lines), 'suggestions': ['Vérifier mon stock', 'Mes cultures'], 'data': [str(h.pk) for h in harvests]}


def _next_harvest(user):
    from apps.agriculture.models import Crop
    crops = list(Crop.objects.filter(user=user, status='active').order_by('expected_harvest_date')[:6])
    if not crops:
        return {'text': "Vous n'avez aucune culture en cours.", 'suggestions': ['Ajoute une culture de mil'], 'data': []}
    today = timezone.localdate()
    lines = ["⏳ **Vos prochaines récoltes** (dates que vous avez enregistrées) :", ""]
    for crop in crops:
        days = (crop.expected_harvest_date - today).days
        when = "la date est passée" if days < 0 else ("aujourd'hui" if days == 0 else f"dans {days} jour{'s' if days > 1 else ''}")
        lines.append(f"• {crop.name} : {_fmt(crop.expected_harvest_date)} ({when})")
    return {'text': "\n".join(lines), 'suggestions': ['Mes cultures', "J'ai récolté du mil"], 'data': [str(c.pk) for c in crops]}


def answer_query(user, intent):
    """Réponse ``{'text', 'suggestions', 'data'}`` à une consultation reconnue par ``detect_query_intent``."""
    if intent['type'] == 'stock_history':
        return _stock_history(user, intent.get('product'))
    if intent['type'] == 'weather':
        return _weather(user, intent.get('place'))
    handlers = {'list_crops': _list_crops, 'list_activities': _list_activities, 'list_harvests': _list_harvests,
                'next_harvest': _next_harvest}
    if intent['type'] in handlers:
        return handlers[intent['type']](user)
    return _list_reminders(user)
