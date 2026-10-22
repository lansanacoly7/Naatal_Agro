import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:nataal_agro/features/ai/data/ai_provider.dart';
import 'package:nataal_agro/features/ai/data/models/ai_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Handler = ResponseBody Function(RequestOptions options);

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handler);

  final _Handler handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
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

const _proposal = {
  'id': 'p-1',
  'conversation_id': 'c-1',
  'response': '📋 Proposition d\'opération',
  'origin': 'database',
  'suggestions': ['Oui, valider', 'Non, annuler'],
  'action_data': {
    'status': 'pending_confirmation',
    'action_type': 'record_sale',
    'parameters': {'product_name': 'Riz', 'quantity': 25},
    'summary': 'Vente de 25 sacs de riz',
    'warnings': ['Stock insuffisant : 10 sacs disponibles pour 25 vendus.'],
  },
};

const _executed = {
  'id': 'o-1',
  'conversation_id': 'c-1',
  'response': '✅ Opération confirmée et enregistrée !',
  'origin': 'database',
  'suggestions': [],
  'action_data': {'status': 'executed', 'proposal_id': 'p-1', 'result': {'success': true}},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Modèles : proposition d\'opération', () {
    test('lit les avertissements, les statuts et l\'identifiant du serveur', () {
      final answer = AiAnswer.fromJson(Map<String, dynamic>.from(_proposal));
      expect(answer.interactionId, 'p-1');
      expect(answer.actionData!.isProposal, isTrue);
      expect(answer.actionData!.isPending, isTrue);
      expect(answer.actionData!.warnings, hasLength(1));

      final outcome = AiAnswer.fromJson(Map<String, dynamic>.from(_executed));
      expect(outcome.actionData!.isProposal, isFalse);
      expect(outcome.actionData!.isExecuted, isTrue);
    });

    test('copyWith ne change que le statut et conserve les avertissements', () {
      final data = AiAnswer.fromJson(Map<String, dynamic>.from(_proposal)).actionData!;
      final done = data.copyWith(status: 'cancelled');
      expect(done.isCancelled, isTrue);
      expect(done.isPending, isFalse);
      expect(done.warnings, data.warnings);
      expect(done.summary, data.summary);
    });

    test('AiMessage.fromAnswer conserve l\'identifiant, copyWith met à jour l\'action', () {
      final message = AiMessage.fromAnswer(
        AiAnswer.fromJson(Map<String, dynamic>.from(_proposal)),
        timestamp: DateTime(2026, 10, 22),
      );
      expect(message.interactionId, 'p-1');
      final updated = message.copyWith(actionData: message.actionData!.copyWith(status: 'executed'));
      expect(updated.interactionId, 'p-1');
      expect(updated.actionData!.isExecuted, isTrue);
      expect(message.actionData!.isPending, isTrue, reason: 'le message d\'origine n\'est pas modifié');
    });

    test('un statut inconnu n\'est ni en attente ni exécuté', () {
      const data = AiActionData(status: 'inconnu', actionType: 'record_sale');
      expect(data.isPending || data.isExecuted || data.isFailed || data.isCancelled, isFalse);
    });
  });

  group('Flux de confirmation dans le chat', () {
    late _ScriptedAdapter adapter;
    late ChatNotifier chat;

    Future<ChatNotifier> build(_Handler handler) async {
      adapter = _ScriptedAdapter(handler);
      final notifier = ChatNotifier(AiRepository(ApiClient(httpClientAdapter: adapter)));
      await pumpEventQueue();
      return notifier;
    }

    ResponseBody defaultHandler(RequestOptions o) {
      if (o.method == 'GET') return _json(200, <dynamic>[]);
      if (o.path == '/ai/ask/') return _json(201, _proposal);
      if (o.path == '/ai/actions/execute/') return _json(201, _executed);
      return _json(404, {'error': 'inconnu'});
    }

    Future<AiMessage> proposeSale() async {
      await chat.sendMessage('J\'ai vendu 25 sacs de riz à 12000 FCFA');
      final message = chat.state.messages.last;
      expect(message.actionData!.isPending, isTrue);
      return message;
    }

    int resolveCalls() => adapter.requests.where((r) => r.path == '/ai/actions/execute/').length;

    test('confirmer envoie l\'identifiant, met à jour la carte et ajoute le résultat', () async {
      chat = await build(defaultHandler);
      final proposal = await proposeSale();
      expect(proposal.interactionId, 'p-1');
      expect(proposal.actionData!.warnings.single, contains('Stock insuffisant'));

      await chat.resolveProposal(proposal, confirm: true);

      final request = adapter.requests.lastWhere((r) => r.path == '/ai/actions/execute/');
      expect(request.data, {'interaction_id': 'p-1', 'decision': 'confirm'});
      expect(chat.state.isLoading, isFalse);

      final messages = chat.state.messages;
      final card = messages.firstWhere((m) => m.interactionId == 'p-1');
      expect(card.actionData!.isExecuted, isTrue, reason: 'la carte de la proposition reflète l\'état du serveur');
      expect(messages.any((m) => m.isUser && m.text == 'Oui, je confirme'), isTrue);
      expect(messages.last.interactionId, 'o-1');
      expect(messages.last.actionData!.isProposal, isFalse);
      expect(messages.last.actionData!.isExecuted, isTrue);
    });

    test('un double appui n\'envoie qu\'une seule requête', () async {
      chat = await build(defaultHandler);
      final proposal = await proposeSale();

      final first = chat.resolveProposal(proposal, confirm: true);
      final second = chat.resolveProposal(proposal, confirm: true);
      await Future.wait([first, second]);

      expect(resolveCalls(), 1);
    });

    test('une coupure réseau laisse la proposition confirmable et explique qu\'on peut réessayer', () async {
      chat = await build((o) {
        if (o.path == '/ai/actions/execute/') {
          throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
        }
        return defaultHandler(o);
      });
      final proposal = await proposeSale();

      await chat.resolveProposal(proposal, confirm: true);

      final messages = chat.state.messages;
      expect(messages.last.isError, isTrue);
      expect(messages.last.text, contains('une seule fois'));
      expect(messages.firstWhere((m) => m.interactionId == 'p-1').actionData!.isPending, isTrue);
      expect(chat.state.isLoading, isFalse);
    });

    test('un conflit serveur (proposition remplacée) affiche le message du serveur', () async {
      chat = await build((o) {
        if (o.path == '/ai/actions/execute/') {
          return _json(409, {'error': 'Cette proposition a été remplacée par une demande plus récente.', 'code': 'superseded'});
        }
        return defaultHandler(o);
      });
      final proposal = await proposeSale();

      await chat.resolveProposal(proposal, confirm: true);

      expect(chat.state.messages.last.isError, isTrue);
      expect(chat.state.messages.last.text, contains('remplacée'));
    });

    test('un message sans identifiant serveur ne peut pas être confirmé', () async {
      chat = await build(defaultHandler);
      final local = AiMessage(text: 'x', isUser: false, timestamp: DateTime.now());

      await chat.resolveProposal(local, confirm: true);

      expect(resolveCalls(), 0);
    });
  });
}
