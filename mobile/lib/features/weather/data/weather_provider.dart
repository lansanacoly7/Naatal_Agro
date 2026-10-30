import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/senegal_regions.dart';
import '../../../screens/markets/markets_data.dart' show userLocationProvider;
import '../../../ui/senegal_map.dart' show isInSenegal;
import '../../auth/data/auth_provider.dart';
import '../../profile/data/profile_provider.dart';
import 'models/weather_report.dart';

/// Où l'on veut la météo : une position (GPS ou lieu choisi) ou un nom de lieu à retrouver côté serveur.
class WeatherQuery {
  const WeatherQuery({this.lat, this.lon, this.place, required this.label, this.isMyPosition = false});

  final double? lat;
  final double? lon;
  final String? place;

  /// Nom montré à la personne.
  final String label;

  /// Vrai quand c'est la position GPS de la personne.
  final bool isMyPosition;

  @override
  bool operator ==(Object other) =>
      other is WeatherQuery && other.lat == lat && other.lon == lon && other.place == place && other.isMyPosition == isMyPosition;

  @override
  int get hashCode => Object.hash(lat, lon, place, isMyPosition);
}

/// Lieu choisi à la main (région ou lieu précisé) ; `null` = on suit la position de la personne.
final manualWeatherQueryProvider = StateProvider<WeatherQuery?>((ref) => null);

/// La position n'est demandée qu'une fois par session : un refus ne fait pas revenir la demande à chaque écran.
final weatherLocateAskedProvider = StateProvider<bool>((ref) => false);

/// Lieu dont on affiche la météo : choix manuel, sinon position GPS, sinon lieu du profil. `null` si on ne sait pas.
final weatherQueryProvider = Provider<WeatherQuery?>((ref) {
  final manual = ref.watch(manualWeatherQueryProvider);
  if (manual != null) return manual;

  final position = ref.watch(userLocationProvider).position;
  if (position != null && isInSenegal(position)) {
    return WeatherQuery(lat: position.latitude, lon: position.longitude, label: 'Ma position', isMyPosition: true);
  }

  final text = ref.watch(profileNotifierProvider).valueOrNull?.location.trim() ?? '';
  if (text.isEmpty) return null;
  final region = SenegalRegions.fromName(text);
  if (region != null) return WeatherQuery(lat: region.lat, lon: region.lon, label: region.name);
  return WeatherQuery(place: text, label: text.split(',').first.trim());
});

/// Météo réelle du lieu demandé. Les erreurs sont explicites : lieu ambigu, source indisponible.
final weatherReportProvider = FutureProvider.autoDispose.family<WeatherReport, WeatherQuery>((ref, query) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.get('/weather/here/', queryParams: {
      if (query.lat != null && query.lon != null) ...{'lat': query.lat, 'lon': query.lon} else 'location': query.place,
    });
    final data = response.data;
    if (data is Map && data['current'] != null) {
      final report = WeatherReport.fromJson(Map<String, dynamic>.from(data));
      // Demandée par position, la météo n'a pas de nom de lieu : on met celui que la personne reconnaît
      return query.lat != null ? report.withPlaceName(query.label) : report;
    }
    throw const WeatherUnavailable('La météo n\'a pas pu être lue.');
  } on DioException catch (e) {
    final data = e.response?.data;
    if (e.response?.statusCode == 409 && data is Map && data['candidates'] is List) {
      throw AmbiguousWeatherPlace([
        for (final c in data['candidates'] as List)
          WeatherPlaceChoice(
            label: c['label'].toString(),
            lat: (c['lat'] as num).toDouble(),
            lon: (c['lon'] as num).toDouble(),
          ),
      ]);
    }
    final message = data is Map ? data['error']?.toString() : null;
    throw WeatherUnavailable(message ?? 'Impossible de joindre le service météo. Vérifiez votre réseau.');
  }
});
