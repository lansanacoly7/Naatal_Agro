import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:nataal_agro/features/agriculture/data/agriculture_provider.dart';
import 'package:nataal_agro/features/agriculture/data/models/crop.dart';
import 'package:nataal_agro/features/map/data/map_provider.dart';
import 'package:nataal_agro/features/map/data/models/map_marker_item.dart';
import 'package:nataal_agro/features/map/presentation/screens/map_screen.dart';
import 'package:nataal_agro/features/markets/data/markets_provider.dart';
import 'package:nataal_agro/features/markets/data/models/market.dart';

void main() {
  group('MapProvider & MapMarkerItem Tests', () {
    test('MapMarkerItem model holds correct properties', () {
      final marker = MapMarkerItem(
        id: 'market_1',
        title: 'Marché Sandaga',
        subtitle: 'Marché · Dakar',
        position: const LatLng(14.6710, -17.4370),
        type: MapMarkerType.market,
        detailText: 'Ouvert 08h-18h',
      );

      expect(marker.id, 'market_1');
      expect(marker.isMarket, isTrue);
      expect(marker.isCrop, isFalse);
      expect(marker.position.latitude, 14.6710);
      expect(marker.position.longitude, -17.4370);
    });

    test('MapMarkerItem for crop works properly', () {
      final marker = MapMarkerItem(
        id: 'crop_1',
        title: 'Parcelle Oignon Thiès',
        subtitle: 'Parcelle · Légume (2.5 ha)',
        position: const LatLng(14.7910, -16.9260),
        type: MapMarkerType.crop,
        detailText: 'Statut : active',
      );

      expect(marker.isCrop, isTrue);
      expect(marker.isMarket, isFalse);
      expect(marker.title, 'Parcelle Oignon Thiès');
    });

    testWidgets('MapScreen renders and shows filter chips', (tester) async {
      final mockMarkets = [
        Market(
          id: 'm1',
          name: 'Marché Castors',
          region: 'Dakar',
          locationGps: '14.7083, -17.4525',
          rating: 4.8,
          openingTime: '08:00:00',
          closingTime: '18:00:00',
        ),
      ];

      final mockCrops = [
        Crop(
          id: 'c1',
          name: 'Parcelle Arachide',
          cropType: 'Arachide',
          plantingDate: '2026-06-15',
          expectedHarvestDate: '2026-10-15',
          status: 'active',
          areaSize: 3.0,
          location: 'Kaolack',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketsListProvider.overrideWith((ref) => Future.value(mockMarkets)),
            cropsProvider.overrideWith((ref) => Future.value(mockCrops)),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Carte interactive'), findsOneWidget);
      expect(find.text('Tous'), findsOneWidget);
      expect(find.text('Marchés du Sénégal'), findsOneWidget);
      expect(find.text('Mes Parcelles'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
