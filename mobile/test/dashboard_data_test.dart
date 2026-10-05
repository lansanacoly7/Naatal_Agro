import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/dashboard/data/models/dashboard_data.dart';

/// Réponse type de GET /api/dashboard/ (voir backend/apps/analytics/views.py)
Map<String, dynamic> _apiResponse() => {
      'agriculture': {'active_crops_count': 2, 'total_area_size': 3.5},
      'markets': [],
      'weather': <String, dynamic>{},
      'alerts': [
        {'id': 'a1', 'type': 'alert', 'message': 'Foyer de chenilles à Thiès', 'created_at': '2026-10-05T08:00:00Z'},
      ],
      'stockItems': [],
      'calendarEvents': [
        {'title': 'Semis', 'description': 'Semis du mil', 'date': '15\nOCT', 'phase': 'Mil'},
      ],
      'featuredProducts': [
        {'id': 'p1', 'name': 'Oignon', 'category': 'LÉGUME', 'price': 400.0, 'trend_percentage': -3.0, 'imageAsset': 'assets/images/products/oignon.png'},
      ],
    };

void main() {
  group('DashboardData.fromJson', () {
    test('accepte le prix numérique envoyé par le backend', () {
      final data = DashboardData.fromJson(_apiResponse());
      expect(data.featuredProducts.single.name, 'Oignon');
      expect(data.featuredProducts.single.price, '400 F/kg');
      expect(data.featuredProducts.single.variety, 'LÉGUME');
    });

    test('extrait le message des alertes renvoyées en objets', () {
      final data = DashboardData.fromJson(_apiResponse());
      expect(data.alerts, ['Foyer de chenilles à Thiès']);
    });

    test('ne fabrique aucune donnée factice quand le backend envoie des listes vides', () {
      final json = _apiResponse()
        ..['calendarEvents'] = []
        ..['featuredProducts'] = []
        ..['stockItems'] = [];
      final data = DashboardData.fromJson(json);
      expect(data.calendarEvents, isEmpty);
      expect(data.featuredProducts, isEmpty);
      expect(data.stockItems, isEmpty);
    });

    test('ne fabrique aucune donnée factice quand les clés sont absentes', () {
      final data = DashboardData.fromJson({'agriculture': <String, dynamic>{}, 'markets': [], 'weather': <String, dynamic>{}, 'alerts': []});
      expect(data.calendarEvents, isEmpty);
      expect(data.featuredProducts, isEmpty);
      expect(data.stockItems, isEmpty);
      expect(data.agriculture.activeCropsCount, 0);
    });
  });
}
