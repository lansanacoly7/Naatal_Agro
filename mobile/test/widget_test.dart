import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nataal_agro/main.dart';
import 'package:nataal_agro/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:nataal_agro/features/auth/presentation/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Affiche Onboarding au premier lancement si onboarding non vu', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': false});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const NataalAgroApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text("Réinventer l'agriculture"), findsOneWidget);
  });

  testWidgets('Redirige vers Login si onboarding déjà validé', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const NataalAgroApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Bon retour'), findsOneWidget);
  });
}
