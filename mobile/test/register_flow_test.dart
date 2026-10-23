import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/auth/data/auth_provider.dart';
import 'package:nataal_agro/features/auth/presentation/screens/register_screen.dart';
import 'package:nataal_agro/main.dart' show sharedPreferencesProvider;
import 'package:nataal_agro/ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository repo;
  late SharedPreferences prefs;

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: NaatalTheme.light,
          home: const EffectsScope(reduced: true, child: AuthStyle(child: RegisterScreen())),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await settle(tester);
  }

  Future<void> fillIdentity(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'Awa Diop');
    await tester.enterText(find.byType(TextField).at(1), '771234567');
    await tapText(tester, 'Continuer');
  }

  Future<void> fillPassword(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'Naatal2026x');
    await tapText(tester, 'J\'accepte les règles d\'utilisation');
    await tapText(tester, 'Continuer');
  }

  testWidgets('Un nouvel utilisateur s\'inscrit en trois étapes, sans e-mail, date de naissance ni région', (tester) async {
    await pumpScreen(tester);

    // Étape 1 : nom et téléphone seulement
    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.textContaining('naissance'), findsNothing);
    expect(find.textContaining('mail'), findsNothing);
    expect(find.byType(BrandLogo), findsOneWidget);
    await fillIdentity(tester);

    // Étape 2 : mot de passe et règles
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.byType(BrandLogo), findsOneWidget);
    await fillPassword(tester);

    // Étape 3 : le code d'essai est déjà écrit
    expect(find.text('Votre code'), findsOneWidget);
    expect(find.textContaining('1 2 3 4'), findsOneWidget);
    await tapText(tester, 'Créer mon compte');

    expect(repo.registered, isNotNull);
    expect(repo.registered!['fullName'], 'Awa Diop');
    expect(repo.registered!['phone'], '771234567');
    expect(repo.registered!['otpCode'], '1234');
    expect(repo.registered!['email'], isNull);
    expect(repo.registered!['dateOfBirth'], isNull);
    expect(repo.registered!['mainCrops'], isEmpty);
    expect(repo.registered!['privacyAccepted'], isTrue);
    // La suggestion de culture est la prochaine étape
    expect(prefs.getBool('pending_crop_setup'), isTrue);
  });

  testWidgets('Un nom ou un numéro manquant est signalé sans quitter la première étape', (tester) async {
    await pumpScreen(tester);
    await tapText(tester, 'Continuer');

    expect(find.text('Écrivez votre nom.'), findsOneWidget);
    expect(find.text('Le numéro a 9 chiffres.'), findsOneWidget);
    expect(find.text('Bienvenue'), findsOneWidget);
  });

  testWidgets('Il faut accepter les règles pour passer à la suite', (tester) async {
    await pumpScreen(tester);
    await fillIdentity(tester);
    await tester.enterText(find.byType(TextField).first, 'Naatal2026x');
    await tapText(tester, 'Continuer');

    expect(find.text('Touchez ici pour accepter.'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
  });

  testWidgets('Un mot de passe refusé par le serveur ramène à l\'étape du mot de passe avec le vrai motif', (tester) async {
    await pumpScreen(tester);
    repo.registerError = Exception('Ce mot de passe est trop courant.');
    await fillIdentity(tester);
    await fillPassword(tester);
    await tapText(tester, 'Créer mon compte');

    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Ce mot de passe est trop courant.'), findsOneWidget);
    expect(prefs.getBool('pending_crop_setup'), isFalse, reason: 'inscription ratée : pas de suggestion de culture');
  });

  testWidgets('Sans code d\'essai (vrai SMS), la personne écrit le code reçu', (tester) async {
    await pumpScreen(tester);
    repo.demoCode = false;
    await fillIdentity(tester);
    await fillPassword(tester);

    expect(find.textContaining('SMS'), findsOneWidget);
    for (final digit in ['4', '5', '6', '7']) {
      await tester.tap(find.text(digit));
      await settle(tester);
    }
    await tapText(tester, 'Créer mon compte');
    expect(repo.registered!['otpCode'], '4567');
  });
}

/// Fait avancer l'horloge : les écrans ont des animations courtes et quelques indicateurs qui tournent sans fin.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
