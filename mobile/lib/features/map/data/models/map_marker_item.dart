import 'package:latlong2/latlong.dart';
import '../../../agriculture/data/models/crop.dart';
import '../../../markets/data/models/market.dart';

enum MapMarkerType {
  market,
  crop,
}

class MapMarkerItem {
  final String id;
  final String title;
  final String subtitle;
  final LatLng position;
  final MapMarkerType type;
  final Market? market;
  final Crop? crop;
  final String? detailText;

  const MapMarkerItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.position,
    required this.type,
    this.market,
    this.crop,
    this.detailText,
  });

  bool get isMarket => type == MapMarkerType.market;
  bool get isCrop => type == MapMarkerType.crop;
}
