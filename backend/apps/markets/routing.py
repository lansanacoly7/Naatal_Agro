"""
Itinéraire vers un marché : durée et distance en voiture et à pied, avec le tracé.

Les calculs viennent de serveurs d'itinéraires libres bâtis sur OpenStreetMap (OSRM) : aucune durée n'est devinée. Si un
serveur ne répond pas, ce mode est absent de la réponse (jamais remplacé par une estimation) ; seule la distance à vol
d'oiseau, calculée ici, est toujours donnée.
"""
import logging
import math

import requests
from django.core.cache import cache

logger = logging.getLogger(__name__)

PROFILES = {
    'car': 'https://router.project-osrm.org/route/v1/driving/{coords}',
    'foot': 'https://routing.openstreetmap.de/routed-foot/route/v1/foot/{coords}',
}
TIMEOUT = 6
CACHE_SECONDS = 600
USER_AGENT = 'NaatalAgro/1.0 (application agricole, Sénégal)'


def straight_line_km(lat1, lon1, lat2, lon2):
    """Distance à vol d'oiseau (formule de haversine), en kilomètres."""
    radius = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    d_phi, d_lambda = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(d_lambda / 2) ** 2
    return 2 * radius * math.asin(math.sqrt(a))


def _route(profile, origin, destination):
    coords = f"{origin[1]:.5f},{origin[0]:.5f};{destination[1]:.5f},{destination[0]:.5f}"
    try:
        response = requests.get(
            PROFILES[profile].format(coords=coords),
            params={'overview': 'simplified', 'geometries': 'geojson', 'steps': 'false'},
            headers={'User-Agent': USER_AGENT}, timeout=TIMEOUT,
        )
        if response.status_code != 200:
            return None
        body = response.json()
        route = body['routes'][0]
        return {
            'distance_km': round(route['distance'] / 1000, 1),
            'minutes': max(1, round(route['duration'] / 60)),
            # [latitude, longitude] pour la carte
            'geometry': [[lat, lon] for lon, lat in route['geometry']['coordinates']],
        }
    except (requests.RequestException, ValueError, KeyError, IndexError, TypeError) as exc:
        logger.warning("[Itinéraire] %s indisponible : %s", profile, type(exc).__name__)
        return None


def route_to_market(origin, destination):
    """``{'straight_km', 'car', 'foot'}`` ; ``car`` ou ``foot`` valent ``None`` si le service d'itinéraire n'a pas répondu."""
    key = f"route:{origin[0]:.3f},{origin[1]:.3f}>{destination[0]:.4f},{destination[1]:.4f}"
    cached = cache.get(key)
    if cached:
        return cached
    result = {
        'straight_km': round(straight_line_km(origin[0], origin[1], destination[0], destination[1]), 1),
        'car': _route('car', origin, destination),
        'foot': _route('foot', origin, destination),
    }
    if result['car'] or result['foot']:  # on ne garde pas en mémoire une panne
        cache.set(key, result, CACHE_SECONDS)
    return result
