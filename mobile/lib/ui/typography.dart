import 'package:flutter/material.dart';

/// Typographie : une seule famille (Onest, embarquée dans l'application).
///
/// Cinq tailles seulement. Les chiffres sont toujours alignés (tabulaires).
abstract final class T {
  static const String family = 'Onest';

  static TextStyle _base(double size, int weight,
      {double? height, double spacing = 0, Color? color, bool tabular = false}) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      height: height,
      letterSpacing: spacing,
      color: color,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
  }

  /// Titre d'écran (grand titre qui se réduit au défilement).
  static TextStyle largeTitle({Color? color}) =>
      _base(30, 800, height: 1.08, spacing: -0.8, color: color);

  /// Titre de section ou de feuille.
  static TextStyle title({Color? color}) =>
      _base(20, 700, height: 1.15, spacing: -0.3, color: color);

  /// Texte courant et lignes de liste.
  static TextStyle body({Color? color, int weight = 500}) =>
      _base(15, weight, height: 1.35, color: color);

  /// Légende, sous-titre, étiquette.
  static TextStyle caption({Color? color, int weight = 600}) =>
      _base(12, weight, height: 1.3, color: color);

  /// Grand chiffre (revenus, température, total).
  static TextStyle number(double size, {Color? color, int weight = 800}) =>
      _base(size, weight,
          height: 1.05, spacing: -size * 0.03, color: color, tabular: true);

  /// Chiffre de taille courante, aligné.
  static TextStyle figure({Color? color, int weight = 700}) =>
      _base(15, weight, height: 1.3, color: color, tabular: true);
}
