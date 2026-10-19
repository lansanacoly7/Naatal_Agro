import 'package:flutter/material.dart';

import 'press_scale.dart';
import 'tokens.dart';
import 'typography.dart';

/// Très grand bouton d'action tactile (hauteur ≥ 56 px), avec photo ou grande icône
/// et libellé court. Adapté aux mains mouillées, gants ou plein soleil.
class BigActionButton extends StatelessWidget {
  const BigActionButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.imageAsset,
    this.domainColor,
    this.subtitle,
    this.height = 64,
    this.isPrimary = true,
  });

  /// Libellé court (1 à 3 mots).
  final String label;

  /// Action au tap.
  final VoidCallback? onTap;

  /// Icône (si pas d'imageAsset ou en complément).
  final IconData? icon;

  /// Photo miniature d'accompagnement (format carré ou 4:3).
  final String? imageAsset;

  /// Couleur d'accent du domaine.
  final Color? domainColor;

  /// Précision courte optionnelle (ex. « 3 parcelles »).
  final String? subtitle;

  /// Hauteur minimale garantie ≥ 56 px.
  final double height;

  /// Style plein accentué ou surface douce.
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final accent = domainColor ?? c.accent;
    final effectiveHeight = height < Hit.primary ? Hit.primary : height;

    final bg = isPrimary
        ? accent
        : (c.isDark ? c.surfaceAlt : c.surface);
    final fg = isPrimary
        ? (domainColor == null ? c.onAccent : Colors.white)
        : c.ink;
    final subFg = isPrimary
        ? fg.withValues(alpha: 0.85)
        : c.ink2;

    return PressScale(
      onTap: onTap,
      child: Container(
        height: effectiveHeight,
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.l),
          border: isPrimary
              ? null
              : Border.all(color: c.line, width: 1),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? accent.withValues(alpha: c.isDark ? 0.35 : 0.22)
                  : Colors.black.withValues(alpha: c.isDark ? 0.2 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image ou Icône
            if (imageAsset != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.m),
                child: Image.asset(
                  imageAsset!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 44,
                    height: 44,
                    color: isPrimary ? Colors.white.withValues(alpha: 0.2) : accent.withValues(alpha: 0.15),
                    child: Icon(icon ?? Icons.touch_app_rounded, color: isPrimary ? fg : accent, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: Space.m),
            ] else if (icon != null) ...[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.22)
                      : accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Radii.m),
                ),
                child: Icon(icon, color: isPrimary ? fg : accent, size: 24),
              ),
              const SizedBox(width: Space.m),
            ],

            // Libellé court
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: T.body(color: fg, weight: 700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: T.caption(color: subFg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Chevron discret
            Icon(
              Icons.chevron_right_rounded,
              color: isPrimary ? fg.withValues(alpha: 0.7) : c.ink2,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
