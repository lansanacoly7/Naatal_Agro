import '../data/models/crop_calendar.dart';

/// Ce qu'il faut dire à l'agriculteur sur une culture à une date donnée, dans sa zone.
///
/// Tout est calculé à partir des périodes sourcées du calendrier : aucune date n'est ajoutée ici. La seule règle
/// propre à l'application est le délai d'annonce (voir [leadDays]).
class CropSeason {
  const CropSeason({
    required this.crop,
    required this.zone,
    required this.sowingNow,
    required this.harvestNow,
    required this.prepare,
    required this.allYear,
  });

  final CalendarCrop crop;
  final String zone;

  /// Périodes de semis en cours aujourd'hui.
  final List<CalendarWindow> sowingNow;

  /// Périodes de récolte en cours aujourd'hui.
  final List<CalendarWindow> harvestNow;

  /// Prochain semis à annoncer : il commence dans moins de [leadDays] jours.
  final UpcomingSowing? prepare;

  /// Semis possible toute l'année.
  final bool allYear;

  bool get hasAnything => sowingNow.isNotEmpty || harvestNow.isNotEmpty || prepare != null || allYear;
}

class UpcomingSowing {
  const UpcomingSowing({required this.window, required this.daysUntil, required this.startsOn});

  final CalendarWindow window;
  final int daysUntil;
  final DateTime startsOn;

  /// « dans 3 semaines », « dans 5 jours ».
  String get inWords {
    if (daysUntil <= 0) return "aujourd'hui";
    if (daysUntil == 1) return 'demain';
    if (daysUntil < 14) return 'dans $daysUntil jours';
    final weeks = (daysUntil / 7).round();
    return 'dans $weeks semaines';
  }
}

/// Délai d'annonce, en jours, avant le début des semis.
///
/// Règle de l'application : 4 semaines avant pour une culture à cycle court ; 6 semaines pour une culture à long
/// cycle (180 jours et plus) ou un arbre fruitier, qui demandent plus de préparation. Ce n'est pas une donnée de la
/// source : c'est le délai qu'on se donne pour prévenir.
int leadDays(CalendarCrop crop, List<CalendarWindow> windows) {
  final longest = windows.map((w) => w.cycleMax ?? 0).fold<int>(0, (a, b) => a > b ? a : b);
  return longest >= 180 ? 42 : 28;
}

/// Situation d'une culture aujourd'hui dans la zone donnée.
CropSeason seasonOf(CalendarCrop crop, String zone, DateTime today) {
  final windows = crop.inZone(zone);
  final sowingNow = <CalendarWindow>[];
  final harvestNow = <CalendarWindow>[];
  UpcomingSowing? prepare;
  var allYear = false;
  final lead = leadDays(crop, windows);

  for (final w in windows) {
    if (w.allYear) allYear = true;
    final sow = w.sow;
    if (sow != null) {
      if (sow.contains(today)) {
        sowingNow.add(w);
      } else {
        final days = sow.daysUntilStart(today);
        if (days <= lead && (prepare == null || days < prepare.daysUntil)) {
          prepare = UpcomingSowing(window: w, daysUntil: days, startsOn: sow.nextStart(today));
        }
      }
    }
    if (w.harvest?.contains(today) ?? false) harvestNow.add(w);
  }
  // Si une période de semis est déjà ouverte, inutile d'annoncer la suivante
  if (sowingNow.isNotEmpty) prepare = null;
  return CropSeason(crop: crop, zone: zone, sowingNow: sowingNow, harvestNow: harvestNow, prepare: prepare, allYear: allYear);
}

/// Bilan du jour pour une zone : ce qu'on sème, ce qu'on récolte, ce qu'il faut préparer.
class SeasonSummary {
  const SeasonSummary({required this.sowing, required this.harvesting, required this.prepare, required this.allYear});

  /// Les semis qui se ferment bientôt d'abord.
  final List<CropSeason> sowing;
  final List<CropSeason> harvesting;

  /// Les semis qui s'ouvrent bientôt d'abord.
  final List<CropSeason> prepare;
  final List<CropSeason> allYear;

  bool get isEmpty => sowing.isEmpty && harvesting.isEmpty && prepare.isEmpty;
}

SeasonSummary summarize(List<CalendarCrop> crops, String zone, DateTime today) {
  final seasons = [for (final crop in crops) seasonOf(crop, zone, today)];
  int soonestClose(CropSeason s) =>
      s.sowingNow.map((w) => w.sow!.daysLeft(today)).reduce((a, b) => a < b ? a : b);
  final sowing = [for (final s in seasons) if (s.sowingNow.isNotEmpty) s]..sort((a, b) => soonestClose(a).compareTo(soonestClose(b)));
  final harvesting = [for (final s in seasons) if (s.harvestNow.isNotEmpty) s]..sort((a, b) => a.crop.name.compareTo(b.crop.name));
  final prepare = [for (final s in seasons) if (s.prepare != null) s]..sort((a, b) => a.prepare!.daysUntil.compareTo(b.prepare!.daysUntil));
  final allYear = [for (final s in seasons) if (s.allYear) s]..sort((a, b) => a.crop.name.compareTo(b.crop.name));
  return SeasonSummary(sowing: sowing, harvesting: harvesting, prepare: prepare, allYear: allYear);
}

/// Pour la grille de l'année et l'aperçu d'un autre mois : semis / récolte qui touchent le mois donné (1 à 12).
class MonthActivity {
  const MonthActivity({required this.sowing, required this.harvesting});

  final bool sowing;
  final bool harvesting;

  bool get any => sowing || harvesting;
}

MonthActivity activityInMonth(CalendarCrop crop, String zone, int month) {
  var sowing = false;
  var harvesting = false;
  for (final w in crop.inZone(zone)) {
    if (w.allYear) sowing = true;
    if (w.sow?.months.contains(month) ?? false) sowing = true;
    if (w.harvest?.months.contains(month) ?? false) harvesting = true;
  }
  return MonthActivity(sowing: sowing, harvesting: harvesting);
}

/// Zone proposée d'office pour une région (la première de la liste), ou `null` si on ne sait pas.
String? defaultZoneForRegion(CalendarData data, String? region) {
  if (region == null) return null;
  final zones = data.regionZones[region];
  return zones == null || zones.isEmpty ? null : zones.first;
}
