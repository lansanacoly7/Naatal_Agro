import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/constants/app_constants.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Handler = ResponseBody Function(RequestOptions options);

/// Faux serveur : chaque test décrit sa réponse en fonction du chemin et de l'en-tête.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handler);

  final _Handler handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

const _storage = FlutterSecureStorage();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'old-access',
      AppConstants.refreshTokenKey: 'old-refresh',
    });
  });

  group('Renouvellement du jeton', () {
    test('un 401 déclenche le renouvellement, conserve le NOUVEAU refresh et rejoue la requête', () async {
      final adapter = _ScriptedAdapter((o) {
        if (o.path == AppConstants.refreshTokenEndpoint) {
          return _json(200, {'access': 'new-access', 'refresh': 'new-refresh'});
        }
        return o.headers['Authorization'] == 'Bearer new-access'
            ? _json(200, {'ok': true})
            : _json(401, {'detail': 'expired'});
      });
      final client = ApiClient(secureStorage: _storage, httpClientAdapter: adapter);

      final response = await client.get('/agriculture/crops/');

      expect(response.statusCode, 200);
      expect(await _storage.read(key: AppConstants.accessTokenKey), 'new-access');
      // Le backend invalide l'ancien refresh à chaque rotation : le nouveau DOIT être conservé
      expect(await _storage.read(key: AppConstants.refreshTokenKey), 'new-refresh');
    });

    test('si le renouvellement est refusé, la session locale est purgée', () async {
      final adapter = _ScriptedAdapter((o) {
        if (o.path == AppConstants.refreshTokenEndpoint) {
          return _json(401, {'detail': 'Token is blacklisted'});
        }
        return _json(401, {'detail': 'expired'});
      });
      final client = ApiClient(secureStorage: _storage, httpClientAdapter: adapter);

      await expectLater(client.get('/agriculture/crops/'), throwsA(isA<DioException>()));

      expect(await _storage.read(key: AppConstants.accessTokenKey), isNull);
      expect(await _storage.read(key: AppConstants.refreshTokenKey), isNull);
    });
  });

  group('Déconnexion', () {
    test('logoutFromServer envoie le refresh actuel au backend', () async {
      final adapter = _ScriptedAdapter((o) => _json(204, {}));
      final client = ApiClient(secureStorage: _storage, httpClientAdapter: adapter);

      await client.logoutFromServer();

      final logout = adapter.requests.single;
      expect(logout.path, AppConstants.logoutEndpoint);
      expect(logout.method, 'POST');
      expect(logout.data, {'refresh': 'old-refresh'});
    });

    test('hors ligne, la déconnexion serveur échoue sans exception et sans file d\'attente', () async {
      final adapter = _ScriptedAdapter((o) => throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ));
      final client = ApiClient(secureStorage: _storage, httpClientAdapter: adapter);

      await client.logoutFromServer(); // ne doit pas lever

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('offline_request_queue') ?? [], isEmpty);
    });

    test('sans refresh stocké, aucun appel réseau n\'est fait', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final adapter = _ScriptedAdapter((o) => _json(204, {}));
      final client = ApiClient(secureStorage: _storage, httpClientAdapter: adapter);

      await client.logoutFromServer();

      expect(adapter.requests, isEmpty);
    });
  });
}
