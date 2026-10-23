import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Constantes globales de l'application Nataal Agro
class AppConstants {
  /// URL de l'API injectable à la compilation, utile pour un téléphone réel ou la prod :
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api`
  static const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  // API Backend Django - Dynamique selon l'environnement
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }

    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.startsWith('file:') && origin != 'null') {
        return '$origin/api';
      }
      return 'http://127.0.0.1:8000/api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // 10.0.2.2 = machine hôte vue depuis l'émulateur Android
      return 'http://10.0.2.2:8000/api';
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://127.0.0.1:8000/api';
    }

    return 'http://127.0.0.1:8000/api';
  }

  // Endpoints Auth
  static const String loginEndpoint = '/users/auth/login/';
  static const String registerEndpoint = '/users/auth/register/';
  static const String refreshTokenEndpoint = '/users/auth/refresh/';
  static const String logoutEndpoint = '/users/auth/logout/';
  static const String changePasswordEndpoint = '/users/auth/password/change/';
  static const String sendOtpEndpoint = '/users/auth/otp/send/';
  static const String verifyOtpEndpoint = '/users/auth/otp/verify/';
  static const String resetPasswordEndpoint = '/users/auth/password/reset/';

  // Endpoints Confidentialité & RGPD / CDP
  static const String deleteAccountEndpoint = '/privacy/delete-account/';
  static const String exportDataEndpoint = '/privacy/export/';
  static const String privacyPolicyEndpoint = '/privacy/policy/';

  // Endpoints Agriculture
  static const String cropsEndpoint = '/agriculture/crops/';
  static const String agronomicGuidesEndpoint = '/agriculture/guides/';

  // Endpoints Markets
  static const String marketsEndpoint = '/markets/';
  static const String pricesEndpoint = '/markets/prices/';

  // Endpoints Weather
  static const String weatherEndpoint = '/weather/';

  // Endpoints IA
  // Chemins relatifs à apiBaseUrl (qui se termine déjà par /api) : ne jamais les préfixer par /api.
  static const String aiAskEndpoint = '/ai/ask/';
  static const String aiConversationsEndpoint = '/ai/conversations/';
  static const String aiResolveActionEndpoint = '/ai/actions/execute/';
  static const String aiTranscribeEndpoint = '/ai/voice/transcribe/';

  static String aiConversationEndpoint(String id) => '$aiConversationsEndpoint$id/';

  // Endpoints Notifications
  static const String notificationsEndpoint = '/notifications/';

  // Endpoints Finances & Inventory
  static const String salesEndpoint = '/finances/sales/';
  static const String financialSummaryEndpoint = '/finances/summary/';
  static const String inventoryEndpoint = '/inventory/';

  // Endpoints Dashboard
  static const String dashboardEndpoint = '/dashboard/';

  // Endpoints User
  static const String profileEndpoint = '/users/me/';
  static const String updateFcmTokenEndpoint = '/users/update-fcm-token/';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';

  // App Info
  static const String appName = 'Nataal Agro';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Votre copilote agricole intelligent';
}

