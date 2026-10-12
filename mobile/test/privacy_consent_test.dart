import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:nataal_agro/features/auth/data/auth_repository.dart';
import 'package:nataal_agro/features/auth/data/auth_provider.dart';

class FakeApiClient extends ApiClient {
  final List<Map<String, dynamic>> recordedRequests = [];

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Duration? receiveTimeout,
    bool queueWhenOffline = true,
  }) async {
    recordedRequests.add({
      'path': path,
      'data': data,
    });
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: {
        'access': 'dummy_access',
        'refresh': 'dummy_refresh',
        'role': 'farmer',
        'location': 'Dakar',
      },
    );
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? role,
    String? location,
  }) async {}
}

void main() {
  group('Privacy Consent & Policy (Tâche n°9)', () {
    test('AuthRepository.register includes privacy_accepted boolean in payload', () async {
      final fakeApi = FakeApiClient();
      final repo = AuthRepository(fakeApi);

      await repo.register(
        phone: '771234567',
        password: 'Password123!',
        fullName: 'Amadou Diallo',
        privacyAccepted: true,
      );

      expect(fakeApi.recordedRequests.isNotEmpty, isTrue);
      final registerReq = fakeApi.recordedRequests.firstWhere(
        (r) => r['path'] == '/users/auth/register/',
      );
      final map = registerReq['data'] as Map<String, dynamic>;
      expect(map['privacy_accepted'], isTrue);
      expect(map['phone_number'], equals('+221771234567'));
      expect(map['full_name'], equals('Amadou Diallo'));
    });

    test('AuthNotifier.register forwards privacyAccepted to repository', () async {
      final fakeApi = FakeApiClient();
      final repo = AuthRepository(fakeApi);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final notifier = container.read(authStateProvider.notifier);
      await notifier.register(
        phone: '779876543',
        password: 'Password123!',
        fullName: 'Fatou Sow',
        privacyAccepted: true,
      );

      expect(fakeApi.recordedRequests.isNotEmpty, isTrue);
      final registerReq = fakeApi.recordedRequests.firstWhere(
        (r) => r['path'] == '/users/auth/register/',
      );
      final map = registerReq['data'] as Map<String, dynamic>;
      expect(map['privacy_accepted'], isTrue);
      expect(map['phone_number'], equals('+221779876543'));
    });
  });
}
