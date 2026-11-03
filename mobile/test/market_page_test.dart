import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nataal_agro/screens/markets/market_page.dart';
import 'package:nataal_agro/screens/markets/market_page_data.dart';
import 'package:nataal_agro/screens/markets/markets_data.dart' show UserLocation, UserLocationNotifier, userLocationProvider;

import 'support/visual_harness.dart';

Map<String, dynamic> product(String name, num price, String trend, {Map<String, dynamic>? forecast, int days = 25}) => {
      'name': name,
      'price': price,
      'trend': trend,
      'date': '2026-10-22',
      'change_week_percent': 3.2,
      'min_30d': price - 20,
      'max_30d': price + 30,
      'avg_30d': price,
      'observed_days': days,
      'markets_compared': 19,
      'cheaper_markets': 4,
      'history': [
        for (var i = 0; i < days; i++) {'date': DateTime(2026, 10, 22).subtract(Duration(days: days - 1 - i)).toIso8601String().substring(0, 10), 'price': price - 20 + i},
      ],
      'forecast': forecast,
    };

final overviewJson = {
  'id': 'm1',
  'name': 'Marché Castors',
  'region': 'Dakar',
  'location_gps': '14.7077,-17.4526',
  'opening_time': '08:00',
  'closing_time': '18:00',
  'hours_verified': false,
  'last_update': '2026-10-22',
  'price_records': 1174,
  'featured': ['Oignon', 'Tomate'],
  'products': [
    product('Oignon', 435, 'up', forecast: {
      'direction': 'up', 'expected_price': 470, 'low': 450, 'high': 490, 'change_percent': 8.0,
      'horizon_days': 7, 'basis_days': 21, 'basis_points': 21, 'confidence': 'good',
    }),
    product('Tomate', 350, 'down', days: 3),
    product('Mil', 300, 'stable', days: 12),
  ],
};

class _Located extends UserLocationNotifier {
  _Located(super.ref) {
    state = const UserLocation(position: LatLng(14.7167, -17.4677));
  }
}

class _Unlocated extends UserLocationNotifier {
  _Unlocated(super.ref);

  @override
  Future<void> locate() async {}
}

List<Override> overrides({required bool located}) => [
      marketOverviewProvider('m1').overrideWith((ref) async => MarketOverview.fromJson(overviewJson)),
      userLocationProvider.overrideWith((ref) => located ? _Located(ref) : _Unlocated(ref)),
      marketRouteProvider.overrideWith((ref, key) async => MarketRoute.fromJson({
            'straight_km': 1.9,
            'destination': {'lat': 14.7077, 'lon': -17.4526},
            'car': {'minutes': 21, 'distance_km': 12.4, 'geometry': [[14.7, -17.4], [14.7077, -17.4526]]},
            'foot': {'minutes': 143, 'distance_km': 11.9, 'geometry': [[14.7, -17.4], [14.7077, -17.4526]]},
          })),
    ];

void main() {
  setUpAll(VisualHarness.init);

  test('les données du serveur se lisent sans rien inventer', () {
    final market = MarketOverview.fromJson(overviewJson);
    expect(market.featuredProducts.map((p) => p.name), ['Oignon', 'Tomate']);
    expect(market.products.firstWhere((p) => p.name == 'Tomate').forecast, isNull);
    expect(market.isOpenAt(DateTime(2026, 10, 24, 10)), isTrue);
    expect(market.isOpenAt(DateTime(2026, 10, 24, 19)), isFalse);
    expect(durationWords(21), '21 min');
    expect(durationWords(143), '2 h 23');
    expect(durationWords(120), '2 h');
  });

  for (final dark in [false, true]) {
    final tag = dark ? 'dark' : 'light';

    testWidgets('Page marché, avec position ($tag)', (tester) async {
      await VisualHarness.shoot(
        tester,
        'market_page_$tag',
        MarketPage(marketId: 'm1', now: DateTime(2026, 10, 24, 10)),
        dark: dark,
        overrides: overrides(located: true),
        size: const Size(390, 1500),
      );
      expect(find.text('Marché Castors'), findsWidgets);
      expect(find.text('Ouvert maintenant'), findsOneWidget);
      expect(find.textContaining('horaires indicatifs'), findsOneWidget);
      expect(find.textContaining('Prix mis à jour il y a 2 jours'), findsOneWidget);
      expect(find.text('Pour y aller'), findsOneWidget);
      expect(find.text('21 min'), findsOneWidget);
      expect(find.text('2 h 23'), findsOneWidget);
      expect(find.text('Produits phares'), findsOneWidget);
      expect(find.text('Tous les produits (3)'), findsOneWidget);
    });
  }

  testWidgets('sans position, la page propose de calculer le trajet au lieu d\'en inventer un', (tester) async {
    await VisualHarness.shoot(
      tester,
      'market_page_nolocation',
      MarketPage(marketId: 'm1', now: DateTime(2026, 10, 24, 20)),
      overrides: overrides(located: false),
      size: const Size(390, 1500),
    );
    expect(find.text('Fermé maintenant'), findsOneWidget);
    expect(find.text('Voir le trajet'), findsOneWidget);
    expect(find.text('21 min'), findsNothing);
  });

  testWidgets('toucher un produit montre son évolution et sa prévision', (tester) async {
    await VisualHarness.shoot(
      tester,
      'market_page_product',
      MarketPage(marketId: 'm1', now: DateTime(2026, 10, 24, 10)),
      overrides: overrides(located: true),
      size: const Size(390, 1500),
      afterPump: (t) async {
        await t.tap(find.text('435 F').last);
        for (var i = 0; i < 8; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      },
    );
    expect(find.text('Ces 30 derniers jours'), findsOneWidget);
    expect(find.text('Et la semaine prochaine ?'), findsOneWidget);
    expect(find.text('Le prix devrait monter.'), findsOneWidget);
    expect(find.textContaining('Entre 450 et 490 F'), findsOneWidget);
    expect(find.textContaining('Ce n\'est pas une promesse'), findsOneWidget);
    expect(find.textContaining('Moins cher dans 4 marchés sur 19'), findsOneWidget);
  });

  testWidgets('un produit trop peu relevé n\'a pas de prévision', (tester) async {
    await VisualHarness.shoot(
      tester,
      'market_page_product_noforecast',
      MarketPage(marketId: 'm1', now: DateTime(2026, 10, 24, 10)),
      overrides: overrides(located: true),
      size: const Size(390, 1500),
      afterPump: (t) async {
        await t.tap(find.text('350 F').last);
        for (var i = 0; i < 8; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      },
    );
    expect(find.text('Pas assez de relevés pour prévoir le prix.'), findsOneWidget);
  });
}
