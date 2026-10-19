import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:nataal_agro/features/finances/data/finances_provider.dart';
import 'package:nataal_agro/features/finances/data/models/financial_summary.dart';
import 'package:nataal_agro/features/inventory/data/inventory_provider.dart';
import 'package:nataal_agro/features/inventory/data/models/stock_item.dart';
import 'package:nataal_agro/features/profile/data/profile_provider.dart';
import 'package:nataal_agro/features/profile/data/profile_repository.dart';
import 'package:nataal_agro/features/profile/domain/profile_model.dart';
import 'package:nataal_agro/main.dart' show sharedPreferencesProvider;
import 'package:nataal_agro/ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Banc de captures d'écran : dessine un écran avec des données d'EXEMPLE (réservées
/// aux tests, jamais affichées dans l'application) et enregistre l'image en PNG.
class VisualHarness {
  static const Size phone = Size(390, 844);

  /// Dossier de sortie : variable SHOTS_DIR, sinon `build/shots`.
  static String get outDir => Platform.environment['SHOTS_DIR'] ?? 'build/shots';

  static Future<void> init() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    for (final channelName in [
      'plugins.flutter.io/path_provider',
      'plugins.flutter.io/path_provider_windows',
      'plugins.flutter.io/path_provider_android',
      'plugins.flutter.io/path_provider_ios',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channelName), (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      });
    }
    await _loadFont('Onest', File('assets/fonts/Onest.ttf'));
    final sdk = Platform.environment['FLUTTER_ROOT'] ??
        'C:/Users/HP/Documents/Flutter/flutter_windows_3.41.1-stable/flutter';
    await _loadFont('MaterialIcons', File('$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf'));
    Directory(outDir).createSync(recursive: true);
  }

  static Future<void> _loadFont(String family, File file) async {
    if (!file.existsSync()) return;
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
  }

  /// Dessine [screen] puis enregistre `build/shots/<name>.png`.
  static Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget screen, {
    bool dark = false,
    List<Override> overrides = const [],
    Duration settle = const Duration(milliseconds: 1600),
    Size size = phone,
    Future<void> Function(WidgetTester tester)? afterPump,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs), ...overrides],
        child: RepaintBoundary(
          key: key,
          child: DefaultAssetBundle(
            bundle: _DiskAssetBundle(),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: NaatalTheme.light,
              darkTheme: NaatalTheme.dark,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: EffectsScope(reduced: false, child: screen),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Les animations d'ambiance tournent en boucle : on avance l'horloge image par image.
    for (var elapsed = Duration.zero; elapsed < settle; elapsed += const Duration(milliseconds: 100)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (afterPump != null) {
      await afterPump(tester);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$outDir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
  }
}

// ───────────── Faux fournisseurs (pas de réseau) ─────────────

class FakeTransactions extends TransactionsNotifier {
  FakeTransactions() : super(ApiClient());
  static List<TransactionItem> seed = [];

  @override
  Future<void> fetchTransactions() async => state = AsyncValue.data(seed);
}

class FakeInventory extends InventoryNotifier {
  FakeInventory() : super(ApiClient());
  static List<StockItem> seed = [];

  @override
  Future<void> fetchInventory() async => state = AsyncValue.data(seed);
}

class FakeProfile extends ProfileNotifier {
  FakeProfile() : super(ProfileRepository(ApiClient()));
  static UserProfile? seed;

  @override
  Future<void> loadProfile() async => state = AsyncValue.data(seed!);
}

final fakeSummary = FinancialSummary(totalRevenue: 185000, totalExpenses: 15000, balance: 170000);

class _DiskAssetBundle extends PlatformAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final file = File(key);
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      return ByteData.sublistView(bytes);
    }
    return super.load(key);
  }
}
