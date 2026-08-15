class Crop {
  final String id;
  final String name;
  final String cropType;
  final String plantingDate;
  final String expectedHarvestDate;
  final String status;
  final double areaSize;
  final String location;

  Crop({
    required this.id,
    required this.name,
    required this.cropType,
    required this.plantingDate,
    required this.expectedHarvestDate,
    required this.status,
    required this.areaSize,
    required this.location,
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
    );
  }

  String get imageAsset {
    final typeLower = cropType.toLowerCase();
    if (typeLower.contains('tomate')) return 'assets/images/products/tomate.png';
    if (typeLower.contains('riz')) return 'assets/images/products/riz.png'; // Fallback if missing
    if (typeLower.contains('mais') || typeLower.contains('maïs')) return 'assets/images/products/mais.png'; // Fallback if missing
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
