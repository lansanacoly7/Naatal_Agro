import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import 'sync_service.dart';

/// Client HTTP centralisé pour communiquer avec le backend Django.
/// Stocke les tokens JWT de façon chiffrée (Android Keystore / iOS Keychain)
/// et intercepte automatiquement les requêtes pour ajouter le token JWT.
class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  ApiClient({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Intercepteur JWT — injecte le token automatiquement depuis le stockage sécurisé
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: AppConstants.accessTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Si c'est une erreur réseau, on met en file d'attente les mutations
          if (error.type == DioExceptionType.connectionTimeout || 
              error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.receiveTimeout) {
            
            final method = error.requestOptions.method.toUpperCase();
            if (['POST', 'PUT', 'PATCH', 'DELETE'].contains(method)) {
              await SyncService.enqueueRequest(
                method: method,
                path: error.requestOptions.path,
                data: error.requestOptions.data,
              );
              // Résoudre l'erreur avec un 202 Accepted factice
              return handler.resolve(Response(
                requestOptions: error.requestOptions,
                statusCode: 202,
                data: {'message': 'Action sauvegardée (Offline)'},
              ));
            }
          }

          // Si le token a expiré (401), tenter un refresh sécurisé
          if (error.response?.statusCode == 401) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Relancer la requête originale avec le nouveau token
              final token = await _secureStorage.read(key: AppConstants.accessTokenKey);
              if (token != null) {
                error.requestOptions.headers['Authorization'] = 'Bearer $token';
                final response = await _dio.fetch(error.requestOptions);
                return handler.resolve(response);
              }
            } else {
              // Si le refresh échoue, déconnexion propre et purge du coffre-fort
              await clearTokens();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Tente de rafraîchir le JWT de manière sécurisée
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await Dio().post(
        '${AppConstants.apiBaseUrl}${AppConstants.refreshTokenEndpoint}',
        data: {'refresh': refreshToken},
      );

      if (response.statusCode == 200) {
        await _secureStorage.write(
          key: AppConstants.accessTokenKey,
          value: response.data['access'],
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ──────────── Méthodes publiques ────────────

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) {
    return _dio.get(path, queryParameters: queryParams);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }

  /// Sauvegarder les tokens dans le coffre-fort chiffré (Keychain/Keystore)
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? role,
    String? location,
  }) async {
    await _secureStorage.write(key: AppConstants.accessTokenKey, value: accessToken);
    await _secureStorage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
    
    final prefs = await SharedPreferences.getInstance();
    if (role != null) {
      await prefs.setString('user_role', role);
    }
    if (location != null) {
      await prefs.setString('user_location', location);
    }
  }

  /// Supprimer les tokens (logout)
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: AppConstants.accessTokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    await prefs.remove('user_location');
  }

  /// Vérifier si l'utilisateur possède un jeton d'accès sécurisé
  Future<bool> hasToken() async {
    final token = await _secureStorage.read(key: AppConstants.accessTokenKey);
    return token != null && token.isNotEmpty;
  }
  
  /// Récupérer le rôle de l'utilisateur
  Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role') ?? 'farmer';
  }
}
