"""
Météo de l'assistant : celle de la zone de la personne, mesurée pour de vrai, ou rien. Jamais celle d'une autre région.
"""
import datetime
from unittest.mock import patch

from django.test import override_settings

from apps.ai_assistant.queries import detect_query_intent
from apps.ai_assistant.services import get_farmer_context
from apps.ai_assistant.test_phase5_dialogue import DialogueBase
from apps.weather import services as weather
from apps.weather.models import WeatherData


def report(name='Thiès (Thiès)', temperature=31.4, icon='partly'):
    return {
        'place': {'name': name, 'lat': 14.79, 'lon': -16.93},
        'current': {'temperature': temperature, 'humidity': 62, 'rainfall': 0.0, 'today_rain': 0.0, 'wind_speed': 18.0,
                    'icon': icon},
        'forecast': [{'date': (datetime.date.today() + datetime.timedelta(days=1)).isoformat(), 'temperature_max': 33.0,
                      'icon': 'clear'}],
        'advice': [],
    }


class ContextWeatherTests(DialogueBase):
    def setUp(self):
        super().setUp()
        self.user.location = 'Thiès, Sénégal'
        self.user.save()

    def test_another_regions_weather_is_never_used(self):
        WeatherData.objects.create(location='Podor', temperature=40, humidity=20, rainfall=0, forecast_date=datetime.date.today())
        context = get_farmer_context(self.user)
        self.assertIsNone(context['weather'])
        self.assertIn('AUCUNE', context['weather_note'])

    def test_a_recent_measure_of_the_same_zone_is_used(self):
        WeatherData.objects.create(location='thiès', temperature=33, humidity=50, rainfall=1, forecast_date=datetime.date.today())
        self.assertEqual(get_farmer_context(self.user)['weather']['temperature_c'], 33)

    def test_an_old_measure_is_not_presented_as_current(self):
        WeatherData.objects.create(location='thiès', temperature=33, humidity=50, rainfall=1,
                                   forecast_date=datetime.date.today() - datetime.timedelta(days=5))
        self.assertIsNone(get_farmer_context(self.user)['weather'])

    @override_settings(AI_LIVE_WEATHER=True)
    def test_the_live_measure_comes_first(self):
        with patch('apps.weather.services.weather_for_place', return_value=report()) as live:
            context = get_farmer_context(self.user)
        live.assert_called_once_with('Thiès')
        self.assertEqual(context['weather']['temperature_c'], 31.4)
        self.assertIn('Open-Meteo', context['weather']['source'])

    @override_settings(AI_LIVE_WEATHER=True)
    def test_when_the_source_is_down_the_weather_is_missing_not_borrowed(self):
        WeatherData.objects.create(location='Podor', temperature=40, humidity=20, rainfall=0, forecast_date=datetime.date.today())
        with patch('apps.weather.services.weather_for_place', side_effect=weather.WeatherUnavailable('hors service')):
            self.assertIsNone(get_farmer_context(self.user)['weather'])


class WeatherQuestionTests(DialogueBase):
    def setUp(self):
        super().setUp()
        self.user.location = 'Thiès, Sénégal'
        self.user.save()

    def text(self, message):
        return self.ask(message).data['response']

    def test_the_question_is_recognised_with_or_without_a_place(self):
        self.assertEqual(detect_query_intent("Quelle est la météo ?"), {'type': 'weather', 'place': None})
        self.assertEqual(detect_query_intent("Météo à Kaolack ?")['place'], 'Kaolack')
        self.assertIsNone(detect_query_intent("Quel temps met le mil à pousser ?"))
        self.assertIsNone(detect_query_intent("météo de demain")['place'])

    def test_the_answer_uses_the_zone_of_the_person_and_plain_words(self):
        with patch('apps.weather.services.weather_for_place', return_value=report()) as live:
            answer = self.text("Quelle est la météo ?")
        live.assert_called_once_with('Thiès')
        self.assertIn('Il fait bon', answer)
        self.assertIn('Demain', answer)

    def test_a_named_place_is_used_instead(self):
        with patch('apps.weather.services.weather_for_place', return_value=report('Kaolack (Kaolack)')) as live:
            answer = self.text("Météo à Kaolack ?")
        live.assert_called_once_with('Kaolack')
        self.assertIn('Kaolack', answer)

    def test_an_unavailable_source_is_said_not_replaced(self):
        with patch('apps.weather.services.weather_for_place', side_effect=weather.WeatherUnavailable('x')):
            answer = self.text("Quelle est la météo ?")
        self.assertIn("n'est pas disponible", answer)
        self.assertIn("pas la météo d'un autre endroit", answer)

    def test_an_ambiguous_place_asks_which_one(self):
        error = weather.AmbiguousPlace([{'label': 'Keur Massar (Dakar)', 'lat': 1, 'lon': 1}, {'label': 'Keur Massar (Louga)', 'lat': 2, 'lon': 2}])
        with patch('apps.weather.services.weather_for_place', side_effect=error):
            response = self.ask("Météo à Keur Massar")
        self.assertIn('Plusieurs endroits', response.data['response'])
        self.assertIn('Météo à Keur Massar (Dakar)', response.data['suggestions'])

    def test_without_a_known_zone_the_assistant_asks_where_you_are(self):
        self.user.location = ''
        self.user.save()
        answer = self.text("Quelle est la météo ?")
        self.assertIn('Dites-moi où vous êtes', answer)
