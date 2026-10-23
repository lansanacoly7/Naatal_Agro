import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:nataal_agro/features/agriculture/data/agriculture_provider.dart';
import 'package:nataal_agro/features/agriculture/data/guides_provider.dart';
import 'package:nataal_agro/features/agriculture/data/models/agronomic_guide.dart';
import 'package:nataal_agro/features/agriculture/data/models/crop.dart';
import 'package:nataal_agro/features/dashboard/data/dashboard_provider.dart';
import 'package:nataal_agro/features/dashboard/data/models/dashboard_data.dart';
import 'package:nataal_agro/features/finances/data/finances_provider.dart';
import 'package:nataal_agro/features/finances/data/models/financial_summary.dart';
import 'package:nataal_agro/features/inventory/data/inventory_provider.dart';
import 'package:nataal_agro/features/inventory/data/models/stock_item.dart';
import 'package:nataal_agro/features/markets/data/markets_provider.dart';
import 'package:nataal_agro/features/markets/data/models/price.dart';
import 'package:nataal_agro/features/markets/data/models/product.dart';
import 'package:nataal_agro/screens/markets/markets_data.dart';
import 'package:nataal_agro/screens/markets/markets_screen.dart';
import 'package:nataal_agro/features/profile/data/notifications_provider.dart';
import 'package:nataal_agro/features/profile/data/profile_provider.dart';
import 'package:nataal_agro/features/profile/domain/profile_model.dart';
import 'package:nataal_agro/main.dart' show sharedPreferencesProvider;
import 'package:nataal_agro/screens/crops/add_crop_screen.dart';
import 'package:nataal_agro/screens/crops/crop_detail_screen.dart';
import 'package:nataal_agro/screens/crops/crops_screen.dart';
import 'package:nataal_agro/screens/assistant/assistant_screen.dart';
import 'package:nataal_agro/features/auth/presentation/screens/login_screen.dart';
import 'package:nataal_agro/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:nataal_agro/features/auth/presentation/screens/register_screen.dart';
import 'package:nataal_agro/screens/finances/finances_screen.dart';
import 'package:nataal_agro/screens/guides/guides_screens.dart';
import 'package:nataal_agro/screens/profile/profile_screen.dart';
import 'package:nataal_agro/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:nataal_agro/features/dashboard/presentation/screens/mon_dashboard_screen.dart';
import 'package:nataal_agro/screens/sell/sell_screen.dart';
import 'package:nataal_agro/screens/stock/stock_screen.dart';
import 'package:nataal_agro/ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/visual_harness.dart';

/// Données d'EXEMPLE pour les captures d'écran de test uniquement.
String _d(int daysFromNow) => DateTime.now().add(Duration(days: daysFromNow)).toIso8601String().split('T').first;

final _crops = <Crop>[
  Crop(
    id: 'c1', name: 'Oignon', cropType: 'Oignon', plantingDate: _d(-62), expectedHarvestDate: _d(38),
    status: 'active', areaSize: 0.8, location: 'Thiès', guideSlug: 'oignon', guideName: 'Oignon (Niayes)',
    activities: [
      CropActivity(id: 'a1', cropId: 'c1', activityType: 'Engrais', description: 'NPK', date: _d(-5), cost: 15000, createdAt: _d(-5)),
      CropActivity(id: 'a2', cropId: 'c1', activityType: 'Arrosage', description: '', date: _d(-1), createdAt: _d(-1)),
    ],
    harvests: const [],
  ),
  Crop(id: 'c2', name: 'Arachide', cropType: 'Arachide', plantingDate: _d(-21), expectedHarvestDate: _d(99), status: 'active', areaSize: 1.5, location: 'Thiès'),
  Crop(id: 'c3', name: 'Mil', cropType: 'Mil', plantingDate: _d(-72), expectedHarvestDate: _d(13), status: 'active', areaSize: 2, location: 'Thiès'),
];

final _stock = <StockItem>[
  StockItem(id: 's1', name: 'Oignon', quantity: 120, unit: 'sacs', alertStatus: false, aiStorageAdvice: 'Stockez au sec, à l\'ombre, dans un local aéré.', updatedAt: _d(-2)),
  StockItem(id: 's2', name: 'Arachide décortiquée', quantity: 4, unit: 'sacs', alertStatus: true, updatedAt: _d(-3)),
  StockItem(id: 's3', name: 'Mil', quantity: 30, unit: 'sacs', alertStatus: false, updatedAt: _d(-6)),
];

final _transactions = <TransactionItem>[
  TransactionItem(id: 't1', type: 'income', amount: 80000, date: _d(-1), description: 'Vente de Oignon (40 sacs)'),
  TransactionItem(id: 't2', type: 'expense', amount: 15000, date: _d(-5), description: 'Activité culture Oignon : Engrais'),
  TransactionItem(id: 't3', type: 'income', amount: 45000, date: _d(-8), description: 'Vente de Arachide (45 sacs)'),
  TransactionItem(id: 't4', type: 'income', amount: 60000, date: _d(-12), description: 'Aide de campagne'),
];

final _dashboard = DashboardData(
  agriculture: AgricultureSummary(activeCropsCount: 3, totalAreaSize: 4.3),
  markets: [
    MarketPrice(productName: 'Oignon', price: 435, trend: 'up', marketName: '12 marchés', minPrice: 380, maxPrice: 500, marketsCount: 12, date: DateTime.now().subtract(const Duration(days: 2)), changePercent: 4.2),
    MarketPrice(productName: 'Arachide', price: 760, trend: 'down', marketName: '9 marchés', minPrice: 700, maxPrice: 820, marketsCount: 9, date: DateTime.now().subtract(const Duration(days: 2)), changePercent: -2.8),
  ],
  weather: WeatherSummary(location: 'thiès, sénégal', temp: 33, humidity: 41, rainfall: 0, date: DateTime.now()),
  alerts: const ['Un foyer de mildiou a été signalé près de Thiès. Surveillez vos parcelles.'],
);

final _profile = UserProfile(
  id: 'u1', phone: '+221770000000', fullName: 'Awa Diop', role: 'farmer', language: 'fr',
  location: 'Thiès, Sénégal', cropsCount: 3, mainCrops: const ['Oignon', 'Arachide'], isVerified: false,
);

class _FakeNotifications extends NotificationsNotifier {
  _FakeNotifications() : super(ApiClient());

  @override
  Future<void> fetchNotifications() async {}
}

class _FakeGuides extends GuidesNotifier {
  _FakeGuides(SharedPreferences prefs) : super(ApiClient(), prefs);

  @override
  Future<void> loadGuides({String? category, String? search}) async {
    state = GuidesListState(guides: const [
      AgronomicGuide(id: 'g1', slug: 'oignon', name: 'Oignon', category: 'legume', summary: '', cycleDaysMin: 70, cycleDaysMax: 120),
      AgronomicGuide(id: 'g2', slug: 'arachide', name: 'Arachide', category: 'legumineuse', summary: '', cycleDaysMin: 80, cycleDaysMax: 125),
      AgronomicGuide(id: 'g3', slug: 'tomate', name: 'Tomate industrielle', category: 'legume', summary: ''),
      AgronomicGuide(id: 'g4', slug: 'mil', name: 'Mil', category: 'cereale', summary: '', cycleDaysMin: 75, cycleDaysMax: 95),
    ]);
  }
}

List<Override> _overrides({bool empty = false}) {
  FakeTransactions.seed = empty ? [] : _transactions;
  FakeInventory.seed = empty ? [] : _stock;
  FakeProfile.seed = _profile;
  return [
    dashboardDataProvider.overrideWith((ref) async => empty
        ? DashboardData(
            agriculture: AgricultureSummary(activeCropsCount: 0, totalAreaSize: 0),
            markets: const [],
            weather: WeatherSummary(location: 'Inconnue', temp: 0, humidity: 0, rainfall: 0, isAvailable: false),
            alerts: const [],
          )
        : _dashboard),
    cropsProvider.overrideWith((ref) async => empty ? <Crop>[] : _crops),
    financialSummaryProvider.overrideWith((ref) async => empty
        ? FinancialSummary(totalRevenue: 0, totalExpenses: 0, balance: 0)
        : FinancialSummary(totalRevenue: 185000, totalExpenses: 15000, balance: 170000)),
    inventoryProvider.overrideWith((ref) async => empty ? <StockItem>[] : _stock),
    transactionsNotifierProvider.overrideWith((ref) => FakeTransactions()),
    inventoryNotifierProvider.overrideWith((ref) => FakeInventory()),
    profileNotifierProvider.overrideWith((ref) => FakeProfile()),
    notificationsProvider.overrideWith((ref) => _FakeNotifications()),
    productPriceHistoryProvider.overrideWith((ref, name) async => empty
        ? <Price>[]
        : [
            for (var d = 29; d >= 0; d--)
              for (var m = 0; m < 3; m++)
                Price(
                  id: 'p$d$m', marketId: 'm$m', productName: name,
                  priceValue: 430 + ((d * 7 + m * 13) % 40) - 20 + (30 - d) * 0.8,
                  trend: 'stable', date: _d(-d),
                ),
          ]),
    guidesNotifierProvider.overrideWith((ref) => _FakeGuides(ref.read(sharedPreferencesProvider))),
    allProductsProvider.overrideWith((ref) async => empty
        ? <Product>[]
        : [
            Product(id: '1', name: 'Oignon', category: 'Légume', currentPrice: 435, trendPercentage: 4.2, imageAsset: '', isTrending: true),
            Product(id: '2', name: 'Arachide', category: 'Légumineuse', currentPrice: 760, trendPercentage: -2.8, imageAsset: '', isTrending: false),
            Product(id: '3', name: 'Tomate', category: 'Légume', currentPrice: 350, trendPercentage: 1.5, imageAsset: '', isTrending: false),
          ]),
    marketQuotesProvider.overrideWith((ref, product) async => empty
        ? <MarketQuote>[]
        : [
            MarketQuote(marketId: 'm1', marketName: 'Castors', region: 'Dakar', productName: product, price: 460, trend: 'up', date: DateTime.now()),
            MarketQuote(marketId: 'm2', marketName: 'Tilène', region: 'Dakar', productName: product, price: 435, trend: 'stable', date: DateTime.now()),
            MarketQuote(marketId: 'm3', marketName: 'Thiès Central', region: 'Thiès', productName: product, price: 410, trend: 'down', date: DateTime.now()),
          ]),
  ];
}

void main() {
  setUpAll(VisualHarness.init);

  for (final dark in [false, true]) {
    final tag = dark ? 'dark' : 'light';

    testWidgets('Accueil ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'home_$tag', const DashboardScreen(), dark: dark, overrides: _overrides(), size: const Size(390, 1900));
      expect(find.textContaining('Bonjour'), findsWidgets);
      expect(find.text('Oignon'), findsWidgets);
      expect(find.text('Relevés indicatifs, non officiels.'), findsOneWidget);
    });

    testWidgets('Accueil sans donnée ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'home_empty_$tag', const DashboardScreen(), dark: dark, overrides: _overrides(empty: true), size: const Size(390, 1900));
      expect(find.text('Météo non disponible'), findsOneWidget);
      expect(find.textContaining('Aucun prix pour vos cultures'), findsOneWidget);
    });

    testWidgets('Cultures ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'crops_$tag', const CropsScreen(), dark: dark, overrides: _overrides());
      expect(find.text('Mes cultures'), findsWidgets);
      expect(find.text('Arachide'), findsOneWidget);
    });

    testWidgets('Fiche culture ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'crop_detail_$tag', const CropDetailScreen(cropId: 'c1'), dark: dark, overrides: _overrides(), size: const Size(390, 1400));
      expect(find.text('Calendrier'), findsOneWidget);
      expect(find.text('Engrais'), findsOneWidget);
    });

    testWidgets('Vente ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'sell_$tag', const SellScreen(), dark: dark, overrides: _overrides(), afterPump: (t) async {
        Finder key(String k) => find.descendant(of: find.byType(NumericKeypad), matching: find.text(k));
        await t.tap(key('4'));
        await t.tap(key('0'));
        await t.pump();
        await t.tap(find.text('Prix par sac'));
        await t.pump();
        for (final k in ['2', '0', '0', '0']) {
          await t.tap(key(k));
          await t.pump();
        }
        await t.pump(const Duration(milliseconds: 600));
      });
      expect(find.text('Confirmer la vente'), findsOneWidget);
      expect(find.text('80 000'), findsOneWidget);
    });

    testWidgets('Stock ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'stock_$tag', const StockScreen(), dark: dark, overrides: _overrides());
      expect(find.text('Ajouter un produit'), findsOneWidget);
      expect(find.text('Stock bas'), findsOneWidget);
    });

    testWidgets('Finances ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'finances_$tag', const FinancesScreen(), dark: dark, overrides: _overrides());
      expect(find.text('Finances'), findsWidgets);
      expect(find.textContaining('Vente de Oignon'), findsOneWidget);
    });

    testWidgets('Mon Dashboard ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'mon_dashboard_$tag', const MonDashboardScreen(), dark: dark, overrides: _overrides(), size: const Size(390, 1600));
      expect(find.text('Mon exploitation'), findsWidgets);
      expect(find.text('Trésorerie nette'), findsOneWidget);
      expect(find.text('Stock valorisé'), findsOneWidget);
      expect(find.text('Opportunités du marché'), findsOneWidget);
    });

    testWidgets('Nouvelle culture ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'add_crop_$tag', const AddCropScreen(), dark: dark, overrides: _overrides(), size: const Size(390, 1300));
      expect(find.text('Enregistrer la culture'), findsOneWidget);
    });

    testWidgets('Profil ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'profile_$tag', const ProfileScreen(), dark: dark, overrides: _overrides(), size: const Size(390, 1500));
      expect(find.text('Awa Diop'), findsWidgets);
    });

    testWidgets('Assistant ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'assistant_$tag', const AssistantScreen(), dark: dark, overrides: _overrides());
      expect(find.byType(AssistantScreen), findsOneWidget);
    });

    testWidgets('Fiches techniques ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'guides_$tag', const GuidesListScreen(), dark: dark, overrides: _overrides());
      expect(find.text('Tomate industrielle'), findsOneWidget);
    });

    testWidgets('Connexion ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'login_$tag', const AuthStyle(child: LoginScreen()), dark: dark, overrides: _overrides(), size: const Size(390, 900));
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    });

    testWidgets('Inscription ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'register_$tag', const AuthStyle(child: RegisterScreen()), dark: dark, overrides: _overrides(), size: const Size(390, 900));
      expect(find.text('Bienvenue'), findsOneWidget);
      expect(find.byType(BrandLogo), findsOneWidget);
    });

    testWidgets('Présentation ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'onboarding_$tag', const AuthStyle(child: OnboardingScreen()), dark: dark, overrides: _overrides(), size: const Size(390, 800));
      expect(find.text("Réinventer l'agriculture"), findsOneWidget);
    });

    testWidgets('Marchés ($tag)', (tester) async {
      await VisualHarness.shoot(tester, 'markets_$tag', const MarketsScreen(), dark: dark, overrides: _overrides(), size: const Size(390, 844));
      expect(find.byType(MarketsScreen), findsOneWidget);
    });
  }
}
