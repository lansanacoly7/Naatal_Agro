from unittest.mock import MagicMock, patch

import requests
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from apps.weather import services
from apps.weather.models import WeatherData

User = get_user_model()

TODAY = '2026-10-24'


def forecast_payload(rain_by_day=None, tmax=33.0, wind=15.0, humidity=60):
    """Réponse type de la source météo (valeurs de test) : 7 jours passés, aujourd'hui, 7 jours à venir."""
    days = ['2026-10-17', '2026-10-18', '2026-10-19', '2026-10-20', '2026-10-21', '2026-10-22', '2026-10-23', TODAY,
            '2026-10-25', '2026-10-26', '2026-10-27', '2026-10-28', '2026-10-29', '2026-10-30']
    rain = rain_by_day or [0.0] * len(days)
    return {
        'current': {'time': f'{TODAY}T13:00', 'temperature_2m': 31.2, 'relative_humidity_2m': humidity,
                    'apparent_temperature': 33.0, 'precipitation': 0.0, 'weather_code': 2, 'wind_speed_10m': 12.0},
        'daily': {
            'time': days,
            'weather_code': [1] * len(days),
            'temperature_2m_max': [tmax] * len(days),
            'temperature_2m_min': [22.0] * len(days),
            'precipitation_sum': rain,
            'precipitation_probability_max': [10] * len(days),
            'wind_speed_10m_max': [wind] * len(days),
        },
    }


def geocoding_payload(*places):
    return {'results': [{'name': n, 'admin1': a, 'latitude': la, 'longitude': lo, 'country_code': 'SN'} for n, a, la, lo in places]}


def fake_get(forecast=None, geocoding=None, status_code=200):
    def get(url, params=None, timeout=None):
        body = geocoding if 'geocoding' in url else forecast
        return MagicMock(status_code=status_code, json=lambda: body)
    return get


class WeatherServiceTests(TestCase):
    def setUp(self):
        cache.clear()

    @patch('apps.weather.services.requests.get')
    def test_builds_report_from_real_measurements(self, get):
        get.side_effect = fake_get(forecast=forecast_payload())
        report = services.weather_at(14.72, -17.18)
        self.assertTrue(report['available'])
        self.assertEqual(report['current']['temperature'], 31.2)
        self.assertEqual(report['current']['humidity'], 60)
        self.assertEqual(report['current']['description'], 'Partiellement nuageux')
        self.assertEqual(report['place']['name'], 'Ma position')
        self.assertEqual(report['source']['name'], 'Open-Meteo')
        self.assertEqual(len(report['forecast']), 6, "demain et les jours suivants, sans aujourd'hui ni le passé")
        self.assertEqual(report['forecast'][0]['date'], '2026-10-25')

    @patch('apps.weather.services.requests.get')
    def test_rain_of_the_last_seven_days_is_summed(self, get):
        rain = [0, 4.0, 0, 6.5, 0, 0, 1.0, 0, 0, 0, 0, 0, 0, 0]
        get.side_effect = fake_get(forecast=forecast_payload(rain_by_day=rain))
        self.assertEqual(services.weather_at(14.72, -17.18)['rain_last_7_days'], 11.5)

    @patch('apps.weather.services.requests.get')
    def test_second_request_for_the_same_zone_uses_the_cache(self, get):
        get.side_effect = fake_get(forecast=forecast_payload())
        services.weather_at(14.72, -17.18)
        services.weather_at(14.7203, -17.1799)
        self.assertEqual(get.call_count, 1)

    @patch('apps.weather.services.requests.get')
    def test_position_outside_senegal_is_refused_without_calling_the_source(self, get):
        with self.assertRaises(services.OutsideSenegal):
            services.weather_at(48.85, 2.35)  # Paris
        get.assert_not_called()

    @patch('apps.weather.services.requests.get', side_effect=requests.ConnectionError('réseau coupé'))
    def test_source_down_raises_instead_of_inventing_values(self, _get):
        with self.assertRaises(services.WeatherUnavailable):
            services.weather_at(14.72, -17.18)
        self.assertEqual(WeatherData.objects.count(), 0)

    @patch('apps.weather.services.requests.get')
    def test_empty_answer_is_not_turned_into_a_report(self, get):
        get.side_effect = fake_get(forecast={'current': {}, 'daily': {}})
        with self.assertRaises(services.WeatherUnavailable):
            services.weather_at(14.72, -17.18)

    @patch('apps.weather.services.requests.get')
    def test_mild_weather_gives_no_filler_advice(self, get):
        get.side_effect = fake_get(forecast=forecast_payload(tmax=30.0, wind=12.0, humidity=55))
        # il a plu récemment : aucune raison d'alerter
        report = services.weather_at(14.72, -17.18)
        self.assertEqual(report['advice'], [])

    @patch('apps.weather.services.requests.get')
    def test_advice_is_plain_words_for_rain_and_wind(self, get):
        rain = [0] * 8 + [12.0, 8.0, 0, 0, 0, 0]
        get.side_effect = fake_get(forecast=forecast_payload(rain_by_day=rain, wind=35.0))
        advice = ' '.join(services.weather_at(14.72, -17.18)['advice'])
        self.assertIn('De la pluie arrive', advice)
        self.assertIn('beaucoup de vent', advice)
        self.assertNotRegex(advice, r'\d')

    @patch('apps.weather.services.requests.get')
    def test_dry_spell_and_heat_recommend_watering(self, get):
        get.side_effect = fake_get(forecast=forecast_payload(tmax=36.0))
        advice = ' '.join(services.weather_at(14.72, -17.18)['advice'])
        self.assertIn('Arrosez', advice)

    @patch('apps.weather.services.requests.get')
    def test_named_place_saves_the_real_measurement_once_per_day(self, get):
        get.side_effect = fake_get(forecast=forecast_payload(), geocoding=geocoding_payload(('Thiès', 'Thiès', 14.79, -16.93)))
        services.weather_for_place('Thiès')
        services.weather_for_place('Thiès')
        self.assertEqual(WeatherData.objects.count(), 1)
        self.assertEqual(WeatherData.objects.get().temperature, 31.2)


class PlaceResolutionTests(TestCase):
    def setUp(self):
        cache.clear()

    @patch('apps.weather.services.requests.get')
    def test_unique_place_is_resolved(self, get):
        get.side_effect = fake_get(geocoding=geocoding_payload(('Thiès', 'Thiès', 14.79, -16.93)))
        found = services.resolve_place('Thiès')
        self.assertEqual((found['lat'], found['lon']), (14.79, -16.93))

    @patch('apps.weather.services.requests.get')
    def test_same_name_in_several_regions_is_never_guessed(self, get):
        get.side_effect = fake_get(geocoding=geocoding_payload(
            ('Keur Massar', 'Louga', 15.46, -15.88), ('Keur Massar', 'Dakar', 14.78, -17.31)))
        with self.assertRaises(services.AmbiguousPlace) as ctx:
            services.resolve_place('Keur Massar')
        labels = [c['label'] for c in ctx.exception.candidates]
        self.assertEqual(labels, ['Keur Massar (Louga)', 'Keur Massar (Dakar)'])

    @patch('apps.weather.services.requests.get')
    def test_a_region_after_the_name_removes_the_doubt(self, get):
        get.side_effect = fake_get(geocoding=geocoding_payload(
            ('Keur Massar', 'Louga', 15.46, -15.88), ('Keur Massar', 'Dakar', 14.78, -17.31)))
        self.assertEqual(services.resolve_place('Keur Massar, Dakar')['lat'], 14.78)

    @patch('apps.weather.services.requests.get')
    def test_unknown_place(self, get):
        get.side_effect = fake_get(geocoding={})
        with self.assertRaises(services.UnknownPlace):
            services.resolve_place('Nullepart')


class WeatherViewTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user(username='+221770400001', phone='+221770400001', password='Motdepasse#2026',
                                             location='Thiès')
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def test_requires_authentication(self):
        self.assertEqual(APIClient().get('/api/weather/here/').status_code, status.HTTP_401_UNAUTHORIZED)

    @patch('apps.weather.services.requests.get')
    def test_here_with_coordinates(self, get):
        get.side_effect = fake_get(forecast=forecast_payload())
        res = self.client.get('/api/weather/here/', {'lat': 14.72, 'lon': -17.18})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['current']['temperature'], 31.2)

    @patch('apps.weather.services.requests.get')
    def test_here_without_coordinates_uses_the_profile_place(self, get):
        get.side_effect = fake_get(forecast=forecast_payload(), geocoding=geocoding_payload(('Thiès', 'Thiès', 14.79, -16.93)))
        res = self.client.get('/api/weather/here/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['place']['name'], 'Thiès (Thiès)')

    def test_here_without_any_place_asks_for_one(self):
        self.user.location = ''
        self.user.save()
        res = self.client.get('/api/weather/here/')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(res.data['available'])

    def test_invalid_coordinates(self):
        self.assertEqual(self.client.get('/api/weather/here/', {'lat': 'x', 'lon': 'y'}).status_code, status.HTTP_400_BAD_REQUEST)

    def test_outside_senegal(self):
        self.assertEqual(self.client.get('/api/weather/here/', {'lat': 48.85, 'lon': 2.35}).status_code,
                         status.HTTP_422_UNPROCESSABLE_ENTITY)

    @patch('apps.weather.services.requests.get')
    def test_ambiguous_place_returns_the_choices(self, get):
        get.side_effect = fake_get(geocoding=geocoding_payload(
            ('Keur Massar', 'Louga', 15.46, -15.88), ('Keur Massar', 'Dakar', 14.78, -17.31)))
        res = self.client.get('/api/weather/here/', {'location': 'Keur Massar'})
        self.assertEqual(res.status_code, status.HTTP_409_CONFLICT)
        self.assertTrue(res.data['ambiguous'])
        self.assertEqual(len(res.data['candidates']), 2)

    @patch('apps.weather.services.requests.get', side_effect=requests.Timeout('trop lent'))
    def test_source_down_answers_503_without_any_weather_values(self, _get):
        res = self.client.get('/api/weather/here/', {'lat': 14.72, 'lon': -17.18})
        self.assertEqual(res.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        self.assertFalse(res.data['available'])
        self.assertNotIn('current', res.data)
        self.assertNotIn('forecast', res.data)

    def test_old_forecast_address_gives_the_same_real_answer(self):
        self.assertEqual(self.client.get('/api/weather/forecast/', {'lat': 48.85, 'lon': 2.35}).status_code,
                         status.HTTP_422_UNPROCESSABLE_ENTITY)

    def test_list_returns_only_stored_real_measurements(self):
        self.assertEqual(self.client.get('/api/weather/').json(), [])
        WeatherData.objects.create(location='thiès', temperature=30, humidity=50, rainfall=0, forecast_date='2026-10-24')
        self.assertEqual(len(self.client.get('/api/weather/', {'location': 'Thiès'}).json()), 1)
