"""
La météo dite avec des mots de tous les jours (mêmes repères que l'application mobile) : le public est peu lettré.
Les seuils sont des repères de l'application ; la mesure, elle, reste celle de la source météo.
"""
import datetime

_WEEKDAYS = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche']
_WET = {'drizzle', 'rain', 'storm'}
_SKY = {
    'clear': 'du soleil', 'partly': 'du soleil et des nuages', 'fog': 'du brouillard',
    'drizzle': 'une petite pluie', 'rain': 'de la pluie', 'storm': 'de l\'orage',
}


def heat_sentence(celsius):
    if celsius >= 38:
        return 'Il fait très chaud'
    if celsius >= 33:
        return 'Il fait chaud'
    if celsius >= 24:
        return 'Il fait bon'
    if celsius >= 18:
        return 'Il fait frais'
    return 'Il fait froid'


def sky_words(family):
    return _SKY.get(family, 'un ciel couvert')


def brings_water(family):
    return family in _WET


def today_rain_sentence(current):
    rain = current.get('today_rain')
    rain = current.get('rainfall') or 0 if rain is None else rain
    if brings_water(current.get('icon')) or (current.get('rainfall') or 0) > 0:
        return 'Il pleut en ce moment'
    if rain >= 10:
        return 'Il a beaucoup plu aujourd\'hui'
    if rain >= 1:
        return 'Il a plu un peu aujourd\'hui'
    return 'Pas de pluie aujourd\'hui'


def wind_words(kmh):
    if kmh >= 30:
        return 'Vent fort'
    if kmh >= 15:
        return 'Un peu de vent'
    return 'Pas de vent'


def day_name(day, today):
    gap = (day - today).days
    if gap == 0:
        return 'Aujourd\'hui'
    if gap == 1:
        return 'Demain'
    if gap == 2:
        return 'Après-demain'
    return _WEEKDAYS[day.weekday()].capitalize()


def report_in_words(report, today=None):
    """Résumé d'un rapport météo (``weather_at``) en phrases simples, avec les conseils du jour."""
    today = today or datetime.date.today()
    current = report['current']
    lines = [
        f"{heat_sentence(current['temperature'])} : {round(current['temperature'])}°. {sky_words(current.get('icon')).capitalize()}.",
        f"{today_rain_sentence(current)}. {wind_words(current.get('wind_speed') or 0)}.",
    ]
    for day in report.get('forecast', [])[:3]:
        date = day['date'] if isinstance(day['date'], datetime.date) else datetime.date.fromisoformat(day['date'])
        high = day.get('temperature_max')
        lines.append(f"{day_name(date, today)} : {sky_words(day.get('icon'))}{f', {round(high)}°' if high is not None else ''}.")
    lines.extend(report.get('advice') or [])
    return lines
