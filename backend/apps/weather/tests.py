from datetime import date
from unittest.mock import patch, MagicMock
from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from rest_framework import status
from rest_framework.test import APIClient

from apps.weather.models import WeatherData
from apps.weather.services import fetch_weather_for_location

User = get_user_model()

OPENWEATHER_RESPONSE = {'main': {'temp': 31.5, 'humidity': 60}, 'rain': {'1h': 2.5}}


class WeatherServiceTests(TestCase):
    @override_settings(OPENWEATHER_API_KEY=None)
    def test_returns_none_without_api_key(self):
        self.assertIsNone(fetch_weather_for_location('Thiès'))

    @override_settings(OPENWEATHER_API_KEY='cle-test')
    @patch('apps.weather.services.requests.get')
    def test_saves_weather_from_api(self, get):
        get.return_value = MagicMock(status_code=200, json=lambda: OPENWEATHER_RESPONSE)
        weather = fetch_weather_for_location('Thiès')
        self.assertEqual(weather.temperature, 31.5)
        self.assertEqual(weather.rainfall, 2.5)
        self.assertEqual(WeatherData.objects.count(), 1)
        # Un second appel le même jour met à jour la ligne au lieu d'en créer une
        fetch_weather_for_location('Thiès')
        self.assertEqual(WeatherData.objects.count(), 1)

    @override_settings(OPENWEATHER_API_KEY='cle-test')
    @patch('apps.weather.services.requests.get', side_effect=Exception('réseau coupé'))
    def test_network_failure_returns_none(self, _get):
        self.assertIsNone(fetch_weather_for_location('Thiès'))


class WeatherViewTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='+221770400001', phone='+221770400001', password='Motdepasse#2026')
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        WeatherData.objects.create(location='thiès', temperature=30, humidity=50, rainfall=0, forecast_date=date.today())

    def test_requires_authentication(self):
        self.assertEqual(APIClient().get('/api/weather/').status_code, status.HTTP_401_UNAUTHORIZED)

    @patch('apps.weather.views.fetch_weather_for_location', return_value=None)
    def test_falls_back_to_database_when_api_unavailable(self, _fetch):
        data = self.client.get('/api/weather/', {'location': 'Thiès'}).json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]['location'], 'thiès')

    def test_list_without_location(self):
        self.assertEqual(len(self.client.get('/api/weather/').json()), 1)
