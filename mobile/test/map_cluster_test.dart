import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nataal_agro/ui/map_cluster.dart';
import 'package:nataal_agro/ui/senegal_map.dart';
import 'package:flutter/painting.dart';

void main() {
  // Trois marchés de Dakar très proches et un marché lointain (Kolda)
  const dakar = [LatLng(14.6710, -17.4370), LatLng(14.6760, -17.4400), LatLng(14.6800, -17.4450)];
  const kolda = LatLng(12.8830, -14.9500);
  final all = [...dakar, kolda];

  test('au zoom du pays, les marchés qui se chevauchent sont comptés ensemble', () {
    final clusters = clusterByGrid<LatLng>(all, (p) => p, 7);
    expect(clusters.length, 2);
    expect(clusters.firstWhere((c) => c.items.length == 3).isSingle, isFalse);
    expect(clusters.firstWhere((c) => c.isSingle).center, kolda);
  });

  test('en zoomant, le groupe se défait et chaque marché retrouve sa place exacte', () {
    final clusters = clusterByGrid<LatLng>(all, (p) => p, 15);
    expect(clusters.length, 4);
    expect(clusters.every((c) => c.isSingle), isTrue);
    expect({for (final c in clusters) c.center}, {...all});
  });

  test('un marché seul n\'est jamais déplacé, quel que soit le zoom', () {
    for (final zoom in [6.0, 7.0, 8.5, 10.0, 13.0]) {
      final solo = clusterByGrid<LatLng>([kolda], (p) => p, zoom).single;
      expect(solo.center, kolda, reason: 'zoom $zoom');
    }
  });

  test('tout le monde est compté une fois : aucun marché ne disparaît ni ne se duplique', () {
    for (final zoom in [6.0, 8.0, 11.0, 14.0]) {
      final total = clusterByGrid<LatLng>(all, (p) => p, zoom).fold<int>(0, (n, c) => n + c.items.length);
      expect(total, all.length, reason: 'zoom $zoom');
    }
  });

  group('Dézoom limité au Sénégal', () {
    test('le zoom minimal fait tenir la hauteur du Sénégal dans l\'écran', () {
      final phone = senegalFitZoom(const Size(412, 839));
      expect(phone, closeTo(7.4, 0.5));
      // un écran plus haut oblige à rester plus zoomé : on ne voit jamais au-delà du pays
      expect(senegalFitZoom(const Size(412, 1200)), greaterThan(phone));
    });

    test('un écran très large est limité par la largeur du pays', () {
      expect(senegalFitZoom(const Size(2400, 600)), greaterThan(senegalFitZoom(const Size(412, 600))));
    });
  });
}
