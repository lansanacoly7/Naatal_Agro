import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/agriculture/data/models/agronomic_guide.dart';
import 'package:nataal_agro/features/agriculture/data/models/crop.dart';
import 'package:nataal_agro/features/agriculture/presentation/screens/cultures_screen.dart';
import 'package:nataal_agro/features/dashboard/data/models/dashboard_data.dart';
import 'package:nataal_agro/features/dashboard/presentation/widgets/advice_carousel.dart';
import 'package:nataal_agro/features/finances/data/models/financial_summary.dart';
import 'package:nataal_agro/features/inventory/data/models/stock_item.dart';

/// Météo par défaut : aucune donnée disponible (aucun conseil météo déclenché).
WeatherSummary _noWeather() => WeatherSummary(
      location: 'Inconnue',
      temp: 0,
      humidity: 0,
      rainfall: 0,
      isAvailable: false,
    );

List<AdviceTip> _advice({
  List<Crop> crops = const [],
  List<StockItem> stock = const [],
  FinancialSummary? finances,
  List<MarketPrice> prices = const [],
  WeatherSummary? weather,
  List<String> alerts = const [],
}) =>
    buildAdvice(
      crops: crops,
      stock: stock,
      finances: finances,
      prices: prices,
      weather: weather ?? _noWeather(),
      alerts: alerts,
    );

Crop _crop({
  required String name,
  int daysToHarvest = 60,
  int plantedDaysAgo = 30,
}) =>
    Crop(
      id: 'crop-1',
      name: name,
      cropType: name,
      plantingDate: DateTime.now().subtract(Duration(days: plantedDaysAgo)).toIso8601String(),
      expectedHarvestDate: DateTime.now().add(Duration(days: daysToHarvest)).toIso8601String(),
      status: 'active',
      areaSize: 1.5,
      location: 'Parcelle A',
    );

StockItem _stock({required String name, required bool alert}) => StockItem(
      id: 'stock-1',
      name: name,
      quantity: alert ? 5 : 200,
      unit: 'kg',
      alertStatus: alert,
      updatedAt: '2026-10-10T12:00:00Z',
    );

void main() {
  group('buildAdvice', () {
    test('sans culture, le conseil propose d\'ajouter la première culture', () {
      final tips = _advice();

      final semis = tips.where((t) => t.tag == 'SEMIS').toList();
      expect(semis, hasLength(1), reason: 'un seul conseil SEMIS attendu');
      expect(semis.first.title, 'Ajoutez votre première culture');
      expect(semis.first.route, '/agriculture/add');
    });

    test('sans culture, la carte Naatal IA est toujours en dernière position', () {
      final tips = _advice();

      expect(tips.last.tag, 'NAATAL IA');
      expect(tips.last.route, '/ai');
      expect(tips.last.isTab, isTrue);
    });

    test('un stock en alerte produit un conseil STOCK « stock bas »', () {
      final tips = _advice(stock: [_stock(name: 'Engrais NPK', alert: true)]);

      final stockTips = tips.where((t) => t.tag == 'STOCK').toList();
      expect(stockTips, hasLength(1));
      expect(stockTips.first.title, 'Engrais NPK : stock bas');
      expect(stockTips.first.text, contains('kg restants'));
      expect(stockTips.first.route, '/stock');
    });

    test('des dépenses sans vente produisent un conseil FINANCES', () {
      final tips = _advice(
        finances: FinancialSummary(totalRevenue: 0, totalExpenses: 25000, balance: -25000),
      );

      final financeTips = tips.where((t) => t.tag == 'FINANCES').toList();
      expect(financeTips, hasLength(1));
      expect(financeTips.first.title, '25 000 F dépensés, aucune vente');
      expect(financeTips.first.route, '/finances');
    });

    test('les conseils sont limités à 6 cartes, Naatal IA restant en dernier', () {
      final tips = _advice(
        crops: [_crop(name: 'Tomate', daysToHarvest: 3)],
        stock: [_stock(name: 'Engrais NPK', alert: true)],
        finances: FinancialSummary(totalRevenue: 0, totalExpenses: 12000, balance: -12000),
        prices: [
          MarketPrice(
            productName: 'Tomate',
            price: 1500,
            trend: 'up',
            marketName: 'Marché de Dakar',
            changePercent: 5.2,
          ),
        ],
        weather: WeatherSummary(location: 'Dakar', temp: 28, humidity: 80, rainfall: 12),
        alerts: ['Vigilance pluie forte annoncée.'],
      );

      expect(tips, hasLength(6), reason: 'au plus 5 conseils + la carte IA');
      expect(tips.last.tag, 'NAATAL IA');
    });
  });

  group('guideForProduct', () {
    final guides = const [
      AgronomicGuide(
        id: 'g-oignon',
        slug: 'oignon',
        name: 'Oignon (Allium cepa)',
        category: 'legume',
        summary: 'Bulbe de conservation.',
        cycleDaysMin: 90,
        cycleDaysMax: 120,
      ),
      AgronomicGuide(
        id: 'g-tomate',
        slug: 'tomate',
        name: 'Tomate',
        category: 'legume',
        summary: 'Fruit comestible.',
        cycleDaysMin: 60,
        cycleDaysMax: 90,
      ),
    ];

    test('« Oignon Local » trouve la fiche oignon', () {
      final guide = guideForProduct('Oignon Local', guides);

      expect(guide, isNotNull);
      expect(guide!.slug, 'oignon');
      expect(guide.name, 'Oignon (Allium cepa)');
    });

    test('un produit inconnu renvoie null', () {
      expect(guideForProduct('Smartphone Pro Max', guides), isNull);
    });

    test('un nom trop court (moins de 3 caractères) renvoie null', () {
      expect(guideForProduct('Mi', guides), isNull);
    });
  });
}
