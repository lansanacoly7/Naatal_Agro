class PestDiseaseItem {
  final String name;
  final String advice;

  const PestDiseaseItem({required this.name, required this.advice});

  factory PestDiseaseItem.fromJson(Map<String, dynamic> json) {
    return PestDiseaseItem(
      name: (json['name'] ?? '').toString(),
      advice: (json['advice'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'advice': advice,
      };
}

class GuideSource {
  final int? number;
  final String title;
  final String publisher;
  final String year;
  final String url;
  final String scope;

  const GuideSource({
    this.number,
    required this.title,
    this.publisher = '',
    this.year = '',
    this.url = '',
    this.scope = 'senegal',
  });

  bool get isSenegal => scope.toLowerCase() == 'senegal';

  factory GuideSource.fromJson(Map<String, dynamic> json) {
    return GuideSource(
      number: json['number'] is int ? json['number'] as int : int.tryParse('${json['number']}'),
      title: (json['title'] ?? '').toString(),
      publisher: (json['publisher'] ?? '').toString(),
      year: (json['year'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      scope: (json['scope'] ?? 'senegal').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'title': title,
        'publisher': publisher,
        'year': year,
        'url': url,
        'scope': scope,
      };
}

class AgronomicGuide {
  final String id;
  final String slug;
  final String name;
  final String scientificName;
  final String category;
  final String summary;
  final String zones;
  final int? cycleDaysMin;
  final int? cycleDaysMax;
  final String calendar;
  final String soilAndSowing;
  final String waterNeeds;
  final String fertilization;
  final List<PestDiseaseItem> pestsDiseases;
  final String harvest;
  final String yieldInfo;
  final String limitations;
  final List<GuideSource> sources;
  final String updatedAt;

  const AgronomicGuide({
    required this.id,
    required this.slug,
    required this.name,
    this.scientificName = '',
    required this.category,
    required this.summary,
    this.zones = '',
    this.cycleDaysMin,
    this.cycleDaysMax,
    this.calendar = '',
    this.soilAndSowing = '',
    this.waterNeeds = '',
    this.fertilization = '',
    this.pestsDiseases = const [],
    this.harvest = '',
    this.yieldInfo = '',
    this.limitations = '',
    this.sources = const [],
    this.updatedAt = '',
  });

  String get categoryLabel {
    switch (category.toLowerCase()) {
      case 'legume':
        return 'Légume';
      case 'cereale':
        return 'Céréale';
      case 'legumineuse':
        return 'Légumineuse';
      case 'fruit':
        return 'Fruit';
      default:
        return category;
    }
  }

  String? get cycleDisplay {
    if (cycleDaysMin != null && cycleDaysMax != null) {
      if (cycleDaysMin == cycleDaysMax) {
        return '$cycleDaysMin jours';
      }
      return '$cycleDaysMin à $cycleDaysMax jours';
    }
    if (cycleDaysMin != null) return 'Dès $cycleDaysMin jours';
    if (cycleDaysMax != null) return 'Jusqu\'à $cycleDaysMax jours';
    return null;
  }

  factory AgronomicGuide.fromJson(Map<String, dynamic> json) {
    return AgronomicGuide(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      scientificName: (json['scientific_name'] ?? '').toString(),
      category: (json['category'] ?? 'legume').toString(),
      summary: (json['summary'] ?? '').toString(),
      zones: (json['zones'] ?? '').toString(),
      cycleDaysMin: json['cycle_days_min'] as int?,
      cycleDaysMax: json['cycle_days_max'] as int?,
      calendar: (json['calendar'] ?? '').toString(),
      soilAndSowing: (json['soil_and_sowing'] ?? '').toString(),
      waterNeeds: (json['water_needs'] ?? '').toString(),
      fertilization: (json['fertilization'] ?? '').toString(),
      pestsDiseases: ((json['pests_diseases'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PestDiseaseItem.fromJson)
          .toList(),
      harvest: (json['harvest'] ?? '').toString(),
      yieldInfo: (json['yield_info'] ?? '').toString(),
      limitations: (json['limitations'] ?? '').toString(),
      sources: ((json['sources'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GuideSource.fromJson)
          .toList(),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'scientific_name': scientificName,
        'category': category,
        'summary': summary,
        'zones': zones,
        'cycle_days_min': cycleDaysMin,
        'cycle_days_max': cycleDaysMax,
        'calendar': calendar,
        'soil_and_sowing': soilAndSowing,
        'water_needs': waterNeeds,
        'fertilization': fertilization,
        'pests_diseases': pestsDiseases.map((e) => e.toJson()).toList(),
        'harvest': harvest,
        'yield_info': yieldInfo,
        'limitations': limitations,
        'sources': sources.map((e) => e.toJson()).toList(),
        'updated_at': updatedAt,
      };
}
