import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  String _formatPhone(String phone) {
    phone = phone.trim();
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
  Future<void> register(
    String fullName,
    String phone,
    String password,
    String language,
    String location, {
    String role = 'farmer',
    String confirmPassword = '',
    String? region,
    List<String> primaryCrops = const [],
  }) async {
    try {
      final formattedPhone = _formatPhone(phone);
      final response = await _apiClient.post(
        AppConstants.registerEndpoint,
        data: {
          'full_name': fullName,
          'phone_number': formattedPhone,
          'password': password,
          'confirm_password': confirmPassword.isEmpty ? password : confirmPassword,
          'language': language,
          'location': location,
          'role': role,
          if (region != null && region.isNotEmpty) 'region': region,
          'primary_crops': primaryCrops,
        },
      );

      if (response.statusCode == 201) {
        // Si l'inscription réussit, on connecte directement l'utilisateur
        await login(formattedPhone, password);
      } else {
        throw Exception('Erreur d\'inscription');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        // Extraire le message d'erreur du backend si disponible
        final errData = e.response?.data;
        if (errData is Map) {
          final firstError = errData.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            throw Exception(firstError.first.toString());
          }
        }
        throw Exception('Ce numéro est déjà utilisé ou les données sont invalides.');
      }
      throw Exception('Impossible de s\'inscrire pour le moment.');
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    await _apiClient.clearTokens();
  }

  /// Vérifie si l'utilisateur est déjà connecté
  Future<bool> isAuthenticated() async {
    return await _apiClient.hasToken();
  }
}
