import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/calendar/domain/season_logic.dart';
import 'package:nataal_agro/features/calendar/presentation/agricultural_calendar_screen.dart';
import 'package:nataal_agro/ui/ui.dart';

import 'support/calendar_fixture.dart';

Future<void> pumpCalendar(WidgetTester tester, {required DateTime today, String? zone = 'niayes', String? region = 'Dakar'}) async {
  tester.view.physicalSize = const Size(390, 2600) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: calendarOverrides(zone: zone, region: region),
      child: MaterialApp(
        theme: NaatalTheme.light,
        home: EffectsScope(reduced: true, child: AgriculturalCalendarScreen(today: today)),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Calendrier réel (données FAO) : logique sur la zone des Niayes', () {
    final data = loadCalendarFixture();

    test('le 24 octobre, on peut semer l\'oignon, la pomme de terre, le chou et la carotte aux Niayes', () {
      final summary = summarize(data.crops, 'niayes', DateTime(2026, 10, 24));
      final names = summary.sowing.map((s) => s.crop.name).toSet();
      expect(names, containsAll(['Oignon', 'Pomme de terre', 'Chou', 'Carotte']));
      expect(names, isNot(contains('Arachide')), reason: 'l\'arachide se sème en juin–juillet, pas en octobre');
      expect(names, isNot(contains('Mil')));
    });

    test('le 24 octobre aux Niayes, aucune culture n\'est dite « à récolter » sans période de récolte en cours', () {
      final summary = summarize(data.crops, 'niayes', DateTime(2026, 10, 24));
      for (final s in summary.harvesting) {
        expect(s.harvestNow.any((w) => w.harvest!.contains(DateTime(2026, 10, 24))), isTrue, reason: s.crop.name);
      }
    });

    test('mi-juillet, la mangue est en récolte aux Niayes', () {
      final summary = summarize(data.crops, 'niayes', DateTime(2026, 7, 10));
      expect(summary.harvesting.map((s) => s.crop.key), contains('mangue'));
    });

    test('dans le bassin arachidier, l\'arachide se sème en juin et on prépare avant', () {
      final prepare = summarize(data.crops, 'bassin', DateTime(2026, 5, 20)).prepare;
      final groundnut = prepare.firstWhere((s) => s.crop.key == 'arachide');
      expect(groundnut.prepare!.daysUntil, 21, reason: 'le 10 juin');
      expect(groundnut.prepare!.inWords, 'dans 3 semaines');
    });

    test('en Casamance au mois de mai, le mil, le maïs et le riz se sèment', () {
      final names = summarize(data.crops, 'casamance', DateTime(2026, 5, 15)).sowing.map((s) => s.crop.key).toSet();
      expect(names, containsAll(['mil', 'mais', 'riz', 'arachide', 'niebe']));
    });

    test('toutes les cultures sont dans le calendrier du Niayes ou d\'une autre zone', () {
      expect(data.crops.length, greaterThanOrEqualTo(30));
      for (final crop in data.crops) {
        expect(crop.windows, isNotEmpty, reason: crop.name);
      }
    });
  });

  group('Écran du calendrier', () {
    testWidgets('octobre aux Niayes : « C\'est le moment de semer », avec les cultures du moment', (tester) async {
      await pumpCalendar(tester, today: DateTime(2026, 10, 24));
      expect(find.text('Calendrier'), findsWidgets);
      expect(find.textContaining('AGRICOLE'), findsWidgets);
      expect(find.text('On sème maintenant'), findsOneWidget);
      expect(find.textContaining('À semer :'), findsOneWidget);
      expect(find.text('Semez maintenant'), findsOneWidget);
      expect(find.text('Oignon'), findsWidgets);
    });

    testWidgets('l\'écran dit d\'où viennent les dates et ce qu\'il ne sait pas', (tester) async {
      await pumpCalendar(tester, today: DateTime(2026, 10, 24));
      await tester.scrollUntilVisible(find.text('Sources'), 800, scrollable: find.byType(Scrollable).first);
      expect(find.text('Sources'), findsOneWidget);
      expect(find.textContaining('FAO Crop Calendar'), findsOneWidget);
      expect(find.text('Dates pas encore connues'), findsOneWidget);
      expect(find.textContaining('Orange'), findsWidgets);
    });

    testWidgets('on peut regarder un autre mois', (tester) async {
      await pumpCalendar(tester, today: DateTime(2026, 10, 24));
      await tester.drag(find.text('Oct.'), const Offset(600, 0)); // la bande des mois s'ouvre sur octobre
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Juil.'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Récoltez en juillet'), findsOneWidget);
      expect(find.text('Mangue'), findsWidgets);
    });

    testWidgets('quelques semaines avant, l\'écran dit de préparer et dans combien de temps', (tester) async {
      // Bassin arachidier : l'arachide se sème à partir du 10 juin
      await pumpCalendar(tester, today: DateTime(2026, 5, 20), zone: 'bassin');
      expect(find.text('Bientôt'), findsOneWidget);
      expect(find.text('Arachide'), findsWidgets);
      expect(find.text('Préparez dans 3 semaines'), findsWidgets);
    });

    testWidgets('sans zone connue, l\'écran demande où l\'on cultive au lieu de deviner', (tester) async {
      await pumpCalendar(tester, today: DateTime(2026, 10, 24), zone: null, region: null);
      expect(find.text('Où cultivez-vous ?'), findsOneWidget);
      expect(find.text('Niayes'), findsOneWidget);
      expect(find.text('Casamance'), findsOneWidget);
      expect(find.text('On sème maintenant'), findsNothing);
    });

    testWidgets('toucher une culture de la grille ouvre son détail sourcé', (tester) async {
      await pumpCalendar(tester, today: DateTime(2026, 10, 24));
      await tester.scrollUntilVisible(find.text('Touchez une culture pour le détail'), 800, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Oignon').last);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Culture hâtive'), findsOneWidget);
      expect(find.text('Semis'), findsWidgets);
      expect(find.textContaining('FAO Crop Calendar'), findsWidgets);
    });
  });
}
