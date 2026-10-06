import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../domain/profile_model.dart';

class ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepository(this._apiClient);

  static const String _profileCacheKey = 'cached_user_profile';

  /// Récupère le profil réel de l'utilisateur connecté via /api/users/me/
  Future<UserProfile> getProfile() async {
    try {
      final response = await _apiClient.get(AppConstants.profileEndpoint);
      if (response.statusCode == 200 && response.data != null) {
        final profile = UserProfile.fromJson(response.data as Map<String, dynamic>);
        // Sauvegarde locale pour usage hors-ligne
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_profileCacheKey, jsonEncode(profile.toJson()));
        } catch (_) {}
        return profile;
      }
    } catch (e) {
      // En cas de coupure réseau ou erreur, utiliser le cache local si disponible
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_profileCacheKey);
        if (cached != null) {
          final data = jsonDecode(cached) as Map<String, dynamic>;
          return UserProfile.fromJson(data);
        }
      } catch (_) {}
      rethrow;
    }

    // Si le serveur a répondu un code != 200, tenter aussi le cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_profileCacheKey);
      if (cached != null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        return UserProfile.fromJson(data);
      }
    } catch (_) {}

    throw Exception('Impossible de charger le profil utilisateur.');
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
