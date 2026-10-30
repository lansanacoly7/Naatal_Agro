import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Un ou plusieurs éléments de la carte qui occupent la même place à l'écran au zoom courant.
class MapCluster<T> {
  const MapCluster(this.items, this.center);

  final List<T> items;

  /// Position exacte de l'élément s'il est seul ; centre du groupe sinon.
  final LatLng center;

  bool get isSingle => items.length == 1;
}

/// Regroupe les éléments qui se chevaucheraient à l'écran : on les compte au lieu de les empiler.
///
/// Le découpage se fait en pixels au zoom donné : en zoomant, les groupes se défont d'eux-mêmes, et un élément
/// isolé garde toujours sa position exacte.
List<MapCluster<T>> clusterByGrid<T>(
  List<T> items,
  LatLng Function(T) positionOf,
  double zoom, {
  double cellWidth = 100,
  double cellHeight = 90,
}) {
  final world = 256 * math.pow(2, zoom).toDouble();
  final cells = <String, List<T>>{};
  for (final item in items) {
    final p = positionOf(item);
    final x = (p.longitude + 180) / 360 * world;
    final latRad = p.latitude * math.pi / 180;
    final y = (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * world;
    cells.putIfAbsent('${(x / cellWidth).floor()}:${(y / cellHeight).floor()}', () => []).add(item);
  }
  return [
    for (final group in cells.values)
      MapCluster<T>(
        group,
        group.length == 1
            ? positionOf(group.first)
            : LatLng(
                group.map((e) => positionOf(e).latitude).reduce((a, b) => a + b) / group.length,
                group.map((e) => positionOf(e).longitude).reduce((a, b) => a + b) / group.length,
              ),
      ),
  ];
}
