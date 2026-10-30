import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/calendar/presentation/agricultural_calendar_screen.dart';
import 'package:nataal_agro/features/calendar/presentation/calendar_labels.dart';

import 'support/calendar_fixture.dart';
import 'support/visual_harness.dart';

/// Les images sont décodées en tâche de fond : sans cette attente, la capture les montrerait encore vides.
Future<void> precacheCropPhotos(WidgetTester tester) async {
  final keys = loadCalendarFixture().crops.map((c) => c.key);
  await tester.runAsync(() async {
    final context = tester.element(find.byType(Scaffold).first);
    for (final key in keys) {
      final asset = calendarCropImage(key);
      if (asset != null) await precacheImage(AssetImage(asset), context);
    }
  });
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(VisualHarness.init);

  for (final dark in [false, true]) {
    final tag = dark ? 'dark' : 'light';

    testWidgets('Calendrier agricole, 24 octobre, Niayes ($tag)', (tester) async {
      await VisualHarness.shoot(
        tester,
        'calendar_oct_$tag',
        AgriculturalCalendarScreen(today: DateTime(2026, 10, 24)),
        dark: dark,
        overrides: calendarOverrides(zone: 'niayes', region: 'Dakar'),
        size: const Size(390, 3000),
        afterPump: (t) => precacheCropPhotos(t),
      );
    });

    testWidgets('Calendrier agricole, 20 mai, bassin arachidier : à préparer ($tag)', (tester) async {
      await VisualHarness.shoot(
        tester,
        'calendar_may_$tag',
        AgriculturalCalendarScreen(today: DateTime(2026, 5, 20)),
        dark: dark,
        overrides: calendarOverrides(zone: 'bassin', region: 'Kaolack'),
        size: const Size(390, 1500),
        afterPump: (t) => precacheCropPhotos(t),
      );
    });
  }
}
