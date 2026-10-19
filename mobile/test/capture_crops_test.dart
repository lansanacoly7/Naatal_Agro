import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/network/api_client.dart';
import 'package:nataal_agro/features/agriculture/data/agriculture_provider.dart';
import 'package:nataal_agro/features/agriculture/data/guides_provider.dart';
import 'package:nataal_agro/features/agriculture/data/models/agronomic_guide.dart';
import 'package:nataal_agro/features/agriculture/data/models/crop.dart';
import 'package:nataal_agro/features/agriculture/presentation/screens/add_crop_screen.dart';
import 'package:nataal_agro/features/agriculture/presentation/screens/crop_detail_screen.dart';
import 'package:nataal_agro/features/agriculture/presentation/screens/cultures_screen.dart';
import 'package:nataal_agro/features/markets/data/markets_provider.dart';
import 'package:nataal_agro/features/markets/data/models/product.dart';
import 'package:nataal_agro/features/profile/data/profile_provider.dart';
import 'package:nataal_agro/features/profile/domain/profile_model.dart';
import 'package:nataal_agro/main.dart' show sharedPreferencesProvider;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/visual_harness.dart';

String _d(int offsetDays) =>
    DateTime.now().add(Duration(days: offsetDays)).toIso8601String().split('T').first;

class _LocalGuides extends GuidesNotifier {
  _LocalGuides(SharedPreferences prefs, this.guideList) : super(ApiClient(), prefs);

  final List<AgronomicGuide> guideList;

  @override
  Future<void> loadGuides({String? category, String? search}) async {
    state = GuidesListState(guides: guideList);
  }
}

void main() {
  setUpAll(VisualHarness.init);

  final crop = Crop(
    id: 'c1',
    name: 'Oignon Gandiol',
    cropType: 'Oignon',
    plantingDate: _d(-45),
    expectedHarvestDate: _d(45),
    status: 'in_progress',
    areaSize: 2.5,
    location: 'Niayes, Thiès',
    activities: [
      CropActivity(
        id: 'a1',
        cropId: 'c1',
        activityType: 'irrigation',
        description: 'Arrosage goutte-à-goutte',
        date: _d(-2),
        cost: 5000,
        createdAt: DateTime.now().toIso8601String(),
      ),
      CropActivity(
        id: 'a2',
        cropId: 'c1',
        activityType: 'fertilisation',
        description: 'Apport NPK 15-15-15',
        date: _d(-10),
        cost: 25000,
        createdAt: DateTime.now().toIso8601String(),
      ),
    ],
    harvests: const [],
  );

  final crops = [
    crop,
    Crop(id: 'c2', name: 'Arachide 73-33', cropType: 'Arachide', plantingDate: _d(-20), expectedHarvestDate: _d(80), status: 'active', areaSize: 1.5, location: 'Bassin arachidier'),
    Crop(id: 'c3', name: 'Tomate Cerise', cropType: 'Tomate', plantingDate: _d(-60), expectedHarvestDate: _d(-5), status: 'harvested', areaSize: 1.0, location: 'Diamniadio'),
  ];

  final guides = [
    const AgronomicGuide(id: 'g1', slug: 'oignon', name: 'Oignon', category: 'legume', summary: 'Culture phare des Niayes', cycleDaysMin: 90, cycleDaysMax: 120),
    const AgronomicGuide(id: 'g2', slug: 'arachide', name: 'Arachide', category: 'legumineuse', summary: 'Base du bassin arachidier', cycleDaysMin: 90, cycleDaysMax: 110),
    const AgronomicGuide(id: 'g3', slug: 'tomate', name: 'Tomate', category: 'legume', summary: 'Culture intensive maraîchère', cycleDaysMin: 75, cycleDaysMax: 90),
  ];

  final products = [
    Product(id: 'p1', name: 'Oignon', category: 'legume', currentPrice: 450, trendPercentage: 3.5, imageAsset: 'assets/images/products/oignon.jpg', isTrending: true),
    Product(id: 'p2', name: 'Arachide', category: 'legumineuse', currentPrice: 750, trendPercentage: -1.2, imageAsset: 'assets/images/products/arachide.jpg', isTrending: false),
    Product(id: 'p3', name: 'Tomate', category: 'legume', currentPrice: 600, trendPercentage: 5.0, imageAsset: 'assets/images/products/tomate.jpg', isTrending: true),
  ];

  final profile = UserProfile(
    id: 'u1',
    phone: '+221770000000',
    fullName: 'Moussa Ndiaye',
    role: 'farmer',
    language: 'fr',
    location: 'Diamniadio, Sénégal',
    cropsCount: 3,
    mainCrops: const ['Oignon', 'Arachide'],
    isVerified: true,
  );

  List<Override> overrides() {
    FakeProfile.seed = profile;
    return [
      cropsProvider.overrideWith((ref) async => crops),
      allProductsProvider.overrideWith((ref) async => products),
      profileNotifierProvider.overrideWith((ref) => FakeProfile()),
      guidesNotifierProvider.overrideWith((ref) => _LocalGuides(ref.read(sharedPreferencesProvider), guides)),
    ];
  }

  testWidgets('Capture Cultures Screen', (tester) async {
    await VisualHarness.shoot(
      tester,
      'cultures_screen_stage_b',
      const CulturesScreen(),
      dark: false,
      overrides: overrides(),
      size: const Size(390, 1000),
    );
  });

  testWidgets('Capture Crop Detail Screen', (tester) async {
    await VisualHarness.shoot(
      tester,
      'crop_detail_stage_b',
      CropDetailScreen(crop: crop),
      dark: false,
      overrides: overrides(),
      size: const Size(390, 1400),
    );
  });

  testWidgets('Capture Add Crop Screen', (tester) async {
    await VisualHarness.shoot(
      tester,
      'add_crop_stage_b',
      const AddCropScreen(),
      dark: false,
      overrides: overrides(),
      size: const Size(390, 1100),
    );
  });
}
