import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../domain/profile_model.dart';

class ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepository(this._apiClient);

  /// Préfixe du cache de profil : une entrée par utilisateur (jamais partagée entre comptes).
  static const String profileCachePrefix = 'cached_user_profile_';

  Future<String> _cacheKey() async => '$profileCachePrefix${await _apiClient.getUserId()}';

  /// Récupère le profil réel de l'utilisateur connecté via /api/users/me/
  ///
  /// Le cache local ne sert qu'en cas de coupure réseau ou d'erreur serveur (5xx), et uniquement
  /// pour le compte actuellement connecté. Une réponse du serveur « refusé » (401, 403, 404…)
  /// n'est jamais remplacée par le profil d'un autre compte.
  Future<UserProfile> getProfile() async {
    final cacheKey = await _cacheKey();
    try {
      final response = await _apiClient.get(AppConstants.profileEndpoint);
      if (response.statusCode == 200 && response.data != null) {
        final profile = UserProfile.fromJson(response.data as Map<String, dynamic>);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(profile.toJson()));
        return profile;
      }
      throw Exception('Impossible de charger le profil utilisateur.');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final serverRefused = status != null && status < 500;
      if (serverRefused) rethrow;
      final cached = await _readCached(cacheKey);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<UserProfile?> _readCached(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached == null) return null;
    return UserProfile.fromJson(jsonDecode(cached) as Map<String, dynamic>);
  }

  /// Met à jour le profil de l'utilisateur (nom, localisation, langue)
  Future<UserProfile> updateProfile({
    String? fullName,
    String? location,
    String? language,
  }) async {
    final payload = <String, dynamic>{};
    if (fullName != null) payload['full_name'] = fullName;
    if (location != null) payload['location'] = location;
    if (language != null) payload['language'] = language;

    final response = await _apiClient.patch(AppConstants.profileEndpoint, data: payload);
    if (response.statusCode == 200 && response.data != null) {
      return UserProfile.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception('Erreur lors de la mise à jour du profil (code: ${response.statusCode})');
  }
}
