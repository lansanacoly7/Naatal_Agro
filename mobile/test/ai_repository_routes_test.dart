import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:nataal_agro/features/ai/data/ai_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faux serveur qui répond 200 et mémorise chaque requête pour vérifier l'URL réellement appelée.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final body = options.method == 'GET' ? '[]' : jsonEncode({'id': 'x', 'response': 'ok', 'text': 'ok'});
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingAdapter adapter;
  late AiRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    adapter = _RecordingAdapter();
    repository = AiRepository(ApiClient(httpClientAdapter: adapter));
  });

  /// L'URL de base se termine déjà par `/api` : un chemin en `/api/...` donnerait `/api/api/...` (404).
  void expectSingleApiPrefix(String expectedPath) {
    final uri = adapter.requests.last.uri;
    expect(uri.path, expectedPath, reason: 'URL réellement appelée : $uri');
    expect(uri.path.contains('/api/api/'), isFalse);
  }

  group('Routes de l\'assistant : un seul préfixe /api', () {
    test('poser une question', () async {
      await repository.askQuestion('Bonjour');
      expectSingleApiPrefix('/api/ai/ask/');
    });

    test('lister les conversations', () async {
      await repository.fetchConversations();
      expectSingleApiPrefix('/api/ai/conversations/');
    });

    test('charger une conversation', () async {
      await repository.fetchConversationMessages('abc');
      expectSingleApiPrefix('/api/ai/conversations/abc/');
    });

    test('renommer une conversation', () async {
      await repository.renameConversation('abc', 'Titre');
      expectSingleApiPrefix('/api/ai/conversations/abc/');
    });

    test('supprimer une conversation', () async {
      await repository.deleteConversation('abc');
      expectSingleApiPrefix('/api/ai/conversations/abc/');
    });

    test('transcrire une note vocale', () async {
      await repository.transcribeAudio(Uint8List.fromList([1, 2, 3]));
      expectSingleApiPrefix('/api/ai/voice/transcribe/');
    });

    test('confirmer une proposition : seul son identifiant est envoyé, jamais l\'opération', () async {
      await repository.resolveProposal('p-1', confirm: true);
      expectSingleApiPrefix('/api/ai/actions/execute/');
      expect(adapter.requests.last.data, {'interaction_id': 'p-1', 'decision': 'confirm'});
    });

    test('annuler une proposition', () async {
      await repository.resolveProposal('p-1', confirm: false);
      expect(adapter.requests.last.data, {'interaction_id': 'p-1', 'decision': 'cancel'});
    });
  });
}
