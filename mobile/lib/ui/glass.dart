import 'dart:ui';

import 'package:flutter/material.dart';

import 'effects.dart';
import 'tokens.dart';

/// Apparence du verre dépoli selon le fond sur lequel il est posé.
enum GlassStyle {
  /// Sur un fond sombre ou coloré (carte météo, en-têtes).
  onHero,

  /// Sur un fond de page : surface givrée (barre flottante, boutons).
  frosted,
}

/// Conteneur en verre dépoli.
///
/// Le flou en temps réel coûte cher sur les téléphones modestes : en mode
/// « effets réduits », le verre devient une surface translucide sans flou.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = Radii.l,
    this.padding,
    this.style = GlassStyle.frosted,
    this.blur = 18,
    this.strong = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final GlassStyle style;
  final double blur;

  /// Voile plus opaque, pour garder le texte lisible.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final reduced = context.reduceEffects;

    final Color fill;
    final Color border;
    switch (style) {
      case GlassStyle.onHero:
        fill = Colors.white.withValues(alpha: reduced ? 0.22 : (strong ? 0.2 : 0.13));
        border = Colors.white.withValues(alpha: 0.28);
      case GlassStyle.frosted:
        if (c.isDark) {
          fill = const Color(0xFF16221B).withValues(alpha: reduced ? 0.96 : (strong ? 0.78 : 0.62));
          border = Colors.white.withValues(alpha: 0.14);
        } else {
          fill = Colors.white.withValues(alpha: reduced ? 0.96 : (strong ? 0.82 : 0.66));
          border = Colors.white.withValues(alpha: 0.7);
        }
    }

    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
      ),
      child: child,
    );

    if (reduced) return box;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: box,
      ),
    );
  }
}
