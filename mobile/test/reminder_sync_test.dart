import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:nataal_agro/features/ai/data/ai_provider.dart';
import 'package:nataal_agro/features/ai/data/models/ai_message.dart';
import 'package:nataal_agro/features/reminders/data/reminder_alarms.dart';
import 'package:nataal_agro/features/reminders/data/reminder_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Handler = ResponseBody Function(RequestOptions options);

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handler);

  _Handler handler;
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

/// Alarmes simulées : enregistre ce qui est programmé et annulé.
class _FakeAlarms implements AlarmPlatform {
  final Map<int, ({String body, DateTime when})> scheduled = {};
  final List<int> cancelledIds = [];
  int cancelAllCalls = 0;

  @override
  Future<void> schedule({required int id, required String title, required String body, required DateTime when}) async {
    scheduled[id] = (body: body, when: when);
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    cancelledIds.add(id);
  }

  @override
  Future<Set<int>> pendingIds() async => scheduled.keys.toSet();

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    scheduled.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 22, 14, 0);
  Map<String, Object?> row(String id, String message, DateTime when) =>
      {'id': id, 'message': message, 'scheduled_for': when.toUtc().toIso8601String()};

  late _ScriptedAdapter adapter;
  late _FakeAlarms alarms;
  late ReminderSync sync;
  late Object listBody;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    listBody = <Object>[];
    adapter = _ScriptedAdapter((o) => _json(200, listBody));
    alarms = _FakeAlarms();
    sync = ReminderSync(ApiClient(httpClientAdapter: adapter), alarms, clock: () => now);
  });

  group('Identifiants d\'alarme stables', () {
    test('valeurs de référence FNV-1a (identiques d\'une exécution à l\'autre)', () {
      expect(stableAlarmId(''), 0x811c9dc5 & 0x7fffffff);
      expect(stableAlarmId('a'), 0xe40c292c & 0x7fffffff);
    });

    test('toujours positif, déterministe, et distinct d\'un rappel à l\'autre', () {
      const a = '5f07213a-0745-4ff5-a101-6bd6a21710e8';
      const b = '3a084687-c0ca-457a-9bf6-a6621ea6d551';
      expect(stableAlarmId(a), stableAlarmId(a));
      expect(stableAlarmId(a), isNot(stableAlarmId(b)));
      expect(stableAlarmId(a), inInclusiveRange(0, 0x7fffffff));
    });
  });

  group('Synchronisation des alarmes', () {
    test('interroge les rappels à venir et programme chacun à son heure', () async {
      final soon = now.add(const Duration(hours: 3));
      final later = now.add(const Duration(days: 1));
      listBody = [row('r-1', 'Arroser les piments', soon), row('r-2', 'Traiter les tomates', later)];

      final result = await sync.sync();

      expect(adapter.requests.single.uri.path, '/api/notifications/');
      expect(adapter.requests.single.uri.queryParameters, {'scope': 'scheduled'});
      expect(result.scheduled, 2);
      expect(alarms.scheduled[stableAlarmId('r-1')]!.body, 'Arroser les piments');
      expect(alarms.scheduled[stableAlarmId('r-1')]!.when.isAtSameMomentAs(soon), isTrue);
      expect(alarms.scheduled.length, 2);
    });

    test('ignore les rappels passés ou imminents (le serveur les délivre) et les lignes illisibles', () async {
      listBody = [
        row('past', 'Déjà passé', now.subtract(const Duration(minutes: 5))),
        row('imminent', 'Dans 2 secondes', now.add(const Duration(seconds: 2))),
        {'id': 'no-date', 'message': 'Sans date', 'scheduled_for': null},
        {'message': 'Sans identifiant', 'scheduled_for': now.add(const Duration(hours: 1)).toIso8601String()},
        'pas un objet',
        row('ok', 'Valide', now.add(const Duration(hours: 1))),
      ];

      final result = await sync.sync();

      expect(result.scheduled, 1);
      expect(alarms.scheduled.keys, [stableAlarmId('ok')]);
    });

    test('retire l\'alarme d\'un rappel annulé ou délivré côté serveur', () async {
      final when = now.add(const Duration(hours: 5));
      listBody = [row('r-1', 'Arroser', when), row('r-2', 'Traiter', when)];
      await sync.sync();
      expect(alarms.scheduled.length, 2);

      listBody = [row('r-2', 'Traiter', when)]; // r-1 annulé via l'assistant
      final result = await sync.sync();

      expect(result.cancelled, 1);
      expect(alarms.cancelledIds, [stableAlarmId('r-1')]);
      expect(alarms.scheduled.keys, [stableAlarmId('r-2')]);
    });

    test('un rappel déplacé est reprogrammé à sa nouvelle heure sans doublon', () async {
      listBody = [row('r-1', 'Arroser', now.add(const Duration(hours: 2)))];
      await sync.sync();
      final moved = now.add(const Duration(days: 2));
      listBody = [row('r-1', 'Arroser', moved)];

      await sync.sync();

      expect(alarms.scheduled.length, 1);
      expect(alarms.scheduled[stableAlarmId('r-1')]!.when.isAtSameMomentAs(moved), isTrue);
    });

    test('rejouer la synchronisation ne change rien', () async {
      listBody = [row('r-1', 'Arroser', now.add(const Duration(hours: 2)))];
      await sync.sync();
      final snapshot = Map.of(alarms.scheduled);

      final second = await sync.sync();

      expect(second.cancelled, 0);
      expect(alarms.scheduled, snapshot);
      expect(alarms.cancelledIds, isEmpty);
    });

    test('accepte une réponse paginée', () async {
      listBody = {'count': 1, 'results': [row('r-1', 'Arroser', now.add(const Duration(hours: 2)))]};
      expect((await sync.sync()).scheduled, 1);
    });

    test('une panne réseau lève une erreur avec sync() mais jamais avec syncQuietly()', () async {
      adapter.handler = (o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError);

      await expectLater(sync.sync(), throwsA(isA<DioException>()));
      expect(await sync.syncQuietly(), isFalse);
    });

    test('syncQuietly renvoie vrai quand tout s\'est bien passé', () async {
      expect(await sync.syncQuietly(), isTrue);
    });

    test('clear retire toutes les alarmes (déconnexion)', () async {
      listBody = [row('r-1', 'Arroser', now.add(const Duration(hours: 2)))];
      await sync.sync();

      await sync.clear();

      expect(alarms.scheduled, isEmpty);
      expect(alarms.cancelAllCalls, 1);
    });
  });

  group('Alarmes dans l\'application (navigateur, ordinateur)', () {
    test('l\'alerte est émise à l\'échéance', () async {
      final platform = InAppAlarmPlatform();
      final alert = platform.alerts.first.timeout(const Duration(seconds: 2));

      await platform.schedule(id: 1, title: 'Rappel', body: 'Arroser', when: DateTime.now().add(const Duration(milliseconds: 40)));

      final received = await alert;
      expect(received.body, 'Arroser');
      expect(await platform.pendingIds(), isEmpty);
    });

    test('une alarme annulée ne sonne jamais', () async {
      final platform = InAppAlarmPlatform();
      var fired = 0;
      platform.alerts.listen((_) => fired++);

      await platform.schedule(id: 1, title: 'Rappel', body: 'Arroser', when: DateTime.now().add(const Duration(milliseconds: 40)));
      await platform.cancel(1);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(fired, 0);
    });

    test('reprogrammer remplace l\'alarme existante : une seule alerte', () async {
      final platform = InAppAlarmPlatform();
      var fired = 0;
      platform.alerts.listen((_) => fired++);
      final soon = DateTime.now().add(const Duration(milliseconds: 40));

      await platform.schedule(id: 1, title: 'Rappel', body: 'Arroser', when: soon);
      await platform.schedule(id: 1, title: 'Rappel', body: 'Arroser', when: soon);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(fired, 1);
    });

    test('cancelAll vide tout', () async {
      final platform = InAppAlarmPlatform();
      await platform.schedule(id: 1, title: 'a', body: 'a', when: DateTime.now().add(const Duration(hours: 1)));
      await platform.schedule(id: 2, title: 'b', body: 'b', when: DateTime.now().add(const Duration(hours: 2)));

      await platform.cancelAll();

      expect(await platform.pendingIds(), isEmpty);
    });
  });

  group('Chat : l\'assistant resynchronise les alarmes', () {
    Map<String, Object?> proposal(String id, String type) => {
          'id': id,
          'conversation_id': 'c-1',
          'response': 'Proposition',
          'origin': 'database',
          'suggestions': <String>[],
          'action_data': {'status': 'pending_confirmation', 'action_type': type, 'parameters': {}, 'summary': 'x'},
        };

    Map<String, Object?> outcome(String status, Map<String, Object?> data) => {
          'id': 'o-1',
          'conversation_id': 'c-1',
          'response': 'Résultat',
          'origin': 'database',
          'suggestions': <String>[],
          'action_data': {
            'status': status,
            'proposal_id': 'p-1',
            'result': {'success': status == 'executed', 'data': data},
          },
        };

    Future<int> confirmAndCountSyncs(String type, Map<String, Object?> outcomeBody) async {
      var syncs = 0;
      final chatAdapter = _ScriptedAdapter((o) {
        if (o.method == 'GET') return _json(200, <Object>[]);
        if (o.path == '/ai/ask/') return _json(201, proposal('p-1', type));
        return _json(201, outcomeBody);
      });
      final chat = ChatNotifier(AiRepository(ApiClient(httpClientAdapter: chatAdapter)), onReminderChanged: () => syncs++);
      await pumpEventQueue();
      await chat.sendMessage('demande');
      final message = chat.state.messages.last;
      await chat.resolveProposal(message, confirm: true);
      return syncs;
    }

    test('un rappel créé, reporté ou annulé déclenche la synchronisation', () async {
      expect(await confirmAndCountSyncs('create_reminder', outcome('executed', {'notification_id': 'n-1'})), 1);
      expect(await confirmAndCountSyncs('cancel_reminder', outcome('executed', {'notification_id': 'n-1', 'cancelled': true})), 1);
    });

    test('une dépense ou une opération échouée ne déclenche rien', () async {
      expect(await confirmAndCountSyncs('record_expense', outcome('executed', {'transaction_id': 't-1'})), 0);
      expect(await confirmAndCountSyncs('create_reminder', outcome('failed', {})), 0);
    });

    test('reminderId lit l\'identifiant du rappel dans le résultat', () {
      final action = AiActionData.fromJson({
        'status': 'executed',
        'result': {'data': {'notification_id': 'n-9'}},
      });
      expect(action.reminderId, 'n-9');
      expect(const AiActionData(status: 'executed').reminderId, isNull);
    });
  });
}
