import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/cache/local_cache.dart';

/// Traduit la réponse d'erreur (400) de l'inscription en un message clair pour l'utilisateur.
/// Le serveur renvoie ses erreurs par champ (numéro, mot de passe, e-mail, date…) : on affiche le vrai motif
/// au lieu d'un message générique.
String registrationErrorMessage(dynamic data) {
  const labels = {
    'phone_number': '',
    'password': '',
    'full_name': 'Nom : ',
    'email': 'E-mail : ',
    'date_of_birth': 'Date de naissance : ',
    'privacy_accepted': '',
    'location': 'Région : ',
  };
  String? firstMessage(dynamic value) {
    if (value is List && value.isNotEmpty) return value.map((e) => e.toString()).take(2).join(' ');
    if (value != null && value.toString().trim().isNotEmpty) return value.toString();
    return null;
  }

  if (data is Map) {
    for (final entry in labels.entries) {
      final message = firstMessage(data[entry.key]);
      if (message != null) return '${entry.value}$message';
    }
    for (final key in ['non_field_errors', 'detail', 'error']) {
      final message = firstMessage(data[key]);
      if (message != null) return message;
    }
    for (final entry in data.entries) {
      final message = firstMessage(entry.value);
      if (message != null) return message;
    }
  }
  return 'Inscription impossible : vérifiez les informations saisies.';
}

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  String _formatPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+'), '').trim();
    if (phone.startsWith('+')) return phone;
    if (phone.startsWith('221')) return '+$phone';
    return '+221$phone';
  }

  /// Connexion de l'utilisateur
  Future<void> login(String phone, String password) async {
    try {
      final formattedPhone = _formatPhone(phone);
      final response = await _apiClient.post(
        AppConstants.loginEndpoint,
        data: {
          'phone_number': formattedPhone,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _apiClient.saveTokens(
          accessToken: data['access'],
          refreshToken: data['refresh'],
          role: data['role'],
          location: data['location'],
        );
      } else {
        throw Exception('Erreur de connexion');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Numéro de téléphone ou mot de passe incorrect.');
      }
      throw Exception('Impossible de se connecter au serveur.');
    }
  }

  /// Inscription d'un nouvel utilisateur
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
    try {
      final formattedPhone = _formatPhone(phone);
      final response = await _apiClient.post(
        AppConstants.registerEndpoint,
        data: {
          'full_name': fullName,
          'phone_number': formattedPhone,
          'password': password,
          'language': language,
          'location': location,
          'role': role,
          if (email != null && email.isNotEmpty) 'email': email,
          if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'date_of_birth': dateOfBirth,
          if (mainCrops.isNotEmpty) 'main_crops': mainCrops,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Si l'inscription réussit, on connecte directement l'utilisateur
        await login(formattedPhone, password);
      } else {
        throw Exception('Erreur d\'inscription');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception(registrationErrorMessage(e.response?.data));
      }
      throw Exception('Impossible de se connecter au serveur. Vérifiez votre connexion.');
    }
  }

  /// Déconnexion : invalide le jeton côté serveur puis purge le stockage local
  Future<void> logout() async {
    await _apiClient.logoutFromServer();
    
    // Purger le cache hors ligne de cet utilisateur
    final userId = await _apiClient.getUserId();
    final prefs = await SharedPreferences.getInstance();
    final cache = LocalCache(prefs, userId);
    await cache.clearUserCache();

    await _apiClient.clearTokens();
  }

  /// Vérifie si l'utilisateur est déjà connecté
  Future<bool> isAuthenticated() async {
    return await _apiClient.hasToken();
  }
}
