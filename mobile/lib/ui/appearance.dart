import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show sharedPreferencesProvider;
import 'theme.dart';

/// Apparence choisie par la personne : clair, sombre, ou automatique (suit le réglage du téléphone).
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  static ThemeMode _read(SharedPreferences prefs) {
    switch (prefs.getString(_key)) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await _prefs.setString(_key, mode.name);
    } catch (_) {
      // Sans stockage local, le choix vaut jusqu'à la fermeture de l'application
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(sharedPreferencesProvider));
});

/// Libellé du choix d'apparence.
String appearanceLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Clair',
      ThemeMode.dark => 'Sombre',
      ThemeMode.system => 'Automatique',
    };

/// Garde un écran en clair tant qu'il n'a pas été adapté au mode sombre.
/// Évite un mélange illisible (texte sombre sur fond sombre) : l'écran garde son aspect clair, entier et lisible.
class LightOnly extends StatelessWidget {
  const LightOnly({super.key, required this.child});

  final Widget child;

  static final ThemeData _light = NaatalTheme.light;

  @override
  Widget build(BuildContext context) => Theme(data: _light, child: child);
}
