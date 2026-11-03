import '../../../../screens/guides/guide_text_cleaner.dart';

class CropVariety {
  final String name;
  final String cycle;
  final String season;
  final String characteristics;
  final String yieldPotential;
  final String zones;

  const CropVariety({
    required this.name,
    this.cycle = '',
    this.season = '',
    this.characteristics = '',
    this.yieldPotential = '',
    this.zones = '',
  });

  factory CropVariety.fromJson(Map<String, dynamic> json) {
    return CropVariety(
      name: cleanGuideText((json['name'] ?? '').toString()),
      cycle: cleanGuideText((json['cycle'] ?? '').toString()),
      season: cleanGuideText((json['season'] ?? '').toString()),
      characteristics: cleanGuideText((json['characteristics'] ?? '').toString()),
      yieldPotential: cleanGuideText((json['yield_potential'] ?? '').toString()),
      zones: cleanGuideText((json['zones'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'cycle': cycle,
        'season': season,
        'characteristics': characteristics,
        'yield_potential': yieldPotential,
        'zones': zones,
      };
}

class GuideVideo {
  final String title;
  final String channel;
  final String url;
  final String duration;

  const GuideVideo({
    required this.title,
    required this.channel,
    required this.url,
    this.duration = '',
  });

  factory GuideVideo.fromJson(Map<String, dynamic> json) {
    return GuideVideo(
      title: cleanGuideText((json['title'] ?? '').toString()),
      channel: cleanGuideText((json['channel'] ?? '').toString()),
      url: (json['url'] ?? '').toString().trim(),
      duration: cleanGuideText((json['duration'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'channel': channel,
        'url': url,
        'duration': duration,
      };
}

class PestDiseaseItem {
  final String name;
  final String advice;

  const PestDiseaseItem({required this.name, required this.advice});

  factory PestDiseaseItem.fromJson(Map<String, dynamic> json) {
    return PestDiseaseItem(
      name: cleanGuideText((json['name'] ?? '').toString()),
      advice: cleanGuideText((json['advice'] ?? '').toString()),
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
      title: cleanGuideText((json['title'] ?? '').toString()),
      publisher: cleanGuideText((json['publisher'] ?? '').toString()),
      year: cleanGuideText((json['year'] ?? '').toString()),
      url: (json['url'] ?? '').toString().trim(),
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
  final List<CropVariety> varieties;
  final String harvest;
  final String yieldInfo;
  final String limitations;
  final List<GuideSource> sources;
  final GuideVideo? video;
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
    this.varieties = const [],
    this.harvest = '',
    this.yieldInfo = '',
    this.limitations = '',
    this.sources = const [],
    this.video,
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
      name: cleanGuideText((json['name'] ?? '').toString()),
      scientificName: cleanGuideText((json['scientific_name'] ?? '').toString()),
      category: (json['category'] ?? 'legume').toString(),
      summary: cleanGuideText((json['summary'] ?? '').toString()),
      zones: cleanGuideText((json['zones'] ?? '').toString()),
      cycleDaysMin: json['cycle_days_min'] as int?,
      cycleDaysMax: json['cycle_days_max'] as int?,
      calendar: cleanGuideText((json['calendar'] ?? '').toString()),
      soilAndSowing: cleanGuideText((json['soil_and_sowing'] ?? '').toString()),
      waterNeeds: cleanGuideText((json['water_needs'] ?? '').toString()),
      fertilization: cleanGuideText((json['fertilization'] ?? '').toString()),
      pestsDiseases: ((json['pests_diseases'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PestDiseaseItem.fromJson)
          .toList(),
      varieties: ((json['varieties'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CropVariety.fromJson)
          .toList(),
      harvest: cleanGuideText((json['harvest'] ?? '').toString()),
      yieldInfo: cleanGuideText((json['yield_info'] ?? '').toString()),
      limitations: cleanGuideText((json['limitations'] ?? '').toString()),
      sources: ((json['sources'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GuideSource.fromJson)
          .toList(),
      video: json['video'] is Map<String, dynamic>
          ? GuideVideo.fromJson(json['video'] as Map<String, dynamic>)
          : null,
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
        'varieties': varieties.map((e) => e.toJson()).toList(),
        'harvest': harvest,
        'yield_info': yieldInfo,
        'limitations': limitations,
        'sources': sources.map((e) => e.toJson()).toList(),
        'video': video?.toJson(),
        'updated_at': updatedAt,
      };
}
