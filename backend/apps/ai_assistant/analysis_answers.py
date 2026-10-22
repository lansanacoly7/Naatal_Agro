"""
Du langage naturel aux analyses : reconnaît la demande de l'agriculteur, appelle le moteur de calcul
(``analysis.py``) et rédige une réponse DÉTERMINISTE : chaque chiffre vient de ses enregistrements, avec sa période,
ses définitions et ce qui manque. Le modèle de langage n'intervient jamais sur ces réponses.

Une demande de CONSEIL (« comment augmenter mes marges ? ») n'est pas interceptée ici : elle va au modèle, qui reçoit
la synthèse chiffrée certifiée (``analysis.context_digest``) et ne doit rien recalculer.
"""
import datetime
import re

from django.utils import timezone

from apps.finances.categories import normalize_text

from . import analysis

# --------------------------------------------------------------------------------------------------------------
# Reconnaissance de la demande
# --------------------------------------------------------------------------------------------------------------
# Questions de conseil ou de planification : réservées au modèle de langage (qui reçoit la synthèse certifiée)
_ADVICE = re.compile(
    r'\b(comment|conseil\w*|ameliorer|augmenter|reduire|baisser|diminuer|optimis\w*|astuce\w*|aide\w*|aider|prepar\w*|'
    r'planifi\w*|programm\w*|dois je vendre|quand)\b')

_PERIODS = (
    (r'\b(depuis le debut de la saison|cette saison|de la saison|la saison)\b', 'season'),
    (r'\b(depuis le debut|au total|toute la periode|depuis toujours)\b', 'all'),
    (r'\b(semaine derniere|semaine passee)\b', 'last_week'),
    (r'\b(cette semaine|de la semaine|semaine en cours)\b', 'current_week'),
    (r'\b(mois dernier|mois passe|mois precedent)\b', 'last_month'),
    (r'\b(ce mois|mois en cours|du mois)\b', 'current_month'),
    (r'\b(cette annee|annee en cours|de l annee)\b', 'current_year'),
    (r'\b(30 derniers jours|30 jours)\b', 'last_30_days'),
)


# Quand une demande de comparaison cite la période en cours ET la précédente (« ce mois au mois dernier »), la période
# analysée est la période en cours : c'est elle qu'on compare à la précédente.
_CURRENT_AND_LAST = (
    (r'\b(ce mois|mois en cours)\b', r'\b(mois dernier|mois passe|mois precedent)\b', 'current_month'),
    (r'\bcette semaine\b', r'\b(semaine derniere|semaine passee)\b', 'current_week'),
    (r'\bcette annee\b', r'\b(annee derniere|annee passee)\b', 'current_year'),
)


def _period_code(n, default, comparing=False):
    if comparing:
        for current, last, code in _CURRENT_AND_LAST:
            if re.search(current, n) and re.search(last, n):
                return code, True
    for pattern, code in _PERIODS:
        if re.search(pattern, n):
            return code, True
    return default, False


def _mentioned_products(user, n):
    """Produits cités dans la demande : cultures et ventes de l'utilisateur, puis produits du marché."""
    from apps.agriculture.models import Crop
    from apps.finances.models import Sale
    from apps.markets.models import Product

    candidates = {}
    for name in Crop.objects.filter(user=user).values_list('name', flat=True):
        candidates.setdefault(normalize_text(name).strip(), name)
    for name in Sale.objects.filter(user=user).exclude(product_name='').values_list('product_name', flat=True).distinct():
        candidates.setdefault(normalize_text(name).strip(), name)
    for name in Product.objects.values_list('name', flat=True):
        candidates.setdefault(normalize_text(name).strip(), name)

    found = []
    for key, name in candidates.items():
        singular = key[:-1] if key.endswith('s') and len(key) > 3 else key
        # « tomates » doit retrouver « Tomate » : on cherche la forme normalisée et sa forme au singulier
        if re.search(rf'\b{re.escape(key)}s?\b', n) or re.search(rf'\b{re.escape(singular)}s?\b', n):
            if name.lower() not in [f.lower() for f in found]:
                found.append(name)
    return found


_STOCK_FILLER = frozenset(
    'combien me il reste restent restant restants t en stock quantite quelle quel de du des d la le les mon mes j ai '
    'a dans mon magasin sac sacs kg kilo kilos tonne tonnes caisse caisses litre litres unite unites'.split())


def detect_analysis_intent(text, user):
    """``{'kind', 'period_code', 'explicit_period', ...}`` pour une demande d'analyse chiffrée, sinon ``None``."""
    n = normalize_text(text)
    if _ADVICE.search(n):
        return None

    def has(pattern):
        return re.search(pattern, n) is not None

    if has(r'\binvest\w*') or (has(r'\bdevrais\b') and has(r'\b(planter|cultiver|semer)\b')):
        return {'kind': 'investment', 'products': _mentioned_products(user, n)}

    if has(r'\bresume\b') or has(r'\bbilan (de la|de cette) semaine\b') or has(r'\bpoint sur (mon|ma|mes)\b'):
        code, explicit = _period_code(n, 'current_week')
        return {'kind': 'activity_summary', 'period_code': code, 'explicit_period': explicit}

    if has(r'\bdepenses?\b') and has(r'\b(augment\w*|hausse|montent?|monter|grimp\w*|flamb\w*|explos\w*|anormal\w*)\b'):
        code, explicit = _period_code(n, 'current_month')
        return {'kind': 'expense_increase', 'period_code': code, 'explicit_period': explicit}

    if has(r'\b(evolution|evolue\w*|tendance\w*|progress\w*)\b'):
        return {'kind': 'trend'}

    if has(r'\b(compar\w*|par rapport|versus|vs|ecarts?)\b'):
        code, explicit = _period_code(n, 'current_month', comparing=True)
        return {'kind': 'comparison', 'period_code': code, 'explicit_period': explicit}

    if has(r'\b(rentable\w*|rentabilite|marges?)\b'):
        return {'kind': 'profitability'}

    if (has(r'\bproduits?\b.*\b(vend\w*|rapport\w*|rentr\w*)\b') or has(r'\bplus d argent\b') or has(r'\bmeilleur\w* (produit|vente|culture)s?\b')
            or has(r'\bse vendent? (le )?(mieux|bien)\b') or has(r'\bplus vendus?\b') or has(r'\bclassement\b')):
        code, explicit = _period_code(n, 'all')
        return {'kind': 'top_products', 'period_code': code, 'explicit_period': explicit}

    if has(r'\b(combien|quelle quantite)\b.*\b(reste\w*|restant\w*|en stock|dispose\w*)\b'):
        query = ' '.join(w for w in n.split() if w not in _STOCK_FILLER)
        if query:
            return {'kind': 'stock_level', 'product_query': query}
        return {'kind': 'stock_outlook'}

    if (has(r'\brupture\w*\b') or has(r'\bstock (bas|faible|critique)\b') or has(r'\b(verifi\w*|etat|point)\b.*\b(stock)s?\b')
            or has(r'\bacheter\b.*\bpriorite\b') or has(r'\b(racheter|reapprovisionner|commander)\b') or has(r'\bmon stock\b')):
        return {'kind': 'stock_outlook'}

    if has(r'\bdepenses?\b'):
        code, explicit = _period_code(n, 'all')
        return {'kind': 'finance', 'focus': 'expenses', 'period_code': code, 'explicit_period': explicit}

    if has(r'\b(gagn\w*|revenus?|recettes?|chiffre d affaires|bilan|solde|benefice\w*|resultat\w*|argent|ventes?|encaisse\w*)\b'):
        code, explicit = _period_code(n, 'all')
        return {'kind': 'finance', 'focus': 'revenue', 'period_code': code, 'explicit_period': explicit}
    return None


# --------------------------------------------------------------------------------------------------------------
# Mise en forme
# --------------------------------------------------------------------------------------------------------------
def fcfa(value):
    return f"{value:,.0f}".replace(',', ' ') + " FCFA"


def number(value):
    return f"{value:,.2f}".rstrip('0').rstrip('.').replace(',', ' ').replace('.', ',')


def pct(value):
    """Pourcentage en français : « 80 % », « 61,9 % »."""
    return (f"{value:.1f}".rstrip('0').rstrip('.') if value is not None else "?").replace('.', ',') + " %"


def signed_pct(value):
    if value is None:
        return "variation non calculable (valeur de référence nulle)"
    text = f"{value:+.1f}".rstrip('0').rstrip('.')
    return text.replace('.', ',') + " %"


def signed_fcfa(value):
    return ("+" if value > 0 else "") + fcfa(value)


_LEVEL_LABEL = {'rupture': "⛔ en rupture", 'critique': "🔴 rupture imminente", 'attention': "🟠 à surveiller",
                'bas': "🟡 stock bas", 'inconnu': "⚪ couverture non calculable", 'ok': "🟢 suffisant"}
_PERIOD_SUGGESTIONS = ["Ce mois-ci", "Le mois dernier", "Depuis le début de la saison"]


def _result(text, suggestions, data):
    return {'text': text, 'suggestions': suggestions, 'data': data}


def _finance_lines(summary):
    lines = [f"• Chiffre d'affaires (ventes) : {fcfa(summary['sales_revenue'])}"]
    if summary['other_income']:
        lines.append(f"• Autres revenus : {fcfa(summary['other_income'])}")
        lines.append(f"• Recettes totales : {fcfa(summary['total_revenue'])}")
    lines.append(f"• Dépenses enregistrées : {fcfa(summary['expenses_total'])}")
    lines.append(f"• Résultat estimé : {fcfa(summary['net_result'])}")
    return lines


_RESULT_NOTE = ("ℹ️ Résultat estimé = recettes − dépenses enregistrées. Ce n'est pas un bénéfice : le stock invendu, "
                "le matériel et les dépenses non saisies ne sont pas comptés.")


# --------------------------------------------------------------------------------------------------------------
# Réponses
# --------------------------------------------------------------------------------------------------------------
def _answer_finance(user, intent, today):
    period = analysis.resolve_period(intent['period_code'], today)
    summary = analysis.financial_summary(user, period)
    if not summary['has_data']:
        return _result(f"Aucune vente ni dépense enregistrée {period.on}.", _PERIOD_SUGGESTIONS, summary)

    lines = [f"📊 **Bilan — {period.label}**", ""] + _finance_lines(summary)
    categories = summary['expenses_by_category']
    if categories and (intent.get('focus') == 'expenses' or summary['expenses_total']):
        lines += ["", "Dépenses par catégorie :"]
        lines += [f"• {c['label']} : {fcfa(c['amount'])} ({pct(c['share_pct'])})" for c in categories[:5]]
    lines += ["", _RESULT_NOTE]
    suggestions = ["Pourquoi mes dépenses augmentent ?", "Quel produit rapporte le plus ?"]
    if not intent.get('explicit_period'):
        suggestions = _PERIOD_SUGGESTIONS[:2] + suggestions[:1]
    return _result("\n".join(lines), suggestions, summary)


def _answer_top_products(user, intent, today):
    period = analysis.resolve_period(intent['period_code'], today)
    data = analysis.product_performance(user, period)
    if not data['products']:
        return _result(f"Aucune vente enregistrée {period.on}.", _PERIOD_SUGGESTIONS, data)
    lines = [f"🏆 **Produits qui rapportent le plus — {period.label}**", ""]
    for rank, p in enumerate(data['products'][:5], 1):
        lines.append(f"{rank}. {p['name']} — {fcfa(p['revenue'])} ({pct(p['share_pct'])} des ventes) · "
                     f"{number(p['quantity'])} vendu(s) · prix moyen {fcfa(p['avg_unit_price'])}")
    lines += ["", "Classement par chiffre d'affaires (ventes), pas par bénéfice : "
                  "dites « produits les plus rentables » pour voir les marges."]
    return _result("\n".join(lines), ["Produits les plus rentables", "Compare ce mois au mois dernier"], data)


def _answer_profitability(user, intent, today):
    data = analysis.crop_profitability(user)
    if not data['crops']:
        return _result("Aucune culture enregistrée : je ne peux pas calculer de marge.", ["Ajouter une culture"], data)
    known = [c for c in data['crops'] if c['status'] == 'ok']
    lines = ["📈 **Rentabilité par culture** (cumul de toutes les campagnes)", ""]
    for rank, c in enumerate(known, 1):
        rate = f", soit {pct(c['margin_rate_pct'])} des ventes" if c['margin_rate_pct'] is not None else ""
        lines.append(f"{rank}. {c['name']} — marge {fcfa(c['margin'])}{rate} "
                     f"(ventes {fcfa(c['revenue'])} − dépenses rattachées {fcfa(c['linked_costs'])})")
    if not known:
        lines.append("Aucune marge significative pour l'instant.")
    waiting = [c for c in data['crops'] if c['status'] == 'no_sales']
    if waiting:
        lines += ["", "Cultures en cours, sans vente pour l'instant (la marge n'a pas encore de sens, ce n'est pas une perte) :"]
        lines += [f"• {c['name']} — {fcfa(c['linked_costs'])} de dépenses rattachées" for c in waiting]
    if data['missing_costs']:
        lines += ["", f"Marge non calculable (aucune dépense rattachée à la culture) : {', '.join(data['missing_costs'])}.",
                  "Rattachez vos dépenses à la culture concernée pour que je puisse la calculer."]
    lines += ["", "ℹ️ La marge ne compte que les dépenses rattachées à la culture ; elle est donc optimiste si certaines "
                  "dépenses ne sont pas saisies."]
    return _result("\n".join(lines), ["Quel produit rapporte le plus ?", "Analyse mes dépenses"], data)


def _answer_expense_increase(user, intent, today):
    period = analysis.resolve_period(intent['period_code'], today)
    data = analysis.expense_drivers(user, period, today)
    if not data['comparable']:
        return _result(data['note'], _PERIOD_SUGGESTIONS, data)
    exp = data['expenses']
    ref = data['reference']['label']
    if not data['previous_has_data']:
        return _result(f"Je n'ai aucune dépense enregistrée pour {ref} : impossible de dire si vos dépenses augmentent. "
                       f"{period.on.capitalize()}, vous avez {fcfa(exp['current'])} de dépenses enregistrées.", ["Analyse mes dépenses"], data)
    if not data['increase']:
        return _result(f"Vos dépenses n'augmentent pas : {fcfa(exp['current'])} {period.on}, contre {fcfa(exp['previous'])} "
                       f"pour {ref} ({signed_pct(exp['delta_pct'])}).", ["Analyse mes dépenses", "Compare ce mois au mois dernier"], data)

    lines = [f"📈 **Vos dépenses ont augmenté** : {fcfa(exp['current'])} {period.on}, contre {fcfa(exp['previous'])} "
             f"pour {ref}, soit {signed_fcfa(exp['delta'])} ({signed_pct(exp['delta_pct'])}).", "", "Ce qui explique la hausse :"]
    for d in data['drivers'][:4]:
        flag = " ⚠️ hausse anormale" if d['anomaly'] else ""
        lines.append(f"• {d['label']} : {signed_fcfa(d['delta'])} ({pct(d['share_of_increase_pct'])} des hausses){flag}")
    if data['offsets']:
        lines.append("Compensée en partie par la baisse de : " + ", ".join(f"{o['label']} ({signed_fcfa(o['delta'])})" for o in data['offsets'][:3]))
    if data['biggest_expenses']:
        lines += ["", "Plus grosses dépenses de la période :"]
        lines += [f"• {b['description']} — {fcfa(b['amount'])} ({b['label']})" for b in data['biggest_expenses']]
    lines += ["", f"ℹ️ Une catégorie est dite anormale si elle atteint {number(analysis.ANOMALY_RATIO)} × sa valeur de référence "
                  f"et augmente d'au moins {fcfa(analysis.ANOMALY_MIN_INCREASE)}."]
    return _result("\n".join(lines), ["Analyse mes dépenses", "Quel produit rapporte le plus ?"], data)


def _answer_comparison(user, intent, today):
    period = analysis.resolve_period(intent['period_code'], today)
    data = analysis.compare_periods(user, period, today)
    if not data['comparable']:
        return _result(data['note'], _PERIOD_SUGGESTIONS, data)
    if not data['current']['has_data'] and not data['previous_has_data']:
        return _result(f"Aucune donnée enregistrée {period.on} ni pour {data['reference']['label']}.", _PERIOD_SUGGESTIONS, data)

    def row(label, d):
        return f"• {label} : {fcfa(d['current'])} contre {fcfa(d['previous'])} ({signed_fcfa(d['delta'])}, {signed_pct(d['delta_pct'])})"

    lines = [f"⚖️ **{period.label[:1].upper()}{period.label[1:]} comparé à {data['reference']['label']}**", "",
             row("Recettes", data['revenue']), row("Dépenses", data['expenses']), row("Résultat estimé", data['net_result']), "",
             _RESULT_NOTE]
    return _result("\n".join(lines), ["Pourquoi mes dépenses augmentent ?", "Quel produit rapporte le plus ?"], data)


def _answer_trend(user, intent, today):
    data = analysis.monthly_trend(user, 6, today)
    if not data['has_data']:
        return _result("Aucune vente ni dépense enregistrée sur les 6 derniers mois.", ["Enregistrer une dépense"], data)
    lines = ["📉 **Évolution mois par mois**", ""]
    for m in data['months']:
        partial = " (en cours)" if m['partial'] else ""
        lines.append(f"• {m['label']}{partial} : recettes {fcfa(m['revenue'])} · dépenses {fcfa(m['expenses'])} · résultat {fcfa(m['net_result'])}")
    lines += ["", "ℹ️ " + data['note']]
    return _result("\n".join(lines), ["Compare ce mois au mois dernier", "Pourquoi mes dépenses augmentent ?"], data)


def _stock_line(item):
    cover = f" · environ {number(item['cover_days'])} jour(s) de ventes" if item['cover_days'] is not None else ""
    return f"• {item['name']} : {number(item['quantity'])} {item['unit']} — {_LEVEL_LABEL[item['level']]}{cover}"


def _answer_stock_outlook(user, intent, today):
    data = analysis.stock_outlook(user, today)
    if not data['items']:
        return _result("Aucun article en stock enregistré.", ["J'ai reçu 20 sacs de mil en stock"], data)
    if data['priorities']:
        lines = ["📦 **Stocks à surveiller ou à racheter en priorité**", ""] + [_stock_line(i) for i in data['priorities']]
        others = len(data['items']) - len(data['priorities'])
        if others:
            lines += ["", f"{others} autre(s) article(s) sans risque identifié."]
    else:
        unknown = [i for i in data['items'] if i['level'] == 'inconnu']
        lines = ["📦 **Aucun stock bas ni rupture imminente détectée**", ""] + [_stock_line(i) for i in data['items'][:8]]
        if unknown:
            lines += ["", f"La couverture en jours n'est pas calculable pour {len(unknown)} article(s) : "
                          f"aucune vente sur les {data['window_days']} derniers jours."]
    lines += ["", "ℹ️ " + data['assumption']]
    return _result("\n".join(lines), ["Historique des mouvements de stock", "Mes rappels"], data)


def _answer_stock_level(user, intent, today):
    data = analysis.stock_level(user, intent['product_query'], today)
    if not data['items']:
        return _result(f"Je ne trouve aucun article « {intent['product_query']} » dans votre stock.",
                       ["Vérifie mon stock"], data)
    lines = ["📦 **Votre stock**", ""] + [_stock_line(i) for i in data['items']]
    return _result("\n".join(lines), ["Historique des mouvements de stock", "Vérifie mon stock"], data)


def _answer_activity_summary(user, intent, today):
    period = analysis.resolve_period(intent['period_code'], today)
    data = analysis.activity_summary(user, period, today)
    finance = data['finance']
    lines = [f"🗓️ **Résumé de votre activité — {period.label}**", ""]
    if finance['has_data']:
        lines += _finance_lines(finance)
    else:
        lines.append("• Aucune vente ni dépense enregistrée sur la période.")
    if data['top_products']:
        lines += ["", "Meilleurs produits : " + " · ".join(f"{p['name']} ({fcfa(p['revenue'])})" for p in data['top_products'])]
    acts = data['activities']
    lines += ["", f"Travaux enregistrés : {acts['count']}" + (
        " (" + ", ".join(f"{a['type']} sur {a['crop']}" for a in acts['recent'][:3]) + ")" if acts['recent'] else "")]
    harv = data['harvests']
    lines.append(f"Récoltes enregistrées : {harv['count']}" + (
        " (" + ", ".join(f"{number(h['quantity'])} {h['unit']} de {h['crop']}" for h in harv['recent'][:3]) + ")" if harv['recent'] else ""))
    if data['stock_priorities']:
        lines += ["", "Stocks à surveiller : " + " · ".join(f"{i['name']} ({number(i['quantity'])} {i['unit']})" for i in data['stock_priorities'])]
    if data['upcoming_reminders']:
        lines += ["", "Prochains rappels : " + " · ".join(
            f"{r['message']} ({timezone.localtime(datetime.datetime.fromisoformat(r['when'])).strftime('%d/%m à %H:%M')})"
            for r in data['upcoming_reminders'])]
    if finance['has_data']:
        lines += ["", _RESULT_NOTE]
    return _result("\n".join(lines), ["Compare cette semaine à la semaine dernière", "Vérifie mon stock"], data)


def _answer_investment(user, intent, today):
    names = intent['products']
    if not names:
        return _result("Dites-moi quels produits comparer, par exemple : « Dois-je investir dans les tomates ou les oignons ? ». "
                       "Je m'appuie sur vos résultats passés pour chacun.", ["Quel produit rapporte le plus ?", "Produits les plus rentables"],
                       {'products': []})
    data = analysis.crop_comparison(user, names[:3])
    lines = ["🌱 **Comparaison de vos produits** (à partir de vos propres résultats)", ""]
    for p in data['products']:
        lines.append(f"**{p['name']}**")
        history = p['history']
        if history:
            margin = (f"marge {fcfa(history['margin'])}" if history['margin'] is not None
                      else "aucune vente pour l'instant" if history['status'] == 'no_sales' else "marge non calculable")
            lines.append(f"• Résultats passés : ventes {fcfa(history['revenue'])} · {margin}")
        if p['yield_per_ha']:
            lines.append(f"• Rendement observé : {number(p['yield_per_ha'])} par hectare")
        if p['cost_per_ha'] is not None:
            lines.append(f"• Dépenses rattachées : {fcfa(p['cost_per_ha'])} par hectare")
        if p['own_prices']:
            op = p['own_prices']
            lines.append(f"• Vos prix de vente : de {fcfa(op['min'])} à {fcfa(op['max'])} (moyenne {fcfa(op['avg'])})")
        if p['market_price']:
            mp = p['market_price']
            lines.append(f"• Prix de marché relevé le {mp['date']} : {fcfa(mp['avg'])} en moyenne ({mp['markets']} marché(s))")
        if p['scenarios']:
            for label, s in p['scenarios'].items():
                margin = f", marge {fcfa(s['margin_per_ha'])}" if s['margin_per_ha'] is not None else ""
                lines.append(f"• Scénario {label} (1 ha, prix {fcfa(s['unit_price'])}) : recettes {fcfa(s['revenue_per_ha'])}{margin}")
        if p['missing']:
            lines.append(f"• Pour mieux comparer, il manque : {', '.join(p['missing'])}.")
        lines.append("")
    lines.append("⚠️ " + data['limits'])
    return _result("\n".join(lines), ["Produits les plus rentables", "Vérifie mon stock"], data)


_HANDLERS = {
    'finance': _answer_finance,
    'top_products': _answer_top_products,
    'profitability': _answer_profitability,
    'expense_increase': _answer_expense_increase,
    'comparison': _answer_comparison,
    'trend': _answer_trend,
    'stock_outlook': _answer_stock_outlook,
    'stock_level': _answer_stock_level,
    'activity_summary': _answer_activity_summary,
    'investment': _answer_investment,
}


def answer_analysis(user, intent, today=None):
    """Réponse ``{'text', 'suggestions', 'data'}`` à une demande reconnue par ``detect_analysis_intent``."""
    return _HANDLERS[intent['kind']](user, intent, today or timezone.localdate())
