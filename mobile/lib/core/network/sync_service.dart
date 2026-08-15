import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import '../constants/app_constants.dart';

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
    print('[SyncService] Requête mise en file d\'attente (offline): $method $path');
  }

  /// Tente de vider la file d'attente si le réseau est de retour
  static Future<void> syncOfflineData(ApiClient apiClient) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print('[SyncService] Toujours hors ligne, annulation de la synchro.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];

    if (queue.isEmpty) {
      return;
    }

    print('[SyncService] Synchronisation de ${queue.length} requêtes...');
    List<String> failedQueue = [];

    for (String reqJson in queue) {
      try {
        final req = jsonDecode(reqJson);
        final method = req['method'];
        final path = req['path'];
        final data = req['data'];

        // Envoi via Dio sans ré-intercepter les erreurs réseau par la queue
        // Pour être sûr, on utilise une méthode directe.
        final response = await _sendRequest(apiClient, method, path, data);
        if (response.statusCode == 200 || response.statusCode == 201) {
          print('[SyncService] Succès: $method $path');
        } else {
          // Erreur serveur (pas réseau), on abandonne la requête pour ne pas bloquer la queue
          print('[SyncService] Erreur serveur sur $path: ${response.statusCode}');
        }
      } catch (e) {
        // En cas d'erreur réseau persistante, on remet dans la file (les prochaines échoueront sûrement aussi)
        print('[SyncService] Échec de la synchro, remise en queue.');
        failedQueue.add(reqJson);
      }
    }

    await prefs.setStringList(_queueKey, failedQueue);
    if (failedQueue.isEmpty) {
      print('[SyncService] Synchronisation terminée avec succès.');
    }
  }

  static Future<Response> _sendRequest(ApiClient client, String method, String path, dynamic data) {
    switch (method.toUpperCase()) {
      case 'POST': return client.post(path, data: data);
      case 'PUT': return client.put(path, data: data);
      case 'PATCH': return client.patch(path, data: data);
      case 'DELETE': return client.delete(path);
      default: throw Exception('Unsupported method');
    }
  }
}
