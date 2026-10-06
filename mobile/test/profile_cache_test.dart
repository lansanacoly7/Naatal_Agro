import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/constants/app_constants.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:nataal_agro/features/profile/data/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Handler = ResponseBody Function(RequestOptions options);

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handler);

  final _Handler handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      handler(options);

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

/// Faux jeton JWT : seule la charge utile (user_id) est lue par l'application.
String _jwt(String userId) {
  String part(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'user_id': userId})}.signature';
}

const _storage = FlutterSecureStorage();

Future<void> _loginAs(String userId) async {
  await _storage.write(key: AppConstants.accessTokenKey, value: _jwt(userId));
  await _storage.write(key: AppConstants.refreshTokenKey, value: 'refresh-$userId');
}

Map<String, dynamic> _profile(String id, String name) => {
      'id': id,
      'phone': '+22177000000$id',
      'full_name': name,
      'role': 'farmer',
      'language': 'fr',
      'location': 'Thiès',
      'crops_count': 0,
      'main_crops': <String>[],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Cache du profil : un compte ne voit jamais le profil d\'un autre', () {
    test('le serveur refuse le nouveau compte : on ne renvoie pas le profil de l\'ancien', () async {
      var serverSaysOk = true;
      final client = ApiClient(
        secureStorage: _storage,
        httpClientAdapter: _ScriptedAdapter(
          (o) => serverSaysOk ? _json(200, _profile('1', 'Ancien Compte')) : _json(403, {'detail': 'refusé'}),
        ),
      );
      final repository = ProfileRepository(client);

      await _loginAs('1');
      expect((await repository.getProfile()).fullName, 'Ancien Compte');

      // Nouvelle inscription sur le même appareil, sans déconnexion propre : le serveur refuse
      await _loginAs('2');
      serverSaysOk = false;

      await expectLater(repository.getProfile(), throwsA(isA<DioException>()));
    });

    test('coupure serveur (500) : le cache du MÊME compte sert de secours', () async {
      var serverDown = false;
      final client = ApiClient(
        secureStorage: _storage,
        httpClientAdapter: _ScriptedAdapter(
          (o) => serverDown ? _json(500, {'detail': 'panne'}) : _json(200, _profile('1', 'Awa Ndiaye')),
        ),
      );
      final repository = ProfileRepository(client);

      await _loginAs('1');
      await repository.getProfile();
      serverDown = true;

      expect((await repository.getProfile()).fullName, 'Awa Ndiaye');
    });

    test('un compte différent ne reçoit pas le cache d\'un autre compte en cas de panne', () async {
      var serverDown = false;
      final client = ApiClient(
        secureStorage: _storage,
        httpClientAdapter: _ScriptedAdapter(
          (o) => serverDown ? _json(500, {'detail': 'panne'}) : _json(200, _profile('1', 'Ancien Compte')),
        ),
      );
      final repository = ProfileRepository(client);

      await _loginAs('1');
      await repository.getProfile();

      await _loginAs('2');
      serverDown = true;

      await expectLater(repository.getProfile(), throwsA(isA<DioException>()));
    });

    test('la déconnexion locale efface tous les profils en cache', () async {
      SharedPreferences.setMockInitialValues({
        'cached_user_profile': '{"id":"1"}',
        '${ProfileRepository.profileCachePrefix}1': '{"id":"1"}',
        'autre_reglage': 'garde',
      });
      final client = ApiClient(secureStorage: _storage, httpClientAdapter: _ScriptedAdapter((o) => _json(200, {})));

      await client.clearTokens();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('cached_user_profile')), isEmpty);
      expect(prefs.getString('autre_reglage'), 'garde');
    });
  });
}
