import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:nataal_agro/features/ai/data/ai_provider.dart';
import 'package:nataal_agro/features/ai/data/models/ai_message.dart';
import 'package:nataal_agro/features/ai/data/services/voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faux serveur qui répond avec un statut et un corps donnés.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

AiRepository _repository(int status, Map<String, dynamic> body) =>
    AiRepository(ApiClient(httpClientAdapter: _FixedAdapter(status, body)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Transcription : des messages d\'erreur que l\'on peut montrer', () {
    test('texte transcrit', () async {
      final text = await _repository(200, {'text': 'J\'ai vendu dix sacs de mil'}).transcribeAudio(Uint8List(10));
      expect(text, 'J\'ai vendu dix sacs de mil');
    });

    test('rien d\'audible : le message du serveur est repris tel quel', () async {
      final repo = _repository(422, {'text': '', 'error': 'Je n\'ai rien entendu. Rapprochez-vous du micro et réessayez.', 'code': 'no_speech'});
      expect(
        () => repo.transcribeAudio(Uint8List(10)),
        throwsA(isA<VoiceException>().having((e) => e.message, 'message', contains('rien entendu'))),
      );
    });

    test('service indisponible : on propose d\'écrire', () async {
      final repo = _repository(503, {'error': 'Le service de transcription est momentanément indisponible. Vous pouvez écrire votre message.'});
      expect(
        () => repo.transcribeAudio(Uint8List(10)),
        throwsA(isA<VoiceException>().having((e) => e.message, 'message', contains('écrire'))),
      );
    });

    test('réponse inattendue : message générique, jamais une trace technique', () async {
      final repo = _repository(200, {'autre': 'chose'});
      expect(
        () => repo.transcribeAudio(Uint8List(10)),
        throwsA(isA<VoiceException>().having((e) => e.message, 'message', isNot(contains('Exception')))),
      );
    });
  });

  group('Lecture à voix haute', () {
    test('le wolof n\'est pas lu avec une voix française', () {
      expect(VoiceService.canSpeak('wo'), isFalse);
      expect(VoiceService.canSpeak('fr'), isTrue);
      expect(VoiceService.canSpeak('mixed'), isTrue);
      expect(VoiceService.canSpeak(null), isTrue);
    });

    test('la langue du serveur est conservée jusqu\'au message affiché', () {
      final answer = AiAnswer.fromJson({'id': '1', 'response': 'Waaw', 'origin': 'general', 'language': 'wo'});
      final message = AiMessage.fromAnswer(answer, timestamp: DateTime(2026));
      expect(message.language, 'wo');
      expect(message.copyWith().language, 'wo');
      expect(AiAnswer.fromJson({'response': 'ok'}).language, isNull);
    });
  });
}
