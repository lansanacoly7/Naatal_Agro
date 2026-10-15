import 'package:flutter/material.dart';

/// Couleurs sémantiques de Naatal Agro, en clair et en sombre.
///
/// Aucun écran n'utilise de couleur en dur : tout passe par `context.c`.
@immutable
class NaatalColors extends ThemeExtension<NaatalColors> {
  const NaatalColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.ink2,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.clay,
    required this.slate,
    required this.gold,
    required this.mint,
    required this.heroTop,
    required this.heroBottom,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color ink2;
  final Color line;
  final Color accent;
  final Color onAccent;
  final Color clay;
  final Color slate;
  final Color gold;
  final Color mint;
  final Color heroTop;
  final Color heroBottom;
  final bool isDark;

  /// Couleur d'accent pour un fond de carte « vivant » (culture, pastille).
  List<Color> get cropPalette => [gold, mint, clay, slate];

  static const light = NaatalColors(
    bg: Color(0xFFF2F4F1),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE7ECE7),
    ink: Color(0xFF0F1A14),
    ink2: Color(0xFF46564C),
    line: Color(0xFFDDE3DD),
    accent: Color(0xFF1D6B43),
    onAccent: Color(0xFFFFFFFF),
    clay: Color(0xFFA8401F),
    slate: Color(0xFF3A5670),
    gold: Color(0xFFE9B949),
    mint: Color(0xFF6FD3A0),
    heroTop: Color(0xFF0F4F31),
    heroBottom: Color(0xFF157A4A),
    isDark: false,
  );

  static const dark = NaatalColors(
    bg: Color(0xFF0A0F0C),
    surface: Color(0xFF151C17),
    surfaceAlt: Color(0xFF1D2620),
    ink: Color(0xFFF2F6F3),
    ink2: Color(0xFFA9B8AE),
    line: Color(0xFF26302A),
    accent: Color(0xFF6FD598),
    onAccent: Color(0xFF06120B),
    clay: Color(0xFFF2A488),
    slate: Color(0xFF9DB6CF),
    gold: Color(0xFFE5B04A),
    mint: Color(0xFF5ED1A0),
    heroTop: Color(0xFF0B3523),
    heroBottom: Color(0xFF0F5A37),
    isDark: true,
  );

  @override
  NaatalColors copyWith() => this;

  @override
  NaatalColors lerp(ThemeExtension<NaatalColors>? other, double t) {
    if (other is! NaatalColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension NaatalContext on BuildContext {
  NaatalColors get c =>
      Theme.of(this).extension<NaatalColors>() ?? NaatalColors.light;
}

/// Échelle d'espacement unique.
abstract final class Space {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double huge = 32;

  /// Marge horizontale des écrans.
  static const double gutter = 20;

  /// Espace réservé en bas pour la barre de navigation flottante.
  static const double navClearance = 108;
}

/// Rayons de courbure.
abstract final class Radii {
  static const double s = 12;
  static const double m = 16;
  static const double l = 20;
  static const double xl = 24;
  static const double sheet = 30;
  static const double pill = 99;
}

/// Durées et courbes : courtes, jamais décoratives.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration count = Duration(milliseconds: 900);

  /// Courbe d'entrée « Apple » : départ vif, arrivée douce.
  static const Curve out = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve inOut = Curves.easeInOutCubic;
}

/// Hauteurs minimales des zones tactiles (utilisables avec des gants).
abstract final class Hit {
  static const double min = 48;
  static const double primary = 56;
}
