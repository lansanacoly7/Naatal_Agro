import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
  final HttpClientAdapter? _httpClientAdapter;

  /// [httpClientAdapter] permet d'injecter un faux serveur dans les tests.
  ApiClient({FlutterSecureStorage? secureStorage, HttpClientAdapter? httpClientAdapter})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _httpClientAdapter = httpClientAdapter {
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

    if (httpClientAdapter != null) {
      _dio.httpClientAdapter = httpClientAdapter;
    }

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
          final path = error.requestOptions.path;
          // Exclure les endpoints d'authentification de la mise en file d'attente offline
          if (path.contains('/auth/')) {
            return handler.next(error);
          }

          // Si c'est une erreur réseau, on met en file d'attente les mutations
          if (error.type == DioExceptionType.connectionTimeout || 
              error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.receiveTimeout) {
            
            final method = error.requestOptions.method.toUpperCase();
            // Les requêtes rejouées par SyncService ne doivent pas être remises en file ici
            final isReplay = error.requestOptions.extra['replay'] == true;
            if (!isReplay && ['POST', 'PUT', 'PATCH', 'DELETE'].contains(method)) {
              await SyncService.enqueueRequest(
                method: method,
                path: error.requestOptions.path,
                data: error.requestOptions.data,
              );
              // Résoudre l'erreur avec un 202 Accepted factice
              return handler.resolve(Response(
                requestOptions: error.requestOptions,
                statusCode: 202,
                data: {'message': 'Action sauvegardée (Offline)', 'offline': true},
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

  /// Tente de rafraîchir le JWT de manière sécurisée.
  /// Le backend fait tourner les jetons de rafraîchissement : l'ancien est invalidé
  /// à chaque renouvellement, le nouveau doit donc être conservé.
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final bareDio = Dio(BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final adapter = _httpClientAdapter;
      if (adapter != null) {
        bareDio.httpClientAdapter = adapter;
      }
      final response = await bareDio.post(
        AppConstants.refreshTokenEndpoint,
        data: {'refresh': refreshToken},
      );

      final access = response.data['access'];
      if (response.statusCode == 200 && access is String && access.isNotEmpty) {
        await _secureStorage.write(key: AppConstants.accessTokenKey, value: access);
        final rotated = response.data['refresh'];
        if (rotated is String && rotated.isNotEmpty) {
          await _secureStorage.write(key: AppConstants.refreshTokenKey, value: rotated);
        }
        return true;
      }
    } catch (e) {
      debugPrint('[ApiClient] Échec du renouvellement du jeton : $e');
    }
    return false;
  }

  /// Invalide le jeton de rafraîchissement côté serveur (liste noire).
  /// Au mieux : si le réseau est coupé, la déconnexion locale doit tout de même aboutir.
  Future<void> logoutFromServer() async {
    try {
      final refreshToken = await _secureStorage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) return;
      await _dio.request(
        AppConstants.logoutEndpoint,
        data: {'refresh': refreshToken},
        options: Options(method: 'POST', extra: {'replay': true}),
      );
    } catch (e) {
      debugPrint('[ApiClient] Déconnexion serveur impossible (déconnexion locale conservée) : $e');
    }
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

  /// Rejoue une requête mise en file hors ligne. Les erreurs réseau sont propagées
  /// (au lieu d'être converties en faux 202) pour que SyncService garde la requête.
  Future<Response> replay(String method, String path, {dynamic data}) {
    return _dio.request(
      path,
      data: data,
      options: Options(method: method, extra: {'replay': true}),
    );
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

  /// Extraire l'ID utilisateur depuis le token JWT
  Future<String> getUserId() async {
    try {
      final token = await _secureStorage.read(key: AppConstants.accessTokenKey);
      if (token == null || token.isEmpty) return 'anonymous';
      
      final parts = token.split('.');
      if (parts.length != 3) return 'anonymous';
      
      String payload = parts[1];
      // Pad to be a multiple of 4
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      
      final decoded = utf8.decode(base64Url.decode(payload));
      final Map<String, dynamic> data = jsonDecode(decoded);
      
      return data['user_id']?.toString() ?? 'anonymous';
    } catch (e) {
      return 'anonymous';
    }
  }
}
