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
    this.domainCultures = const Color(0xFF1B5E20),
    this.domainStock = const Color(0xFFD97706),
    this.domainMarches = const Color(0xFFA8401F),
    this.domainMeteo = const Color(0xFF0284C7),
    this.domainFinances = const Color(0xFF3A5670),
    this.domainAlerts = const Color(0xFFFF9500),
    this.domainIa = const Color(0xFF7C3AED),
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

  // Couleurs de domaine (Refonte Images d'Abord)
  final Color domainCultures;
  final Color domainStock;
  final Color domainMarches;
  final Color domainMeteo;
  final Color domainFinances;
  final Color domainAlerts;
  final Color domainIa;

  /// Couleur d'accent pour un fond de carte « vivant » (culture, pastille).
  List<Color> get cropPalette => [gold, mint, clay, slate];

  static const light = NaatalColors(
    bg: Color(0xFFFBF7F0), // Crème chaud (#FBF7F0)
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0ECE3),
    ink: Color(0xFF0F1A14),
    ink2: Color(0xFF46564C),
    line: Color(0xFFE5DFD5),
    accent: Color(0xFF1B5E20),
    onAccent: Color(0xFFFFFFFF),
    clay: Color(0xFFA8401F),
    slate: Color(0xFF3A5670),
    gold: Color(0xFFE9B949),
    mint: Color(0xFF6FD3A0),
    heroTop: Color(0xFF0F4F31),
    heroBottom: Color(0xFF157A4A),
    isDark: false,
    domainCultures: Color(0xFF1B5E20),
    domainStock: Color(0xFFD97706),
    domainMarches: Color(0xFFA8401F),
    domainMeteo: Color(0xFF0284C7),
    domainFinances: Color(0xFF3A5670),
    domainAlerts: Color(0xFFFF9500),
    domainIa: Color(0xFF7C3AED),
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
    domainCultures: Color(0xFF6FD598),
    domainStock: Color(0xFFE5B04A),
    domainMarches: Color(0xFFF2A488),
    domainMeteo: Color(0xFF38BDF8),
    domainFinances: Color(0xFF9DB6CF),
    domainAlerts: Color(0xFFFB923C),
    domainIa: Color(0xFFA78BFA),
  );

  @override
  NaatalColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? ink2,
    Color? line,
    Color? accent,
    Color? onAccent,
    Color? clay,
    Color? slate,
    Color? gold,
    Color? mint,
    Color? heroTop,
    Color? heroBottom,
    bool? isDark,
    Color? domainCultures,
    Color? domainStock,
    Color? domainMarches,
    Color? domainMeteo,
    Color? domainFinances,
    Color? domainAlerts,
    Color? domainIa,
  }) => NaatalColors(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    ink: ink ?? this.ink,
    ink2: ink2 ?? this.ink2,
    line: line ?? this.line,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    clay: clay ?? this.clay,
    slate: slate ?? this.slate,
    gold: gold ?? this.gold,
    mint: mint ?? this.mint,
    heroTop: heroTop ?? this.heroTop,
    heroBottom: heroBottom ?? this.heroBottom,
    isDark: isDark ?? this.isDark,
    domainCultures: domainCultures ?? this.domainCultures,
    domainStock: domainStock ?? this.domainStock,
    domainMarches: domainMarches ?? this.domainMarches,
    domainMeteo: domainMeteo ?? this.domainMeteo,
    domainFinances: domainFinances ?? this.domainFinances,
    domainAlerts: domainAlerts ?? this.domainAlerts,
    domainIa: domainIa ?? this.domainIa,
  );

  @override
  NaatalColors lerp(ThemeExtension<NaatalColors>? other, double t) {
    if (other is! NaatalColors) return this;
    return NaatalColors(
      bg: Color.lerp(bg, other.bg, t) ?? bg,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t) ?? surfaceAlt,
      ink: Color.lerp(ink, other.ink, t) ?? ink,
      ink2: Color.lerp(ink2, other.ink2, t) ?? ink2,
      line: Color.lerp(line, other.line, t) ?? line,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      onAccent: Color.lerp(onAccent, other.onAccent, t) ?? onAccent,
      clay: Color.lerp(clay, other.clay, t) ?? clay,
      slate: Color.lerp(slate, other.slate, t) ?? slate,
      gold: Color.lerp(gold, other.gold, t) ?? gold,
      mint: Color.lerp(mint, other.mint, t) ?? mint,
      heroTop: Color.lerp(heroTop, other.heroTop, t) ?? heroTop,
      heroBottom: Color.lerp(heroBottom, other.heroBottom, t) ?? heroBottom,
      isDark: t < 0.5 ? isDark : other.isDark,
      domainCultures: Color.lerp(domainCultures, other.domainCultures, t) ?? domainCultures,
      domainStock: Color.lerp(domainStock, other.domainStock, t) ?? domainStock,
      domainMarches: Color.lerp(domainMarches, other.domainMarches, t) ?? domainMarches,
      domainMeteo: Color.lerp(domainMeteo, other.domainMeteo, t) ?? domainMeteo,
      domainFinances: Color.lerp(domainFinances, other.domainFinances, t) ?? domainFinances,
      domainAlerts: Color.lerp(domainAlerts, other.domainAlerts, t) ?? domainAlerts,
      domainIa: Color.lerp(domainIa, other.domainIa, t) ?? domainIa,
    );
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
  static const double navClearance = 24;
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
