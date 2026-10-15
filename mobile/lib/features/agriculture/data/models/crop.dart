class CropActivity {
  final String id;
  final String cropId;
  final String activityType;
  final String description;
  final String date;
  final double? cost;
  final String createdAt;

  CropActivity({
    required this.id,
    required this.cropId,
    required this.activityType,
    required this.description,
    required this.date,
    this.cost,
    required this.createdAt,
  });

  factory CropActivity.fromJson(Map<String, dynamic> json) {
    return CropActivity(
      id: json['id']?.toString() ?? '',
      cropId: json['crop']?.toString() ?? '',
      activityType: json['activity_type']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      cost: json['cost'] != null ? double.tryParse(json['cost'].toString()) : null,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  DateTime? get parsedDate => DateTime.tryParse(date);
}

/// Récolte enregistrée sur une culture.
class CropHarvest {
  final String id;
  final double quantity;
  final String unit;
  final String date;
  final String notes;

  CropHarvest({
    required this.id,
    required this.quantity,
    required this.unit,
    required this.date,
    this.notes = '',
  });

  factory CropHarvest.fromJson(Map<String, dynamic> json) => CropHarvest(
        id: json['id']?.toString() ?? '',
        quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
        unit: json['unit']?.toString() ?? 'kg',
        date: json['date']?.toString() ?? '',
        notes: json['notes']?.toString() ?? '',
      );

  DateTime? get parsedDate => DateTime.tryParse(date);
}

class Crop {
  final String id;
  final String name;
  final String cropType;
  final String plantingDate;
  final String expectedHarvestDate;
  final String status;
  final double areaSize;
  final String location;
  final String? guideId;
  final String? guideSlug;
  final String? guideName;
  final List<CropActivity> activities;
  final List<CropHarvest> harvests;

  Crop({
    required this.id,
    required this.name,
    required this.cropType,
    required this.plantingDate,
    required this.expectedHarvestDate,
    required this.status,
    required this.areaSize,
    required this.location,
    this.guideId,
    this.guideSlug,
    this.guideName,
    this.activities = const [],
    this.harvests = const [],
  });

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      cropType: json['crop_type'] ?? '',
      plantingDate: json['planting_date'] ?? '',
      expectedHarvestDate: json['expected_harvest_date'] ?? '',
      status: json['status'] ?? 'active',
      areaSize: double.tryParse(json['area_size']?.toString() ?? '0') ?? 0.0,
      location: json['location'] ?? '',
      guideId: json['guide']?.toString(),
      guideSlug: json['guide_slug']?.toString(),
      guideName: json['guide_name']?.toString(),
      activities: (json['activities'] as List?)
              ?.map((e) => CropActivity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      harvests: (json['harvests'] as List?)
              ?.whereType<Map>()
              .map((e) => CropHarvest.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }

  DateTime? get parsedPlantingDate => DateTime.tryParse(plantingDate);
  DateTime? get parsedHarvestDate => DateTime.tryParse(expectedHarvestDate);

  /// Avancement entre le semis et la récolte prévue, ou null si les dates sont inutilisables.
  /// (Aucune valeur de remplacement : l'écran affiche « dates à renseigner ».)
  double? get progressOrNull {
    final start = parsedPlantingDate;
    final end = parsedHarvestDate;
    if (start == null || end == null) return null;
    final totalDays = end.difference(start).inDays;
    if (totalDays <= 0) return null;
    return (DateTime.now().difference(start).inDays / totalDays).clamp(0.0, 1.0);
  }

  /// Jours restants avant la récolte prévue (négatif si dépassée), ou null.
  int? get daysToHarvest {
    final end = parsedHarvestDate;
    if (end == null) return null;
    final now = DateTime.now();
    return DateTime(end.year, end.month, end.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  double get calculatedProgress {
    final start = parsedPlantingDate;
    final end = parsedHarvestDate;
    if (start == null || end == null) return 0.5;
    final totalDays = end.difference(start).inDays;
    if (totalDays <= 0) return 0.5;
    final passedDays = DateTime.now().difference(start).inDays;
    return (passedDays / totalDays).clamp(0.0, 1.0);
  }

  String get calculatedPhase {
    final progress = calculatedProgress;
    if (progress < 0.20) return 'Semis / Démarrage';
    if (progress < 0.50) return 'Croissance végétative';
    if (progress < 0.80) return 'Floraison / Fructification';
    return 'Maturation / Récolte';
  }

  String get imageAsset {
    final typeLower = cropType.toLowerCase();
    if (typeLower.contains('tomate')) return 'assets/images/products/tomate.png';
    if (typeLower.contains('riz')) return 'assets/images/products/riz.jpg';
    if (typeLower.contains('mais') || typeLower.contains('maïs')) return 'assets/images/products/mais.jpg';
    if (typeLower.contains('pomme') && !typeLower.contains('terre')) return 'assets/images/products/pomme.jpg';
    if (typeLower.contains('fraise')) return 'assets/images/products/fraise.jpg';
    if (typeLower.contains('arachide')) return 'assets/images/products/arachide.png';
    if (typeLower.contains('oignon')) return 'assets/images/products/oignon_local.png';
    if (typeLower.contains('pomme de terre')) return 'assets/images/products/pomme_de_terre.png';
    if (typeLower.contains('chou')) return 'assets/images/products/chou.png';
    if (typeLower.contains('aubergine')) return 'assets/images/products/aubergine.png';
    if (typeLower.contains('pasteque') || typeLower.contains('pastèque')) return 'assets/images/products/pasteque.png';
    if (typeLower.contains('papaye')) return 'assets/images/products/papaye.png';
    if (typeLower.contains('mangue')) return 'assets/images/products/mangue.png';
    if (typeLower.contains('niebe') || typeLower.contains('niébé')) return 'assets/images/products/niebe.png';
    // Fallback generique
    return 'assets/images/naatal_agro_logo-removebg-preview.png';
  }
}
