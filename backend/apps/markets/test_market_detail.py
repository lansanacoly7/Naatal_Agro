"""Page détail d'un marché : données calculées depuis les relevés réels, prévision prudente, itinéraire sans invention."""
import datetime
from unittest.mock import patch

import requests
from django.core.cache import cache
from rest_framework.test import APITestCase

from apps.markets import market_overview as overview
from apps.markets.models import Market, Price, Product

TODAY = datetime.date(2026, 10, 22)


def day(offset):
    return TODAY - datetime.timedelta(days=offset)


class ForecastTests(APITestCase):
    def series(self, prices, last=TODAY):
        return [(last - datetime.timedelta(days=len(prices) - 1 - i), p) for i, p in enumerate(prices)]

    def test_a_rising_series_is_announced_as_rising_with_a_range(self):
        result = overview.forecast_from_series(self.series([400 + 5 * i for i in range(21)]))
        self.assertEqual(result['direction'], 'up')
        self.assertGreater(result['expected_price'], 500)
        self.assertLessEqual(result['low'], result['expected_price'])
        self.assertGreaterEqual(result['high'], result['expected_price'])
        self.assertEqual(result['confidence'], 'good')
        self.assertEqual(result['horizon_days'], 7)

    def test_a_flat_series_is_stable(self):
        self.assertEqual(overview.forecast_from_series(self.series([435] * 21))['direction'], 'stable')

    def test_a_falling_series_is_falling(self):
        self.assertEqual(overview.forecast_from_series(self.series([600 - 6 * i for i in range(21)]))['direction'], 'down')

    def test_too_few_records_give_no_forecast_instead_of_a_guess(self):
        self.assertIsNone(overview.forecast_from_series(self.series([400, 410, 420, 430])))
        self.assertIsNone(overview.forecast_from_series([]))

    def test_an_erratic_series_has_low_confidence(self):
        noisy = [400, 700, 380, 720, 390, 710, 405, 690, 400, 705, 395, 700]
        self.assertEqual(overview.forecast_from_series(self.series(noisy))['confidence'], 'low')

    def test_the_forecast_never_goes_below_zero(self):
        result = overview.forecast_from_series(self.series([max(1, 200 - 15 * i) for i in range(21)]))
        self.assertGreaterEqual(result['low'], 0)
        self.assertGreaterEqual(result['expected_price'], 0)


class OverviewApiTests(APITestCase):
    def setUp(self):
        self.market = Market.objects.create(name='Marché Test', region='Thiès', location_gps='14.79,-16.93')
        self.other = Market.objects.create(name='Autre marché', region='Dakar', location_gps='14.70,-17.45')
        Product.objects.create(name='Oignon', category='legume', is_trending=True, current_price=435)
        for i in range(25):
            Price.objects.create(market=self.market, product_name='Oignon', price=400 + i * 2, trend='up', date=day(24 - i))
            Price.objects.create(market=self.other, product_name='Oignon', price=500, trend='stable', date=day(24 - i))
        Price.objects.create(market=self.market, product_name='Mil', price=300, trend='stable', date=day(0))

    def get(self):
        return self.client.get(f'/api/markets/{self.market.id}/overview/')

    def test_the_overview_describes_the_market_from_its_own_records(self):
        response = self.get()
        self.assertEqual(response.status_code, 200)
        data = response.data
        self.assertEqual(data['name'], 'Marché Test')
        self.assertEqual(data['last_update'], max(day(0), day(24 - 24)).isoformat())
        self.assertEqual(data['price_records'], 26)
        self.assertEqual([p['name'] for p in data['products']], ['Mil', 'Oignon'])
        self.assertFalse(data['hours_verified'])

    def test_a_product_carries_its_history_comparison_and_forecast(self):
        onion = next(p for p in self.get().data['products'] if p['name'] == 'Oignon')
        self.assertEqual(onion['price'], 448)
        self.assertEqual(len(onion['history']), 25)
        self.assertEqual(onion['cheaper_markets'], 0)  # ce marché est le moins cher des deux
        self.assertEqual(onion['markets_compared'], 2)
        self.assertEqual(onion['forecast']['direction'], 'up')
        self.assertIn('Oignon', self.get().data['featured'])

    def test_a_product_with_one_record_has_no_forecast_and_no_comparison(self):
        mil = next(p for p in self.get().data['products'] if p['name'] == 'Mil')
        self.assertIsNone(mil['forecast'])
        self.assertIsNone(mil['cheaper_markets'])
        self.assertIsNone(mil['change_week_percent'])

    def test_a_market_without_records_returns_an_empty_overview(self):
        empty = Market.objects.create(name='Vide', region='Thiès')
        data = self.client.get(f'/api/markets/{empty.id}/overview/').data
        self.assertEqual(data['products'], [])
        self.assertIsNone(data['last_update'])


def osrm_reply(km, minutes):
    body = {'routes': [{'distance': km * 1000, 'duration': minutes * 60,
                        'geometry': {'coordinates': [[-16.9, 14.7], [-16.93, 14.79]]}}]}
    return type('R', (), {'status_code': 200, 'json': lambda self: body})()


class RouteApiTests(APITestCase):
    def setUp(self):
        cache.clear()
        self.market = Market.objects.create(name='Marché Test', region='Thiès', location_gps='14.79,-16.93')

    def url(self, query='lat=14.70&lon=-16.90'):
        return f'/api/markets/{self.market.id}/route/?{query}'

    def test_the_route_gives_car_and_walking_times_and_the_line_to_draw(self):
        with patch('apps.markets.routing.requests.get', side_effect=[osrm_reply(12.4, 21), osrm_reply(11.9, 143)]):
            data = self.client.get(self.url()).data
        self.assertEqual(data['car']['minutes'], 21)
        self.assertEqual(data['foot']['minutes'], 143)
        self.assertEqual(data['car']['distance_km'], 12.4)
        self.assertEqual(data['car']['geometry'][0], [14.7, -16.9])  # [latitude, longitude]
        self.assertGreater(data['straight_km'], 0)

    def test_when_the_routing_service_is_down_only_the_straight_distance_remains(self):
        with patch('apps.markets.routing.requests.get', side_effect=requests.Timeout()):
            data = self.client.get(self.url()).data
        self.assertIsNone(data['car'])
        self.assertIsNone(data['foot'])
        self.assertGreater(data['straight_km'], 0)

    def test_missing_or_invalid_position_is_refused(self):
        self.assertEqual(self.client.get(self.url('')).status_code, 400)
        self.assertEqual(self.client.get(self.url('lat=abc&lon=1')).status_code, 400)
        self.assertEqual(self.client.get(self.url('lat=95&lon=1')).status_code, 400)

    def test_a_market_without_position_cannot_be_routed(self):
        self.market.location_gps = ''
        self.market.save()
        self.assertEqual(self.client.get(self.url()).status_code, 400)
