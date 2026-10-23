"""
Corpus et mesure du français / wolof de l'assistant (Phase 6).

Le corpus est ÉCRIT par l'équipe de développement : il n'a PAS été relu par un locuteur natif du wolof. Les chiffres
produits ici mesurent donc la tenue du code sur ces phrases, pas la qualité du wolof de l'assistant auprès de vrais
producteurs. Chaque cas : ``(texte, langue attendue, intention attendue)`` ; l'intention vaut ``'record_sale'``,
``'record_expense'``, ``'create_reminder'``… pour une action, ``'analysis:<type>'`` pour une analyse chiffrée, ou
``None`` quand la demande doit aller au modèle de langage (conseil, agronomie).
"""
from apps.ai_assistant import language
from apps.ai_assistant.actions import detect_action_intent
from apps.ai_assistant.analysis_answers import detect_analysis_intent

FR, WO, MIX = language.FRENCH, language.WOLOF, language.MIXED

CORPUS = (
    # --- français ---
    ("J'ai vendu 10 sacs de mil à 15000 FCFA", FR, 'record_sale'),
    ("J'ai dépensé 15000 FCFA pour de l'engrais", FR, 'record_expense'),
    ("Rappelle-moi d'arroser les piments demain à 7h", FR, 'create_reminder'),
    ("Combien il me reste de mil en stock ?", FR, 'analysis:stock_level'),
    ("Quel est mon bilan ce mois ?", FR, 'analysis:finance'),
    ("Quel produit rapporte le plus ?", FR, 'analysis:top_products'),
    ("Pourquoi mes dépenses augmentent ?", FR, 'analysis:expense_increase'),
    ("Comment traiter le mildiou sur la tomate ?", FR, None),
    ("Quand semer l'oignon à Saint-Louis ?", FR, None),
    ("Merci beaucoup", FR, None),
    ("Mes feuilles de piment jaunissent, que faire ?", FR, None),
    ("Montre mes dernières ventes", FR, 'analysis:recent_sales'),
    # --- wolof (écrit comme on l'écrit sur un téléphone) ---
    ("Jaay naa 10 sac ceeb ci 15000", WO, 'record_sale'),
    ("Jaay naa 20 saaku dugub ci 12000 cfa", WO, 'record_sale'),
    ("Depaase naa 15000 cfa ci kompoos", WO, 'record_expense'),
    ("Fey naa 5000 cfa ci ndox", WO, 'record_expense'),
    ("Jënd naa engrais 20000 cfa", WO, 'record_expense'),
    ("Fattali ma ëllëk ci suba ma suuxat sama tomaat", WO, 'create_reminder'),
    ("Ñaata dugub laa am ci sama stock ?", WO, 'analysis:stock_level'),
    ("Naka lañuy fajee soble ?", WO, None),
    ("Naka laay def ngir sama tomaat yi baax ?", WO, None),
    ("Ndox bi dafa tuuti, lan laay def ?", WO, None),
    ("Bëgg naa xam kañ laay jëmbët sama tool", WO, None),
    ("Waaw jërëjëf", WO, None),
    ("Baykat laa, bëgg naa jàng ci mbay mi", WO, None),
    ("Sama nebbe yi dafa feebar", WO, None),
    # --- mélanges français-wolof (usage réel) ---
    ("Jaay naa 5 sacs de mil à 10000", MIX, 'record_sale'),
    ("Dama bëgg enregistrer une dépense de 8000 FCFA", MIX, 'record_expense'),
    ("Fattali ma demain à 7h pour arroser les tomates", MIX, 'create_reminder'),
    ("Naka laay traiter le mildiou sur ma tomate ?", MIX, None),
    ("Ndax je dois vendre maintenant ou attendre ?", MIX, None),
)

# Variantes plus difficiles (orthographe SMS, sans diacritiques, fautes) : mesurées à part, jamais ajustées sur le code.
HARD_CORPUS = (
    ("jaay na 3 sac dugub ci 9000", WO, 'record_sale'),
    ("jay naa 4 saaku ceeb ci 14000", WO, 'record_sale'),
    ("Depense naa 7000 ci essence", WO, 'record_expense'),
    ("jend naa ndox 3000 f", WO, 'record_expense'),
    ("fatali ma suba ci 6h ma jang", WO, 'create_reminder'),
    ("nata soble laa am", WO, None),
    ("Naka la sama tool yi ?", WO, None),
    ("man dama bëgg jaay sama mboq", WO, None),
    ("J ai vendu 3 sacs d arachide a 18000", FR, 'record_sale'),
    ("jai depense 4500 f pour le gasoil", FR, 'record_expense'),
    ("ou est mon stock de mais", FR, 'analysis:stock_outlook'),
    ("bonjour", FR, None),
)


def intent_of(text, user):
    """Intention que l'application reconnaît dans ``text`` (même chaîne de décision que la vue), ou ``None``."""
    action = detect_action_intent(text, user)
    if action.get('has_intent'):
        return action['action_type']
    analysis = detect_analysis_intent(text, user)
    return f"analysis:{analysis['kind']}" if analysis else None


def evaluate(user, corpus=CORPUS):  # noqa: C901
    """Mesures hors ligne : détection de langue et reconnaissance d'intention, par langue, avec la liste des échecs."""
    report = {'cases': len(corpus), 'language': {}, 'intent': {}, 'failures': []}
    previous = None
    for text, lang, expected_intent in corpus:
        detected = language.detect(text).language
        found = intent_of(text, user)
        for bucket, ok in (('language', detected == lang), ('intent', found == expected_intent)):
            stats = report[bucket].setdefault(lang, {'ok': 0, 'total': 0})
            stats['total'] += 1
            stats['ok'] += int(ok)
        if detected != lang:
            report['failures'].append({'text': text, 'what': 'language', 'expected': lang, 'got': detected})
        if found != expected_intent:
            report['failures'].append({'text': text, 'what': 'intent', 'expected': expected_intent, 'got': found})
    for bucket in ('language', 'intent'):
        for stats in report[bucket].values():
            stats['rate'] = round(stats['ok'] / stats['total'], 3)
    return report
