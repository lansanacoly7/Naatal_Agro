import 'package:nataal_agro/features/auth/data/auth_repository.dart';

/// Faux dépôt d'authentification : enregistre ce que l'écran d'inscription envoie.
class FakeAuthRepository implements AuthRepository {
  Map<String, dynamic>? registered;
  Object? registerError;
  bool demoCode = true;

  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Future<void> login(String phone, String password) async {}

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
    if (registerError != null) throw registerError!;
    registered = {
      'fullName': fullName,
      'phone': phone,
      'password': password,
      'location': location,
      'email': email,
      'dateOfBirth': dateOfBirth,
      'mainCrops': mainCrops,
      'privacyAccepted': privacyAccepted,
      'otpCode': otpCode,
    };
  }

  @override
  Future<Map<String, dynamic>> sendOtp(String phone, {String purpose = 'register'}) async =>
      demoCode ? {'code': '1234', 'demo': true} : {'message': 'envoyé'};

  @override
  Future<bool> verifyOtp(String phone, String code, {String purpose = 'register'}) async => true;

  @override
  Future<void> resetPassword(String phone, String code, String newPassword) async {}

  @override
  Future<void> logout() async {}
}
