import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/senegal_regions.dart';
import '../../../main.dart' show sharedPreferencesProvider;
import '../../auth/data/auth_provider.dart';
import '../../profile/data/profile_provider.dart';
import '../domain/season_logic.dart';
import 'models/crop_calendar.dart';

const _cacheKey = 'crop_calendar_cache_v1';

/// Calendrier agricole du serveur. Une copie est gardée sur le téléphone : sans réseau, la dernière version reçue
/// reste lisible (et on le sait : la donnée est de toute façon annuelle).
final cropCalendarProvider = FutureProvider<CalendarData>((ref) async {
  final api = ref.watch(apiClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  try {
    final response = await api.get('/agriculture/calendar/');
    final data = response.data;
    if (data is Map) {
      final parsed = CalendarData.fromJson(Map<String, dynamic>.from(data));
      try {
        await prefs.setString(_cacheKey, jsonEncode(data));
      } catch (_) {
        // Copie impossible : sans importance pour l'affichage du moment
      }
      return parsed;
    }
    throw const FormatException('Réponse inattendue');
  } catch (error) {
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      debugPrint('[Calendrier] Réseau indisponible, copie gardée sur le téléphone utilisée : $error');
      return CalendarData.fromJson(Map<String, dynamic>.from(jsonDecode(cached) as Map));
    }
    rethrow;
  }
});

/// Zone choisie à la main ; `null` = celle qui correspond à la région de la personne.
final calendarZoneChoiceProvider = StateProvider<String?>((ref) => null);

/// Région de la personne, d'après son profil (nom de région reconnu), sinon `null`.
final profileRegionNameProvider = Provider<String?>((ref) {
  final text = ref.watch(profileNotifierProvider).valueOrNull?.location.trim() ?? '';
  return text.isEmpty ? null : SenegalRegions.fromName(text)?.name;
});

/// Zone agro-écologique dont on affiche le calendrier : le choix de la personne, sinon celle de sa région.
/// `null` si on ne sait pas : on lui demande alors de choisir, on ne devine pas.
final calendarZoneProvider = Provider<String?>((ref) {
  final chosen = ref.watch(calendarZoneChoiceProvider);
  if (chosen != null) return chosen;
  final data = ref.watch(cropCalendarProvider).valueOrNull;
  if (data == null) return null;
  return defaultZoneForRegion(data, ref.watch(profileRegionNameProvider));
});

/// Bilan du jour dans la zone de la personne (pour l'accueil), ou `null` tant qu'on ne sait pas.
final todaySeasonProvider = Provider<SeasonSummary?>((ref) {
  final data = ref.watch(cropCalendarProvider).valueOrNull;
  final zone = ref.watch(calendarZoneProvider);
  if (data == null || zone == null) return null;
  return summarize(data.crops, zone, DateTime.now());
});
