import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../domain/profile_model.dart';

class ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepository(this._apiClient);

  /// Récupère le profil réel de l'utilisateur connecté via /api/users/me/
  Future<UserProfile> getProfile() async {
    final response = await _apiClient.get(AppConstants.profileEndpoint);
    if (response.statusCode == 200 && response.data != null) {
      return UserProfile.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception('Impossible de charger le profil utilisateur (code: ${response.statusCode})');
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
