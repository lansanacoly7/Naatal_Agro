import datetime
import math
import re
import logging
import unicodedata
import uuid
from django.db import transaction as db_transaction
from django.utils import timezone

from apps.finances.categories import CATEGORY_CODES, category_label, infer_expense_category, normalize_text
from .scheduling import parse_schedule, strip_time_expressions

logger = logging.getLogger(__name__)

# Plafonds alignés sur les champs de la base (DecimalField 12,2 pour les montants, 10,2 pour les prix)
MAX_AMOUNT = 9_999_999_999.0
MAX_UNIT_PRICE = 99_999_999.0
MAX_QUANTITY = 1_000_000_000.0

TECHNICAL_ERROR_MESSAGE = "Une erreur technique est survenue : rien n'a été enregistré. Réessayez dans un instant."

# Patterns d'extraction d'actions financières et logistiques
# 1. Achat / Dépense avec quantité + produit + montant monétaire distinct
# Ex: "J'ai acheté 3 sacs d'engrais à 15000 FCFA" ou "Jend naa 3 saag kompoos ci 15000 cfa"
RE_EXPENSE_WITH_QTY = re.compile(
    r'(?:achet[ée]|achat|pay[ée]|j[ëe]nd)\s+'
    r'(?:naa\s+|na\s+|nga\s+|nañu\s+)?'
    r'([0-9\s.,]+)\s*'
    r'([a-zA-ZÀ-ÿ]+)?\s+'
    r'(?:de\s+|d[\'’]|ci\s+)?([a-zA-ZÀ-ÿ\s]+?)\s+'
    r'(?:[àa]|pour|co[uû]tant|montant\s+de|ci)\s+'
    r'([0-9\s.,]+)\s*(?:fcfa|cfa|f\b)?',
    re.IGNORECASE
)

# 2. Dépense formulée sous forme d'ordre impératif
# Ex: "Enregistre une dépense de 15000 FCFA pour l'essence"
# Achat formulé en wolof, produit avant le montant : « Jënd naa engrais 20000 cfa »
RE_EXPENSE_WOLOF_BUY = re.compile(
    r'\bj[ëe]nd\s+(?:naa|na|nga|nañu)\s+([a-zA-ZÀ-ÿ\s]+?)\s+([0-9][0-9\s.,]*)\s*(?:fcfa|cfa|f\b)', re.IGNORECASE
)

RE_EXPENSE_COMMAND = re.compile(
    r'(?:enregistre|ajoute|note|mets)\s+(?:une\s+)?d[ée]pens[ée]\s+(?:de\s+)?'
    r'([0-9\s.,]+)\s*(?:fcfa|cfa|f\b)?\s*'
    r'(?:pour|sur|de|en)?\s*(.+)?',
    re.IGNORECASE
)

# 3. Dépense directe
# Ex: "J'ai dépensé 15 000 FCFA pour l'achat d'engrais urée" ou "Depaase naa 15000 cfa ci kompoos"
RE_EXPENSE_DIRECT = re.compile(
    r'(?:d[ée]pens[ée]|depaase|fey|pay[ée]|co[uû]t|facture)\s+'
    r'(?:naa\s+|na\s+|nga\s+|nañu\s+)?(?:de\s+)?'
    r'([0-9\s.,]+)\s*(?:fcfa|cfa|f\b)?\s*'
    r'(?:pour|sur|de|en|ci)?\s*(.+)?',
    re.IGNORECASE
)

# 4. Vente avec montant global ("pour 25000 FCFA", "au total de 25000 FCFA")
# Ex: "J'ai vendu 50 kg de maïs pour 25000 FCFA"
RE_SALE_TOTAL = re.compile(
    r'(?:vendu|vente|ja{1,2}y)\s+'
    r'(?:naa\s+|na\s+|nga\s+|nañu\s+)?'
    r'([0-9\s.,]+)\s*'
    r'([a-zA-ZÀ-ÿ]+)?\s+'
    r'(?:de\s+|ci\s+)?([a-zA-ZÀ-ÿ\s]+?)\s+'
    r'(?:pour|au\s+total\s+de)\s+'
    r'([0-9\s.,]+)\s*(?:fcfa|cfa|f\b)?',
    re.IGNORECASE
)

# 5. Vente avec prix unitaire ("à 12000 FCFA", "à 12000 FCFA le sac")
# Ex: "J'ai vendu 25 sacs de riz à 12000 FCFA" ou "Jaay naa 10 sac ceeb à 15000 f"
RE_SALE_UNIT = re.compile(
    r'(?:vendu|vente|ja{1,2}y)\s+'
    r'(?:naa\s+|na\s+|nga\s+|nañu\s+)?'
    r'([0-9\s.,]+)\s*'
    r'([a-zA-ZÀ-ÿ]+)?\s+'
    r'(?:de\s+|ci\s+)?([a-zA-ZÀ-ÿ\s]+?)\s+'
    r'(?:[àa]|au\s+prix\s+de|ci)\s+'
    r'([0-9\s.,]+)\s*(?:fcfa|cfa|f\b)?',
    re.IGNORECASE
)

RE_STOCK_ADD = re.compile(
    r'(?:re[çc]u|stock[ée]|stocker|ajoute|doli)\s+([0-9\s.,]+)\s*([a-zA-ZÀ-ÿ]+)?\s+(?:de\s+)?([a-zA-ZÀ-ÿ\s]+?)\s+(?:en\s+stock|au\s+magasin|ci\s+magasaŋ)?',
    re.IGNORECASE
)

# Création d'un rappel : seulement des formulations explicites (« rappelle-moi », « mets un rappel »…)
RE_REMINDER = re.compile(
    r"(?:rappelle[- ]moi|alerte[- ]moi|fatt?ali\s+ma"
    r"|(?:mets|programme|cr[ée]e|ajoute|pose)\s+(?:moi\s+)?un\s+(?:rappel|alerte))"
    r"\s*(?:de\s+|d['’]\s*|pour\s+|:\s*)?(.+)",
    re.IGNORECASE
)
_REMINDER_NOUN = (
    r"(?:mon|ma|le|la|ce|cet|cette|mes|les|l['’])\s*(?:rappel|alerte)s?\b\s*"
    r"(?:de\s+|d['’]\s*|pour\s+|du\s+|des\s+)?"
)
RE_REMINDER_CANCEL = re.compile(
    r"(?:annule|supprime|retire|efface|enl[eè]ve)\s+(?:moi\s+)?" + _REMINDER_NOUN + r"(.*)", re.IGNORECASE)
RE_REMINDER_UPDATE = re.compile(
    r"(?:d[ée]cale|reporte|repousse|modifie|change|avance|d[ée]place)\s+" + _REMINDER_NOUN
    + r"(.*?)\s+(?:[àa]|pour|au|vers|sur|jusqu['’]?[àa])\s+(.+)$", re.IGNORECASE)
RE_STOCK_SET = re.compile(
    r"(?:corrige|mets|mettre|ajuste|fixe|modifie|r[ée]gle)\s+(?:le\s+|mon\s+)?stock\s+"
    r"(?:de\s+|du\s+|des\s+|d['’]\s*)?([a-zA-ZÀ-ÿ\s]+?)\s+(?:[àa]|sur|=)\s*([0-9][0-9\s.,]*)\s*([a-zA-ZÀ-ÿ]+)?",
    re.IGNORECASE
)

# Vocabulaire des réponses à une proposition d'opération (mots normalisés : sans accent ni ponctuation).
# Une réponse n'est une confirmation/annulation que si TOUS ses mots appartiennent à ce vocabulaire :
# « ok mais mets 5000 » n'est donc jamais une confirmation.
_CONFIRM_WORDS = frozenset({
    'oui', 'ouais', 'ok', 'okay', 'okey', 'yes', 'confirme', 'confirmer', 'valide', 'valider',
    'enregistre', 'enregistrer', 'daccord', 'cestbon', 'vasy', 'waaw', 'baaxna', 'baax',
})
_CANCEL_WORDS = frozenset({
    'non', 'nan', 'nope', 'annule', 'annuler', 'stop', 'laissetomber', 'nefaisrien', 'deedet', 'deedeet',
})
_POLITE_WORDS = frozenset({'merci', 'svp', 'stp', 's', 'il', 'vous', 'plait', 'te', 'je', 'bien', 'sur', 'alors'})
_REPLY_PHRASES = (
    (re.compile(r'\bd accord\b'), 'daccord'),
    (re.compile(r'\bc est bon\b'), 'cestbon'),
    (re.compile(r'\bvas y\b'), 'vasy'),
    (re.compile(r'\bbaax na\b'), 'baaxna'),
    (re.compile(r'\blaisse tomber\b'), 'laissetomber'),
    (re.compile(r'\bne fais rien\b'), 'nefaisrien'),
)
_MAX_REPLY_WORDS = 8


def _parse_number(val_str):
    """Extrait un float propre depuis une chaîne avec espaces ou virgules ou séparateurs de milliers."""
    if not val_str:
        return 0.0
    clean = re.sub(r'[^\d,.]', '', str(val_str)).strip()
    if not clean:
        return 0.0
    # Gérer les séparateurs de milliers ex: 15.000 ou 15 000
    if re.match(r'^\d{1,3}(?:\.\d{3})+$', clean):
        clean = clean.replace('.', '')
    elif re.match(r'^\d{1,3}(?:,\d{3})+$', clean):
        clean = clean.replace(',', '')
    else:
        clean = clean.replace(',', '.')
    try:
        return float(clean)
    except ValueError:
        return 0.0


def _fmt_datetime(value):
    return timezone.localtime(value).strftime("%d/%m/%Y à %H:%M")


def _note(text, suggestions=None):
    """Réponse de service : la demande est reconnue mais ne peut pas devenir une proposition."""
    return {'has_intent': False, 'note': text, 'suggestions': suggestions or ['Mes rappels', 'Consulter mon solde']}


def _match_user_crop(user, text):
    """Culture de l'utilisateur citée dans ``text`` (par son nom entier), à condition qu'elle soit unique."""
    if not user or not getattr(user, 'is_authenticated', False):
        return None
    from apps.agriculture.models import Crop
    haystack = normalize_text(text)
    found = {}
    for crop in Crop.objects.filter(user=user).only('id', 'name')[:100]:
        name = normalize_text(crop.name).strip()
        if name and f' {name} ' in haystack:
            found[name] = crop
    return next(iter(found.values())) if len(found) == 1 else None


_REMINDER_STOPWORDS = frozenset({
    'mon', 'mes', 'rappel', 'rappels', 'alerte', 'alertes', 'pour', 'dans', 'avec', 'cette', 'celui', 'celle',
    'tout', 'tous', 'toutes', 'plus', 'quand', 'les', 'des', 'une', 'prevu', 'prevue',
})


def _find_reminders(user, text):
    """Rappels à venir de l'utilisateur dont le texte contient tous les mots significatifs de ``text``."""
    from apps.notifications.services import pending_reminders
    words = [w for w in normalize_text(strip_time_expressions(text)).split()
             if len(w) >= 4 and w not in _REMINDER_STOPWORDS]
    reminders = list(pending_reminders(user)[:50])
    return [r for r in reminders if all(w[:5] in normalize_text(r.message) for w in words)]


def _describe_reminders(reminders):
    return "\n".join(f"{i}. {r.message} — {_fmt_datetime(r.scheduled_for)}" for i, r in enumerate(reminders, 1))


def _reminder_target(user, text, verb):
    """(rappel, None) si un seul correspond ; (None, note) sinon, avec l'explication à donner à l'utilisateur."""
    matches = _find_reminders(user, text)
    if not matches:
        return None, _note("Aucun rappel à venir ne correspond à votre demande. Dites « mes rappels » pour les voir.")
    if len(matches) > 1:
        return None, _note(
            f"Plusieurs rappels correspondent, je n'en {verb} aucun pour l'instant :\n{_describe_reminders(matches)}\n\n"
            f"Redites votre demande en citant un mot du rappel (exemple : « {verb} mon rappel d'arroser les piments »)."
        )
    return matches[0], None


def _detect_reminder_cancel(q, user):
    match = RE_REMINDER_CANCEL.search(q)
    if not match or not user:
        return None
    target, note = _reminder_target(user, match.group(1), 'annule')
    if note:
        return note
    return {
        'has_intent': True,
        'action_type': 'cancel_reminder',
        'params': {
            'notification_id': str(target.pk),
            'message': target.message,
            'scheduled_for': target.scheduled_for.isoformat(),
        },
        'summary': f"Annulation du rappel « {target.message} » prévu le {_fmt_datetime(target.scheduled_for)}",
        'confirm_prompt': "Confirmez-vous l'annulation de ce rappel ?",
    }


def _detect_reminder_update(q, user):
    match = RE_REMINDER_UPDATE.search(q)
    if not match or not user:
        return None
    schedule = parse_schedule(match.group(2))
    if schedule is None:
        return _note(
            "Je n'ai pas compris la nouvelle échéance du rappel. Précisez-la, par exemple : "
            "« décale mon rappel d'arroser à demain 7h »."
        )
    target, note = _reminder_target(user, match.group(1), 'décale')
    if note:
        return note
    return {
        'has_intent': True,
        'action_type': 'update_reminder',
        'params': {
            'notification_id': str(target.pk),
            'message': target.message,
            'previous_scheduled_for': target.scheduled_for.isoformat(),
            'scheduled_for': schedule.when.isoformat(),
            'time_defaulted': schedule.time_defaulted,
        },
        'summary': (f"Report du rappel « {target.message} » : {_fmt_datetime(target.scheduled_for)} "
                    f"→ {_fmt_datetime(schedule.when)}"),
        'confirm_prompt': "Confirmez-vous ce changement d'échéance ?",
    }


def _detect_reminder_create(q):
    match = RE_REMINDER.search(q)
    if not match:
        return None
    text = match.group(1).strip(" .!?")
    if not text:
        return None
    schedule = parse_schedule(text)
    message = (strip_time_expressions(text) or text)
    return build_reminder_intent(message, schedule.when if schedule else None,
                                 time_defaulted=schedule is None or schedule.time_defaulted)


def build_reminder_intent(message, when=None, time_defaulted=False):
    """
    Proposition de rappel. Sans échéance du tout (``when`` absent), on retient demain matin ET on le marque
    (``time_missing``) : le dialogue préfère alors demander l'échéance plutôt que de la deviner.
    """
    time_missing = when is None
    if time_missing:
        when = parse_schedule("demain matin").when
        time_defaulted = True
    message = message.strip()
    return {
        'has_intent': True,
        'action_type': 'create_reminder',
        'params': {
            'message': message[:1].upper() + message[1:],
            'scheduled_for': when.isoformat(),
            'time_defaulted': time_defaulted,
            'time_missing': time_missing,
        },
        'summary': f"Rappel pour le {_fmt_datetime(when)} : « {message} »",
        'confirm_prompt': f"Voulez-vous que je programme ce rappel pour le {_fmt_datetime(when)} : « {message} » ?",
    }


def build_sale_intent(product, qty, unit, unit_price=None, total_price=None):
    """Proposition de vente. Le prix peut être donné unitaire OU total ; l'autre s'en déduit."""
    unit = (unit or "unités").strip()
    if unit_price is None:
        unit_price = round(total_price / qty, 2)
        summary = f"Vente de {qty:g} {unit} de {product} pour {total_price:,.0f} FCFA ({unit_price:,.0f} FCFA/{unit})"
        prompt = (f"Confirmez-vous l'enregistrement de la vente de {qty:g} {unit} de {product} "
                  f"pour un montant total de {total_price:,.0f} FCFA ?")
    else:
        total = round(qty * unit_price, 2)
        summary = f"Vente de {qty:g} {unit} de {product} à {unit_price:,.0f} FCFA/u (Total : {total:,.0f} FCFA)"
        prompt = f"Confirmez-vous l'enregistrement de la vente de {qty:g} {unit} de {product} pour un total de {total:,.0f} FCFA ?"
    return {
        'has_intent': True,
        'action_type': 'record_sale',
        'params': {
            'product_name': product.capitalize(),
            'quantity': qty,
            'price_per_unit': unit_price,
            'unit': unit,
            'date': str(timezone.now().date()),
        },
        'summary': summary.replace(',', ' '),
        'confirm_prompt': prompt.replace(',', ' '),
    }


def build_stock_add_intent(product, qty, unit):
    unit = (unit or "unités").strip()
    return {
        'has_intent': True,
        'action_type': 'update_stock',
        'params': {'product_name': product.capitalize(), 'quantity': qty, 'unit': unit, 'operation': 'add'},
        'summary': f"Ajout au stock : {qty:g} {unit} de {product}",
        'confirm_prompt': f"Confirmez-vous l'ajout de {qty:g} {unit} de {product} dans votre stock ?",
    }


def _expense_intent(amount, description, user):
    """Proposition d'enregistrement d'une dépense, avec sa catégorie et la culture concernée si elles sont connues."""
    description = re.sub(r'\s{2,}', ' ', description).strip(" .!?") or "Dépense exploitation"
    category = infer_expense_category(description)
    crop = _match_user_crop(user, description)
    params = {
        'amount': amount,
        'description': description,
        'date': str(timezone.now().date()),
        'category': category,
    }
    details = f"catégorie : {category_label(category)}"
    if crop:
        params['crop_id'] = str(crop.pk)
        params['crop_name'] = crop.name
        details += f" · culture : {crop.name}"
    return {
        'has_intent': True,
        'action_type': 'record_expense',
        'params': params,
        'summary': f"Dépense de {amount:,.0f} FCFA pour {description} ({details})".replace(',', ' '),
        'confirm_prompt': f"Confirmez-vous l'enregistrement de cette dépense de {amount:,.0f} FCFA pour « {description} » ?".replace(',', ' '),
    }


def _stock_set_intent(match, user):
    product = match.group(1).strip()
    if not product or not match.group(2).strip():
        return None
    return build_stock_set_intent(product, _parse_number(match.group(2)), (match.group(3) or '').strip() or None, user)


def build_expense_intent(amount, description, user):
    """Proposition de dépense (catégorie et culture déduites du libellé)."""
    return _expense_intent(amount, description, user)


def build_stock_set_intent(product, quantity, unit, user):
    """Proposition de correction de stock : « 50 → 40 » si l'article existe, sinon création."""
    from apps.inventory.models import StockItem
    current = StockItem.objects.filter(user=user, name__iexact=product).first() if user else None
    unit = (unit or (current.unit if current else "unités")).strip()
    if current:
        summary = f"Correction du stock de {current.name} : {current.quantity:g} → {quantity:g} {unit}"
    else:
        summary = f"Création du stock de {product} : {quantity:g} {unit}"
    return {
        'has_intent': True,
        'action_type': 'update_stock',
        'params': {'product_name': product.capitalize(), 'quantity': quantity, 'unit': unit, 'operation': 'set'},
        'summary': summary,
        'confirm_prompt': f"Confirmez-vous cette correction : {product} = {quantity:g} {unit} ?",
    }


def detect_action_intent(query, user=None):
    """
    Analyse l'intention de l'utilisateur pour détecter une action métier concrète.
    Implémente un parseur déterministe hiérarchique avec séparation stricte des
    quantités/conditionnements physiques et des montants monétaires en FCFA.

    Renvoie ``{'has_intent': True, 'action_type', 'params', 'summary', 'confirm_prompt'}`` pour une proposition,
    ``{'has_intent': False, 'note': ...}`` quand la demande est reconnue mais ne peut pas être traitée
    (rappel introuvable, plusieurs rappels possibles, échéance incomprise), sinon ``{'has_intent': False}``.
    """
    q = query.strip()

    # 0. Rappels : créer, reporter, annuler (testés en premier, leurs verbes sont sans ambiguïté)
    for detect in (lambda: _detect_reminder_cancel(q, user), lambda: _detect_reminder_update(q, user),
                   lambda: _detect_reminder_create(q)):
        intent = detect()
        if intent:
            return intent

    # 1. Détection de Dépense avec quantité & montant monétaire distinct
    # Ex: "J'ai acheté 3 sacs d'engrais à 15000 FCFA" -> amount = 15000, desc = "Achat 3 sacs d'engrais"
    m_exp_qty = RE_EXPENSE_WITH_QTY.search(q)
    if m_exp_qty:
        qty_str = m_exp_qty.group(1)
        unit = (m_exp_qty.group(2) or "").strip()
        product = m_exp_qty.group(3).strip()
        amount = _parse_number(m_exp_qty.group(4))
        qty = _parse_number(qty_str)

        if amount > 0:
            qty_part = f"{qty:g} {unit}".strip() if qty > 0 else ""
            desc = f"Achat {qty_part} de {product}".strip() if qty_part else f"Achat {product}"
            return _expense_intent(amount, desc, user)

    m_buy = RE_EXPENSE_WOLOF_BUY.search(q)
    if m_buy and _parse_number(m_buy.group(2)) > 0:
        return _expense_intent(_parse_number(m_buy.group(2)), f"Achat {m_buy.group(1).strip()}", user)

    # 2. Détection de Dépense formulée en ordre direct ou montant direct
    # Ex: "J'ai dépensé 15 000 FCFA pour l'achat d'engrais urée" ou "Depaase naa 15000 cfa ci kompoos"
    m_exp = RE_EXPENSE_COMMAND.search(q) or RE_EXPENSE_DIRECT.search(q)
    if m_exp:
        amount = _parse_number(m_exp.group(1))
        if amount > 0:
            desc = (m_exp.group(2) or "Dépense exploitation").strip(" .!?")
            return _expense_intent(amount, desc[:1].upper() + desc[1:] if desc else desc, user)

    # 3. Détection de Vente avec montant TOTAL (ex: "J'ai vendu 50 kg de maïs pour 25000 FCFA")
    m_sale_tot = RE_SALE_TOTAL.search(q)
    if m_sale_tot:
        qty = _parse_number(m_sale_tot.group(1))
        unit = (m_sale_tot.group(2) or "unités").strip()
        product = m_sale_tot.group(3).strip()
        total_price = _parse_number(m_sale_tot.group(4))

        if qty > 0 and total_price > 0:
            return build_sale_intent(product, qty, unit, total_price=total_price)

    # 4. Détection de Vente avec prix UNITAIRE (ex: "J'ai vendu 25 sacs de riz à 12000 FCFA")
    m_sale_u = RE_SALE_UNIT.search(q)
    if m_sale_u:
        qty = _parse_number(m_sale_u.group(1))
        unit = (m_sale_u.group(2) or "unités").strip()
        product = m_sale_u.group(3).strip()
        price = _parse_number(m_sale_u.group(4))
        if qty > 0 and price > 0:
            return build_sale_intent(product, qty, unit, unit_price=price)

    # 5a. Correction d'un stock (« Mets le stock de mil à 40 sacs »)
    m_stock_set = RE_STOCK_SET.search(q)
    if m_stock_set:
        intent = _stock_set_intent(m_stock_set, user)
        if intent:
            return intent

    # 5b. Détection d'Ajout de Stock
    if any(k in q.lower() for k in ('stock', 'magasin', 'magasaŋ', 'sacs', 'caisses')) and any(k in q.lower() for k in ('reçu', 'ajouter', 'enregistre', 'mettre', 'doli', 'stocké', 'stocker')):
        m_stock = RE_STOCK_ADD.search(q)
        if m_stock:
            qty = _parse_number(m_stock.group(1))
            unit = (m_stock.group(2) or "unités").strip()
            product = m_stock.group(3).strip()
            if qty > 0 and product:
                return build_stock_add_intent(product, qty, unit)

    return {'has_intent': False}


def _reply_words(text):
    """Mots d'une réponse : minuscules, sans accent ni ponctuation, locutions courantes fusionnées."""
    decomposed = unicodedata.normalize('NFD', str(text or '').lower())
    plain = ''.join(ch for ch in decomposed if unicodedata.category(ch) != 'Mn')
    plain = ' '.join(re.sub(r'[^a-z0-9]+', ' ', plain).split())
    for pattern, replacement in _REPLY_PHRASES:
        plain = pattern.sub(replacement, plain)
    return plain.split()


def classify_reply(query):
    """
    Interprète la réponse de l'utilisateur à une proposition d'opération.

    - ``'confirm'`` / ``'cancel'`` : message composé uniquement de mots de confirmation (ou d'annulation)
      et de politesse (« oui », « Oui, confirme », « non merci »…).
    - ``'ambiguous'`` : message qui COMMENCE par oui/non mais contient autre chose
      (« ok mais mets 5000 »), ou mélange confirmation et annulation : rien ne doit être exécuté.
    - ``None`` : message sans rapport avec la proposition.
    """
    words = _reply_words(query)
    if not words:
        return None
    has_confirm = any(w in _CONFIRM_WORDS for w in words)
    has_cancel = any(w in _CANCEL_WORDS for w in words)
    if has_confirm and has_cancel:
        return 'ambiguous'
    only_reply_words = all(w in _CONFIRM_WORDS or w in _CANCEL_WORDS or w in _POLITE_WORDS for w in words)
    if only_reply_words and len(words) <= _MAX_REPLY_WORDS:
        if has_confirm:
            return 'confirm'
        if has_cancel:
            return 'cancel'
        return None
    if words[0] in _CONFIRM_WORDS or words[0] in _CANCEL_WORDS:
        return 'ambiguous'
    return None


def is_confirmation(query):
    """Vrai uniquement si le message est une confirmation explicite et rien d'autre."""
    return classify_reply(query) == 'confirm'


def is_cancellation(query):
    """Vrai uniquement si le message est une annulation explicite et rien d'autre."""
    return classify_reply(query) == 'cancel'


def _as_text(value, limit):
    """Texte nettoyé et tronqué ; seule une chaîne est acceptée (une liste ou un nombre donne une chaîne vide)."""
    return value.strip()[:limit] if isinstance(value, str) else ''


def _as_positive_number(value, maximum):
    """Nombre fini, strictement positif et inférieur au plafond, ou ``None``."""
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(number) or number <= 0 or number > maximum:
        return None
    return number


def _as_date(value):
    """Date ISO (aujourd'hui si absente) ; ``None`` si la valeur est illisible."""
    if not value:
        return timezone.now().date()
    if isinstance(value, datetime.date):
        return value
    try:
        return datetime.date.fromisoformat(str(value)[:10])
    except ValueError:
        return None


def _failure(message, code):
    return {'success': False, 'message': message, 'error_code': code, 'data': {}}


def _as_non_negative_number(value, maximum):
    """Nombre fini compris entre 0 (inclus) et le plafond, ou ``None``."""
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(number) or number < 0 or number > maximum:
        return None
    return number


def _parse_aware_datetime(value):
    """Date-heure ISO interprétée comme aware ; ``None`` si elle est illisible."""
    try:
        parsed = datetime.datetime.fromisoformat(str(value))
    except ValueError:
        return None
    return timezone.make_aware(parsed) if timezone.is_naive(parsed) else parsed


def _insufficient_stock_message(stock, quantity):
    return (f"Stock insuffisant : {stock.quantity:g} {stock.unit} disponible(s) pour {quantity:g} à vendre. "
            "Corrigez d'abord votre stock (par exemple « mets le stock de ... à ... ») ou la quantité vendue.")


def check_action(user, action_type, params):
    """
    Contrôles faits AVANT de proposer une opération (aucune écriture en base).

    Renvoie ``(blockers, warnings)`` : un blocage empêche toute proposition (l'assistant applique les mêmes règles
    que l'application), un avertissement est affiché avec la proposition.
    """
    blockers, warnings = [], []
    if not user:
        return blockers, warnings

    if action_type == 'record_sale':
        from apps.inventory.models import StockItem
        name = _as_text(params.get('product_name'), 255)
        quantity = _as_positive_number(params.get('quantity'), MAX_QUANTITY)
        stock = StockItem.objects.filter(user=user, name__iexact=name).first() if name else None
        if stock and quantity is not None and quantity > stock.quantity:
            blockers.append(_insufficient_stock_message(stock, quantity))

    elif action_type == 'record_expense':
        if params.get('category') == 'autre':
            warnings.append("Catégorie non identifiée : la dépense sera classée « Autre ».")

    elif action_type in ('create_reminder', 'update_reminder'):
        when = _parse_aware_datetime(params.get('scheduled_for'))
        if when is not None and when < timezone.now() - datetime.timedelta(minutes=1):
            blockers.append(f"L'échéance du {_fmt_datetime(when)} est déjà passée : précisez une date à venir.")
        elif params.get('time_defaulted'):
            warnings.append(
                f"Aucune heure précisée : j'ai retenu le {_fmt_datetime(when)}. "
                "Pour une autre heure, redonnez votre demande avec l'heure souhaitée."
            )

    if action_type in ('cancel_reminder', 'update_reminder'):
        from apps.notifications.services import pending_reminders
        if not pending_reminders(user).filter(pk=params.get('notification_id')).exists():
            blockers.append("Ce rappel a déjà été délivré ou annulé.")

    return blockers, warnings


def execute_action(user, action_type, params):
    """
    Exécute l'action demandée de manière strictement sécurisée et transactionnelle.
    Renvoie ``{'success': bool, 'message': str, 'data': dict}``.
    """
    if not user or not user.is_authenticated:
        return _failure("Utilisateur non authentifié.", 'unauthenticated')
    if not isinstance(params, dict):
        return _failure("Paramètres d'opération invalides.", 'invalid_params')

    try:
        with db_transaction.atomic():
            if action_type == 'record_expense':
                from apps.finances.models import Transaction
                from apps.agriculture.models import Crop
                amount = _as_positive_number(params.get('amount'), MAX_AMOUNT)
                if amount is None:
                    return _failure("Le montant de la dépense doit être un nombre supérieur à zéro.", 'invalid_amount')

                desc = _as_text(params.get('description'), 255) or 'Dépense enregistrée par Naatal IA'
                t_date = _as_date(params.get('date'))
                if t_date is None:
                    return _failure("La date de la dépense est illisible.", 'invalid_date')

                category = params.get('category')
                if category not in CATEGORY_CODES:
                    category = infer_expense_category(desc)
                crop = None
                if params.get('crop_id'):
                    try:
                        crop = Crop.objects.filter(user=user, pk=uuid.UUID(str(params['crop_id']))).first()
                    except ValueError:
                        crop = None

                tx = Transaction.objects.create(
                    user=user,
                    transaction_type='expense',
                    amount=amount,
                    description=desc,
                    date=t_date,
                    category=category,
                    crop=crop,
                )
                return {
                    'success': True,
                    'message': (f"Dépense de {amount:,.0f} FCFA pour « {desc} » enregistrée avec succès "
                                f"(catégorie : {category_label(category)}).").replace(',', ' '),
                    'data': {
                        'transaction_id': str(tx.id),
                        'amount': float(tx.amount),
                        'description': tx.description,
                        'date': str(tx.date),
                        'category': tx.category,
                        'crop_id': str(crop.pk) if crop else None,
                    }
                }

            elif action_type == 'record_sale':
                from apps.finances.models import Sale, Transaction
                from apps.inventory.models import StockItem
                from apps.inventory.services import change_stock
                from apps.agriculture.models import Crop

                product_name = _as_text(params.get('product_name'), 255)
                qty = _as_positive_number(params.get('quantity'), MAX_QUANTITY)
                price = _as_positive_number(params.get('price_per_unit'), MAX_UNIT_PRICE)
                s_date = _as_date(params.get('date'))
                buyer = _as_text(params.get('buyer'), 255)

                if not product_name:
                    return _failure("Le produit vendu est requis.", 'missing_product')
                if qty is None or price is None or qty * price > MAX_AMOUNT:
                    return _failure("La quantité et le prix unitaire doivent être des nombres supérieurs à zéro.", 'invalid_amount')
                if s_date is None:
                    return _failure("La date de la vente est illisible.", 'invalid_date')

                # Même règle que l'API des ventes : on ne vend pas plus que le stock disponible
                stock_item = StockItem.objects.filter(user=user, name__iexact=product_name).first()
                if stock_item and qty > stock_item.quantity:
                    return _failure(_insufficient_stock_message(stock_item, qty), 'insufficient_stock')

                crop = Crop.objects.filter(user=user, name__iexact=product_name).first()
                sale = Sale.objects.create(
                    user=user,
                    crop=crop,
                    product_name=product_name if not crop else crop.name,
                    quantity_sold=qty,
                    price_per_unit=price,
                    date=s_date,
                    buyer=buyer or "Client comptant"
                )

                # Décrémenter le stock (journalisé avec la vente qui l'explique)
                if stock_item:
                    change_stock(stock_item, stock_item.quantity - qty, reason='sale',
                                 note=f"Vente du {s_date} (assistant)", sale=sale)

                # Créer la transaction de revenu
                Transaction.objects.update_or_create(
                    sale=sale,
                    defaults={
                        'user': user,
                        'transaction_type': 'income',
                        'amount': sale.total_revenue,
                        'date': sale.date,
                        'description': f"Vente de {product_name} ({qty})"
                    }
                )

                return {
                    'success': True,
                    'message': f"Vente de {qty} de {product_name} à {price:,.0f} FCFA enregistrée (Recette : {sale.total_revenue:,.0f} FCFA).".replace(',', ' '),
                    'data': {
                        'sale_id': str(sale.id),
                        'product_name': product_name,
                        'total_revenue': float(sale.total_revenue),
                        'quantity': qty,
                    }
                }

            elif action_type == 'update_stock':
                from apps.inventory.models import StockItem
                from apps.inventory.services import change_stock, create_stock_item
                product_name = _as_text(params.get('product_name'), 255)
                op = params.get('operation', 'add')
                # Une correction peut ramener le stock à zéro ; un ajout doit apporter une quantité positive
                qty = _as_non_negative_number(params.get('quantity'), MAX_QUANTITY) if op == 'set' \
                    else _as_positive_number(params.get('quantity'), MAX_QUANTITY)
                unit = _as_text(params.get('unit'), 50) or 'unités'

                if not product_name or qty is None or op not in ('add', 'set'):
                    return _failure("Informations de stock incomplètes.", 'invalid_stock')

                stock_item = StockItem.objects.filter(user=user, name__iexact=product_name).first()
                if stock_item:
                    if op == 'add':
                        change_stock(stock_item, stock_item.quantity + qty, reason='purchase',
                                     note="Ajout demandé à l'assistant")
                    else:
                        change_stock(stock_item, qty, reason='correction', note="Correction demandée à l'assistant")
                else:
                    stock_item = create_stock_item(user, product_name, qty, unit, reason='manual',
                                                   note="Création demandée à l'assistant")

                return {
                    'success': True,
                    'message': f"Stock de {stock_item.name} mis à jour : {stock_item.quantity:g} {stock_item.unit} disponibles au magasin.",
                    'data': {
                        'stock_id': str(stock_item.id),
                        'product_name': stock_item.name,
                        'quantity': stock_item.quantity,
                        'unit': stock_item.unit
                    }
                }

            elif action_type == 'create_reminder':
                from apps.notifications.models import Notification
                msg = _as_text(params.get('message'), 500)
                if not msg:
                    return _failure("Le texte du rappel est requis.", 'missing_message')

                scheduled_for = params.get('scheduled_for')
                sched_dt = None
                if scheduled_for:
                    sched_dt = _parse_aware_datetime(scheduled_for)
                    if sched_dt is None:
                        return _failure("La date du rappel est illisible.", 'invalid_date')
                    if sched_dt < timezone.now() - datetime.timedelta(minutes=1):
                        return _failure("Ce rappel est programmé dans le passé : précisez une échéance à venir.", 'past_schedule')

                notif = Notification.objects.create(
                    user=user,
                    type='reminder',
                    message=msg,
                    scheduled_for=sched_dt
                )
                date_str = _fmt_datetime(sched_dt) if sched_dt else "immédiat"
                return {
                    'success': True,
                    'message': f"Rappel programmé avec succès pour le {date_str} : « {msg} ».",
                    'data': {
                        'notification_id': str(notif.id),
                        'message': notif.message,
                        'scheduled_for': notif.scheduled_for.isoformat() if notif.scheduled_for else None,
                        'is_sent': notif.is_sent,
                        'created_at': notif.created_at.isoformat()
                    }
                }

            elif action_type in ('cancel_reminder', 'update_reminder'):
                from apps.notifications import services as reminders
                from apps.notifications.models import Notification
                try:
                    notification_id = uuid.UUID(str(params.get('notification_id')))
                except ValueError:
                    return _failure("Rappel introuvable.", 'reminder_not_found')
                reminder = Notification.objects.filter(pk=notification_id, user=user, type='reminder').first()
                if reminder is None:
                    return _failure("Rappel introuvable.", 'reminder_not_found')

                if action_type == 'cancel_reminder':
                    if not reminders.cancel_reminder(reminder):
                        return _failure("Ce rappel a déjà été délivré ou annulé : rien n'a été modifié.", 'reminder_not_pending')
                    return {
                        'success': True,
                        'message': f"Rappel « {reminder.message} » annulé.",
                        'data': {'notification_id': str(reminder.pk), 'cancelled': True},
                    }

                new_time = _parse_aware_datetime(params.get('scheduled_for'))
                if new_time is None:
                    return _failure("La nouvelle date du rappel est illisible.", 'invalid_date')
                if new_time < timezone.now() - datetime.timedelta(minutes=1):
                    return _failure("La nouvelle échéance est déjà passée : précisez une date à venir.", 'past_schedule')
                if not reminders.reschedule_reminder(reminder, new_time):
                    return _failure("Ce rappel a déjà été délivré ou annulé : rien n'a été modifié.", 'reminder_not_pending')
                return {
                    'success': True,
                    'message': f"Rappel « {reminder.message} » reporté au {_fmt_datetime(new_time)}.",
                    'data': {'notification_id': str(reminder.pk), 'scheduled_for': new_time.isoformat()},
                }

            else:
                return _failure("Cette opération n'est pas prise en charge.", 'unsupported_action')

    except Exception:
        # La transaction est annulée en bloc : aucune écriture partielle. Le détail reste dans les journaux.
        logger.exception("[Execute Action] Échec de l'action %s", action_type)
        return _failure(TECHNICAL_ERROR_MESSAGE, 'technical_error')


def analyze_farmer_finances(user, period='all'):
    """
    Bilan financier certifié d'une période (``all``, ``current_month``, ``last_month``, ``current_week``, ``last_week``,
    ``current_year``, ``season``, ``last_30_days``). Les calculs sont ceux du moteur ``analysis`` (source unique) ;
    cette fonction conserve le format historique de l'API ``/api/ai/analytics/``.
    """
    if not user or not user.is_authenticated:
        return {
            'period': period or 'all',
            'total_revenue_fcfa': 0.0,
            'total_expenses_fcfa': 0.0,
            'balance_fcfa': 0.0,
            'is_profitable': True,
            'sales_count': 0,
            'expenses_count': 0,
        }
    from . import analysis
    resolved = analysis.resolve_period(period)
    summary = analysis.financial_summary(user, resolved)
    return {
        'period': period or 'all',
        'start_date': str(resolved.start) if resolved.start else None,
        'end_date': str(resolved.end) if resolved.end else None,
        'total_revenue_fcfa': summary['total_revenue'],
        'total_expenses_fcfa': summary['expenses_total'],
        'balance_fcfa': summary['net_result'],
        'is_profitable': summary['net_result'] >= 0,
        'sales_count': summary['sales_count'],
        'expenses_count': summary['expenses_count'],
    }


def analyze_farmer_inventory(user):
    """Analyse certifiée de l'état des stocks en magasin."""
    if not user or not user.is_authenticated:
        return {'total_items': 0, 'low_stock_count': 0, 'items': [], 'low_stock_items': []}

    from apps.inventory.models import StockItem
    stocks = list(StockItem.objects.filter(user=user).order_by('name'))
    low_stocks = [s for s in stocks if s.quantity <= 5 or s.alert_status]
    return {
        'total_items': len(stocks),
        'low_stock_count': len(low_stocks),
        'items': [{'name': s.name, 'quantity': s.quantity, 'unit': s.unit, 'alert': bool(s.alert_status or s.quantity <= 5)} for s in stocks],
        'low_stock_items': [{'name': s.name, 'quantity': s.quantity, 'unit': s.unit} for s in low_stocks]
    }

