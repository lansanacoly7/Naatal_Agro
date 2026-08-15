import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'sync_service.dart';

/// Client HTTP centralisé pour communiquer avec le backend Django.
/// Intercepte automatiquement les requêtes pour ajouter le token JWT.
class ApiClient {
  late final Dio _dio;

  ApiClient() {
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

    // Intercepteur JWT — injecte le token automatiquement
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(AppConstants.accessTokenKey);
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

          // Si le token a expiré (401), tenter un refresh
          if (error.response?.statusCode == 401) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Relancer la requête originale avec le nouveau token
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString(AppConstants.accessTokenKey);
              if (token != null) {
                error.requestOptions.headers['Authorization'] = 'Bearer $token';
                final response = await _dio.fetch(error.requestOptions);
                return handler.resolve(response);
              }
            } else {
              // Si le refresh échoue (refresh token expiré ou invalide), on déconnecte de force.
              await clearTokens();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Tente de rafraîchir le JWT
  Future<bool> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(AppConstants.refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await Dio().post(
        '${AppConstants.apiBaseUrl}${AppConstants.refreshTokenEndpoint}',
        data: {'refresh': refreshToken},
      );

      if (response.statusCode == 200) {
        await prefs.setString(
          AppConstants.accessTokenKey,
          response.data['access'],
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

  /// Sauvegarder les tokens après login
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? role,
    String? location,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.accessTokenKey, accessToken);
    await prefs.setString(AppConstants.refreshTokenKey, refreshToken);
    if (role != null) {
      await prefs.setString('user_role', role);
    }
    if (location != null) {
      await prefs.setString('user_location', location);
    }
  }

  /// Supprimer les tokens (logout)
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.accessTokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove('user_role');
    await prefs.remove('user_location');
  }

  /// Vérifier si l'utilisateur a un token valide
  Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.accessTokenKey);
    return token != null && token.isNotEmpty;
  }
  
  /// Récupérer le rôle de l'utilisateur
  Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role') ?? 'farmer';
  }
}
