import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/auth/data/auth_provider.dart';
import 'package:nataal_agro/features/auth/data/auth_repository.dart';
import 'package:nataal_agro/features/profile/data/profile_provider.dart';
import 'package:nataal_agro/features/profile/domain/profile_model.dart';
import 'package:nataal_agro/features/profile/presentation/screens/profile_screen.dart';

/// Fake AuthRepository pour espionner l'appel réel à logout()
class _FakeAuthRepository implements AuthRepository {
  bool wasLogoutCalled = false;
  bool authenticated = true;

  @override
  Future<bool> isAuthenticated() async => authenticated;

  @override
  Future<Map<String, dynamic>> login(String phone, String password) async {
    authenticated = true;
    return {'access': 'fake-access', 'refresh': 'fake-refresh'};
  }

  @override
  Future<void> register({
    required String fullName,
    required String phone,
    required String password,
    String language = 'fr',
    String location = '',
    String role = 'farmer',
    String? email,
    String? dateOfBirth,
    List<String> mainCrops = const [],
  }) async {
    authenticated = true;
  }

  @override
  Future<void> logout() async {
    wasLogoutCalled = true;
    authenticated = false;
  }
}

/// Fake ProfileNotifier pour contrôler précisément l'état du profil
class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier(super.repository, {UserProfile? initialProfile, Object? initialError}) {
    if (initialError != null) {
      state = AsyncValue.error(initialError, StackTrace.empty);
    } else if (initialProfile != null) {
      state = AsyncValue.data(initialProfile);
    }
  }

  @override
  Future<void> loadProfile() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProfile = UserProfile(
    id: 1,
    phone: '+221770000000',
    fullName: 'Amadou Diallo',
    role: 'farmer',
    language: 'fr',
    location: 'Thiès, Sénégal',
    cropsCount: 3,
    mainCrops: ['Arachide', 'Mil', 'Maïs'],
    isVerified: true,
  );

  testWidgets(
    'Cliquer sur le bouton Se déconnecter de ProfileScreen déclenche authStateProvider.notifier.logout()',
    (WidgetTester tester) async {
      final fakeAuthRepo = _FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            profileNotifierProvider.overrideWith((ref) => _FakeProfileNotifier(
                  ref.watch(profileRepositoryProvider),
                  initialProfile: testProfile,
                )),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // Laisser le temps à Riverpod et au rendu
      await tester.pumpAndSettle();

      // Vérifier que le profil est bien affiché
      expect(find.text('Amadou Diallo'), findsOneWidget);

      // Trouver le bouton "Se déconnecter" principal
      final logoutButtonFinder = find.widgetWithText(ElevatedButton, 'Se déconnecter');
      expect(logoutButtonFinder, findsOneWidget);

      // Scroller jusqu'au bouton pour s'assurer qu'il est cliquable dans le CustomScrollView
      await tester.ensureVisible(logoutButtonFinder);
      await tester.pumpAndSettle();

      // Tap sur le bouton de déconnexion
      await tester.tap(logoutButtonFinder);
      await tester.pumpAndSettle();

      // Vérification : le repository a bien été appelé
      expect(fakeAuthRepo.wasLogoutCalled, isTrue);

      // Vérification : le Container Riverpod montre que l'authentification est false
      final container = ProviderScope.containerOf(tester.element(find.byType(ProfileScreen)));
      final authState = container.read(authStateProvider);
      expect(authState.value, isFalse);
    },
  );

  testWidgets(
    'Cliquer sur Se déconnecter en état d\'erreur du profil appelle authStateProvider.notifier.logout()',
    (WidgetTester tester) async {
      final fakeAuthRepo = _FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            profileNotifierProvider.overrideWith((ref) => _FakeProfileNotifier(
                  ref.watch(profileRepositoryProvider),
                  initialError: 'Impossible de contacter le serveur',
                )),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Vérifier l'état d'erreur
      expect(find.text('Impossible de contacter le serveur'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);

      // Trouver le bouton TextButton de déconnexion dans l'écran d'erreur
      final logoutTextButtonFinder = find.widgetWithText(TextButton, 'Se déconnecter');
      expect(logoutTextButtonFinder, findsOneWidget);

      // Cliquer sur Se déconnecter
      await tester.tap(logoutTextButtonFinder);
      await tester.pumpAndSettle();

      // Vérification
      expect(fakeAuthRepo.wasLogoutCalled, isTrue);

      final container = ProviderScope.containerOf(tester.element(find.byType(ProfileScreen)));
      final authState = container.read(authStateProvider);
      expect(authState.value, isFalse);
    },
  );
}
