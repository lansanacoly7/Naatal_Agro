import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'tokens.dart';

/// Rectangle qui enferme le Sénégal : la carte ne peut pas être déplacée au-delà.
final senegalBounds = LatLngBounds(const LatLng(12.20, -17.80), const LatLng(16.75, -11.30));

/// Ce que la caméra peut montrer : le Sénégal avec de la marge, surtout au sud, pour que la Casamance ne passe pas sous la barre
/// du bas ou les boutons. Au-delà de la frontière, tout est voilé : on ne voit pas les pays voisins.
final senegalViewBounds = LatLngBounds(const LatLng(11.10, -18.50), const LatLng(17.35, -10.60));

/// Zoom le plus éloigné permis pour un écran de cette taille : celui où le rectangle du Sénégal remplit l'écran.
/// En dessous, l'écran montrerait autre chose que le Sénégal : on ne peut donc pas dézoomer plus loin.
double senegalFitZoom(Size viewport) {
  double mercatorY(double lat) => math.log(math.tan(math.pi / 4 + lat * math.pi / 360));
  final spanX = (senegalViewBounds.east - senegalViewBounds.west) / 360; // part de la largeur du monde
  final spanY = (mercatorY(senegalViewBounds.north) - mercatorY(senegalViewBounds.south)) / (2 * math.pi);
  final zoomX = math.log(viewport.width / (256 * spanX)) / math.ln2;
  final zoomY = math.log(viewport.height / (256 * spanY)) / math.ln2;
  return math.max(zoomX, zoomY) + 0.02;
}

/// Les bords de l'écran ne quittent jamais le rectangle du Sénégal : on ne peut aller nulle part ailleurs.
CameraConstraint get senegalCameraConstraint => CameraConstraint.contain(bounds: senegalViewBounds);

/// Vrai si une position est dans le rectangle du Sénégal (une position à l'étranger n'est pas montrée sur la carte).
bool isInSenegal(LatLng point) => senegalBounds.contains(point);

/// Vrai si un point est à l'intérieur de la frontière exacte du Sénégal (le point est dans l'anneau).
bool isInsideBorder(LatLng point, List<LatLng> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i];
    final b = ring[j];
    final crosses = (a.latitude > point.latitude) != (b.latitude > point.latitude) &&
        point.longitude < (b.longitude - a.longitude) * (point.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude;
    if (crosses) inside = !inside;
  }
  return inside;
}

/// Frontière du Sénégal, lue dans `assets/data/senegal_border.json` (OpenStreetMap, simplifiée à environ 90 m).
final senegalBorderProvider = FutureProvider<List<LatLng>>((ref) async {
  final raw = jsonDecode(await rootBundle.loadString('assets/data/senegal_border.json')) as Map<String, dynamic>;
  return [for (final p in raw['ring'] as List) LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble())];
});

/// Voile qui cache tout ce qui est hors du Sénégal (pays voisins, océan lointain) et trace la frontière.
/// À placer juste au-dessus des tuiles de la carte.
class SenegalMask extends ConsumerWidget {
  const SenegalMask({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ring = ref.watch(senegalBorderProvider).valueOrNull;
    if (ring == null) return const SizedBox.shrink();
    final c = context.c;
    return PolygonLayer(
      polygons: [
        Polygon(
          // Un grand rectangle percé d'un trou aux contours du Sénégal
          points: const [LatLng(-5, -45), LatLng(-5, 15), LatLng(35, 15), LatLng(35, -45)],
          holePointsList: [ring],
          color: c.bg,
          borderColor: c.accent.withValues(alpha: 0.75),
          borderStrokeWidth: 2.5,
        ),
      ],
    );
  }
}
