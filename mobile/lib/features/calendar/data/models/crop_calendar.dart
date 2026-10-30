// Calendrier agricole du Sénégal, tel que le renvoie le serveur : pour chaque culture, quand semer et quand récolter
// dans chaque zone, avec la source de chaque ligne. Une période absente veut dire « non documentée ».

/// Un jour de l'année (sans l'année) : les périodes reviennent chaque année.
class MonthDay {
  const MonthDay(this.month, this.day);

  final int month;
  final int day;

  /// Ordre dans l'année, pour comparer deux jours.
  int get order => month * 100 + day;

  /// Le jour dans l'année donnée ; le 29 février d'une année non bissextile devient le dernier jour de février.
  DateTime inYear(int year) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }

  @override
  bool operator ==(Object other) => other is MonthDay && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(month, day);
}

/// Période annuelle, qui peut passer d'une année à l'autre (ex. du 1er novembre au 28 février).
class Span {
  const Span(this.start, this.end);

  final MonthDay start;
  final MonthDay end;

  bool get wraps => end.order < start.order;

  /// Le jour [date] tombe-t-il dans la période ?
  bool contains(DateTime date) {
    final x = date.month * 100 + date.day;
    return wraps ? (x >= start.order || x <= end.order) : (x >= start.order && x <= end.order);
  }

  /// Mois (1 à 12) que la période touche.
  Set<int> get months {
    final result = <int>{};
    var m = start.month;
    while (true) {
      result.add(m);
      if (m == end.month) break;
      m = m % 12 + 1;
    }
    return result;
  }

  /// Jours avant le prochain début (0 si la période est en cours aujourd'hui).
  int daysUntilStart(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    if (contains(day)) return 0;
    var next = start.inYear(day.year);
    if (next.isBefore(day)) next = start.inYear(day.year + 1);
    return next.difference(day).inDays;
  }

  /// Jours restants avant la fin (la période doit être en cours) ; 0 le dernier jour.
  int daysLeft(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    var end = endInYear(day.year);
    if (wraps && day.month * 100 + day.day >= start.order) end = endInYear(day.year + 1);
    return end.difference(day).inDays;
  }

  DateTime endInYear(int year) => end.inYear(year);

  /// Date du prochain début.
  DateTime nextStart(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    return day.add(Duration(days: daysUntilStart(today)));
  }

  /// Date de fin de la période en cours.
  DateTime currentEnd(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    return day.add(Duration(days: daysLeft(today)));
  }

  static Span? fromList(dynamic values) {
    if (values is! List || values.length != 4) return null;
    return Span(MonthDay((values[0] as num).toInt(), (values[1] as num).toInt()), MonthDay((values[2] as num).toInt(), (values[3] as num).toInt()));
  }
}

class CalendarWindow {
  const CalendarWindow({
    required this.zone,
    required this.label,
    required this.allYear,
    required this.sow,
    required this.harvest,
    required this.cycleMin,
    required this.cycleMax,
    required this.periodText,
    required this.notes,
    required this.sourceKey,
    required this.sourceNote,
  });

  final String zone;

  /// Variante : culture hâtive, contre-saison… (vide s'il n'y en a qu'une).
  final String label;
  final bool allYear;
  final Span? sow;
  final Span? harvest;
  final int? cycleMin;
  final int? cycleMax;

  /// Période en toutes lettres, quand la source la donne ainsi (« De mi-juin à début août »).
  final String periodText;
  final String notes;
  final String sourceKey;
  final String sourceNote;

  factory CalendarWindow.fromJson(Map<String, dynamic> json) => CalendarWindow(
        zone: json['zone'].toString(),
        label: json['label']?.toString() ?? '',
        allYear: json['all_year'] == true,
        sow: Span.fromList(json['sow']),
        harvest: Span.fromList(json['harvest']),
        cycleMin: (json['cycle_days_min'] as num?)?.toInt(),
        cycleMax: (json['cycle_days_max'] as num?)?.toInt(),
        periodText: json['period_text']?.toString() ?? '',
        notes: json['notes']?.toString() ?? '',
        sourceKey: json['source']?.toString() ?? '',
        sourceNote: json['source_note']?.toString() ?? '',
      );

  /// Cette période vaut-elle pour la zone donnée ?
  bool appliesTo(String zoneCode) => zone == zoneCode || zone == 'all';
}

class CalendarCrop {
  const CalendarCrop({required this.key, required this.name, required this.category, required this.windows});

  final String key;
  final String name;

  /// cereale, legume, legumineuse, tubercule, fruit, industrielle.
  final String category;
  final List<CalendarWindow> windows;

  List<CalendarWindow> inZone(String zoneCode) => [for (final w in windows) if (w.appliesTo(zoneCode)) w];

  factory CalendarCrop.fromJson(Map<String, dynamic> json) => CalendarCrop(
        key: json['key'].toString(),
        name: json['name'].toString(),
        category: json['category'].toString(),
        windows: [for (final w in (json['windows'] as List)) CalendarWindow.fromJson(Map<String, dynamic>.from(w as Map))],
      );
}

class CalendarZone {
  const CalendarZone({required this.code, required this.name, required this.description, required this.regions});

  final String code;
  final String name;
  final String description;
  final List<String> regions;

  factory CalendarZone.fromJson(Map<String, dynamic> json) => CalendarZone(
        code: json['code'].toString(),
        name: json['name'].toString(),
        description: json['description']?.toString() ?? '',
        regions: [for (final r in (json['regions'] as List? ?? const [])) r.toString()],
      );
}

class CalendarSource {
  const CalendarSource({required this.key, required this.title, required this.publisher, required this.year, required this.url, required this.note});

  final String key;
  final String title;
  final String publisher;
  final int? year;
  final String url;
  final String note;

  factory CalendarSource.fromJson(String key, Map<String, dynamic> json) => CalendarSource(
        key: key,
        title: json['title']?.toString() ?? '',
        publisher: json['publisher']?.toString() ?? '',
        year: (json['year'] as num?)?.toInt(),
        url: json['url']?.toString() ?? '',
        note: json['note']?.toString() ?? '',
      );
}

class CalendarData {
  const CalendarData({required this.zones, required this.regionZones, required this.crops, required this.sources, required this.undocumented});

  final List<CalendarZone> zones;

  /// Pour chaque région, la ou les zones agro-écologiques (la première est proposée d'office).
  final Map<String, List<String>> regionZones;
  final List<CalendarCrop> crops;
  final Map<String, CalendarSource> sources;

  /// Cultures du catalogue sans source : on ne leur invente pas de dates.
  final List<String> undocumented;

  CalendarZone? zone(String code) {
    for (final z in zones) {
      if (z.code == code) return z;
    }
    return null;
  }

  factory CalendarData.fromJson(Map<String, dynamic> json) => CalendarData(
        zones: [for (final z in (json['zones'] as List)) CalendarZone.fromJson(Map<String, dynamic>.from(z as Map))],
        regionZones: {
          for (final e in Map<String, dynamic>.from(json['region_zones'] as Map).entries) e.key: [for (final z in e.value as List) z.toString()],
        },
        crops: [for (final c in (json['crops'] as List)) CalendarCrop.fromJson(Map<String, dynamic>.from(c as Map))],
        sources: {
          for (final e in Map<String, dynamic>.from(json['sources'] as Map).entries)
            e.key: CalendarSource.fromJson(e.key, Map<String, dynamic>.from(e.value as Map)),
        },
        undocumented: [for (final u in (json['undocumented'] as List? ?? const [])) u.toString()],
      );
}
