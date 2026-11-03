import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/ai/data/ai_provider.dart';
import 'package:nataal_agro/features/ai/data/services/voice_service.dart';
import 'package:nataal_agro/screens/assistant/voice_sheet.dart';
import 'package:nataal_agro/ui/ui.dart';

class FakeVoice implements VoiceService {
  FakeVoice(this.stream, {this.available = true});

  final StreamController<Uint8List> stream;
  final bool available;
  bool stopped = false;

  @override
  Future<Stream<Uint8List>?> startLive() async => available ? stream.stream : null;

  @override
  Future<void> stopLive() async => stopped = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeRepository implements AiRepository {
  final List<({int seq, int bytes, bool isFinal})> sent = [];
  final Map<int, String> partialTexts = {0: 'j ai vendu', 1: 'j ai vendu dis sac'};
  String finalText = 'J\'ai vendu 10 sacs';
  bool failFinal = false;

  @override
  Future<LiveVoiceResult> sendLiveChunk({required String session, required int seq, required Uint8List pcm, String language = 'fr', bool isFinal = false}) async {
    sent.add((seq: seq, bytes: pcm.length, isFinal: isFinal));
    if (isFinal) {
      if (failFinal) throw const VoiceException('Je n\'ai rien entendu. Rapprochez-vous du micro et réessayez.');
      return LiveVoiceResult(text: finalText, rawText: 'j ai vendu dis sac');
    }
    return LiveVoiceResult(text: partialTexts[seq] ?? '', rawText: partialTexts[seq] ?? '');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> pumpSheet(WidgetTester tester, FakeVoice voice, FakeRepository repo, ValueChanged<String> onSend) async {
  tester.view.physicalSize = const Size(390, 900) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [voiceServiceProvider.overrideWithValue(voice), aiRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: NaatalTheme.light,
        home: Scaffold(body: SingleChildScrollView(child: VoiceSheet(onSend: onSend))),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

Uint8List sound(int bytes) => Uint8List(bytes);

void main() {
  testWidgets('le texte apparaît pendant que la personne parle, puis elle confirme', (tester) async {
    final stream = StreamController<Uint8List>();
    final repo = FakeRepository();
    final sent = <String>[];
    await pumpSheet(tester, FakeVoice(stream), repo, sent.add);

    expect(find.text('Je vous écoute'), findsOneWidget);
    expect(find.textContaining('Parlez'), findsWidgets);
    expect(find.textContaining(':'), findsNothing, reason: 'pas de minuteur à l\'écran');

    stream.add(sound(48000));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();
    expect(find.text('j ai vendu'), findsOneWidget); // texte visible AVANT la fin de la phrase

    stream.add(sound(48000));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();
    expect(find.text('j ai vendu dis sac'), findsOneWidget);

    await tester.tap(find.text('J\'ai fini de parler'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('J\'ai compris :'), findsOneWidget);
    expect(find.text('J\'ai vendu 10 sacs'), findsOneWidget);
    expect(sent, isEmpty, reason: 'rien n\'est envoyé tant que la personne n\'a pas confirmé');

    await tester.tap(find.text('Oui, envoyer'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(sent, ['J\'ai vendu 10 sacs']);
    expect(repo.sent.map((c) => c.seq), [0, 1, 2]);
    expect(repo.sent.last.isFinal, isTrue);
    unawaited(stream.close());
  });

  testWidgets('« Non, recommencer » repart d\'un écran vide', (tester) async {
    final stream = StreamController<Uint8List>.broadcast(); // le micro redémarre : un nouveau flux est écouté
    final repo = FakeRepository();
    await pumpSheet(tester, FakeVoice(stream), repo, (_) {});
    stream.add(sound(48000));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.tap(find.text('J\'ai fini de parler'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.tap(find.text('Non, recommencer'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600)); // fin du fondu entre l'ancien texte et l'écran vide
    expect(find.text('Je vous écoute'), findsOneWidget);
    expect(find.text('J\'ai vendu 10 sacs'), findsNothing);
    unawaited(stream.close());
  });

  testWidgets('un micro inutilisable est dit clairement', (tester) async {
    final stream = StreamController<Uint8List>();
    await pumpSheet(tester, FakeVoice(stream, available: false), FakeRepository(), (_) {});
    expect(find.textContaining('Impossible d\'activer le micro'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    unawaited(stream.close());
  });

  testWidgets('rien entendu : le message du serveur est affiché', (tester) async {
    final stream = StreamController<Uint8List>();
    final repo = FakeRepository()..failFinal = true;
    await pumpSheet(tester, FakeVoice(stream), repo, (_) {});
    await tester.tap(find.text('J\'ai fini de parler'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.textContaining('Je n\'ai rien entendu'), findsOneWidget);
    unawaited(stream.close());
  });
}
