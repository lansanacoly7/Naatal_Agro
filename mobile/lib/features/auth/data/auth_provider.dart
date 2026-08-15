import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import 'auth_repository.dart';

// Provider global pour le ApiClient
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

// Provider global pour le AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient);
});

// Provider global pour l'état de l'authentification
final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<bool>>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});

class AuthNotifier extends StateNotifier<AsyncValue<bool>> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AsyncValue.loading()) {
    _checkAuthStatus();
  }

  /// Vérifie si l'utilisateur est déjà connecté au démarrage
  Future<void> _checkAuthStatus() async {
    state = const AsyncValue.loading();
    try {
      final isAuthenticated = await _repository.isAuthenticated();
      state = AsyncValue.data(isAuthenticated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Action de connexion
  Future<void> login(String phone, String password) async {
    state = const AsyncValue.loading();
    try {
      await _repository.login(phone, password);
      state = const AsyncValue.data(true);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Action d'inscription
  Future<void> register(String fullName, String phone, String password, String language, String location, {String role = 'farmer'}) async {
    state = const AsyncValue.loading();
    try {
      await _repository.register(fullName, phone, password, language, location, role: role);
      state = const AsyncValue.data(true);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Action de déconnexion
  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await _repository.logout();
      state = const AsyncValue.data(false);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
