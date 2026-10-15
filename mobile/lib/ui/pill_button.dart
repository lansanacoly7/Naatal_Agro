import 'package:flutter/material.dart';

import 'glass.dart';
import 'press_scale.dart';
import 'tokens.dart';
import 'typography.dart';

enum PillVariant {
  /// Action principale : fond d'accent.
  primary,

  /// Action secondaire : contour.
  secondary,

  /// Bouton en verre posé sur un fond sombre ou coloré.
  glass,

  /// Bouton blanc posé sur un fond sombre.
  light,

  /// Action destructive (supprimer).
  danger,
}

/// Bouton en pilule. Taille de 56 px pour les actions principales,
/// 48 px au minimum pour toutes les autres.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = PillVariant.primary,
    this.expand = false,
    this.compact = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PillVariant variant;
  final bool expand;
  final bool compact;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = onPressed != null && !loading;
    final height = compact ? Hit.min : Hit.primary;

    final Color fg;
    final Color? bg;
    BoxBorder? border;
    switch (variant) {
      case PillVariant.primary:
        fg = c.onAccent;
        bg = c.accent;
      case PillVariant.secondary:
        fg = c.accent;
        bg = null;
        border = Border.all(color: c.accent, width: 1.8);
      case PillVariant.glass:
        fg = Colors.white;
        bg = null;
      case PillVariant.light:
        fg = const Color(0xFF0E1F16);
        bg = Colors.white;
      case PillVariant.danger:
        fg = c.clay;
        bg = c.clay.withValues(alpha: c.isDark ? 0.18 : 0.12);
    }

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: Space.s),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.body(color: fg, weight: 700),
            ),
          ),
        ],
      ],
    );

    Widget button;
    if (variant == PillVariant.glass) {
      button = Glass(
        style: GlassStyle.onHero,
        radius: Radii.pill,
        padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 24),
        child: SizedBox(height: height - 2, child: Center(child: content)),
      );
    } else {
      button = Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 26),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: border,
        ),
        child: Center(widthFactor: expand ? null : 1, child: content),
      );
    }

    return Opacity(
      opacity: onPressed == null && !loading ? 0.45 : 1,
      child: PressScale(
        onTap: enabled ? onPressed : null,
        semanticLabel: label,
        child: expand ? SizedBox(width: double.infinity, child: button) : button,
      ),
    );
  }
}
