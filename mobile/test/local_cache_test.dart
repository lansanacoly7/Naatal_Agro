import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/cache/local_cache.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:nataal_agro/features/agriculture/data/agriculture_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faux serveur HTTP réutilisable pour les tests de cache.
/// Simule soit une réponse avec un code HTTP donné et un body JSON,
/// soit une panne réseau complète.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.statusCode, this.body, this.networkDown = false});

  final int? statusCode;
  final dynamic body;
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
      jsonEncode(body ?? {'ok': true}),
      statusCode ?? 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_FakeAdapter adapter) => ApiClient(
      secureStorage: const FlutterSecureStorage(),
      httpClientAdapter: adapter,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalCache cacheUser1;
  late LocalCache cacheUser2;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cacheUser1 = LocalCache(prefs, 'user_1');
    cacheUser2 = LocalCache(prefs, 'user_2');
  });

  group('LocalCache — opérations de base', () {
    test('écriture puis lecture du cache, avec la date', () async {
      await cacheUser1.write('test_key', {'hello': 'world'});
      final entry = await cacheUser1.read('test_key');

      expect(entry, isNotNull);
      expect(entry!.data['hello'], 'world');
      // La date d'enregistrement doit être très récente
      expect(
        entry.cachedAt.difference(DateTime.now()).inSeconds.abs() < 2,
        isTrue,
      );
    });

    test('deux utilisateurs différents : aucune fuite de l\'un vers l\'autre', () async {
      await cacheUser1.write('crops', {'data': 'user1_crops'});
      await cacheUser2.write('crops', {'data': 'user2_crops'});

      final entry1 = await cacheUser1.read('crops');
      final entry2 = await cacheUser2.read('crops');

      expect(entry1!.data['data'], 'user1_crops');
      expect(entry2!.data['data'], 'user2_crops');
    });

    test('purge à la déconnexion', () async {
      await cacheUser1.write('crops', {'data': 'user1_crops'});
      await cacheUser1.write('prices', {'data': 'user1_prices'});

      await cacheUser1.clearUserCache();

      expect(await cacheUser1.read('crops'), isNull);
      expect(await cacheUser1.read('prices'), isNull);
    });

    test('cache expiré au-delà de 7 jours', () async {
      final oldDate = DateTime.now().subtract(const Duration(days: 8));
      final rawData = {
        'data': {'hello': 'world'},
        'cachedAt': oldDate.toIso8601String(),
      };
      // On écrit directement dans SharedPreferences avec une date expirée
      await prefs.setString(
        'naatal_cache_user_1_expired_key',
        jsonEncode(rawData),
      );

      final entry = await cacheUser1.read('expired_key');
      expect(entry, isNull);
    });

    test('cache non expiré à exactement 6 jours', () async {
      final recentDate = DateTime.now().subtract(const Duration(days: 6));
      final rawData = {
        'data': {'hello': 'world'},
        'cachedAt': recentDate.toIso8601String(),
      };
      await prefs.setString(
        'naatal_cache_user_1_recent_key',
        jsonEncode(rawData),
      );

      final entry = await cacheUser1.read('recent_key');
      expect(entry, isNotNull);
      expect(entry!.data['hello'], 'world');
    });
  });

  group('AgricultureRepository — cache hors ligne', () {
    final mockCropsResponse = {
      'count': 1,
      'next': null,
      'previous': null,
      'results': [
        {
          'id': '1',
          'name': 'Oignon',
          'crop_type': 'oignon',
          'planting_date': '2026-03-01',
          'expected_harvest_date': '2026-06-01',
          'status': 'active',
          'area_size': '2.0',
          'location': 'Thiès',
        }
      ],
    };

    final mockCropsFreshResponse = {
      'count': 1,
      'next': null,
      'previous': null,
      'results': [
        {
          'id': '2',
          'name': 'Tomate',
          'crop_type': 'tomate',
          'planting_date': '2026-04-01',
          'expected_harvest_date': '2026-07-01',
          'status': 'active',
          'area_size': '1.5',
          'location': 'Saint-Louis',
        }
      ],
    };

    test('panne réseau avec cache : la liste est servie depuis le cache et isFromCache vaut vrai', () async {
      // 1. Premier appel réussi → remplit le cache
      final successAdapter = _FakeAdapter(statusCode: 200, body: mockCropsResponse);
      final repo1 = AgricultureRepository(_client(successAdapter));
      final result1 = await repo1.getCropsPaginated(page: 1);
      expect(result1.isFromCache, isFalse);
      expect(result1.results.first.name, 'Oignon');

      // 2. Panne réseau → le cache doit répondre
      final networkDownAdapter = _FakeAdapter(networkDown: true);
      final repo2 = AgricultureRepository(_client(networkDownAdapter));
      final result2 = await repo2.getCropsPaginated(page: 1);

      expect(result2.isFromCache, isTrue);
      expect(result2.cachedAt, isNotNull);
      expect(result2.results.first.name, 'Oignon');
    });

    test('panne réseau sans cache : erreur', () async {
      final networkDownAdapter = _FakeAdapter(networkDown: true);
      final repo = AgricultureRepository(_client(networkDownAdapter));

      expect(
        () => repo.getCropsPaginated(page: 1),
        throwsA(isA<DioException>()),
      );
    });

    test('erreur 500 avec cache présent : l\'erreur est affichée, le cache n\'est pas utilisé', () async {
      // 1. Remplir le cache
      final successAdapter = _FakeAdapter(statusCode: 200, body: mockCropsResponse);
      final repo1 = AgricultureRepository(_client(successAdapter));
      await repo1.getCropsPaginated(page: 1);

      // 2. Erreur serveur 500 — ce n'est PAS une erreur réseau, le cache ne doit pas être utilisé
      final errorAdapter = _FakeAdapter(statusCode: 500, body: {'error': 'Internal Server Error'});
      final repo2 = AgricultureRepository(_client(errorAdapter));

      expect(
        () => repo2.getCropsPaginated(page: 1),
        throwsException,
      );
    });

    test('réseau rétabli : les données fraîches remplacent le cache', () async {
      // 1. Premier chargement avec données A
      final adapterA = _FakeAdapter(statusCode: 200, body: mockCropsResponse);
      final repoA = AgricultureRepository(_client(adapterA));
      final resultA = await repoA.getCropsPaginated(page: 1);
      expect(resultA.results.first.name, 'Oignon');

      // 2. Réseau rétabli avec données B fraîches
      final adapterB = _FakeAdapter(statusCode: 200, body: mockCropsFreshResponse);
      final repoB = AgricultureRepository(_client(adapterB));
      final resultB = await repoB.getCropsPaginated(page: 1);

      expect(resultB.isFromCache, isFalse);
      expect(resultB.results.first.name, 'Tomate');

      // 3. Le cache contient désormais les données B
      final networkDown = _FakeAdapter(networkDown: true);
      final repoC = AgricultureRepository(_client(networkDown));
      final resultC = await repoC.getCropsPaginated(page: 1);
      expect(resultC.isFromCache, isTrue);
      expect(resultC.results.first.name, 'Tomate');
    });
  });
}
