import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../agriculture/data/agriculture_provider.dart';
import '../../markets/data/markets_provider.dart';
import 'models/map_marker_item.dart';

/// Coordonnées géographiques de référence des principales régions et places de marché au Sénégal
const Map<String, LatLng> senegalRegionalCoordinates = {
  'dakar': LatLng(14.6937, -17.4441),
  'sandaga': LatLng(14.6710, -17.4370),
  'tilène': LatLng(14.6850, -17.4510),
  'tilene': LatLng(14.6850, -17.4510),
  'castors': LatLng(14.7083, -17.4525),
  'thiaroye': LatLng(14.7640, -17.3750),
  'rufisque': LatLng(14.7167, -17.2667),
  'thiès': LatLng(14.7910, -16.9260),
  'thies': LatLng(14.7910, -16.9260),
  'mbour': LatLng(14.4220, -16.9638),
  'niayes': LatLng(14.8500, -17.1500),
  'saint-louis': LatLng(16.0333, -16.5000),
  'saint louis': LatLng(16.0333, -16.5000),
  'kaolack': LatLng(14.1500, -16.0833),
  'diourbel': LatLng(14.6500, -16.2333),
  'touba': LatLng(14.8625, -15.8756),
  'fatick': LatLng(14.3333, -16.4000),
  'ziguinchor': LatLng(12.5833, -16.2719),
  'kolda': LatLng(12.8833, -14.9500),
  'tambacounda': LatLng(13.7667, -13.6667),
  'louga': LatLng(15.6167, -16.2167),
  'matam': LatLng(15.6559, -13.2554),
  'kédougou': LatLng(12.5564, -12.1747),
  'kedougou': LatLng(12.5564, -12.1747),
  'sédhiou': LatLng(12.7081, -15.5569),
  'sedhiou': LatLng(12.7081, -15.5569),
  'kaffrine': LatLng(14.1059, -15.5508),
};

enum MapFilter {
  all,
  markets,
  crops,
}

final mapFilterProvider = StateProvider<MapFilter>((ref) => MapFilter.all);

final mapMarkersProvider = Provider<AsyncValue<List<MapMarkerItem>>>((ref) {
  final marketsAsync = ref.watch(marketsListProvider);
  final cropsAsync = ref.watch(cropsProvider);
  final filter = ref.watch(mapFilterProvider);

  if (marketsAsync.isLoading || cropsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (marketsAsync.hasError) {
    return AsyncValue.error(marketsAsync.error!, marketsAsync.stackTrace!);
  }

  final markers = <MapMarkerItem>[];

  // 1. Ajouter les marchés
  if (filter == MapFilter.all || filter == MapFilter.markets) {
    final markets = marketsAsync.value ?? [];
    for (final m in markets) {
      LatLng? pos = m.latLng;
      if (pos == null) {
        final keyName = m.name.toLowerCase().trim();
        final keyRegion = m.region.toLowerCase().trim();
        pos = senegalRegionalCoordinates[keyName] ?? senegalRegionalCoordinates[keyRegion];
      }
      if (pos != null) {
        markers.add(
          MapMarkerItem(
            id: 'market_${m.id}',
            title: m.name,
            subtitle: 'Marché · ${m.region}',
            position: pos,
            type: MapMarkerType.market,
            market: m,
            detailText: 'Horaires : ${m.openingTime?.substring(0, 5) ?? "08:00"} - ${m.closingTime?.substring(0, 5) ?? "18:00"}',
          ),
        );
      }
    }
  }

  // 2. Ajouter les cultures de l'agriculteur
  if (filter == MapFilter.all || filter == MapFilter.crops) {
    final crops = cropsAsync.value ?? [];
    for (var i = 0; i < crops.length; i++) {
      final c = crops[i];
      LatLng? pos;
      final loc = c.location.trim();
      if (loc.contains(',')) {
        try {
          final parts = loc.split(',');
          pos = LatLng(double.parse(parts[0].trim()), double.parse(parts[1].trim()));
        } catch (_) {}
      }
      if (pos == null) {
        final locLower = loc.toLowerCase();
        for (final entry in senegalRegionalCoordinates.entries) {
          if (locLower.contains(entry.key)) {
            // Décaler très légèrement si plusieurs parcelles sont dans la même zone
            final offset = (i * 0.015);
            pos = LatLng(entry.value.latitude + offset, entry.value.longitude + offset);
            break;
          }
        }
      }
      // Position par défaut aux Niayes si non localisée
      pos ??= LatLng(14.8500 + (i * 0.012), -17.1500 + (i * 0.012));

      markers.add(
        MapMarkerItem(
          id: 'crop_${c.id}',
          title: c.name,
          subtitle: 'Parcelle · ${c.cropType} (${c.areaSize} ha)',
          position: pos,
          type: MapMarkerType.crop,
          crop: c,
          detailText: 'Statut : ${c.status} · Localisation : ${c.location.isNotEmpty ? c.location : "Niayes"}',
        ),
      );
    }
  }

  return AsyncValue.data(markers);
});
