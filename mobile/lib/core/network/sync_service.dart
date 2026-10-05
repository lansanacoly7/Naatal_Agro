import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';

class SyncService {
  static const String _queueKey = 'offline_request_queue';

  /// Ajoute une requête échouée à la file d'attente
  static Future<void> enqueueRequest({
    required String method,
    required String path,
    dynamic data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];

    final requestMap = {
      'method': method,
      'path': path,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };

    queue.add(jsonEncode(requestMap));
    await prefs.setStringList(_queueKey, queue);
    debugPrint('[SyncService] Requête mise en file d\'attente (offline): $method $path');
  }

  /// Tente de vider la file d'attente si le réseau est de retour
  static Future<void> syncOfflineData(ApiClient apiClient) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        debugPrint('[SyncService] Toujours hors ligne, annulation de la synchro.');
        return;
      }
    } catch (e) {
      // Le plugin de connectivité peut être absent (web, tests) : on tente quand même
      // l'envoi, les échecs réseau remettent chaque requête en file.
      debugPrint('[SyncService] Vérification connectivité non disponible: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];

    if (queue.isEmpty) {
      return;
    }

    debugPrint('[SyncService] Synchronisation de ${queue.length} requêtes...');
    List<String> failedQueue = [];

    for (String reqJson in queue) {
      try {
        final req = jsonDecode(reqJson);
        final method = req['method'];
        final path = req['path'];
        final data = req['data'];

        await _sendRequest(apiClient, method, path, data);
        debugPrint('[SyncService] Succès: $method $path');
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status != null && status >= 400 && status < 500 && status != 408 && status != 429) {
          // Rejet définitif par le serveur (validation, droits...) : rejouer ne servirait à rien
          debugPrint('[SyncService] Requête abandonnée (HTTP $status): $reqJson');
        } else {
          // Réseau coupé ou erreur serveur temporaire : on la garde pour la prochaine synchro
          debugPrint('[SyncService] Échec temporaire, remise en file.');
          failedQueue.add(reqJson);
        }
      } catch (e) {
        debugPrint('[SyncService] Entrée illisible ignorée: $e');
      }
    }

    await prefs.setStringList(_queueKey, failedQueue);
    if (failedQueue.isEmpty) {
      debugPrint('[SyncService] Synchronisation terminée avec succès.');
    }
  }

  static Future<Response> _sendRequest(ApiClient client, String method, String path, dynamic data) {
    const allowed = ['POST', 'PUT', 'PATCH', 'DELETE'];
    if (!allowed.contains(method.toUpperCase())) {
      throw ArgumentError('Méthode non supportée: $method');
    }
    return client.replay(method.toUpperCase(), path, data: data);
  }
}
