import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/auth/data/auth_provider.dart';
import 'package:nataal_agro/features/auth/data/auth_repository.dart';
import 'package:nataal_agro/features/profile/data/profile_provider.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:nataal_agro/features/profile/data/notifications_provider.dart';
import 'package:nataal_agro/features/profile/domain/profile_model.dart';
import 'package:nataal_agro/main.dart' show sharedPreferencesProvider;
import 'package:nataal_agro/screens/profile/profile_screen.dart';
import 'package:nataal_agro/ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    bool privacyAccepted = true,
    String? otpCode,
  }) async {
    authenticated = true;
  }

  @override
  Future<Map<String, dynamic>> sendOtp(String phone, {String purpose = 'register'}) async {
    return {'status': 'success', 'message': 'OTP sent'};
  }

  @override
  Future<bool> verifyOtp(String phone, String code, {String purpose = 'register'}) async {
    return true;
  }

  @override
  Future<void> resetPassword(String phone, String code, String newPassword) async {}

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

class _FakeNotifications extends NotificationsNotifier {
  _FakeNotifications() : super(ApiClient());

  @override
  Future<void> fetchNotifications() async {}
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

  Future<void> pumpProfile(WidgetTester tester, _FakeAuthRepository repo, {UserProfile? profile, Object? error}) async {
    tester.view.physicalSize = const Size(390, 1800) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(repo),
          notificationsProvider.overrideWith((ref) => _FakeNotifications()),
          profileNotifierProvider.overrideWith((ref) => _FakeProfileNotifier(
                ref.watch(profileRepositoryProvider),
                initialProfile: profile,
                initialError: error,
              )),
        ],
        child: MaterialApp(
          theme: NaatalTheme.light,
          home: const EffectsScope(reduced: true, child: ProfileScreen()),
        ),
      ),
    );
    // Les animations d'ambiance bouclent : on avance l'horloge sans attendre le repos.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'Se déconnecter (après confirmation) déclenche authStateProvider.notifier.logout()',
    (WidgetTester tester) async {
      final fakeAuthRepo = _FakeAuthRepository();
      await pumpProfile(tester, fakeAuthRepo, profile: testProfile);

      expect(find.text('Amadou Diallo'), findsOneWidget);

      final logoutButton = find.text('Se déconnecter');
      expect(logoutButton, findsOneWidget);
      await tester.ensureVisible(logoutButton);
      await tester.pump(const Duration(milliseconds: 300));

      // Première étape : demande de confirmation, aucune déconnexion encore.
      await tester.tap(logoutButton);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Se déconnecter ?'), findsOneWidget);
      expect(fakeAuthRepo.wasLogoutCalled, isFalse);

      // Deuxième étape : confirmation dans la feuille.
      await tester.tap(find.text('Se déconnecter').last);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(fakeAuthRepo.wasLogoutCalled, isTrue);
      final container = ProviderScope.containerOf(tester.element(find.byType(ProfileScreen)));
      expect(container.read(authStateProvider).value, isFalse);
    },
  );

  testWidgets(
    'Se déconnecter en état d\'erreur du profil appelle authStateProvider.notifier.logout() sans confirmation',
    (WidgetTester tester) async {
      final fakeAuthRepo = _FakeAuthRepository();
      await pumpProfile(tester, fakeAuthRepo, error: 'Impossible de contacter le serveur');

      expect(find.text('Votre profil n\'a pas pu être chargé.'), findsOneWidget);

      final logoutButton = find.text('Se déconnecter');
      expect(logoutButton, findsOneWidget);
      await tester.tap(logoutButton);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(fakeAuthRepo.wasLogoutCalled, isTrue);
      final container = ProviderScope.containerOf(tester.element(find.byType(ProfileScreen)));
      expect(container.read(authStateProvider).value, isFalse);
    },
  );
}
