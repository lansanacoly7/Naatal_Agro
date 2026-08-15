import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Constantes globales de l'application Nataal Agro
class AppConstants {
  // API Backend Django - Dynamique selon l'environnement
  static String get apiBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api'; // Changé pour 127.0.0.1 au lieu d'une IP fixe pour le dev local
    }
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    
    return 'http://127.0.0.1:8000/api';
  }

  // Endpoints Auth
  static const String loginEndpoint = '/users/auth/login/';
  static const String registerEndpoint = '/users/auth/register/';
  static const String refreshTokenEndpoint = '/users/auth/refresh/';

  // Endpoints Agriculture
  static const String cropsEndpoint = '/agriculture/crops/';

  // Endpoints Markets
  static const String marketsEndpoint = '/markets/';
  static const String pricesEndpoint = '/markets/prices/';

  // Endpoints Weather
  static const String weatherEndpoint = '/weather/';

  // Endpoints IA
  static const String aiAskEndpoint = '/ai/ask/';

  // Endpoints Notifications
  static const String notificationsEndpoint = '/notifications/';

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

