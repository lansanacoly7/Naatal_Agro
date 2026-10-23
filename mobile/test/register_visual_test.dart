import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/location/region_locator.dart';
import 'package:nataal_agro/core/location/senegal_regions.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:nataal_agro/features/agriculture/data/guides_provider.dart';
import 'package:nataal_agro/features/agriculture/data/models/agronomic_guide.dart';
import 'package:nataal_agro/features/auth/data/auth_provider.dart';
import 'package:nataal_agro/features/auth/presentation/screens/register_screen.dart';
import 'package:nataal_agro/main.dart' show sharedPreferencesProvider;
import 'package:nataal_agro/screens/onboarding/crop_setup_screen.dart';
import 'package:nataal_agro/ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_repository.dart';
import 'support/visual_harness.dart';

/// Fiches d'EXEMPLE (captures d'écran de test uniquement) : les zones reprennent le style des vraies fiches.
class _FakeGuides extends GuidesNotifier {
  _FakeGuides(SharedPreferences prefs) : super(ApiClient(), prefs);

  @override
  Future<void> loadGuides({String? category, String? search}) async {
    state = GuidesListState(guides: const [
      AgronomicGuide(id: 'g1', slug: 'arachide', name: 'Arachide', category: 'legumineuse', summary: '', zones: 'Bassin arachidier : Louga, Thiès, Diourbel, Kaolack'),
      AgronomicGuide(id: 'g2', slug: 'oignon', name: 'Oignon', category: 'legume', summary: '', zones: 'Niayes. [1]'),
      AgronomicGuide(id: 'g3', slug: 'carotte', name: 'Carotte', category: 'legume', summary: '', zones: 'Niayes. [1]'),
      AgronomicGuide(id: 'g4', slug: 'riz-irrigue', name: 'Riz irrigué', category: 'cereale', summary: '', zones: 'Vallée du fleuve Sénégal. [1]'),
      AgronomicGuide(id: 'g5', slug: 'gombo', name: 'Gombo', category: 'legume', summary: ''),
      AgronomicGuide(id: 'g6', slug: 'mil', name: 'Mil', category: 'cereale', summary: '', zones: 'Sud des régions de Thiès et de Kaolack'),
      AgronomicGuide(id: 'g7', slug: 'bissap', name: 'Bissap', category: 'legume', summary: ''),
      AgronomicGuide(id: 'g8', slug: 'tomate-industrielle', name: 'Tomate industrielle', category: 'legume', summary: '', zones: 'Vallée du fleuve Sénégal. [1]'),
    ]);
  }
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _identityThenPassword(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'Awa Diop');
  await tester.enterText(find.byType(TextField).at(1), '771234567');
  await _tap(tester, 'Continuer');
}

/// Les images sont décodées en tâche de fond : sans cette attente, la capture les montrerait encore vides.
Future<void> _precache(WidgetTester tester, List<String> assets) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byType(Scaffold).first);
    for (final asset in assets) {
      await precacheImage(AssetImage(asset), context);
    }
  });
  await tester.pump(const Duration(milliseconds: 400));
}

const _cropImages = [
  'assets/images/products/arachide.png',
  'assets/images/products/oignon_local.png',
  'assets/images/products/carotte.png',
  'assets/images/products/riz.png',
  'assets/images/products/gombo.png',
  'assets/images/products/mil.png',
  'assets/images/products/tomate.png',
];

void main() {
  setUpAll(VisualHarness.init);

  final auth = [authRepositoryProvider.overrideWithValue(FakeAuthRepository())];
  final guides = [
    guidesNotifierProvider.overrideWith((ref) => _FakeGuides(ref.read(sharedPreferencesProvider))),
    regionDetectorProvider.overrideWithValue(() async => null),
  ];
  const phone = Size(390, 900);
  const register = AuthStyle(child: RegisterScreen());
  final logo = [BrandLogo.asset];

  testWidgets('Inscription : étape 1', (tester) async {
    await VisualHarness.shoot(tester, 'register_1', register, overrides: auth, size: phone, afterPump: (t) => _precache(t, logo));
  });

  testWidgets('Inscription : étape 2', (tester) async {
    await VisualHarness.shoot(tester, 'register_2', register, overrides: auth, size: phone, afterPump: (t) async {
      await _identityThenPassword(t);
      await t.enterText(find.byType(TextField).first, 'Naatal2');
      await _precache(t, logo);
    });
  });

  testWidgets('Inscription : étape 3', (tester) async {
    await VisualHarness.shoot(tester, 'register_3', register, overrides: auth, size: phone, afterPump: (t) async {
      await _identityThenPassword(t);
      await t.enterText(find.byType(TextField).first, 'Naatal2026x');
      await _tap(t, 'J\'accepte les règles d\'utilisation');
      await _tap(t, 'Continuer');
      await _precache(t, logo);
    });
  });

  testWidgets('Suggestion de culture : région à choisir', (tester) async {
    await VisualHarness.shoot(tester, 'crop_setup_noregion', const CropSetupScreen(), overrides: guides, size: phone, afterPump: (t) => _precache(t, [...logo, ..._cropImages]));
  });

  testWidgets('Suggestion de culture : région trouvée, deux cultures choisies', (tester) async {
    final found = [
      guidesNotifierProvider.overrideWith((ref) => _FakeGuides(ref.read(sharedPreferencesProvider))),
      regionDetectorProvider.overrideWithValue(() async => SenegalRegions.fromName('Thiès')),
    ];
    await VisualHarness.shoot(tester, 'crop_setup_thies', const CropSetupScreen(), overrides: found, size: const Size(390, 1500), afterPump: (t) async {
      await _precache(t, [...logo, ..._cropImages]);
      await _tap(t, 'Arachide');
      await _tap(t, 'Oignon');
    });
  });
}
