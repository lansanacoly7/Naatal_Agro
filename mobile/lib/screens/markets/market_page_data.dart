import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../features/auth/data/auth_provider.dart';

/// Prévision de prix d'un produit sur un marché : une tendance des dernières semaines, jamais une certitude.
class MarketForecast {
  const MarketForecast({
    required this.direction,
    required this.expectedPrice,
    required this.low,
    required this.high,
    required this.changePercent,
    required this.horizonDays,
    required this.basisDays,
    required this.confidence,
  });

  /// `up`, `down` ou `stable`.
  final String direction;
  final double expectedPrice;
  final double low;
  final double high;
  final double changePercent;
  final int horizonDays;
  final int basisDays;

  /// `good`, `medium` ou `low`.
  final String confidence;

  factory MarketForecast.fromJson(Map<String, dynamic> json) => MarketForecast(
        direction: '${json['direction']}',
        expectedPrice: (json['expected_price'] as num).toDouble(),
        low: (json['low'] as num).toDouble(),
        high: (json['high'] as num).toDouble(),
        changePercent: (json['change_percent'] as num).toDouble(),
        horizonDays: (json['horizon_days'] as num).toInt(),
        basisDays: (json['basis_days'] as num).toInt(),
        confidence: '${json['confidence']}',
      );
}

/// Un produit vendu sur le marché, avec son évolution.
class MarketProduct {
  const MarketProduct({
    required this.name,
    required this.price,
    required this.trend,
    required this.date,
    required this.history,
    this.changeWeekPercent,
    this.min30,
    this.max30,
    this.avg30,
    this.marketsCompared = 0,
    this.cheaperMarkets,
    this.forecast,
    this.source,
    this.windowDays = 30,
    this.category = '',
  });

  final String name;
  final double price;
  final String trend;
  final DateTime? date;
  final List<({DateTime date, double price})> history;
  final double? changeWeekPercent;
  final double? min30;
  final double? max30;
  final double? avg30;
  final int marketsCompared;

  /// Nombre de marchés où ce produit est moins cher (null si on ne peut pas comparer).
  final int? cheaperMarkets;
  final MarketForecast? forecast;

  /// Mention de provenance quand le prix est un relevé officiel (null sinon).
  final String? source;

  /// Période couverte par la courbe et les chiffres (jours).
  final int windowDays;
  final String category;

  factory MarketProduct.fromJson(Map<String, dynamic> json) {
    double? number(Object? v) => v is num ? v.toDouble() : null;
    final rawCat = json['category'];
    String cat = rawCat is String ? rawCat.trim() : '';
    if (cat.isEmpty) {
      final n = '${json['name']}'.toLowerCase();
      if (n.contains('arachide') || n.contains('mil') || n.contains('maïs') || n.contains('mais') || n.contains('sorgho') || n.contains('riz') || n.contains('niébé') || n.contains('niebe') || n.contains('fonio')) {
        cat = 'CÉRÉALE';
      } else if (n.contains('oignon') || n.contains('tomate') || n.contains('chou') || n.contains('carotte') || n.contains('aubergine') || n.contains('piment') || n.contains('poivron') || n.contains('gombo') || n.contains('navet') || n.contains('courge') || n.contains('salade') || n.contains('laitue') || n.contains('ail') || n.contains('concombre')) {
        cat = 'LÉGUME';
      } else if (n.contains('mangue') || n.contains('banane') || n.contains('papaye') || n.contains('pastèque') || n.contains('pasteque') || n.contains('orange') || n.contains('citron')) {
        cat = 'FRUIT';
      } else if (n.contains('manioc') || n.contains('patate') || n.contains('pomme de terre') || n.contains('igname')) {
        cat = 'TUBERCULE';
      } else {
        cat = 'AUTRE';
      }
    }
    return MarketProduct(
      category: cat,
      name: '${json['name']}',
      price: (json['price'] as num).toDouble(),
      trend: '${json['trend'] ?? 'stable'}',
      date: DateTime.tryParse('${json['date']}'),
      history: [
        for (final row in (json['history'] as List? ?? const []).whereType<Map>())
          if (DateTime.tryParse('${row['date']}') != null && row['price'] is num)
            (date: DateTime.parse('${row['date']}'), price: (row['price'] as num).toDouble()),
      ],
      changeWeekPercent: number(json['change_week_percent']),
      min30: number(json['min_30d']),
      max30: number(json['max_30d']),
      avg30: number(json['avg_30d']),
      marketsCompared: (json['markets_compared'] as num?)?.toInt() ?? 0,
      cheaperMarkets: (json['cheaper_markets'] as num?)?.toInt(),
      source: json['source'] is String && (json['source'] as String).isNotEmpty ? json['source'] as String : null,
      windowDays: (json['window_days'] as num?)?.toInt() ?? 30,
      forecast: json['forecast'] is Map ? MarketForecast.fromJson(Map<String, dynamic>.from(json['forecast'] as Map)) : null,
    );
  }
}

/// Tout ce que l'on sait d'un marché.
class MarketOverview {
  const MarketOverview({
    required this.id,
    required this.name,
    required this.region,
    required this.position,
    required this.openingTime,
    required this.closingTime,
    required this.hoursVerified,
    required this.lastUpdate,
    required this.priceRecords,
    required this.featured,
    required this.products,
  });

  final String id;
  final String name;
  final String region;
  final LatLng? position;
  final String? openingTime;
  final String? closingTime;
  final bool hoursVerified;
  final DateTime? lastUpdate;
  final int priceRecords;
  final List<String> featured;
  final List<MarketProduct> products;

  List<MarketProduct> get featuredProducts => [
        for (final name in featured)
          for (final p in products)
            if (p.name == name) p,
      ];

  /// Vrai/faux selon l'heure donnée ; `null` si les horaires ne sont pas connus.
  bool? isOpenAt(DateTime now) {
    final open = _minutes(openingTime), close = _minutes(closingTime);
    if (open == null || close == null) return null;
    final current = now.hour * 60 + now.minute;
    return current >= open && current < close;
  }

  static int? _minutes(String? hhmm) {
    final parts = (hhmm ?? '').split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    return h == null || m == null ? null : h * 60 + m;
  }

  factory MarketOverview.fromJson(Map<String, dynamic> json) {
    LatLng? position;
    final gps = '${json['location_gps'] ?? ''}'.split(',');
    if (gps.length == 2) {
      final lat = double.tryParse(gps[0].trim()), lon = double.tryParse(gps[1].trim());
      if (lat != null && lon != null) position = LatLng(lat, lon);
    }
    return MarketOverview(
      id: '${json['id']}',
      name: '${json['name']}',
      region: '${json['region'] ?? ''}',
      position: position,
      openingTime: json['opening_time']?.toString(),
      closingTime: json['closing_time']?.toString(),
      hoursVerified: json['hours_verified'] == true,
      lastUpdate: DateTime.tryParse('${json['last_update']}'),
      priceRecords: (json['price_records'] as num?)?.toInt() ?? 0,
      featured: [for (final n in (json['featured'] as List? ?? const [])) '$n'],
      products: [
        for (final p in (json['products'] as List? ?? const []).whereType<Map>())
          MarketProduct.fromJson(Map<String, dynamic>.from(p)),
      ],
    );
  }
}

/// Un trajet (voiture ou à pied) : durée, distance et tracé à dessiner.
class RouteMode {
  const RouteMode({required this.minutes, required this.distanceKm, required this.points});

  final int minutes;
  final double distanceKm;
  final List<LatLng> points;

  static RouteMode? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final minutes = raw['minutes'], km = raw['distance_km'];
    if (minutes is! num || km is! num) return null;
    return RouteMode(
      minutes: minutes.toInt(),
      distanceKm: km.toDouble(),
      points: [
        for (final p in (raw['geometry'] as List? ?? const []))
          if (p is List && p.length == 2 && p[0] is num && p[1] is num) LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ],
    );
  }
}

/// Itinéraire vers le marché. `car` ou `foot` sont `null` si le service d'itinéraire n'a pas répondu.
class MarketRoute {
  const MarketRoute({required this.straightKm, required this.destination, this.car, this.foot});

  final double straightKm;
  final LatLng destination;
  final RouteMode? car;
  final RouteMode? foot;

  factory MarketRoute.fromJson(Map<String, dynamic> json) {
    final dest = json['destination'] is Map ? Map<String, dynamic>.from(json['destination'] as Map) : const <String, dynamic>{};
    return MarketRoute(
      straightKm: (json['straight_km'] as num?)?.toDouble() ?? 0,
      destination: LatLng((dest['lat'] as num?)?.toDouble() ?? 0, (dest['lon'] as num?)?.toDouble() ?? 0),
      car: RouteMode.tryParse(json['car']),
      foot: RouteMode.tryParse(json['foot']),
    );
  }
}

final marketOverviewProvider = FutureProvider.autoDispose.family<MarketOverview, String>((ref, marketId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get('/markets/$marketId/overview/');
  final data = response.data;
  if (data is! Map) throw Exception('Réponse inattendue');
  return MarketOverview.fromJson(Map<String, dynamic>.from(data));
});

/// Clé d'un itinéraire : marché et position de départ (arrondie : un petit déplacement ne relance pas le calcul).
class RouteKey {
  RouteKey(this.marketId, double lat, double lon)
      : lat = double.parse(lat.toStringAsFixed(3)),
        lon = double.parse(lon.toStringAsFixed(3));

  final String marketId;
  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) => other is RouteKey && other.marketId == marketId && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(marketId, lat, lon);
}

final marketRouteProvider = FutureProvider.autoDispose.family<MarketRoute, RouteKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get('/markets/${key.marketId}/route/', queryParams: {'lat': key.lat, 'lon': key.lon});
  final data = response.data;
  if (data is! Map) throw Exception('Réponse inattendue');
  return MarketRoute.fromJson(Map<String, dynamic>.from(data));
});

/// Durée en mots : « 21 min », « 2 h 20 ».
String durationWords(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}
