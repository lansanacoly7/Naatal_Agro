"""
Données de présentation des analyses : un petit descripteur de graphique que l'application mobile dessine.

Chaque chiffre vient du résultat déterministe de ``analysis.py`` (rien n'est recalculé ni estimé ici) ; le texte de la
réponse reste la version de référence, le graphique n'en est qu'une lecture visuelle. Types :

- ``bars``    : barres horizontales ``items=[{label, value, tone}]`` (valeurs négatives possibles) ;
- ``compare`` : paires période en cours / période de référence ``rows=[{label, current, previous}]`` ;
- ``months``  : évolution mensuelle ``items=[{label, revenue, expenses, partial}]`` ;
- ``levels``  : niveaux de stock ``items=[{label, quantity, unit, level, cover_days}]``.

``tone`` : ``positive`` (vert), ``negative`` (argile), ``neutral``.
"""


def _bars(title, items, unit='FCFA'):
    items = [i for i in items if i['value'] is not None]
    return {'type': 'bars', 'title': title, 'unit': unit, 'items': items} if items else None


def _finance(data, intent):
    if not data.get('has_data'):
        return None
    net = data['net_result']
    return _bars("Recettes et dépenses", [
        {'label': 'Recettes', 'value': data['total_revenue'], 'tone': 'positive'},
        {'label': 'Dépenses', 'value': data['expenses_total'], 'tone': 'negative'},
        {'label': 'Résultat estimé', 'value': net, 'tone': 'positive' if net >= 0 else 'negative'},
    ])


def _top_products(data, intent):
    return _bars("Chiffre d'affaires par produit",
                 [{'label': p['name'], 'value': p['revenue'], 'tone': 'positive'} for p in data.get('products', [])[:5]])


def _profitability(data, intent):
    items = [{'label': c['name'], 'value': c['margin'], 'tone': 'positive' if c['margin'] >= 0 else 'negative'}
             for c in data.get('crops', []) if c['status'] == 'ok' and c['margin'] is not None]
    return _bars("Marge par culture", items[:6])


def _expense_increase(data, intent):
    if not data.get('comparable') or not data.get('increase'):
        return None
    return _bars("Ce qui explique la hausse des dépenses",
                 [{'label': d['label'], 'value': d['delta'], 'tone': 'negative'} for d in data.get('drivers', [])[:5]])


def _comparison(data, intent):
    if not data.get('comparable'):
        return None
    rows = [{'label': label, 'current': data[key]['current'], 'previous': data[key]['previous']}
            for label, key in (('Recettes', 'revenue'), ('Dépenses', 'expenses'), ('Résultat', 'net_result'))]
    return {'type': 'compare', 'title': "Période en cours et période de référence", 'unit': 'FCFA', 'rows': rows,
            'current_label': data['period']['label'], 'previous_label': data['reference']['label']}


def _trend(data, intent):
    if not data.get('has_data'):
        return None
    return {'type': 'months', 'title': "Recettes et dépenses par mois", 'unit': 'FCFA',
            'items': [{'label': m['label'], 'revenue': m['revenue'], 'expenses': m['expenses'], 'partial': m['partial']}
                      for m in data['months']]}


def _stock(data, intent):
    items = data.get('priorities') or data.get('items') or []
    if not items:
        return None
    return {'type': 'levels', 'title': "État des stocks", 'items': [
        {'label': i['name'], 'quantity': i['quantity'], 'unit': i['unit'], 'level': i['level'], 'cover_days': i['cover_days']}
        for i in items[:8]]}


_BUILDERS = {
    'finance': _finance,
    'top_products': _top_products,
    'profitability': _profitability,
    'expense_increase': _expense_increase,
    'comparison': _comparison,
    'trend': _trend,
    'stock_outlook': _stock,
    'stock_level': _stock,
}


def visual_for(intent, answer):
    """Descripteur de graphique de l'analyse, ou ``None`` quand les données ne s'y prêtent pas."""
    builder = _BUILDERS.get(intent.get('kind'))
    if not builder:
        return None
    return builder((answer or {}).get('data') or {}, intent)
