import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/ai/data/models/ai_message.dart';
import 'package:nataal_agro/screens/assistant/analysis_visual.dart';
import 'package:nataal_agro/ui/ui.dart';

Widget _host(Map<String, dynamic> visual, {ThemeData? theme, double width = 360}) => MaterialApp(
      theme: theme ?? NaatalTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(child: SizedBox(width: width, child: AnalysisVisualCard(visual: visual))),
      ),
    );

final _bars = {
  'type': 'bars',
  'title': 'Recettes et dépenses',
  'unit': 'FCFA',
  'items': [
    {'label': 'Recettes', 'value': 1500000, 'tone': 'positive'},
    {'label': 'Dépenses', 'value': 1800000, 'tone': 'negative'},
    {'label': 'Résultat estimé', 'value': -300000, 'tone': 'negative'},
  ],
};

void main() {
  test('formatAmount : milliers français et signe moins', () {
    expect(formatAmount(1234567), '1\u202f234\u202f567');
    expect(formatAmount(-300000), '−300\u202f000');
    expect(formatAmount(0), '0');
  });

  test('isDrawable refuse les descripteurs inconnus ou vides', () {
    expect(AnalysisVisualCard.isDrawable(null), isFalse);
    expect(AnalysisVisualCard.isDrawable({'type': 'camembert', 'items': [1]}), isFalse);
    expect(AnalysisVisualCard.isDrawable({'type': 'bars', 'items': []}), isFalse);
    expect(AnalysisVisualCard.isDrawable({'type': 'compare', 'rows': [{}]}), isTrue);
    expect(AnalysisVisualCard.isDrawable(_bars), isTrue);
  });

  testWidgets('barres : libellés, montants et résultat négatif affichés en toutes lettres', (tester) async {
    await tester.pumpWidget(_host(_bars));
    expect(find.text('Recettes et dépenses'), findsOneWidget);
    expect(find.text('1\u202f500\u202f000 FCFA'), findsOneWidget);
    expect(find.text('−300\u202f000 FCFA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comparaison : légende avec les deux périodes', (tester) async {
    await tester.pumpWidget(_host({
      'type': 'compare', 'title': 'Comparaison', 'unit': 'FCFA', 'current_label': 'octobre 2026', 'previous_label': 'septembre 2026',
      'rows': [{'label': 'Recettes', 'current': 20000, 'previous': 5000}],
    }));
    expect(find.text('octobre 2026'), findsOneWidget);
    expect(find.text('septembre 2026'), findsOneWidget);
    expect(find.text('20\u202f000 FCFA'), findsOneWidget);
  });

  testWidgets('évolution mensuelle : se dessine en clair comme en sombre, avec la mention du mois en cours', (tester) async {
    final months = {
      'type': 'months', 'title': 'Par mois', 'unit': 'FCFA',
      'items': [
        {'label': 'août 2026', 'revenue': 100000, 'expenses': 40000, 'partial': false},
        {'label': 'octobre 2026', 'revenue': 0, 'expenses': 0, 'partial': true},
      ],
    };
    for (final theme in [NaatalTheme.light, NaatalTheme.dark]) {
      await tester.pumpWidget(_host(months, theme: theme));
      await tester.pumpAndSettle();
      expect(find.text('Le dernier mois est en cours (incomplet).'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('stock : le niveau est écrit, pas seulement coloré', (tester) async {
    await tester.pumpWidget(_host({
      'type': 'levels', 'title': 'État des stocks',
      'items': [{'label': 'Mil', 'quantity': 3, 'unit': 'sac', 'level': 'critique', 'cover_days': 2.5}],
    }));
    expect(find.textContaining('Rupture imminente'), findsOneWidget);
  });

  testWidgets('petit écran et étiquette très longue : pas de débordement', (tester) async {
    await tester.pumpWidget(_host({
      'type': 'bars', 'title': 'Test', 'unit': 'FCFA',
      'items': [{'label': 'Un nom de produit extrêmement long qui ne tient jamais sur une seule ligne d\'écran', 'value': 123456789, 'tone': 'positive'}],
    }, width: 260));
    expect(tester.takeException(), isNull);
  });

  testWidgets('descripteur invalide : rien n\'est dessiné', (tester) async {
    await tester.pumpWidget(_host({'type': 'inconnu'}));
    expect(find.byType(Text), findsNothing);
  });

  test('le descripteur traverse le modèle jusqu\'au message', () {
    final answer = AiAnswer.fromJson({
      'id': '1', 'response': 'Bilan', 'origin': 'database',
      'action_data': {'kind': 'analysis', 'visual': _bars},
    });
    expect(answer.actionData?.visual?['type'], 'bars');
    expect(answer.actionData?.isProposal, isFalse);
    expect(AiMessage.fromAnswer(answer, timestamp: DateTime(2026)).actionData?.visual, isNotNull);
  });
}
