"""
Page détail d'un marché : tout ce que l'on sait de ce marché, calculé uniquement à partir des relevés de prix enregistrés.

Rien n'est inventé : un chiffre absent reste absent (``None``). La prévision est une simple tendance des dernières
semaines, annoncée comme telle, avec son niveau de confiance ; elle n'est donnée que s'il y a assez de relevés.
"""
import math
from collections import defaultdict
from datetime import timedelta

from django.db.models import F, Window
from django.db.models.functions import RowNumber

from .models import Price, Product

HISTORY_DAYS = 30
OFFICIAL_HISTORY_DAYS = 365
FORECAST_BASIS_DAYS = 21
FORECAST_HORIZON_DAYS = 7
MIN_FORECAST_POINTS = 10
MIN_FORECAST_SPAN_DAYS = 10
STABLE_BAND_PERCENT = 2.0
FEATURED_COUNT = 6

# Relevés officiels : code enregistré -> mention affichée à l'utilisateur
OFFICIAL_SOURCES = {'wfp': 'Relevé officiel PAM / ANSD'}


def forecast_from_series(points):
    """
    Tendance sur les derniers jours : ``points`` = liste de ``(date, prix)``. Renvoie ``None`` s'il y a trop peu de relevés.

    Droite des moindres carrés sur les 3 dernières semaines, prolongée de 7 jours. La fourchette est celle des écarts
    habituels autour de la droite ; la confiance dépend du nombre de relevés et de la régularité de la tendance.
    """
    if not points:
        return None
    last_day = points[-1][0]
    recent = [(d, p) for d, p in points if (last_day - d).days < FORECAST_BASIS_DAYS]
    if len(recent) < MIN_FORECAST_POINTS or (recent[-1][0] - recent[0][0]).days < MIN_FORECAST_SPAN_DAYS:
        return None

    xs = [(d - recent[0][0]).days for d, _ in recent]
    ys = [float(p) for _, p in recent]
    n = len(xs)
    mean_x, mean_y = sum(xs) / n, sum(ys) / n
    var_x = sum((x - mean_x) ** 2 for x in xs)
    if var_x == 0:
        return None
    slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys)) / var_x
    intercept = mean_y - slope * mean_x
    residuals = [y - (intercept + slope * x) for x, y in zip(xs, ys)]
    total_var = sum((y - mean_y) ** 2 for y in ys)
    r_squared = 1 - sum(r * r for r in residuals) / total_var if total_var > 0 else 0.0
    spread = math.sqrt(sum(r * r for r in residuals) / max(1, n - 2))

    horizon_x = xs[-1] + FORECAST_HORIZON_DAYS
    expected = max(0.0, intercept + slope * horizon_x)
    low, high = max(0.0, expected - 1.5 * spread), expected + 1.5 * spread
    current = ys[-1]
    change_percent = (expected - current) / current * 100 if current else 0.0
    if change_percent > STABLE_BAND_PERCENT:
        direction = 'up'
    elif change_percent < -STABLE_BAND_PERCENT:
        direction = 'down'
    else:
        direction = 'stable'

    if n >= 18 and r_squared >= 0.5:
        confidence = 'good'
    elif r_squared >= 0.25:
        confidence = 'medium'
    else:
        confidence = 'low'
    return {
        'direction': direction,
        'expected_price': round(expected, 0),
        'low': round(low, 0),
        'high': round(high, 0),
        'change_percent': round(change_percent, 1),
        'horizon_days': FORECAST_HORIZON_DAYS,
        'basis_days': (recent[-1][0] - recent[0][0]).days + 1,
        'basis_points': n,
        'confidence': confidence,
    }


def _daily_series(rows):
    """Un prix par jour (moyenne si plusieurs relevés le même jour), du plus ancien au plus récent."""
    per_day = defaultdict(list)
    for date, price in rows:
        per_day[date].append(float(price))
    return [(day, sum(values) / len(values)) for day, values in sorted(per_day.items())]


def _price_on_or_before(series, day):
    chosen = None
    for d, p in series:
        if d <= day:
            chosen = p
        else:
            break
    return chosen


def build_overview(market):
    """Vue complète d'un marché : informations, produits, évolution des prix et prévision."""
    prices = Price.objects.filter(market=market)
    newest = prices.order_by('-date').values_list('date', flat=True).first()
    base = {
        'id': str(market.id),
        'name': market.name,
        'region': market.region,
        'location_gps': market.location_gps,
        'opening_time': market.opening_time.strftime('%H:%M') if market.opening_time else None,
        'closing_time': market.closing_time.strftime('%H:%M') if market.closing_time else None,
        # Les horaires ne sont pas encore relevés marché par marché : on le dit plutôt que de les présenter comme certains
        'hours_verified': False,
        'last_update': newest.isoformat() if newest else None,
        'price_records': prices.count(),
        'products': [],
        'featured': [],
    }
    if newest is None:
        return base

    since = newest - timedelta(days=HISTORY_DAYS - 1)
    official_since = newest - timedelta(days=OFFICIAL_HISTORY_DAYS - 1)
    by_product = defaultdict(list)
    trend_of = {}
    source_of = {}
    for name, date, price, trend, source in prices.filter(date__gte=official_since).order_by('date', 'created_at').values_list(
            'product_name', 'date', 'price', 'trend', 'source'):
        # Les relevés officiels sont mensuels : on garde l'année entière pour avoir une courbe, au lieu de 30 jours
        if source not in OFFICIAL_SOURCES and date < since:
            continue
        by_product[name].append((date, price))
        trend_of[name] = trend
        source_of[name] = source

    # Position de ce marché parmi tous les marchés qui suivent le même produit (dernier relevé de chaque marché)
    latest_rows = (
        Price.objects.filter(product_name__in=list(by_product))
        .annotate(rn=Window(RowNumber(), partition_by=[F('market_id'), F('product_name')],
                            order_by=[F('date').desc(), F('created_at').desc()]))
        .filter(rn=1, date__gte=since)
        .values_list('product_name', 'market_id', 'price')
    )
    market_prices = defaultdict(dict)
    for name, market_id, price in latest_rows:
        market_prices[name][market_id] = float(price)

    trending = set(Product.objects.filter(is_trending=True).values_list('name', flat=True))
    category_map = dict(Product.objects.values_list('name', 'category'))

    def _get_category(product_name):
        cat = category_map.get(product_name)
        if cat:
            return cat
        clean = product_name.lower().strip()
        if any(w in clean for w in ['arachide', 'mil', 'mais', 'maïs', 'sorgho', 'riz', 'niebe', 'niébé', 'fonio']):
            return 'CÉRÉALE'
        if any(w in clean for w in ['oignon', 'tomate', 'chou', 'carotte', 'aubergine', 'piment', 'poivron', 'gombo', 'navet', 'courge', 'salade', 'laitue', 'ail', 'concombre', 'haricot']):
            return 'LÉGUME'
        if any(w in clean for w in ['mangue', 'banane', 'papaye', 'pasteque', 'pastèque', 'orange', 'citron', 'ananas']):
            return 'FRUIT'
        if any(w in clean for w in ['manioc', 'patate', 'pomme de terre', 'igname']):
            return 'TUBERCULE'
        return 'AUTRE'

    products = []
    for name, rows in by_product.items():
        series = _daily_series(rows)
        last_day, current = series[-1]
        week_ago = _price_on_or_before(series, last_day - timedelta(days=7))
        values = [p for _, p in series]
        peers = market_prices.get(name, {})
        cheaper_markets = sum(1 for other, p in peers.items() if other != market.id and p < current)
        products.append({
            'name': name,
            'category': _get_category(name),
            'price': round(current, 0),
            'trend': trend_of.get(name, 'stable'),
            'date': last_day.isoformat(),
            'change_week_percent': round((current - week_ago) / week_ago * 100, 1) if week_ago else None,
            'min_30d': round(min(values), 0),
            'max_30d': round(max(values), 0),
            'avg_30d': round(sum(values) / len(values), 0),
            'observed_days': len(series),
            'markets_compared': len(peers),
            'cheaper_markets': cheaper_markets if len(peers) > 1 else None,
            'history': [{'date': d.isoformat(), 'price': round(p, 0)} for d, p in series],
            'forecast': forecast_from_series(series),
            'is_trending': name in trending,
            # Origine du dernier relevé : seul un relevé officiel porte une mention de source
            'source': OFFICIAL_SOURCES.get(source_of.get(name, '')),
            'window_days': OFFICIAL_HISTORY_DAYS if source_of.get(name) in OFFICIAL_SOURCES else HISTORY_DAYS,
        })

    # Produits phares propres à ce marché :
    # On met en avant les produits qui animent réellement CE marché particulier :
    # 1. Plus forte variation de prix récente sur ce marché (|change_week_percent|)
    # 2. Tendance active (hausse ou baisse de cours)
    # 3. Disponibilité d'une prévision calculée sur l'historique
    # 4. Nombre de relevés / présence observée sur ce marché
    # 5. Tendance catalogue en cas d'égalité
    def _featured_rank(p):
        chg = abs(p['change_week_percent']) if p['change_week_percent'] is not None else 0.0
        has_movement = 1 if p['trend'] in ('up', 'down') else 0
        has_forecast = 1 if p.get('forecast') else 0
        obs = p.get('observed_days', 0)
        trending_bonus = 1 if p.get('is_trending') else 0
        return (-round(chg, 1), -has_movement, -has_forecast, -obs, -trending_bonus, p['name'])

    products.sort(key=_featured_rank)
    base['featured'] = [p['name'] for p in products[:FEATURED_COUNT]]
    products.sort(key=lambda p: p['name'])
    base['products'] = products
    return base
