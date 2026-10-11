import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/constants/app_constants.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Handler = ResponseBody Function(RequestOptions options);

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'valid-access-token',
      AppConstants.refreshTokenKey: 'valid-refresh-token',
    });
  });

  group('Sécurité & Confidentialité — Endpoints réels', () {
    test('Changement de mot de passe appelle le bon endpoint avec 204', () async {
      late RequestOptions captured;
      final adapter = _ScriptedAdapter((options) {
        captured = options;
        if (options.path == AppConstants.changePasswordEndpoint && options.method == 'POST') {
          return _json(204, {});
        }
        return _json(404, {'error': 'not found'});
      });

      final client = ApiClient(httpClientAdapter: adapter);
      final response = await client.post(
        AppConstants.changePasswordEndpoint,
        data: {'old_password': 'oldPass123', 'new_password': 'newPass123!'},
      );

      expect(response.statusCode, 204);
      expect(captured.path, '/users/auth/password/change/');
      expect(captured.data['old_password'], 'oldPass123');
      expect(captured.data['new_password'], 'newPass123!');
    });

    test('Suppression de compte appelle delete-account avec mot de passe et 204', () async {
      late RequestOptions captured;
      final adapter = _ScriptedAdapter((options) {
        captured = options;
        if (options.path == AppConstants.deleteAccountEndpoint && options.method == 'POST') {
          return _json(204, {});
        }
        return _json(404, {'error': 'not found'});
      });

      final client = ApiClient(httpClientAdapter: adapter);
      final response = await client.post(
        AppConstants.deleteAccountEndpoint,
        data: {'password': 'userSecretPass'},
      );

      expect(response.statusCode, 204);
      expect(captured.path, '/privacy/delete-account/');
      expect(captured.data['password'], 'userSecretPass');
    });

    test('Export des données appelle /privacy/export/ en GET avec 200', () async {
      late RequestOptions captured;
      final adapter = _ScriptedAdapter((options) {
        captured = options;
        if (options.path == AppConstants.exportDataEndpoint && options.method == 'GET') {
          return _json(200, {
            'crops': [
              {'name': 'Arachide'},
            ],
            'sales': [],
          });
        }
        return _json(404, {'error': 'not found'});
      });

      final client = ApiClient(httpClientAdapter: adapter);
      final response = await client.get(AppConstants.exportDataEndpoint);

      expect(response.statusCode, 200);
      expect(captured.path, '/privacy/export/');
      expect(response.data['crops'], hasLength(1));
    });
  });
}
