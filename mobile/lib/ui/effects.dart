import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show sharedPreferencesProvider;

/// Réglage « effets réduits » : désactive le flou et les animations d'ambiance
/// pour les téléphones d'entrée de gamme. Enregistré sur l'appareil.
class EffectsNotifier extends StateNotifier<bool> {
  EffectsNotifier(this._prefs) : super(_prefs.getBool(_key) ?? false);

  static const String _key = 'reduce_effects';
  final SharedPreferences _prefs;

  Future<void> set(bool reduced) async {
    state = reduced;
    await _prefs.setBool(_key, reduced);
  }
}

final effectsReducedProvider =
    StateNotifierProvider<EffectsNotifier, bool>((ref) {
  return EffectsNotifier(ref.watch(sharedPreferencesProvider));
});

/// Rend le réglage disponible à tous les composants sans dépendre de Riverpod.
class EffectsScope extends InheritedWidget {
  const EffectsScope({super.key, required this.reduced, required super.child});

  /// `true` : pas de flou, pas d'animation d'ambiance.
  final bool reduced;

  static bool reducedOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<EffectsScope>();
    final system = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return (scope?.reduced ?? false) || system;
  }

  @override
  bool updateShouldNotify(EffectsScope oldWidget) =>
      reduced != oldWidget.reduced;
}

extension EffectsContext on BuildContext {
  /// Vrai si le flou et les animations d'ambiance doivent être évités.
  bool get reduceEffects => EffectsScope.reducedOf(this);
}
