"""
Météo réelle du lieu où se trouve l'agriculteur (source : Open-Meteo, https://open-meteo.com).

Règle de l'application : aucune valeur n'est inventée. Si la source ne répond pas, on le dit (``WeatherUnavailable``) ;
on ne remplace jamais une mesure manquante par une valeur « réaliste ».

Limite à dire clairement : Open-Meteo donne une prévision numérique à maille d'environ 11 km, pas la mesure d'une
station installée dans le champ.
"""
import logging
import unicodedata
from datetime import date

import requests
from django.core.cache import cache

from .models import WeatherData

logger = logging.getLogger(__name__)

FORECAST_URL = 'https://api.open-meteo.com/v1/forecast'
GEOCODING_URL = 'https://geocoding-api.open-meteo.com/v1/search'
TIMEOUT = 10
WEATHER_CACHE_SECONDS = 15 * 60
PLACE_CACHE_SECONDS = 7 * 24 * 3600

# Rectangle qui enferme le Sénégal, avec une petite marge (latitude min/max, longitude min/max)
SENEGAL_LAT = (12.0, 17.0)
SENEGAL_LON = (-18.0, -11.0)

SOURCE = {
    'name': 'Open-Meteo',
    'url': 'https://open-meteo.com',
    'note': "Prévision numérique à maille d'environ 11 km : ce n'est pas la mesure d'une station dans votre champ.",
}

# Codes météo internationaux (OMM/WMO) : texte français et famille d'icône
WMO_CODES = {
    0: ('Ciel dégagé', 'clear'),
    1: ('Plutôt dégagé', 'clear'),
    2: ('Partiellement nuageux', 'partly'),
    3: ('Couvert', 'cloudy'),
    45: ('Brouillard', 'fog'),
    48: ('Brouillard givrant', 'fog'),
    51: ('Bruine légère', 'drizzle'),
    53: ('Bruine', 'drizzle'),
    55: ('Bruine dense', 'drizzle'),
    56: ('Bruine verglaçante', 'drizzle'),
    57: ('Bruine verglaçante dense', 'drizzle'),
    61: ('Pluie faible', 'rain'),
    63: ('Pluie', 'rain'),
    65: ('Forte pluie', 'rain'),
    66: ('Pluie verglaçante', 'rain'),
    67: ('Forte pluie verglaçante', 'rain'),
    80: ('Averses faibles', 'rain'),
    81: ('Averses', 'rain'),
    82: ('Fortes averses', 'rain'),
    95: ('Orage', 'storm'),
    96: ('Orage avec grêle', 'storm'),
    99: ('Violent orage avec grêle', 'storm'),
}


class WeatherUnavailable(Exception):
    """La source météo ne répond pas ou renvoie une réponse inutilisable."""


class OutsideSenegal(Exception):
    """La position demandée est hors du Sénégal."""


class UnknownPlace(Exception):
    """Aucun lieu du Sénégal ne porte ce nom."""


class AmbiguousPlace(Exception):
    """Plusieurs lieux portent ce nom : il faut demander lequel (on ne devine pas)."""

    def __init__(self, candidates):
        super().__init__('Plusieurs lieux portent ce nom.')
        self.candidates = candidates


def describe(code):
    """Texte français et famille d'icône d'un code météo."""
    return WMO_CODES.get(code, ('Temps variable', 'cloudy'))


def _normalize(text):
    decomposed = unicodedata.normalize('NFKD', (text or '').lower())
    return ''.join(ch for ch in decomposed if not unicodedata.combining(ch)).strip()


def in_senegal(lat, lon):
    return SENEGAL_LAT[0] <= lat <= SENEGAL_LAT[1] and SENEGAL_LON[0] <= lon <= SENEGAL_LON[1]


def _get_json(url, params):
    try:
        response = requests.get(url, params=params, timeout=TIMEOUT)
    except requests.RequestException as exc:
        logger.warning('Météo : source injoignable (%s)', type(exc).__name__)
        raise WeatherUnavailable('La source météo ne répond pas.') from exc
    if response.status_code != 200:
        logger.warning('Météo : la source a répondu %s', response.status_code)
        raise WeatherUnavailable('La source météo a refusé la demande.')
    try:
        return response.json()
    except ValueError as exc:
        raise WeatherUnavailable('Réponse météo illisible.') from exc


def resolve_place(text):
    """
    Position d'un lieu du Sénégal à partir de son nom (« Keur Massar », « Keur Massar, Dakar »).

    Plusieurs villages portent souvent le même nom dans des régions différentes : sans précision de région,
    on lève ``AmbiguousPlace`` avec les candidats plutôt que de choisir au hasard.
    """
    name, _, hint = (text or '').partition(',')
    name, hint = name.strip(), _normalize(hint)
    if not name:
        raise UnknownPlace('Aucun lieu indiqué.')

    key = f'wx:geo:{_normalize(name)}'
    results = cache.get(key)
    if results is None:
        data = _get_json(GEOCODING_URL, {'name': name, 'count': 10, 'language': 'fr', 'countryCode': 'SN', 'format': 'json'})
        results = [
            {'name': r.get('name', name), 'admin1': r.get('admin1') or '', 'lat': r['latitude'], 'lon': r['longitude']}
            for r in data.get('results') or []
            if r.get('country_code') == 'SN' and 'latitude' in r and 'longitude' in r
        ]
        cache.set(key, results, PLACE_CACHE_SECONDS)

    if hint:
        narrowed = [r for r in results if hint in _normalize(r['admin1'])]
        results = narrowed or results
    if not results:
        raise UnknownPlace(f'Aucun lieu du Sénégal ne s\'appelle « {name} ».')
    distinct = {(round(r['lat'], 2), round(r['lon'], 2)) for r in results}
    if len(distinct) > 1:
        raise AmbiguousPlace([
            {'label': f"{r['name']} ({r['admin1']})" if r['admin1'] else r['name'], 'lat': r['lat'], 'lon': r['lon']}
            for r in results
        ])
    return results[0]


def build_advice(report):
    """
    Conseils tirés uniquement des mesures et prévisions du rapport, dits en phrases simples (pas de chiffres ni de
    mots techniques : le public est peu lettré). S'il n'y a rien de notable, on ne remplit pas avec des conseils génériques.
    """
    advice = []
    current = report['current']
    days = report['forecast']
    next_days = days[:3]
    rain_ahead = sum(d['rainfall'] for d in next_days)
    best_chance = max((d['rain_probability'] or 0 for d in next_days), default=0)
    past_rain = report['rain_last_7_days']
    hottest = max((d['temperature_max'] for d in next_days), default=current['temperature'])

    if rain_ahead >= 10 or best_chance >= 70:
        advice.append("De la pluie arrive dans les prochains jours. Attendez avant d'arroser, de mettre de l'engrais ou de traiter.")
    elif past_rain < 2 and rain_ahead < 2 and hottest >= 33:
        advice.append("Il n'a presque pas plu et il fait chaud. Arrosez tôt le matin ou le soir.")
    if hottest >= 38:
        advice.append("Il va faire très chaud. Protégez les jeunes plants et ne travaillez pas aux heures chaudes.")
    wind = max((d['wind_speed'] for d in next_days), default=current['wind_speed'])
    if wind >= 30:
        advice.append("Il y aura beaucoup de vent. Ne traitez pas vos plantes, le produit serait emporté.")
    if current['humidity'] >= 85 and current['temperature'] >= 20:
        advice.append("L'air est très humide. Regardez les feuilles : les maladies arrivent vite.")
    return advice


def _build_report(raw, place):
    current = raw.get('current') or {}
    daily = raw.get('daily') or {}
    times = daily.get('time') or []
    if current.get('temperature_2m') is None or not times:
        raise WeatherUnavailable('La source météo n\'a donné aucune mesure pour ce lieu.')

    today = date.today().isoformat()
    # Le jour courant est donné dans le fuseau du Sénégal par la source : on s'y fie plutôt qu'à l'horloge du serveur
    today = (current.get('time') or today)[:10]

    def at(name, i, default=None):
        values = daily.get(name) or []
        return values[i] if i < len(values) and values[i] is not None else default

    past_rain = 0.0
    forecast = []
    for i, day in enumerate(times):
        if day < today:
            past_rain += at('precipitation_sum', i, 0.0) or 0.0
            continue
        if day == today:
            continue  # aujourd'hui est décrit par la mesure du moment
        text, icon = describe(at('weather_code', i))
        forecast.append({
            'date': day,
            'temperature_max': at('temperature_2m_max', i),
            'temperature_min': at('temperature_2m_min', i),
            'rainfall': at('precipitation_sum', i, 0.0),
            'rain_probability': at('precipitation_probability_max', i),
            'wind_speed': at('wind_speed_10m_max', i, 0.0),
            'description': text,
            'icon': icon,
        })

    today_index = times.index(today) if today in times else None
    text, icon = describe(current.get('weather_code'))
    report = {
        'available': True,
        'place': place,
        'current': {
            'temperature': current['temperature_2m'],
            'feels_like': current.get('apparent_temperature'),
            'humidity': current.get('relative_humidity_2m'),
            'rainfall': current.get('precipitation') or 0.0,
            'wind_speed': current.get('wind_speed_10m') or 0.0,
            'description': text,
            'icon': icon,
            'observed_at': current.get('time'),
            'today_max': at('temperature_2m_max', today_index) if today_index is not None else None,
            'today_min': at('temperature_2m_min', today_index) if today_index is not None else None,
            'today_rain': at('precipitation_sum', today_index, 0.0) if today_index is not None else None,
        },
        'forecast': forecast,
        'rain_last_7_days': round(past_rain, 1),
        'source': SOURCE,
    }
    report['advice'] = build_advice(report)
    return report


def _remember(report):
    """Garde la mesure réelle du jour (utilisée par l'assistant et les statistiques). Sans effet bloquant."""
    try:
        place = report['place']
        current = report['current']
        WeatherData.objects.update_or_create(
            location=place['name'].lower(),
            forecast_date=date.today(),
            defaults={
                'temperature': current['temperature'],
                'humidity': current['humidity'] or 0,
                'rainfall': current['rainfall'] or 0,
            },
        )
    except Exception:  # la conservation ne doit jamais empêcher de répondre
        logger.exception('Météo : mesure non enregistrée')


def weather_at(lat, lon, name=None):
    """Météo réelle d'une position du Sénégal (cache de 15 minutes par zone de 1 km environ)."""
    if not in_senegal(lat, lon):
        raise OutsideSenegal('Cette position est hors du Sénégal.')
    key = f'wx:{lat:.2f}:{lon:.2f}'
    raw = cache.get(key)
    if raw is None:
        raw = _get_json(FORECAST_URL, {
            'latitude': round(lat, 4),
            'longitude': round(lon, 4),
            'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m',
            'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,'
                     'precipitation_probability_max,wind_speed_10m_max',
            'timezone': 'Africa/Dakar',
            'forecast_days': 7,
            'past_days': 7,
        })
        cache.set(key, raw, WEATHER_CACHE_SECONDS)
    place = {'name': name or 'Ma position', 'lat': round(lat, 4), 'lon': round(lon, 4)}
    report = _build_report(raw, place)
    if name:
        _remember(report)
    return report


def weather_for_place(text):
    """Météo réelle d'un lieu désigné par son nom."""
    found = resolve_place(text)
    label = f"{found['name']} ({found['admin1']})" if found['admin1'] else found['name']
    report = weather_at(found['lat'], found['lon'], name=found['name'])
    report['place']['name'] = label
    return report
