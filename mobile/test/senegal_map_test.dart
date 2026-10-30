import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nataal_agro/core/location/senegal_regions.dart';
import 'package:nataal_agro/ui/senegal_map.dart';
import 'package:nataal_agro/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Limites de la carte', () {
    late List<LatLng> ring;

    setUpAll(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      ring = await container.read(senegalBorderProvider.future);
    });

    test('la frontière est chargée avec assez de détail', () {
      expect(ring.length, greaterThan(1500));
    });

    test('les 14 chefs-lieux de région sont à l\'intérieur du Sénégal', () {
      for (final region in SenegalRegions.all) {
        expect(isInsideBorder(LatLng(region.lat, region.lon), ring), isTrue, reason: region.name);
      }
    });

    test('Diamniadio, Touba et Keur Massar aussi', () {
      expect(isInsideBorder(const LatLng(14.7167, -17.1833), ring), isTrue, reason: 'Diamniadio');
      expect(isInsideBorder(const LatLng(14.85, -15.88), ring), isTrue, reason: 'Touba');
      expect(isInsideBorder(const LatLng(14.7847, -17.3100), ring), isTrue, reason: 'Keur Massar');
    });

    test('les capitales voisines et la Gambie sont à l\'extérieur', () {
      expect(isInsideBorder(const LatLng(13.4549, -16.5790), ring), isFalse, reason: 'Banjul (Gambie)');
      expect(isInsideBorder(const LatLng(13.45, -15.30), ring), isFalse, reason: 'l\'intérieur de la Gambie');
      expect(isInsideBorder(const LatLng(12.6392, -8.0029), ring), isFalse, reason: 'Bamako (Mali)');
      expect(isInsideBorder(const LatLng(18.0735, -15.9582), ring), isFalse, reason: 'Nouakchott (Mauritanie)');
      expect(isInsideBorder(const LatLng(9.6412, -13.5784), ring), isFalse, reason: 'Conakry (Guinée)');
      expect(isInsideBorder(const LatLng(11.8636, -15.5977), ring), isFalse, reason: 'Bissau (Guinée-Bissau)');
    });

    test('une position à l\'étranger n\'est pas montrée sur la carte', () {
      expect(isInSenegal(const LatLng(14.7167, -17.4677)), isTrue);
      expect(isInSenegal(const LatLng(48.8566, 2.3522)), isFalse, reason: 'Paris');
      expect(isInSenegal(const LatLng(12.6392, -8.0029)), isFalse, reason: 'Bamako');
    });
  });

  group('Balises', () {
    testWidgets('la balise a une pointe : elle est plus haute que large', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Center(child: MapPin(color: Colors.green, size: 40, child: Icon(Icons.storefront_rounded))),
      ));
      final size = tester.getSize(find.byType(MapPin));
      expect(size.width, 40);
      expect(size.height, closeTo(MapPin.heightFor(40), 0.01));
      expect(size.height, greaterThan(size.width));
    });

    testWidgets('l\'avatar de la personne montre ses initiales, ou une silhouette à défaut', (tester) async {
      Widget app(String? initials) => MaterialApp(
            theme: NaatalTheme.light,
            home: EffectsScope(reduced: true, child: Center(child: UserAvatarPin(initials: initials))),
          );
      await tester.pumpWidget(app('AD'));
      expect(find.text('AD'), findsOneWidget);
      await tester.pumpWidget(app(null));
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(tester.getSize(find.byType(UserAvatarPin)).height, UserAvatarPin.markerHeight);
    });
  });
}
