import 'package:latlong2/latlong.dart';

class Market {
  final String id;
  final String name;
  final String? locationGps;
  final String region;

  final double? rating;
  final String? openingTime;
  final String? closingTime;

  Market({
    required this.id,
    required this.name,
    this.locationGps,
    required this.region,
    this.rating,
    this.openingTime,
    this.closingTime,
  });

  factory Market.fromJson(Map<String, dynamic> json) {
    return Market(
      id: json['id'],
      name: json['name'],
      locationGps: json['location_gps'],
      region: json['region'],
      rating: json['rating'] != null ? double.tryParse(json['rating'].toString()) : 4.5,
      openingTime: json['opening_time'] ?? '08:00:00',
      closingTime: json['closing_time'] ?? '18:00:00',
    );
  }

  /// Retourne les coordonnées GPS sous forme d'objet LatLng pour la carte
  LatLng? get latLng {
    if (locationGps == null || locationGps!.isEmpty) return null;
    try {
      final parts = locationGps!.split(',');
      if (parts.length == 2) {
        final lat = double.parse(parts[0].trim());
        final lng = double.parse(parts[1].trim());
        return LatLng(lat, lng);
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}

