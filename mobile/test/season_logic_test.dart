import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/calendar/data/models/crop_calendar.dart';
import 'package:nataal_agro/features/calendar/domain/season_logic.dart';

Span span(int m1, int d1, int m2, int d2) => Span(MonthDay(m1, d1), MonthDay(m2, d2));

CalendarWindow window({
  String zone = 'niayes',
  String label = '',
  bool allYear = false,
  Span? sow,
  Span? harvest,
  int? cycleMax,
}) =>
    CalendarWindow(
      zone: zone,
      label: label,
      allYear: allYear,
      sow: sow,
      harvest: harvest,
      cycleMin: null,
      cycleMax: cycleMax,
      periodText: '',
      notes: '',
      sourceKey: 'fao',
      sourceNote: '',
    );

CalendarCrop crop(String key, List<CalendarWindow> windows, {String category = 'legume'}) =>
    CalendarCrop(key: key, name: key, category: category, windows: windows);

void main() {
  group('Période de l\'année', () {
    test('une période dans la même année', () {
      final june = span(6, 10, 7, 31);
      expect(june.contains(DateTime(2026, 6, 10)), isTrue, reason: 'premier jour');
      expect(june.contains(DateTime(2026, 7, 31)), isTrue, reason: 'dernier jour');
      expect(june.contains(DateTime(2026, 6, 9)), isFalse);
      expect(june.contains(DateTime(2026, 8, 1)), isFalse);
      expect(june.wraps, isFalse);
    });

    test('une période qui passe d\'une année à l\'autre (du 1er novembre au 28 février)', () {
      final winter = span(11, 1, 2, 28);
      expect(winter.wraps, isTrue);
      for (final d in [DateTime(2026, 11, 1), DateTime(2026, 12, 25), DateTime(2027, 1, 15), DateTime(2027, 2, 28)]) {
        expect(winter.contains(d), isTrue, reason: '$d');
      }
      for (final d in [DateTime(2026, 10, 31), DateTime(2027, 3, 1), DateTime(2026, 7, 4)]) {
        expect(winter.contains(d), isFalse, reason: '$d');
      }
    });

    test('les mois touchés, y compris en passant par décembre', () {
      expect(span(9, 1, 10, 31).months, {9, 10});
      expect(span(11, 1, 2, 28).months, {11, 12, 1, 2});
      expect(span(6, 15, 8, 10).months, {6, 7, 8});
    });

    test('jours avant le début : cette année, ou l\'année prochaine si c\'est passé', () {
      final sowing = span(10, 1, 11, 30);
      expect(sowing.daysUntilStart(DateTime(2026, 9, 10)), 21);
      expect(sowing.daysUntilStart(DateTime(2026, 10, 15)), 0, reason: 'en cours');
      expect(sowing.daysUntilStart(DateTime(2026, 12, 1)), 304, reason: 'prochain début : 1er octobre 2027');
      expect(sowing.nextStart(DateTime(2026, 9, 10)), DateTime(2026, 10, 1));
    });

    test('jours restants, avec une période qui passe l\'année', () {
      expect(span(6, 10, 7, 31).daysLeft(DateTime(2026, 7, 19)), 12);
      expect(span(6, 10, 7, 31).daysLeft(DateTime(2026, 7, 31)), 0, reason: 'dernier jour');
      final winter = span(11, 1, 2, 28);
      expect(winter.daysLeft(DateTime(2026, 12, 31)), 59, reason: 'jusqu\'au 28 février 2027');
      expect(winter.daysLeft(DateTime(2027, 2, 1)), 27);
    });

    test('le 29 février d\'une année non bissextile devient le 28', () {
      expect(const MonthDay(2, 29).inYear(2026), DateTime(2026, 2, 28));
      expect(const MonthDay(2, 29).inYear(2028), DateTime(2028, 2, 29));
    });
  });

  group('Situation d\'une culture', () {
    // Oignon des Niayes d'après la FAO : semis hâtif sept.–oct., de saison nov.–déc., tardif janv.–févr.
    final onion = crop('oignon', [
      window(label: 'Culture hâtive', sow: span(9, 1, 10, 31), harvest: span(12, 1, 2, 28), cycleMax: 100),
      window(label: 'Pleine saison', sow: span(11, 1, 12, 31), harvest: span(3, 1, 4, 30), cycleMax: 150),
      window(label: 'Culture tardive', sow: span(1, 1, 2, 28), harvest: span(5, 1, 7, 31), cycleMax: 150),
    ]);

    test('en pleine période de semis : on dit qu\'on peut semer, pas qu\'il faut se préparer', () {
      final season = seasonOf(onion, 'niayes', DateTime(2026, 10, 24));
      expect(season.sowingNow.single.label, 'Culture hâtive');
      expect(season.prepare, isNull, reason: 'la période suivante n\'est pas annoncée pendant qu\'une autre est ouverte');
      expect(season.harvestNow, isEmpty);
    });

    test('quelques semaines avant : « préparez », avec le délai en toutes lettres', () {
      final season = seasonOf(onion, 'niayes', DateTime(2026, 8, 11)); // 21 jours avant le 1er septembre
      expect(season.sowingNow, isEmpty);
      expect(season.prepare!.window.label, 'Culture hâtive');
      expect(season.prepare!.daysUntil, 21);
      expect(season.prepare!.inWords, 'dans 3 semaines');
      expect(season.prepare!.startsOn, DateTime(2026, 9, 1));
    });

    test('trop tôt : rien n\'est annoncé', () {
      expect(seasonOf(onion, 'niayes', DateTime(2026, 7, 1)).prepare, isNull, reason: '62 jours avant : au-delà du délai de 4 semaines');
    });

    test('la récolte en cours est signalée', () {
      final season = seasonOf(onion, 'niayes', DateTime(2027, 1, 20));
      expect(season.harvestNow.single.label, 'Culture hâtive');
      expect(season.sowingNow.single.label, 'Culture tardive', reason: 'le 20 janvier : on sème encore la culture tardive');
    });

    test('une autre zone n\'est pas concernée', () {
      expect(seasonOf(onion, 'casamance', DateTime(2026, 10, 24)).hasAnything, isFalse);
    });

    test('une période valable « toutes zones » compte pour chaque zone', () {
      final lime = crop('lime', [window(zone: 'all', harvest: span(9, 1, 11, 30))], category: 'fruit');
      expect(seasonOf(lime, 'casamance', DateTime(2026, 10, 1)).harvestNow, hasLength(1));
      expect(seasonOf(lime, 'niayes', DateTime(2026, 10, 1)).harvestNow, hasLength(1));
    });

    test('un semis possible toute l\'année est signalé à part, sans compte à rebours', () {
      final okra = crop('gombo', [window(zone: 'all', allYear: true)]);
      final season = seasonOf(okra, 'niayes', DateTime(2026, 10, 24));
      expect(season.allYear, isTrue);
      expect(season.prepare, isNull);
      expect(season.sowingNow, isEmpty);
    });

    test('un arbre fruitier : pas de semis, seulement une récolte', () {
      final mango = crop('mangue', [window(harvest: span(6, 15, 8, 10))], category: 'fruit');
      final july = seasonOf(mango, 'niayes', DateTime(2026, 7, 10));
      expect(july.harvestNow, hasLength(1));
      expect(july.sowingNow, isEmpty);
      expect(seasonOf(mango, 'niayes', DateTime(2026, 10, 24)).hasAnything, isFalse);
    });
  });

  group('Délai d\'annonce selon le cycle', () {
    test('culture à cycle court : 4 semaines', () {
      expect(leadDays(crop('x', []), [window(cycleMax: 90)]), 28);
      expect(leadDays(crop('x', []), [window()]), 28);
    });

    test('culture à long cycle : 6 semaines', () {
      expect(leadDays(crop('x', []), [window(cycleMax: 180)]), 42);
      expect(leadDays(crop('x', []), [window(cycleMax: 365)]), 42);
    });

    test('une culture à long cycle est annoncée plus tôt', () {
      final longCycle = crop('canne', [window(sow: span(10, 1, 10, 31), cycleMax: 365)]);
      final shortCycle = crop('chou', [window(sow: span(10, 1, 10, 31), cycleMax: 90)]);
      final day = DateTime(2026, 8, 25); // 37 jours avant le 1er octobre
      expect(seasonOf(longCycle, 'niayes', day).prepare, isNotNull);
      expect(seasonOf(shortCycle, 'niayes', day).prepare, isNull);
    });
  });

  group('Bilan du jour', () {
    final tomato = crop('tomate', [window(sow: span(10, 1, 1, 31), harvest: span(12, 20, 6, 30), cycleMax: 150)]);
    final onion = crop('oignon', [window(sow: span(11, 1, 12, 31), harvest: span(3, 1, 4, 30))]);
    final potato = crop('pomme-de-terre', [window(sow: span(2, 1, 3, 31))]);

    test('classe les cultures : semis, récolte, préparation', () {
      final summary = summarize([tomato, onion, potato], 'niayes', DateTime(2026, 10, 24));
      expect(summary.sowing.map((s) => s.crop.key), ['tomate']);
      expect(summary.harvesting, isEmpty);
      expect(summary.prepare.map((s) => s.crop.key), ['oignon'], reason: 'l\'oignon de saison commence dans 8 jours');
    });

    test('les semis qui se ferment bientôt passent en premier', () {
      final late = crop('a-tard', [window(sow: span(10, 1, 12, 31))]);
      final soon = crop('b-vite', [window(sow: span(10, 1, 10, 31))]);
      final summary = summarize([late, soon], 'niayes', DateTime(2026, 10, 24));
      expect(summary.sowing.map((s) => s.crop.key), ['b-vite', 'a-tard']);
    });

    test('un mois sans rien : le bilan est vide', () {
      expect(summarize([tomato, onion, potato], 'niayes', DateTime(2026, 7, 10)).isEmpty, isTrue);
    });
  });

  group('Activité par mois (grille de l\'année)', () {
    final tomato = crop('tomate', [window(sow: span(10, 1, 1, 31), harvest: span(12, 20, 6, 30))]);

    test('semis et récolte par mois, même quand la période passe l\'année', () {
      expect(activityInMonth(tomato, 'niayes', 11).sowing, isTrue);
      expect(activityInMonth(tomato, 'niayes', 1).sowing, isTrue);
      expect(activityInMonth(tomato, 'niayes', 1).harvesting, isTrue);
      expect(activityInMonth(tomato, 'niayes', 4).harvesting, isTrue);
      expect(activityInMonth(tomato, 'niayes', 8).any, isFalse);
    });

    test('toute l\'année : semis tous les mois', () {
      final okra = crop('gombo', [window(zone: 'all', allYear: true)]);
      for (var m = 1; m <= 12; m++) {
        expect(activityInMonth(okra, 'niayes', m).sowing, isTrue);
      }
    });
  });

  group('Zone proposée', () {
    final data = CalendarData(
      zones: const [],
      regionZones: const {'Dakar': ['niayes'], 'Thiès': ['bassin', 'niayes'], 'Kolda': ['casamance']},
      crops: const [],
      sources: const {},
      undocumented: const [],
    );

    test('la première zone de la région est proposée d\'office', () {
      expect(defaultZoneForRegion(data, 'Dakar'), 'niayes');
      expect(defaultZoneForRegion(data, 'Thiès'), 'bassin');
      expect(defaultZoneForRegion(data, 'Kolda'), 'casamance');
    });

    test('région inconnue : pas de zone devinée', () {
      expect(defaultZoneForRegion(data, 'Keur Massar'), isNull);
      expect(defaultZoneForRegion(data, null), isNull);
    });
  });
}
