import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ce qui empêche (ou non) d'utiliser la position du téléphone.
enum LocationAccess {
  /// Prête : autorisation donnée et localisation allumée.
  granted,

  /// L'utilisateur a coupé l'option dans le profil de l'application.
  disabledByUser,

  /// Autorisation refusée : on peut encore la redemander.
  denied,

  /// Refus définitif : seul le réglage du téléphone permet de revenir en arrière.
  deniedForever,

  /// Le GPS / la localisation est éteint sur le téléphone.
  serviceOff,
}

const _prefKey = 'location_enabled';

/// Choix de l'utilisateur dans le profil. Activé par défaut : le système demande de toute façon l'autorisation.
class LocationEnabledNotifier extends StateNotifier<bool> {
  LocationEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_prefKey) ?? true;
    } catch (e) {
      debugPrint('[Localisation] Préférence illisible : $e');
    }
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (e) {
      debugPrint('[Localisation] Préférence non enregistrée : $e');
    }
  }
}

final locationEnabledProvider = StateNotifierProvider<LocationEnabledNotifier, bool>((ref) => LocationEnabledNotifier());

/// Lit l'état réel sans rien demander à l'utilisateur.
Future<LocationAccess> checkLocationAccess({required bool enabledByUser}) async {
  if (!enabledByUser) return LocationAccess.disabledByUser;
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;
    return _fromPermission(await Geolocator.checkPermission());
  } catch (e) {
    debugPrint('[Localisation] État illisible : $e');
    return LocationAccess.denied;
  }
}

/// Comme [checkLocationAccess], mais redemande l'autorisation si elle a été refusée (une nouvelle chance).
Future<LocationAccess> requestLocationAccess() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    return _fromPermission(permission);
  } catch (e) {
    debugPrint('[Localisation] Demande impossible : $e');
    return LocationAccess.denied;
  }
}

LocationAccess _fromPermission(LocationPermission p) => switch (p) {
      LocationPermission.denied || LocationPermission.unableToDetermine => LocationAccess.denied,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.granted,
    };

/// Ouvre l'écran de réglages qui permet de corriger [access]. Renvoie `false` s'il n'y en a pas (navigateur).
Future<bool> openLocationFix(LocationAccess access) async {
  try {
    if (access == LocationAccess.serviceOff) return await Geolocator.openLocationSettings();
    if (access == LocationAccess.deniedForever) return await Geolocator.openAppSettings();
  } catch (e) {
    debugPrint('[Localisation] Réglages inaccessibles : $e');
  }
  return false;
}

/// Phrase simple, sans jargon, pour dire pourquoi la position n'est pas disponible.
String locationAccessMessage(LocationAccess access) => switch (access) {
      LocationAccess.granted => 'La localisation est active.',
      LocationAccess.disabledByUser => 'La localisation est désactivée dans l\'application. Activez-la pour voir ce qui est près de vous.',
      LocationAccess.denied => 'La localisation a été refusée. Touchez « Activer la localisation » pour réessayer.',
      LocationAccess.deniedForever => 'La localisation est bloquée. Ouvrez les réglages du téléphone pour l\'autoriser.',
      LocationAccess.serviceOff => 'La localisation est éteinte sur votre téléphone. Allumez-la dans les réglages.',
    };

/// Texte du bouton qui permet de corriger le problème.
String locationFixLabel(LocationAccess access) => switch (access) {
      LocationAccess.deniedForever || LocationAccess.serviceOff => 'Ouvrir les réglages',
      _ => 'Activer la localisation',
    };
