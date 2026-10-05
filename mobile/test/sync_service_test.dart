import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:nataal_agro/core/network/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _queueKey = 'offline_request_queue';

/// Faux serveur : renvoie un code HTTP donné ou simule une panne réseau.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.statusCode, this.networkDown = false});

  final int? statusCode;
  final bool networkDown;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (networkDown) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'réseau coupé',
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      statusCode ?? 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<List<String>> _queue() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_queueKey) ?? [];
}

ApiClient _client(_FakeAdapter adapter) =>
    ApiClient(secureStorage: const FlutterSecureStorage(), httpClientAdapter: adapter);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('SyncService - file d\'attente hors ligne', () {
    test('une action faite hors ligne est mise en file et signalée comme telle', () async {
      final adapter = _FakeAdapter(networkDown: true);
      final response = await _client(adapter).post('/agriculture/crops/', data: {'name': 'Mil'});

      expect(response.statusCode, 202);
      expect(response.data['offline'], true);
      expect(await _queue(), hasLength(1));
    });

    test('la synchro envoie les requêtes en file puis vide la file', () async {
      await SyncService.enqueueRequest(method: 'POST', path: '/agriculture/crops/', data: {'name': 'Mil'});
      final adapter = _FakeAdapter(statusCode: 201);

      await SyncService.syncOfflineData(_client(adapter));

      expect(adapter.calls, 1);
      expect(await _queue(), isEmpty);
    });

    test('une requête rejetée par le serveur (4xx) est abandonnée, pas rejouée à l\'infini', () async {
      await SyncService.enqueueRequest(method: 'POST', path: '/agriculture/crops/', data: {'name': ''});
      final adapter = _FakeAdapter(statusCode: 400);

      await SyncService.syncOfflineData(_client(adapter));

      expect(adapter.calls, 1);
      expect(await _queue(), isEmpty);
    });

    test('une panne réseau garde la requête en file sans la dupliquer', () async {
      await SyncService.enqueueRequest(method: 'POST', path: '/agriculture/crops/', data: {'name': 'Mil'});
      final adapter = _FakeAdapter(networkDown: true);

      await SyncService.syncOfflineData(_client(adapter));

      expect(await _queue(), hasLength(1));
    });

    test('une erreur serveur temporaire (5xx) garde la requête en file', () async {
      await SyncService.enqueueRequest(method: 'POST', path: '/agriculture/crops/', data: {'name': 'Mil'});

      await SyncService.syncOfflineData(_client(_FakeAdapter(statusCode: 503)));

      expect(await _queue(), hasLength(1));
    });
  });
}
