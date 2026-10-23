"""
Moteur d'analyses métier DÉTERMINISTE de Naatal IA (cahier des charges §4.B, §4.D, §8).

Tout chiffre présenté à l'agriculteur est calculé ici, à partir de SES enregistrements, jamais estimé par le modèle
de langage. Chaque résultat indique sa période, ses hypothèses et ce qui manque pour aller plus loin.

Vocabulaire (à ne jamais confondre) :
- chiffre d'affaires  = ventes enregistrées (quantité × prix) ;
- recettes            = chiffre d'affaires + autres revenus enregistrés ;
- résultat estimé     = recettes − dépenses enregistrées. C'est un solde de trésorerie estimé, PAS un bénéfice :
                        il ignore les stocks invendus, l'amortissement du matériel et les dépenses non saisies ;
- marge d'une culture = ventes de la culture − dépenses rattachées à cette culture, uniquement si des dépenses lui
                        sont rattachées (sinon elle n'est pas calculable et on le dit).
"""
import calendar
import datetime
from dataclasses import dataclass

from django.conf import settings
from django.db.models import Count, ExpressionWrapper, F, FloatField, Q, Sum
from django.db.models.functions import TruncMonth
from django.utils import timezone

from apps.finances.categories import category_label, normalize_text

# Seuils des alertes : hypothèses de travail, réglables dans les paramètres Django (ANALYSIS_*, voir base.py)
ANOMALY_RATIO = getattr(settings, 'ANALYSIS_ANOMALY_RATIO', 1.5)  # catégorie « en hausse anormale » si >= 1,5 × sa référence…
ANOMALY_MIN_INCREASE = getattr(settings, 'ANALYSIS_ANOMALY_MIN_INCREASE', 10_000)  # …ET si elle augmente d'au moins 10 000 FCFA
STOCK_CRITICAL_DAYS = getattr(settings, 'ANALYSIS_STOCK_CRITICAL_DAYS', 7)  # moins de 7 jours de ventes en stock : rupture imminente
STOCK_WARNING_DAYS = getattr(settings, 'ANALYSIS_STOCK_WARNING_DAYS', 14)   # moins de 14 jours : à surveiller
SEASON_DAYS = getattr(settings, 'ANALYSIS_SEASON_DAYS', 120)                # hypothèse : une saison agricole = 4 mois glissants
STOCK_SALES_WINDOW_DAYS = 30   # fenêtre de calcul du rythme de vente
LOW_STOCK_QUANTITY = 5         # seuil historique de l'application quand le rythme de vente est inconnu

REVENUE = ExpressionWrapper(F('quantity_sold') * F('price_per_unit'), output_field=FloatField())

_MONTHS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre',
           'novembre', 'décembre']


def _round(value):
    return round(float(value or 0.0), 2)


def _pct(part, whole):
    return round(part / whole * 100, 1) if whole else None


# --------------------------------------------------------------------------------------------------------------
# Périodes
# --------------------------------------------------------------------------------------------------------------
@dataclass(frozen=True)
class Period:
    code: str
    label: str
    start: datetime.date | None
    end: datetime.date | None

    @property
    def on(self):
        """Tournure utilisable après un verbe ou un montant : « sur cette semaine », « depuis le début… »."""
        return f"sur {self.label}" if self.code in ('season', 'last_30_days') else self.label

    @property
    def days(self):
        return (self.end - self.start).days + 1 if self.start and self.end else None

    def as_dict(self):
        return {'code': self.code, 'label': self.label,
                'start': self.start.isoformat() if self.start else None,
                'end': self.end.isoformat() if self.end else None}


PERIOD_ALIASES = {
    'all': 'all', 'tout': 'all',
    'current_week': 'current_week', 'week': 'current_week', 'cette_semaine': 'current_week',
    'last_week': 'last_week', 'semaine_derniere': 'last_week',
    'current_month': 'current_month', 'month': 'current_month', 'ce_mois_ci': 'current_month',
    'last_month': 'last_month', 'mois_dernier': 'last_month',
    'current_year': 'current_year', 'year': 'current_year', 'cette_annee': 'current_year',
    'season': 'season', 'saison': 'season',
    'last_30_days': 'last_30_days',
}


def _fmt(day):
    return day.strftime('%d/%m/%Y')


def _span(start, end):
    return f"du {_fmt(start)} au {_fmt(end)}"


def resolve_period(code, today=None):
    """``Period`` correspondant à un code (ou alias) ; un code inconnu donne la période « tout »."""
    today = today or timezone.localdate()
    code = PERIOD_ALIASES.get(str(code or 'all').strip().lower(), 'all')

    if code == 'current_week':
        start = today - datetime.timedelta(days=today.weekday())
        return Period(code, f"cette semaine ({_span(start, today)})", start, today)
    if code == 'last_week':
        start = today - datetime.timedelta(days=today.weekday() + 7)
        end = start + datetime.timedelta(days=6)
        return Period(code, f"la semaine dernière ({_span(start, end)})", start, end)
    if code == 'current_month':
        start = today.replace(day=1)
        return Period(code, f"ce mois-ci ({_span(start, today)})", start, today)
    if code == 'last_month':
        end = today.replace(day=1) - datetime.timedelta(days=1)
        return Period(code, f"le mois dernier ({_MONTHS[end.month - 1]} {end.year})", end.replace(day=1), end)
    if code == 'current_year':
        start = today.replace(month=1, day=1)
        return Period(code, f"cette année ({_span(start, today)})", start, today)
    if code == 'season':
        start = today - datetime.timedelta(days=SEASON_DAYS - 1)
        return Period(code, f"la saison (hypothèse : {SEASON_DAYS} derniers jours, {_span(start, today)})", start, today)
    if code == 'last_30_days':
        start = today - datetime.timedelta(days=29)
        return Period(code, f"les 30 derniers jours ({_span(start, today)})", start, today)
    return Period('all', "depuis le début de vos enregistrements", None, None)


def previous_period(period, today=None):
    """
    Période de référence de même durée pour comparer (mois en cours -> mêmes jours du mois précédent, etc.),
    ou ``None`` pour « tout ». Comparer deux durées différentes fausserait l'écart.
    """
    today = today or timezone.localdate()
    if period.code == 'current_week':
        start = period.start - datetime.timedelta(days=7)
        return Period('previous_week', f"la semaine précédente, mêmes jours ({_span(start, start + datetime.timedelta(days=period.days - 1))})",
                      start, start + datetime.timedelta(days=period.days - 1))
    if period.code == 'last_week':
        start = period.start - datetime.timedelta(days=7)
        return Period('previous_week', f"la semaine d'avant ({_span(start, start + datetime.timedelta(days=6))})",
                      start, start + datetime.timedelta(days=6))
    if period.code in ('current_month', 'last_month'):
        last_of_previous = period.start - datetime.timedelta(days=1)
        start = last_of_previous.replace(day=1)
        if period.code == 'current_month':
            end = start.replace(day=min(period.end.day, calendar.monthrange(start.year, start.month)[1]))
            label = f"le mois précédent, mêmes {period.end.day} premiers jours ({_span(start, end)})"
        else:
            end = last_of_previous
            label = f"le mois d'avant ({_MONTHS[end.month - 1]} {end.year})"
        return Period('previous_month', label, start, end)
    if period.code == 'current_year':
        start = period.start.replace(year=period.start.year - 1)
        try:
            end = period.end.replace(year=period.end.year - 1)
        except ValueError:  # 29 février
            end = period.end.replace(year=period.end.year - 1, day=28)
        return Period('previous_year', f"l'année précédente, même période ({_span(start, end)})", start, end)
    if period.code in ('season', 'last_30_days'):
        end = period.start - datetime.timedelta(days=1)
        start = end - datetime.timedelta(days=period.days - 1)
        return Period('previous_window', f"la période précédente de même durée ({_span(start, end)})", start, end)
    return None


# --------------------------------------------------------------------------------------------------------------
# Accès aux données (toujours filtrées par utilisateur)
# --------------------------------------------------------------------------------------------------------------
def _sales(user, period=None):
    from apps.finances.models import Sale
    queryset = Sale.objects.filter(Q(user=user) | Q(crop__user=user))
    if period and period.start:
        queryset = queryset.filter(date__gte=period.start, date__lte=period.end)
    return queryset


def _transactions(user, kind, period=None):
    from apps.finances.models import Transaction
    queryset = Transaction.objects.filter(user=user, transaction_type=kind)
    if period and period.start:
        queryset = queryset.filter(date__gte=period.start, date__lte=period.end)
    return queryset


def _product_name(sale):
    return (sale.crop.name if sale.crop else sale.product_name) or 'Produit'


# --------------------------------------------------------------------------------------------------------------
# Bilan financier
# --------------------------------------------------------------------------------------------------------------
DEFINITIONS = {
    'chiffre_affaires': "ventes enregistrées (quantité × prix)",
    'recettes': "chiffre d'affaires + autres revenus enregistrés",
    'resultat_estime': "recettes − dépenses enregistrées ; ce n'est pas un bénéfice (stocks invendus, matériel et "
                       "dépenses non saisies ne sont pas pris en compte)",
}


def financial_summary(user, period):
    """Bilan d'une période : chiffre d'affaires, recettes, dépenses par catégorie et résultat estimé."""
    sales = _sales(user, period)
    sales_revenue = _round(sales.aggregate(total=Sum(REVENUE))['total'])
    other_income = _round(_transactions(user, 'income', period).filter(sale__isnull=True).aggregate(t=Sum('amount'))['t'])
    expenses = _transactions(user, 'expense', period)
    expenses_total = _round(expenses.aggregate(t=Sum('amount'))['t'])

    by_category = {}
    for row in expenses.values('category').annotate(total=Sum('amount'), n=Count('id')):
        code = row['category'] or 'autre'  # les anciennes dépenses sans catégorie sont classées « autre »
        entry = by_category.setdefault(code, {'category': code, 'label': category_label(code), 'amount': 0.0, 'count': 0})
        entry['amount'] = _round(entry['amount'] + float(row['total'] or 0))
        entry['count'] += row['n']
    categories = sorted(by_category.values(), key=lambda e: -e['amount'])
    for entry in categories:
        entry['share_pct'] = _pct(entry['amount'], expenses_total)

    total_revenue = _round(sales_revenue + other_income)
    return {
        'period': period.as_dict(),
        'sales_revenue': sales_revenue,
        'other_income': other_income,
        'total_revenue': total_revenue,
        'expenses_total': expenses_total,
        'net_result': _round(total_revenue - expenses_total),
        'sales_count': sales.count(),
        'expenses_count': expenses.count(),
        'expenses_by_category': categories,
        'has_data': bool(sales_revenue or other_income or expenses_total),
        'definitions': DEFINITIONS,
    }


def _delta(current, previous):
    delta = _round(current - previous)
    return {'current': _round(current), 'previous': _round(previous), 'delta': delta,
            'delta_pct': round(delta / previous * 100, 1) if previous else None}


def compare_periods(user, period, today=None):
    """Compare une période à la période de référence de même durée (écarts absolus et en %)."""
    reference = previous_period(period, today)
    current = financial_summary(user, period)
    if reference is None:
        return {'period': period.as_dict(), 'reference': None, 'current': current, 'previous': None,
                'comparable': False, 'note': "Aucune période de référence pour « tout » : choisissez une durée précise."}
    previous = financial_summary(user, reference)

    categories = {}
    for source, key in ((current, 'current'), (previous, 'previous')):
        for entry in source['expenses_by_category']:
            categories.setdefault(entry['category'], {'category': entry['category'], 'label': entry['label'],
                                                      'current': 0.0, 'previous': 0.0})[key] = entry['amount']
    category_deltas = []
    for entry in categories.values():
        item = {**entry, **{k: v for k, v in _delta(entry['current'], entry['previous']).items() if k in ('delta', 'delta_pct')}}
        item['anomaly'] = bool(
            item['delta'] >= ANOMALY_MIN_INCREASE
            and (entry['previous'] == 0 or entry['current'] >= ANOMALY_RATIO * entry['previous'])
        )
        category_deltas.append(item)
    category_deltas.sort(key=lambda e: -e['delta'])

    return {
        'period': period.as_dict(),
        'reference': reference.as_dict(),
        'comparable': True,
        'current': current,
        'previous': previous,
        'revenue': _delta(current['total_revenue'], previous['total_revenue']),
        'sales_revenue': _delta(current['sales_revenue'], previous['sales_revenue']),
        'expenses': _delta(current['expenses_total'], previous['expenses_total']),
        'net_result': _delta(current['net_result'], previous['net_result']),
        'expense_categories': category_deltas,
        'previous_has_data': previous['has_data'],
    }


def expense_drivers(user, period, today=None):
    """
    Explique l'évolution des dépenses : quelles catégories expliquent la hausse, lesquelles sont anormales
    (>= 1,5 × la référence et +10 000 FCFA), et les plus grosses dépenses de la période.
    """
    comparison = compare_periods(user, period, today)
    top = list(_transactions(user, 'expense', period).order_by('-amount')[:3])
    biggest = [{'description': t.description, 'amount': _round(t.amount), 'date': t.date.isoformat(),
                'category': t.category or 'autre', 'label': category_label(t.category or 'autre')} for t in top]
    if not comparison['comparable']:
        return {**comparison, 'increase': None, 'drivers': [], 'offsets': [], 'biggest_expenses': biggest}

    total_delta = comparison['expenses']['delta']
    drivers, offsets = [], []
    if total_delta > 0:
        gross_increase = sum(e['delta'] for e in comparison['expense_categories'] if e['delta'] > 0)
        for entry in comparison['expense_categories']:
            if entry['delta'] > 0:
                # Part parmi les seules hausses (la somme fait 100 %), même si d'autres catégories baissent
                drivers.append({**entry, 'share_of_increase_pct': _pct(entry['delta'], gross_increase)})
            elif entry['delta'] < 0:
                offsets.append(entry)
    return {**comparison, 'increase': total_delta > 0, 'drivers': drivers, 'offsets': offsets, 'biggest_expenses': biggest}


# --------------------------------------------------------------------------------------------------------------
# Produits et cultures
# --------------------------------------------------------------------------------------------------------------
def product_performance(user, period):
    """Ventes par produit sur la période : quantité, chiffre d'affaires, prix moyen / min / max, part du total."""
    grouped = {}
    for sale in _sales(user, period).select_related('crop'):
        name = _product_name(sale)
        entry = grouped.setdefault(normalize_text(name), {
            'name': name, 'quantity': 0.0, 'revenue': 0.0, 'sales_count': 0, 'prices': []})
        entry['quantity'] += float(sale.quantity_sold)
        entry['revenue'] += sale.total_revenue
        entry['sales_count'] += 1
        entry['prices'].append(float(sale.price_per_unit))

    total = sum(e['revenue'] for e in grouped.values())
    products = []
    for entry in grouped.values():
        prices = entry.pop('prices')
        products.append({
            **entry,
            'quantity': round(entry['quantity'], 2),
            'revenue': _round(entry['revenue']),
            'avg_unit_price': _round(entry['revenue'] / entry['quantity']) if entry['quantity'] else None,
            'min_unit_price': _round(min(prices)),
            'max_unit_price': _round(max(prices)),
            'share_pct': _pct(entry['revenue'], total),
        })
    products.sort(key=lambda e: -e['revenue'])
    return {'period': period.as_dict(), 'total_revenue': _round(total), 'products': products}


def crop_profitability(user):
    """
    Rentabilité cumulée par culture (toutes les campagnes enregistrées) : ventes − dépenses rattachées à la culture.
    La marge n'est calculée que si des dépenses sont rattachées ; sinon la culture est listée dans ``missing_costs``.
    """
    from apps.agriculture.models import Crop, Harvest
    from apps.finances.models import Transaction

    crops_by_name = {}
    for crop in Crop.objects.filter(user=user):
        crops_by_name.setdefault(normalize_text(crop.name), []).append(crop)

    sales_by_crop_id = {row['crop']: row['t'] for row in
                        _sales(user).filter(crop__isnull=False).values('crop').annotate(t=Sum(REVENUE))}
    orphan_sales = {}
    for sale in _sales(user).filter(crop__isnull=True):
        key = normalize_text(sale.product_name or '')
        orphan_sales[key] = orphan_sales.get(key, 0.0) + sale.total_revenue
    costs_by_crop_id = {row['crop']: row['t'] for row in
                        Transaction.objects.filter(user=user, transaction_type='expense', crop__isnull=False)
                        .values('crop').annotate(t=Sum('amount'))}
    harvest_by_crop_id = {row['crop']: row['q'] for row in
                          Harvest.objects.filter(user=user).values('crop').annotate(q=Sum('quantity'))}

    results, missing = [], []
    for key, crops in crops_by_name.items():
        revenue = sum(float(sales_by_crop_id.get(c.pk) or 0) for c in crops) + orphan_sales.get(key, 0.0)
        costs = sum(float(costs_by_crop_id.get(c.pk) or 0) for c in crops)
        area = sum(c.area_size or 0 for c in crops)
        harvest = sum(float(harvest_by_crop_id.get(c.pk) or 0) for c in crops)
        costs_known = costs > 0
        # « no_sales » : culture en cours, dépenses engagées mais rien de vendu -> ce n'est pas une perte, la marge
        # n'est simplement pas encore significative
        status = 'no_costs' if not costs_known else ('no_sales' if revenue <= 0 else 'ok')
        margin = _round(revenue - costs) if status == 'ok' else None
        entry = {
            'name': crops[0].name, 'campaigns': len(crops), 'area_ha': round(area, 2),
            'revenue': _round(revenue), 'linked_costs': _round(costs), 'costs_known': costs_known,
            'status': status,
            'margin': margin, 'margin_rate_pct': _pct(margin, revenue) if status == 'ok' else None,
            'harvested_quantity': round(harvest, 2),
        }
        results.append(entry)
        if status == 'no_costs':
            missing.append(crops[0].name)
    results.sort(key=lambda e: (e['status'] != 'ok', -(e['margin'] or 0), -e['revenue']))
    return {'crops': results, 'missing_costs': missing,
            'awaiting_sales': [c['name'] for c in results if c['status'] == 'no_sales'],
            'assumption': "Ventes et dépenses cumulées sur toutes les campagnes de la culture ; seules les dépenses "
                          "rattachées à la culture sont comptées."}


# --------------------------------------------------------------------------------------------------------------
# Évolution
# --------------------------------------------------------------------------------------------------------------
def monthly_trend(user, months=6, today=None):
    """Série mensuelle (chiffre d'affaires, dépenses, résultat) sur les ``months`` derniers mois, mois en cours inclus."""
    today = today or timezone.localdate()
    cursor = today.replace(day=1)
    keys = []
    for _ in range(months):
        keys.append((cursor.year, cursor.month))
        cursor = (cursor - datetime.timedelta(days=1)).replace(day=1)
    keys.reverse()
    start = datetime.date(keys[0][0], keys[0][1], 1)

    def monthly(queryset, expression):
        rows = queryset.filter(date__gte=start, date__lte=today).annotate(m=TruncMonth('date')) \
            .values('m').annotate(total=expression)
        return {(r['m'].year, r['m'].month): float(r['total'] or 0) for r in rows}

    revenue = monthly(_sales(user), Sum(REVENUE))
    other = monthly(_transactions(user, 'income').filter(sale__isnull=True), Sum('amount'))
    expenses = monthly(_transactions(user, 'expense'), Sum('amount'))

    series = []
    for year, month in keys:
        rev = _round(revenue.get((year, month), 0) + other.get((year, month), 0))
        exp = _round(expenses.get((year, month), 0))
        series.append({'month': f"{year}-{month:02d}", 'label': f"{_MONTHS[month - 1]} {year}",
                       'revenue': rev, 'expenses': exp, 'net_result': _round(rev - exp),
                       'partial': (year, month) == (today.year, today.month)})
    return {'months': series, 'has_data': any(m['revenue'] or m['expenses'] for m in series),
            'note': "Le mois en cours est partiel : ne le comparez pas à un mois complet."}


# --------------------------------------------------------------------------------------------------------------
# Stocks
# --------------------------------------------------------------------------------------------------------------
_LEVEL_ORDER = {'rupture': 0, 'critique': 1, 'attention': 2, 'bas': 3, 'inconnu': 4, 'ok': 5}


def stock_outlook(user, today=None):
    """
    État de chaque article et risque de rupture, d'après le rythme de vente des 30 derniers jours.

    Hypothèse : les ventes sont exprimées dans la même unité que le stock. Sans vente récente, la couverture n'est
    pas calculable (niveau « inconnu », ou « bas » sous le seuil historique de 5).
    """
    from apps.inventory.models import StockItem
    today = today or timezone.localdate()
    window_start = today - datetime.timedelta(days=STOCK_SALES_WINDOW_DAYS - 1)
    sold = {}
    for sale in _sales(user).filter(date__gte=window_start, date__lte=today).select_related('crop'):
        key = normalize_text(_product_name(sale))
        sold[key] = sold.get(key, 0.0) + float(sale.quantity_sold)

    items = []
    for item in StockItem.objects.filter(user=user):
        daily = sold.get(normalize_text(item.name), 0.0) / STOCK_SALES_WINDOW_DAYS
        cover = round(item.quantity / daily, 1) if daily > 0 else None
        if item.quantity <= 0:
            level = 'rupture'
        elif cover is not None and cover <= STOCK_CRITICAL_DAYS:
            level = 'critique'
        elif cover is not None and cover <= STOCK_WARNING_DAYS:
            level = 'attention'
        elif cover is None and item.quantity <= LOW_STOCK_QUANTITY:
            level = 'bas'
        elif cover is None:
            level = 'inconnu'
        else:
            level = 'ok'
        items.append({'name': item.name, 'quantity': item.quantity, 'unit': item.unit, 'level': level,
                      'daily_sales': round(daily, 2), 'cover_days': cover})
    items.sort(key=lambda e: (_LEVEL_ORDER[e['level']], e['cover_days'] if e['cover_days'] is not None else 1e9, e['name']))
    return {
        'items': items,
        'priorities': [e for e in items if e['level'] in ('rupture', 'critique', 'attention', 'bas')],
        'window_days': STOCK_SALES_WINDOW_DAYS,
        'assumption': f"Rythme de vente calculé sur les {STOCK_SALES_WINDOW_DAYS} derniers jours, ventes et stock supposés "
                      "dans la même unité.",
    }


def stock_level(user, query, today=None):
    """Articles dont le nom contient tous les mots de ``query`` (avec leur couverture en jours de vente)."""
    words = [w for w in normalize_text(query).split() if len(w) >= 3]
    outlook = stock_outlook(user, today)
    matches = [i for i in outlook['items'] if words and all(w in normalize_text(i['name']) for w in words)]
    return {'query': query, 'items': matches, 'assumption': outlook['assumption']}


# --------------------------------------------------------------------------------------------------------------
# Résumé d'activité
# --------------------------------------------------------------------------------------------------------------
def activity_summary(user, period, today=None):
    """Résumé d'une période : bilan, meilleurs produits, travaux réalisés, récoltes, stocks à surveiller, rappels."""
    from apps.agriculture.models import Activity, Harvest
    from apps.notifications.services import pending_reminders

    finance = financial_summary(user, period)
    products = product_performance(user, period)['products'][:3]

    activities = Activity.objects.filter(crop__user=user)
    harvests = Harvest.objects.filter(user=user)
    if period.start:
        activities = activities.filter(date__gte=period.start, date__lte=period.end)
        harvests = harvests.filter(date__gte=period.start, date__lte=period.end)
    work = [{'crop': a.crop.name, 'type': a.activity_type, 'date': a.date.isoformat()}
            for a in activities.select_related('crop').order_by('-date')[:5]]
    harvested = [{'crop': h.crop.name, 'quantity': h.quantity, 'unit': h.unit, 'date': h.date.isoformat()}
                 for h in harvests.select_related('crop').order_by('-date')[:5]]

    return {
        'period': period.as_dict(),
        'finance': finance,
        'top_products': products,
        'activities': {'count': activities.count(), 'recent': work},
        'harvests': {'count': harvests.count(), 'recent': harvested},
        'stock_priorities': stock_outlook(user, today)['priorities'][:3],
        'upcoming_reminders': [{'message': r.message, 'when': r.scheduled_for.isoformat()}
                               for r in pending_reminders(user)[:3]],
    }


# --------------------------------------------------------------------------------------------------------------
# Comparaison de cultures pour un investissement
# --------------------------------------------------------------------------------------------------------------
INVESTMENT_LIMITS = (
    "Je ne tiens pas compte des variations de prix à venir, du climat, des maladies, de la demande ni des coûts "
    "de transport et de commercialisation. Ces scénarios reprennent seulement vos résultats passés et les prix observés : "
    "ils ne garantissent ni rendement ni bénéfice."
)


def _market_prices(product_name):
    from apps.markets.models import Price
    latest = Price.objects.filter(product_name__iexact=product_name).order_by('-date').first()
    if latest is None:
        return None
    same_day = Price.objects.filter(product_name__iexact=product_name, date=latest.date)
    prices = [float(p.price) for p in same_day]
    return {'date': latest.date.isoformat(), 'avg': _round(sum(prices) / len(prices)),
            'min': _round(min(prices)), 'max': _round(max(prices)), 'markets': len(prices)}


def crop_comparison(user, names):
    """
    Pour chaque produit : résultats passés (ventes, coûts rattachés, rendement par hectare), prix observés (vos ventes,
    marché) et trois scénarios prudent / intermédiaire / favorable par hectare. Les scénarios n'existent que si le
    rendement, la surface et les coûts sont connus ; sinon la liste ``missing`` dit quoi renseigner.
    """
    profitability = {normalize_text(c['name']): c for c in crop_profitability(user)['crops']}
    comparison = []
    for name in names:
        key = normalize_text(name)
        crop = profitability.get(key)
        sales = [s for s in _sales(user).select_related('crop') if normalize_text(_product_name(s)) == key]
        own_prices = [float(s.price_per_unit) for s in sales]
        market = _market_prices(name)
        observed = own_prices + ([market['avg']] if market else [])

        yield_per_ha = cost_per_ha = None
        if crop and crop['area_ha'] > 0:
            if crop['harvested_quantity'] > 0:
                yield_per_ha = round(crop['harvested_quantity'] / crop['area_ha'], 2)
            if crop['costs_known']:
                cost_per_ha = _round(crop['linked_costs'] / crop['area_ha'])

        missing = []
        if not crop:
            missing.append("aucune culture enregistrée pour ce produit")
        else:
            if crop['area_ha'] <= 0:
                missing.append("surface cultivée")
            if crop['harvested_quantity'] <= 0:
                missing.append("quantités récoltées")
            if not crop['costs_known']:
                missing.append("dépenses rattachées à la culture")
        if not observed:
            missing.append("prix de vente ou prix de marché")

        scenarios = None
        if yield_per_ha and observed:
            scenarios = {}
            for label, price in (('prudent', min(observed)), ('intermédiaire', sum(observed) / len(observed)),
                                 ('favorable', max(observed))):
                revenue = yield_per_ha * price
                scenarios[label] = {'unit_price': _round(price), 'revenue_per_ha': _round(revenue),
                                    'margin_per_ha': _round(revenue - cost_per_ha) if cost_per_ha is not None else None}

        comparison.append({
            'name': crop['name'] if crop else name.capitalize(),
            'history': crop,
            'sales_count': len(sales),
            'own_prices': {'min': _round(min(own_prices)), 'avg': _round(sum(own_prices) / len(own_prices)),
                           'max': _round(max(own_prices))} if own_prices else None,
            'market_price': market,
            'yield_per_ha': yield_per_ha,
            'cost_per_ha': cost_per_ha,
            'scenarios': scenarios,
            'missing': missing,
        })
    return {'products': comparison, 'limits': INVESTMENT_LIMITS}


# --------------------------------------------------------------------------------------------------------------
# Synthèse pour le modèle de langage (questions ouvertes)
# --------------------------------------------------------------------------------------------------------------
def context_digest(user, today=None):
    """
    Synthèse CHIFFRÉE ET CERTIFIÉE transmise au modèle pour les questions ouvertes : il ne doit rien recalculer ni
    inventer. Volontairement compacte (données minimales envoyées au fournisseur d'IA).
    """
    today = today or timezone.localdate()
    month = resolve_period('current_month', today)
    comparison = compare_periods(user, month, today)
    digest = {
        'definitions': DEFINITIONS,
        'ce_mois': {
            'periode': month.label,
            'recettes_fcfa': comparison['current']['total_revenue'],
            'depenses_fcfa': comparison['current']['expenses_total'],
            'resultat_estime_fcfa': comparison['current']['net_result'],
            'depenses_par_categorie': [{'categorie': c['label'], 'fcfa': c['amount']}
                                       for c in comparison['current']['expenses_by_category'][:5]],
        },
        'top_produits_depuis_le_debut': [{'produit': p['name'], 'ca_fcfa': p['revenue'], 'quantite': p['quantity']}
                                         for p in product_performance(user, resolve_period('all'))['products'][:5]],
        'stocks_a_surveiller': [{'produit': i['name'], 'quantite': i['quantity'], 'unite': i['unit'],
                                 'niveau': i['level'], 'jours_de_couverture': i['cover_days']}
                                for i in stock_outlook(user, today)['priorities'][:5]],
    }
    if comparison['comparable'] and comparison['previous_has_data']:
        digest['ce_mois']['ecart_vs_' + comparison['reference']['code']] = {
            'reference': comparison['reference']['label'],
            'recettes_pct': comparison['revenue']['delta_pct'],
            'depenses_pct': comparison['expenses']['delta_pct'],
            'categories_en_hausse_anormale': [c['label'] for c in comparison['expense_categories'] if c['anomaly']],
        }
    profitable = [c for c in crop_profitability(user)['crops'] if c['margin'] is not None][:5]
    if profitable:
        digest['marge_par_culture'] = [{'culture': c['name'], 'marge_fcfa': c['margin'], 'taux_pct': c['margin_rate_pct']}
                                       for c in profitable]
    return digest


# --------------------------------------------------------------------------------------------------------------
# Un produit en détail, et les dernières opérations (pour « ce produit », « mes dernières ventes »…)
# --------------------------------------------------------------------------------------------------------------
def product_summary(user, product, period):
    """Ventes d'un produit sur une période (quantité, chiffre d'affaires, prix) + son stock actuel et sa rentabilité."""
    key = normalize_text(product)
    sales = [s for s in _sales(user, period).select_related('crop') if normalize_text(_product_name(s)) == key]
    quantity = sum(float(s.quantity_sold) for s in sales)
    revenue = sum(s.total_revenue for s in sales)
    prices = [float(s.price_per_unit) for s in sales]
    last_sale = max(sales, key=lambda s: (s.date, s.created_at), default=None)

    stock = next((i for i in stock_outlook(user)['items'] if normalize_text(i['name']) == key), None)
    profit = next((c for c in crop_profitability(user)['crops'] if normalize_text(c['name']) == key), None)
    return {
        'period': period.as_dict(),
        'product': product,
        'sales_count': len(sales),
        'quantity': round(quantity, 2),
        'revenue': _round(revenue),
        'avg_unit_price': _round(revenue / quantity) if quantity else None,
        'min_unit_price': _round(min(prices)) if prices else None,
        'max_unit_price': _round(max(prices)) if prices else None,
        'last_sale': {'date': last_sale.date.isoformat(), 'quantity': float(last_sale.quantity_sold),
                      'unit_price': _round(last_sale.price_per_unit)} if last_sale else None,
        'stock': stock,
        'profitability': profit,
    }


def recent_sales(user, limit=5):
    """Les dernières ventes enregistrées, de la plus récente à la plus ancienne."""
    rows = _sales(user).select_related('crop').order_by('-date', '-created_at')[:limit]
    return {'sales': [{'date': s.date.isoformat(), 'product': _product_name(s), 'quantity': float(s.quantity_sold),
                       'unit_price': _round(s.price_per_unit), 'total': _round(s.total_revenue), 'buyer': s.buyer or ''}
                      for s in rows]}


def recent_expenses(user, limit=5):
    """Les dernières dépenses enregistrées, de la plus récente à la plus ancienne."""
    rows = _transactions(user, 'expense').select_related('crop').order_by('-date', '-created_at')[:limit]
    return {'expenses': [{'date': t.date.isoformat(), 'description': t.description, 'amount': _round(t.amount),
                          'category': t.category or 'autre', 'label': category_label(t.category or 'autre'),
                          'crop': t.crop.name if t.crop_id else ''} for t in rows]}
