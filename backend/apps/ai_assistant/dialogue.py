"""
Dialogue de précision de Naatal IA (cahier des charges §4.A).

Quand une demande d'opération est reconnue mais INCOMPLÈTE (« j'ai vendu du mil », « enregistre une dépense », « rappelle-moi
demain »), l'assistant ne devine pas : il pose UNE question à la fois sur ce qui manque, en réutilisant tout ce que
l'application sait déjà (unité du stock, dernier prix de vente…). Quand tout est connu, il construit la proposition habituelle,
qui passe par le récapitulatif et la confirmation explicite : ce module n'écrit jamais dans les données métier.

L'état du dialogue (un « brouillon » d'opération et les derniers sujets abordés) est stocké sur la conversation. Un brouillon :
- n'est continué que si la dernière question posée est le dernier échange de la conversation (sinon l'utilisateur est passé
  à autre chose) ;
- expire après 15 minutes ;
- est abandonné après deux réponses incompréhensibles, ou sur « annule », « laisse tomber »… ;
- cède la place à toute nouvelle demande complète de l'utilisateur.
"""
import datetime
import logging
import re

from django.utils import timezone

from apps.finances.categories import normalize_text

from . import actions, proposals
from .numbers_fr import parse_amount
from .scheduling import parse_schedule, strip_time_expressions

logger = logging.getLogger(__name__)

DRAFT_TTL = datetime.timedelta(minutes=15)
MAX_FAILED_ANSWERS = 2
QUESTION_KIND = 'question'
MAX_SUGGESTIONS = 4

QUANTITY_UNITS = frozenset((
    'sac sacs kg kilo kilos kilogramme kilogrammes tonne tonnes caisse caisses cageot cageots botte bottes panier paniers '
    'litre litres unite unites piece pieces tas bidon bidons seau seaux charrette charrettes carton cartons plateau plateaux '
    'regime regimes').split())
CURRENCY_WORDS = frozenset('fcfa cfa f francs franc xof'.split())
TOTAL_CUES = ('pour', 'au total', 'en tout', 'total', 'au total de')
UNIT_PRICE_CUES = ('a', 'au prix de', 'par', 'le', 'la', 'chaque')
GENERIC_PRODUCTS = frozenset((
    'recolte recoltes production productions stock stocks marchandise marchandises produit produits legumes fruits cereales '
    'cultures tout partie quelque chose rien ca cela mes mon ma').split())
_STOP_WORDS = frozenset('a pour au aux hier aujourd ce cette en chez sur avec dans hui demain matin soir marche '.split())
_FILLER = frozenset('du de des d la le les l un une mon ma mes ce cette c est il s agit'.split())
# Réponses qui ne sont jamais un nom de produit, une dépense ou un objet de rappel
_NOT_A_VALUE = frozenset(
    'oui non ok okay merci bonjour salut daccord pas sais sait comprends idee aucune aucun rien jsp svp peut etre hein'.split())
_VERBS = frozenset('vendu vendre vente recu recus stocke stocker ajoute ajouter mets met mettre achete paye depense'.split())

_NUMBER_TOKEN = re.compile(
    r"(?P<pre>(?:\b(?:à|a|pour|au prix de|au total de|au total|en tout|total)\s+)?)"
    r"(?P<num>\d[\d\s.,]*\d|\d)(?P<mult>\s*(?:mille|k)\b)?\s*(?P<unit>[A-Za-zÀ-ÿ]+)?", re.IGNORECASE)
_QUESTION_START = re.compile(r"^\s*(?:quand|comment|pourquoi|combien|quel|quelle|quels|quelles|ou|est ce|peux tu|pouvez vous|faut il|dois je)\b")

_INTRO = {
    'record_expense': "D'accord, notons cette dépense.",
    'record_sale': "D'accord, enregistrons cette vente.",
    'update_stock': "D'accord, mettons votre stock à jour.",
    'create_reminder': "Très bien, je programme un rappel.",
}
_REASSURANCE = "Rien n'est enregistré tant que vous n'avez pas confirmé le récapitulatif."


# --------------------------------------------------------------------------------------------------------------
# État du dialogue (stocké sur la conversation)
# --------------------------------------------------------------------------------------------------------------
def _state(conversation):
    state = conversation.state
    return state if isinstance(state, dict) else {}


def _save(conversation, state):
    conversation.state = state
    type(conversation).objects.filter(pk=conversation.pk).update(state=state)  # sans toucher à updated_at


def clear_draft(conversation):
    state = _state(conversation)
    if 'draft' in state:
        state = {k: v for k, v in state.items() if k != 'draft'}
        _save(conversation, state)


def active_draft(conversation, now=None):
    """Brouillon à continuer, ou ``None`` (expiré, ou un autre échange s'est intercalé depuis la dernière question)."""
    draft = _state(conversation).get('draft')
    if not draft:
        return None
    try:
        expired = datetime.datetime.fromisoformat(draft['expires_at']) < (now or timezone.now())
    except (KeyError, ValueError):
        expired = True
    last = conversation.interactions.order_by('-created_at').first()
    if expired or last is None or str(last.pk) != draft.get('question_id'):
        clear_draft(conversation)
        return None
    return draft


def _store_draft(conversation, draft):
    state = dict(_state(conversation))
    state['draft'] = draft
    _save(conversation, state)


def bind_question(conversation, interaction):
    """Associe le brouillon à la question qui vient d'être posée (voir ``active_draft``)."""
    draft = _state(conversation).get('draft')
    if draft:
        draft['question_id'] = str(interaction.pk)
        _store_draft(conversation, draft)


def remember(conversation, **facts):
    """Retient les derniers sujets (produit, analyse, période…) pour comprendre « ce produit » ou « et le mois dernier ? »."""
    facts = {k: v for k, v in facts.items() if v}
    if not facts:
        return
    state = dict(_state(conversation))
    state['last'] = {**state.get('last', {}), **facts, 'at': timezone.now().isoformat()}
    _save(conversation, state)


def last_facts(conversation):
    return dict(_state(conversation).get('last', {}))


def product_of(action_data):
    """Produit concerné par une proposition (ou son résultat), pour le retenir comme « ce produit »."""
    params = (action_data or {}).get('parameters') or {}
    return params.get('product_name') or params.get('crop_name') or None


# --------------------------------------------------------------------------------------------------------------
# Ce que l'application sait déjà de l'utilisateur
# --------------------------------------------------------------------------------------------------------------
def user_products(user):
    """Produits de l'utilisateur (stock, cultures, ventes passées), sans doublon, dans cet ordre de priorité."""
    from apps.agriculture.models import Crop
    from apps.finances.models import Sale
    from apps.inventory.models import StockItem
    names = list(StockItem.objects.filter(user=user).values_list('name', flat=True))
    names += list(Crop.objects.filter(user=user).values_list('name', flat=True))
    names += list(Sale.objects.filter(user=user).exclude(product_name='').values_list('product_name', flat=True).distinct())
    seen, products = set(), []
    for name in names:
        key = normalize_text(name).strip()
        if key and key not in seen:
            seen.add(key)
            products.append(name)
    return products


def _stock_item(user, product):
    from apps.inventory.models import StockItem
    return StockItem.objects.filter(user=user, name__iexact=product).first()


def _last_unit_price(user, product):
    from apps.finances.models import Sale
    sale = Sale.objects.filter(user=user, product_name__iexact=product).order_by('-date', '-created_at').first()
    return float(sale.price_per_unit) if sale else None


def _known_matches(text, products):
    """Produits connus cités dans ``text`` (mot entier, pluriel toléré), les noms les plus longs d'abord."""
    n = normalize_text(text)
    found = []
    for name in sorted(products, key=lambda p: -len(p)):
        key = normalize_text(name).strip()
        singular = key[:-1] if key.endswith('s') and len(key) > 3 else key
        if re.search(rf"(?<=\s){re.escape(key)}s?(?=\s)", n) or re.search(rf"(?<=\s){re.escape(singular)}s?(?=\s)", n):
            # « mil local » contient « mil » : on garde le nom le plus précis
            if not any(normalize_text(name).strip() in normalize_text(other) for other in found):
                found.append(name)
    return found


def _free_product(text):
    """Nom de produit tapé librement après le verbe (« j'ai vendu des oignons violets à ... »), sinon ``None``."""
    words = normalize_text(text).split()
    start = next((i + 1 for i, w in enumerate(words) if w in _VERBS), 0)
    chosen = []
    for index, word in enumerate(words[start:], start):
        if word.isdigit() or word in QUANTITY_UNITS or word in CURRENCY_WORDS:
            continue
        if word in _STOP_WORDS:
            break
        if word in _FILLER:
            following = words[index + 1] if index + 1 < len(words) else ''
            if chosen and word in ('de', 'du', 'd') and following and following not in _STOP_WORDS and not following.isdigit():
                chosen.append(word)
            continue
        chosen.append(word)
        if len(chosen) >= 3:
            break
    while chosen and chosen[-1] in _FILLER:
        chosen.pop()
    if not chosen or any(w in GENERIC_PRODUCTS for w in chosen) or ' '.join(chosen) in GENERIC_PRODUCTS:
        return None
    return ' '.join(chosen).capitalize()


def extract_product(text, user):
    """``(produit | None, candidats)`` : produit unique reconnu, ou liste de candidats si l'énoncé est ambigu."""
    known = _known_matches(text, user_products(user))
    if len(known) == 1:
        return known[0], []
    if len(known) > 1:
        return None, known
    free = _free_product(text)
    if free:  # « du mil » alors que le stock contient « Mil local » : on ne crée pas un doublon, on rapproche ou on demande
        words = normalize_text(free).split()
        close = [p for p in user_products(user) if all(w in normalize_text(p).split() for w in words)]
        if len(close) == 1:
            return close[0], []
        if len(close) > 1:
            return None, close
    return free, []


def _resolve_product_reply(text, user):
    """Réponse à « Quel produit ? » : un nom connu (même abrégé), un nom libre, ou une ambiguïté à lever."""
    products = user_products(user)
    n = normalize_text(text)
    words = [w for w in n.split() if w not in _FILLER]
    if not words:
        return None, []
    if any(w in GENERIC_PRODUCTS or w in _NOT_A_VALUE for w in words):
        return None, []
    known = _known_matches(text, products)
    if not known:  # « mil » tapé pour « Mil local » : tous les mots de la réponse figurent dans le nom d'un produit connu
        known = [p for p in products if all(w in normalize_text(p).split() for w in words)]
    if len(known) == 1:
        return known[0], []
    if len(known) > 1:
        return None, known
    if len(words) <= 4 and not any(w.isdigit() for w in words):
        return ' '.join(words).capitalize(), []
    return None, []


# --------------------------------------------------------------------------------------------------------------
# Lecture des fragments d'une phrase
# --------------------------------------------------------------------------------------------------------------
def _is_question(text):
    return text.strip().endswith('?') or bool(_QUESTION_START.match(normalize_text(text).strip()))


def _numbers(text):
    """Nombres d'une phrase avec leur rôle : quantité (+ unité), prix unitaire, total, montant quelconque, ou nombre nu."""
    found = {'quantity': None, 'unit': None, 'unit_price': None, 'total_price': None, 'money': None, 'bare': []}
    for match in _NUMBER_TOKEN.finditer(text):
        value = parse_amount(match.group(0))
        if not value:
            continue
        unit_original = (match.group('unit') or '').strip()
        unit_word = normalize_text(unit_original).strip()
        pre = normalize_text(match.group('pre') or '').strip()
        # « 250000 au total » : l'indice de total se trouve APRÈS le nombre
        after = normalize_text(text[match.end('num') + len(match.group('mult') or ''):]).strip()
        says_total = bool(re.match(r"(?:fcfa |cfa |francs? |f )?(?:au total|en tout|total)\b", after))
        if unit_word in QUANTITY_UNITS and found['quantity'] is None:
            found['quantity'], found['unit'] = value, unit_original.lower()
        elif unit_word in CURRENCY_WORDS or pre or says_total:
            found['money'] = found['money'] or value
            if pre in TOTAL_CUES or says_total:
                found['total_price'] = found['total_price'] or value
            else:
                found['unit_price'] = found['unit_price'] or value
        else:
            found['bare'].append(value)
    return found


def _tail_after(text, pattern):
    match = re.search(pattern, text, re.IGNORECASE)
    return text[match.end():].strip(" .,;:!?") if match else ''


def _clean_description(tail):
    tail = re.sub(r"\d[\d\s.,]*\s*(?:fcfa|cfa|francs?|f)?\b", ' ', tail, flags=re.IGNORECASE)
    tail = re.sub(r"^(?:(?:pour|de|du|des|le|la|les|un|une|mes|mon|ma)\s+|(?:l|d)['’]\s*)+", '', tail.strip(), flags=re.IGNORECASE)
    tail = re.sub(r"\b(?:aujourd['’]hui|hier|ce matin|ce soir|demain)\b", ' ', tail, flags=re.IGNORECASE)
    return re.sub(r"\s{2,}", ' ', tail).strip(" .,;:!?-")


# --------------------------------------------------------------------------------------------------------------
# Détection des demandes incomplètes
# --------------------------------------------------------------------------------------------------------------
_EXPENSE_TRIGGER = re.compile(
    r"\b(?:j['’]ai|je viens d['’]|je viens de|nous avons)\s*(?P<verb>achet[ée]|pay[ée]|d[ée]pens[ée]|r[ée]gl[ée])\b|"
    r"\b(?:enregistre|ajoute|note|saisis|cr[ée]e|mets)(?:[- ]moi)?\s+(?:une |la |cette )?(?:nouvelle )?(?P<noun>d[ée]pense)\b|"
    r"\b(?:jend naa|depaase naa)\b", re.IGNORECASE)
_SALE_TRIGGER = re.compile(
    r"\b(?:j['’]ai vendu|je viens de vendre|j['’]ai fait une vente|jaay naa)\b|"
    r"\b(?:enregistre|ajoute|note|saisis|mets)(?:[- ]moi)?\s+(?:une )?vente\b", re.IGNORECASE)
_STOCK_ADD_TRIGGER = re.compile(
    r"\b(?:j['’]ai re[çc]u|j['’]ai stock[ée]|je viens de recevoir)\b|"
    r"\b(?:ajoute|mets|met|stocke|enregistre)\b.{0,40}\b(?:au stock|en stock|au magasin|dans (?:mon )?stock)\b", re.IGNORECASE)
_STOCK_SET_TRIGGER = re.compile(r"\b(?:corrige|ajuste|r[ée]gle|modifie|mets|mettre)\s+(?:le |mon )?stock\b", re.IGNORECASE)


def _new_draft(action_type, fragments, now=None):
    return {
        'action_type': action_type,
        'fragments': {k: v for k, v in fragments.items() if v is not None},
        'failures': 0,
        'expires_at': ((now or timezone.now()) + DRAFT_TTL).isoformat(),
        'question_id': None,
        'candidates': [],
    }


def _partial_expense(text, user):
    match = _EXPENSE_TRIGGER.search(text)
    if not match:
        return None
    numbers = _numbers(text)
    tail = _clean_description(text[match.end():])
    fragments = {'amount': numbers['money'] or (numbers['bare'][0] if len(numbers['bare']) == 1 else None)}
    if tail:
        fragments['description'] = tail[:1].upper() + tail[1:]
    return _new_draft('record_expense', fragments)


def _partial_sale(text, user):
    if not _SALE_TRIGGER.search(text):
        return None
    numbers = _numbers(text)
    product, candidates = extract_product(text, user)
    draft = _new_draft('record_sale', {
        'product': product, 'quantity': numbers['quantity'] or (numbers['bare'][0] if len(numbers['bare']) == 1 and not numbers['money'] else None),
        'unit': numbers['unit'], 'unit_price': numbers['unit_price'], 'total_price': numbers['total_price'],
    })
    draft['candidates'] = candidates
    return draft


def _partial_stock_add(text, user):
    if not _STOCK_ADD_TRIGGER.search(text) or _STOCK_SET_TRIGGER.search(text):
        return None
    numbers = _numbers(text)
    product, candidates = extract_product(text, user)
    draft = _new_draft('update_stock', {'operation': 'add', 'product': product, 'quantity': numbers['quantity'], 'unit': numbers['unit']})
    draft['candidates'] = candidates
    return draft


def _partial_stock_set(text, user):
    if not _STOCK_SET_TRIGGER.search(text):
        return None
    numbers = _numbers(text)
    product, candidates = extract_product(text, user)
    quantity = numbers['quantity'] if numbers['quantity'] is not None else (numbers['bare'][0] if len(numbers['bare']) == 1 else None)
    draft = _new_draft('update_stock', {'operation': 'set', 'product': product, 'quantity': quantity, 'unit': numbers['unit']})
    draft['candidates'] = candidates
    return draft


def _partial_reminder(text):
    """« Rappelle-moi demain » : on connaît l'échéance mais pas l'objet du rappel."""
    match = actions.RE_REMINDER.search(text)
    if not match:
        return None
    tail = match.group(1).strip(" .!?")
    if tail and strip_time_expressions(tail):
        return None  # il y a bien un objet : la détection normale s'en charge (et demande l'échéance si elle manque)
    schedule = parse_schedule(tail) if tail else None
    return _new_draft('create_reminder', {'when': schedule.when.isoformat() if schedule else None})


def _draft_from_incomplete_reminder(intent):
    """Rappel avec objet mais SANS aucune échéance : on demande l'heure au lieu de la deviner."""
    return _new_draft('create_reminder', {'message': intent['params']['message']})


def _start_draft(text, intent, user):
    if _is_question(text):
        return None
    if intent.get('has_intent'):
        if intent['action_type'] != 'create_reminder':
            return None  # demande complète : la détection normale la traite
        # « Rappelle-moi demain » : échéance connue, objet manquant ; « Rappelle-moi d'arroser » : objet connu, échéance manquante
        return _partial_reminder(text) or (_draft_from_incomplete_reminder(intent) if intent['params'].get('time_missing') else None)
    if intent.get('note'):
        return None
    return (_partial_expense(text, user) or _partial_sale(text, user) or _partial_stock_set(text, user)
            or _partial_stock_add(text, user))


# --------------------------------------------------------------------------------------------------------------
# Compléter un brouillon
# --------------------------------------------------------------------------------------------------------------
def missing_slots(draft):
    f, kind = draft['fragments'], draft['action_type']
    if kind == 'record_expense':
        return [s for s, key in (('description', 'description'), ('amount', 'amount')) if not f.get(key)]
    if kind == 'record_sale':
        slots = [s for s, key in (('product', 'product'), ('quantity', 'quantity')) if not f.get(key)]
        if not (f.get('unit_price') or f.get('total_price')):
            slots.append('price')
        return slots
    if kind == 'update_stock':
        return ([] if f.get('product') else ['product']) + ([] if f.get('quantity') is not None else ['quantity'])
    if kind == 'create_reminder':
        return [s for s, key in (('message', 'message'), ('when', 'when')) if not f.get(key)]
    return []


def _fill_from_sentence(draft, text, user):
    """Remplit d'un coup tout ce qu'une réponse libre apporte, même hors de l'ordre des questions."""
    f, kind = draft['fragments'], draft['action_type']
    numbers = _numbers(text)
    if kind == 'record_sale':
        if not f.get('product'):
            product, candidates = extract_product(text, user)
            if product:
                f['product'], draft['candidates'] = product, []
        if not f.get('quantity') and numbers['quantity']:
            f['quantity'], f['unit'] = numbers['quantity'], numbers['unit'] or f.get('unit')
        if not (f.get('unit_price') or f.get('total_price')):
            if numbers['total_price']:
                f['total_price'] = numbers['total_price']
            elif numbers['unit_price']:
                f['unit_price'] = numbers['unit_price']
    elif kind == 'update_stock':
        if not f.get('product'):
            product, _ = extract_product(text, user)
            if product:
                f['product'], draft['candidates'] = product, []
        if f.get('quantity') is None and numbers['quantity'] is not None:
            f['quantity'], f['unit'] = numbers['quantity'], numbers['unit'] or f.get('unit')
    elif kind == 'record_expense':
        if not f.get('amount') and numbers['money']:
            f['amount'] = numbers['money']


def _apply_asked_slot(draft, slot, text, user):
    """Interprète ``text`` comme la valeur du champ demandé (réponse « nue » : « 20 », « du mil », « demain 7h »…). ``True`` si lu."""
    f = draft['fragments']
    if slot == 'amount':
        value = parse_amount(text)
        if value:
            f['amount'] = value
            return True
    elif slot == 'quantity':
        value = parse_amount(text)
        if value is None and draft['action_type'] == 'update_stock' and re.search(r"\b(?:z[ée]ro|0|plus rien|vide)\b", normalize_text(text)):
            value = 0.0
        if value is not None:
            f['quantity'] = value
            numbers = _numbers(text)
            if numbers['unit']:
                f['unit'] = numbers['unit']
            return True
    elif slot == 'price':
        value = parse_amount(text)
        if value:
            plain = normalize_text(text)
            if re.search(r"\b(?:au total|en tout|total)\b", plain):
                f['total_price'] = value
            else:
                f['unit_price'] = value
            return True
    elif slot == 'product':
        product, candidates = _resolve_product_reply(text, user)
        if product:
            f['product'], draft['candidates'] = product, []
            return True
        if candidates:
            draft['candidates'] = candidates
    elif slot == 'description':
        cleaned = _clean_description(text)
        if cleaned and not cleaned.isdigit() and len(cleaned) <= 120 and not (set(normalize_text(cleaned).split()) & _NOT_A_VALUE):
            f['description'] = cleaned[:1].upper() + cleaned[1:]
            return True
    elif slot == 'message':
        cleaned = strip_time_expressions(re.sub(r"^(?:de |d['’]|pour )", '', text.strip(), flags=re.IGNORECASE))
        if cleaned and not cleaned.isdigit() and not (set(normalize_text(cleaned).split()) & _NOT_A_VALUE):
            f['message'] = cleaned
            return True
    elif slot == 'when':
        schedule = parse_schedule(text)
        if schedule:
            f['when'] = schedule.when.isoformat()
            f['time_defaulted'] = schedule.time_defaulted
            return True
    return False


# --------------------------------------------------------------------------------------------------------------
# Questions
# --------------------------------------------------------------------------------------------------------------
def question_for(slot, draft, user, first=False):
    """``(texte, suggestions)`` de la question portant sur ``slot``. Réutilise ce que l'application sait déjà."""
    f, kind = draft['fragments'], draft['action_type']
    product = f.get('product')
    stock = _stock_item(user, product) if product else None
    intro = f"{_INTRO[kind]} " if first else ''

    if slot == 'description':
        return (f"{intro}Pour quelle dépense ? Par exemple : engrais, semences, carburant, main-d'œuvre.",
                ["Engrais", "Semences", "Carburant", "Main-d'œuvre"])
    if slot == 'amount':
        what = f" pour « {f['description']} »" if f.get('description') else ''
        return f"{intro}Quel montant avez-vous dépensé{what} (en FCFA) ?", []
    if slot == 'product':
        verb = {'record_sale': 'vendu', 'update_stock': 'concerné dans votre stock'}.get(kind, 'concerné')
        candidates = draft.get('candidates') or user_products(user)[:MAX_SUGGESTIONS]
        if draft.get('candidates'):
            return f"Plusieurs produits correspondent : {', '.join(draft['candidates'])}. Lequel ?", draft['candidates'][:MAX_SUGGESTIONS]
        return f"{intro}Quel produit avez-vous {verb} ?", candidates[:MAX_SUGGESTIONS]
    if slot == 'quantity':
        unit = f.get('unit') or (stock.unit if stock else None)
        verb = 'vendue' if kind == 'record_sale' else ('à mettre en stock' if f.get('operation') == 'add' else 'en stock')
        unit_part = f" (en {unit})" if unit else ''
        in_stock = f" Vous en avez {stock.quantity:g} {stock.unit} en stock." if stock and kind == 'record_sale' else ''
        if kind == 'update_stock' and f.get('operation') == 'set':
            return f"{intro}Quelle quantité de {product} avez-vous maintenant en stock{unit_part} ?", []
        return f"{intro}Quelle quantité de {product} avez-vous {verb}{unit_part} ?{in_stock}", []
    if slot == 'price':
        unit = f.get('unit') or (stock.unit if stock else 'unité')
        last = _last_unit_price(user, product) if product else None
        hint = f" (dernière vente : {last:,.0f} FCFA par {unit})".replace(',', ' ') if last else ''
        suggestions = [f"{last:.0f} FCFA par {unit}"] if last else []
        return (f"À quel prix par {unit} l'avez-vous vendu (en FCFA){hint} ? Vous pouvez aussi donner le total "
                f"(par exemple « 250000 au total »).", suggestions)
    if slot == 'message':
        return f"{intro}De quoi dois-je vous rappeler ?", []
    if slot == 'when':
        return (f"{intro}Pour quand ? Par exemple « demain à 7h », « ce soir à 18h » ou « dans 2 heures ».",
                ["Demain matin", "Demain à 7h", "Dans 2 heures"])
    return "Pouvez-vous préciser ?", []


def _retry_hint(slot):
    return {
        'amount': "Je n'ai pas compris le montant. Donnez-le en chiffres ou en lettres, par exemple « 15000 » ou « quinze mille ».",
        'quantity': "Je n'ai pas compris la quantité. Par exemple « 20 » ou « vingt sacs ».",
        'price': "Je n'ai pas compris le prix. Par exemple « 12000 » (par unité) ou « 250000 au total ».",
        'product': "Je n'ai pas reconnu le produit. Dites son nom, par exemple « mil » ou « tomate ».",
        'description': "Je n'ai pas compris l'objet de la dépense. Dites par exemple « engrais » ou « carburant ».",
        'message': "Je n'ai pas compris l'objet du rappel. Dites par exemple « arroser les piments ».",
        'when': "Je n'ai pas compris l'échéance. Dites par exemple « demain à 7h » ou « dans 2 heures ».",
    }.get(slot, "Je n'ai pas compris.")


# --------------------------------------------------------------------------------------------------------------
# Du brouillon à la proposition
# --------------------------------------------------------------------------------------------------------------
def to_intent(draft, user):
    f, kind = draft['fragments'], draft['action_type']
    if kind == 'record_expense':
        return actions.build_expense_intent(float(f['amount']), f['description'], user)
    if kind == 'record_sale':
        stock = _stock_item(user, f['product'])
        unit = f.get('unit') or (stock.unit if stock else None)
        quantity = float(f['quantity'])
        if f.get('unit_price'):
            return actions.build_sale_intent(f['product'], quantity, unit, unit_price=float(f['unit_price']))
        return actions.build_sale_intent(f['product'], quantity, unit, total_price=float(f['total_price']))
    if kind == 'update_stock':
        stock = _stock_item(user, f['product'])
        unit = f.get('unit') or (stock.unit if stock else None)
        if f.get('operation') == 'set':
            return actions.build_stock_set_intent(f['product'], float(f['quantity']), unit, user)
        return actions.build_stock_add_intent(f['product'], float(f['quantity']), unit)
    when = datetime.datetime.fromisoformat(f['when'])
    return actions.build_reminder_intent(f['message'], when, time_defaulted=bool(f.get('time_defaulted')))


# --------------------------------------------------------------------------------------------------------------
# Point d'entrée : un tour de dialogue
# --------------------------------------------------------------------------------------------------------------
def _ask(conversation, user, draft, text, context, first):
    slot = missing_slots(draft)[0]
    question, suggestions = question_for(slot, draft, user, first=first)
    if first:
        question = f"{question}\n\n{_REASSURANCE}"
    _store_draft(conversation, draft)
    note = proposals.create_note(user=user, conversation=conversation, query=text, context=context,
                                 text=question, suggestions=suggestions, kind=QUESTION_KIND)
    bind_question(conversation, note)
    return note


def handle_turn(user, conversation, text, intent, context='general'):
    """
    Traite ce message dans le cadre d'un dialogue de précision. Renvoie l'interaction à retourner à l'utilisateur
    (question, proposition, abandon), ou ``None`` : le message n'est pas concerné et suit le circuit normal.

    ``intent`` est le résultat de ``actions.detect_action_intent`` pour ce message.
    """
    draft = active_draft(conversation)
    if draft:
        return _continue(user, conversation, draft, text, intent, context)

    new_draft = _start_draft(text, intent, user)
    if new_draft is None:
        return None
    if not missing_slots(new_draft):  # tout était déjà dans la phrase : on passe directement à la proposition
        return _complete(user, conversation, new_draft, text, context)
    return _ask(conversation, user, new_draft, text, context, first=True)


def _complete(user, conversation, draft, text, context):
    clear_draft(conversation)
    return proposals.create_proposal(user=user, conversation=conversation, query=text, context=context,
                                     intent=to_intent(draft, user))


def _abandon(user, conversation, text, context, why):
    clear_draft(conversation)
    return proposals.create_note(
        user=user, conversation=conversation, query=text, context=context,
        text=f"{why} Rien n'a été enregistré. Redites-moi ce que vous voulez faire quand vous voulez.",
        suggestions=['Consulter mon solde', 'Vérifier mon stock', 'Mes rappels'])


def _continue(user, conversation, draft, text, intent, context):
    from .actions import classify_reply

    if classify_reply(text) == 'cancel':
        return _abandon(user, conversation, text, context, "D'accord, j'abandonne.")
    # Une nouvelle demande complète (ou un message de service) prend le pas sur le brouillon
    new_request = (intent.get('has_intent') and not intent['params'].get('time_missing')) or intent.get('note')
    if new_request:
        clear_draft(conversation)
        return None

    asked = missing_slots(draft)[0]
    before = set(missing_slots(draft))
    _fill_from_sentence(draft, text, user)
    if asked in missing_slots(draft):
        _apply_asked_slot(draft, asked, text, user)

    if len(missing_slots(draft)) < len(before) or set(missing_slots(draft)) != before:
        draft['failures'] = 0
        if not missing_slots(draft):
            return _complete(user, conversation, draft, text, context)
        return _ask(conversation, user, draft, text, context, first=False)

    # Rien de compris : on précise, puis on renonce plutôt que de tourner en rond
    draft['failures'] = draft.get('failures', 0) + 1
    if draft['failures'] > MAX_FAILED_ANSWERS:
        return _abandon(user, conversation, text, context, "Je n'arrive pas à compléter cette opération.")
    if draft.get('candidates') and asked == 'product':
        question, suggestions = question_for(asked, draft, user)
        hint = question
    else:
        question, suggestions = question_for(asked, draft, user)
        hint = f"{_retry_hint(asked)}\n\n{question}"
    _store_draft(conversation, draft)
    note = proposals.create_note(user=user, conversation=conversation, query=text, context=context,
                                 text=hint, suggestions=suggestions, kind=QUESTION_KIND)
    bind_question(conversation, note)
    return note
