import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'senegal_regions.dart';

/// Détecteur de région injectable (remplacé dans les tests, où il n'y a ni GPS ni autorisation à demander).
final regionDetectorProvider = Provider<Future<SenegalRegion?> Function()>((ref) => detectRegion);

/// Région devinée à partir de la position du téléphone. Aucune saisie : l'agriculteur n'a rien à écrire.
///
/// Renvoie `null` si l'autorisation est refusée, si la localisation est coupée ou si la position n'arrive pas à temps :
/// l'écran propose alors de choisir la région en touchant son nom.
Future<SenegalRegion?> detectRegion() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 12)),
    );

    // Sur téléphone, le nom de région donné par le système est plus fiable que la distance au chef-lieu
    if (!kIsWeb) {
      try {
        final places = await placemarkFromCoordinates(position.latitude, position.longitude).timeout(const Duration(seconds: 6));
        for (final place in places) {
          final region = SenegalRegions.fromName('${place.administrativeArea ?? ''} ${place.subAdministrativeArea ?? ''}');
          if (region != null) return region;
        }
      } catch (e) {
        debugPrint('[Localisation] Nom de région indisponible, repli sur le chef-lieu le plus proche : $e');
      }
    }
    return SenegalRegions.nearest(position.latitude, position.longitude);
  } catch (e) {
    debugPrint('[Localisation] Position indisponible : $e');
    return null;
  }
}
