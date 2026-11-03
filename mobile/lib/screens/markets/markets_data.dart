import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/location/location_access.dart';
import '../../features/auth/data/auth_provider.dart';

export '../../ui/product_photo.dart' show productImageForName;

/// Dernier prix relevé d'un produit sur un marché.
class MarketQuote {
  const MarketQuote({
    required this.marketId,
    required this.marketName,
    required this.region,
    required this.productName,
    required this.price,
    required this.trend,
    required this.date,
    this.position,
  });

  final String marketId;
  final String marketName;
  final String region;
  final String productName;
  final double price;
  final String trend;
  final DateTime? date;

  /// Coordonnées du marché (null si le marché n'en a pas).
  final LatLng? position;

  factory MarketQuote.fromJson(Map<String, dynamic> json) {
    LatLng? position;
    final gps = (json['location_gps'] ?? '').toString().split(',');
    if (gps.length == 2) {
      final lat = double.tryParse(gps[0].trim());
      final lng = double.tryParse(gps[1].trim());
      if (lat != null && lng != null) position = LatLng(lat, lng);
    }
    return MarketQuote(
      marketId: json['market']?.toString() ?? '',
      marketName: json['market_name']?.toString() ?? '',
      region: json['region']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      price: double.tryParse('${json['price']}') ?? 0,
      trend: json['trend']?.toString() ?? 'stable',
      date: DateTime.tryParse('${json['date']}'),
      position: position,
    );
  }
}

/// Un point de l'historique des prix.
class PricePoint {
  const PricePoint({required this.date, required this.price});

  final DateTime date;
  final double price;
}

/// Dernier prix de chaque marché pour un produit.
final marketQuotesProvider = FutureProvider.autoDispose.family<List<MarketQuote>, String>((ref, product) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get('/markets/prices/latest/', queryParams: {'product': product});
  final data = response.data;
  if (data is! List) return const [];
  return data.whereType<Map>().map((m) => MarketQuote.fromJson(Map<String, dynamic>.from(m))).toList();
});

/// Clé d'un historique : produit, et marché si on veut un seul marché.
class HistoryKey {
  const HistoryKey(this.product, [this.marketId]);

  final String product;
  final String? marketId;

  @override
  bool operator ==(Object other) => other is HistoryKey && other.product == product && other.marketId == marketId;

  @override
  int get hashCode => Object.hash(product, marketId);
}

/// Historique journalier (30 jours) : moyenne des marchés, ou prix d'un marché.
final priceHistoryProvider = FutureProvider.autoDispose.family<List<PricePoint>, HistoryKey>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get('/markets/prices/history/', queryParams: {
    'product': key.product,
    'days': 30,
    if (key.marketId != null) 'market': key.marketId,
  });
  final data = response.data;
  if (data is! List) return const [];
  final points = <PricePoint>[];
  for (final row in data.whereType<Map>()) {
    final date = DateTime.tryParse('${row['date']}');
    final price = double.tryParse('${row['price']}');
    if (date != null && price != null) points.add(PricePoint(date: date, price: price));
  }
  return points;
});

// ───────────── Position de l'utilisateur (demandée seulement s'il le souhaite) ─────────────

class UserLocation {
  const UserLocation({this.position, this.loading = false, this.error, this.access});

  final LatLng? position;
  final bool loading;
  final String? error;

  /// Pourquoi la position manque (null = pas encore demandée, ou position introuvable malgré l'autorisation).
  final LocationAccess? access;

  /// Vrai quand une action de l'utilisateur (autoriser, allumer le GPS) peut débloquer la situation.
  bool get needsFix => access != null && access != LocationAccess.granted;
}

class UserLocationNotifier extends StateNotifier<UserLocation> {
  UserLocationNotifier(this._ref) : super(const UserLocation());

  final Ref _ref;

  Future<void> locate() async {
    state = const UserLocation(loading: true);
    try {
      if (!_ref.read(locationEnabledProvider)) {
        state = UserLocation(access: LocationAccess.disabledByUser, error: locationAccessMessage(LocationAccess.disabledByUser));
        return;
      }
      final access = await requestLocationAccess();
      if (access != LocationAccess.granted) {
        state = UserLocation(access: access, error: locationAccessMessage(access));
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 12)),
      );
      state = UserLocation(position: LatLng(p.latitude, p.longitude), access: LocationAccess.granted);
    } catch (_) {
      state = const UserLocation(error: 'Position introuvable. Réessayez à l\'extérieur.');
    }
  }

  /// Bouton « Activer la localisation » : rallume l'option, redemande l'autorisation ou ouvre les réglages du téléphone.
  Future<void> enable() async {
    await _ref.read(locationEnabledProvider.notifier).set(true);
    final blocking = await checkLocationAccess(enabledByUser: true);
    if (blocking == LocationAccess.deniedForever || blocking == LocationAccess.serviceOff) {
      final opened = await openLocationFix(blocking);
      if (!opened) {
        state = UserLocation(access: blocking, error: '${locationAccessMessage(blocking)} Dans le navigateur, utilisez le cadenas à côté de l\'adresse.');
        return;
      }
    }
    await locate();
  }

  /// Interrupteur du profil : éteint l'usage de la position et oublie celle qu'on avait.
  Future<void> disable() async {
    await _ref.read(locationEnabledProvider.notifier).set(false);
    state = UserLocation(access: LocationAccess.disabledByUser, error: locationAccessMessage(LocationAccess.disabledByUser));
  }

  void clear() => state = const UserLocation();
}

final userLocationProvider = StateNotifierProvider<UserLocationNotifier, UserLocation>((ref) => UserLocationNotifier(ref));
