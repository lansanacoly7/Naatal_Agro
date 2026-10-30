import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nataal_agro/features/calendar/data/calendar_provider.dart';
import 'package:nataal_agro/features/calendar/data/models/crop_calendar.dart';
import 'package:nataal_agro/features/markets/data/markets_provider.dart';

/// Réponse réelle de l'API du calendrier (vraies données FAO), enregistrée pour les tests :
/// `backend` → `CropCalendarView`. À régénérer si le calendrier change.
CalendarData loadCalendarFixture() {
  final raw = File('test/fixtures/crop_calendar_api.json').readAsStringSync();
  return CalendarData.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
}

/// Surcharges qui évitent tout appel réseau : calendrier de la fixture, zone et région fixées.
List<Override> calendarOverrides({String? zone = 'niayes', String? region = 'Dakar'}) => [
      cropCalendarProvider.overrideWith((ref) async => loadCalendarFixture()),
      calendarZoneChoiceProvider.overrideWith((ref) => zone),
      profileRegionNameProvider.overrideWithValue(region),
      allProductsProvider.overrideWith((ref) async => const []),
    ];
