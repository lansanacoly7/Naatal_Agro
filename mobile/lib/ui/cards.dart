import 'package:flutter/material.dart';

import 'press_scale.dart';
import 'tokens.dart';
import 'typography.dart';

/// Carte de surface : fond blanc (ou sombre), coins arrondis, contour léger.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.l),
    this.onTap,
    this.color,
    this.radius = Radii.l,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: c.line.withValues(alpha: c.isDark ? 1 : 0.7)) : null,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return PressScale(onTap: onTap, scale: 0.98, child: card);
  }
}

/// Pastille d'icône colorée, utilisée en tête de ligne.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.color,
    this.size = 38,
    this.iconColor,
  });

  final IconData icon;
  final Color? color;
  final double size;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? c.accent,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.52, color: iconColor ?? c.onAccent),
    );
  }
}

/// Titre de section, avec action facultative à droite.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.s),
      child: Row(
        children: [
          Expanded(child: Text(title, style: T.title(color: c.ink))),
          if (action != null)
            PressScale(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s, horizontal: Space.xs),
                child: Text(action!, style: T.caption(color: c.accent, weight: 700)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Liste groupée « façon iOS » : un seul bloc arrondi, lignes séparées par un filet.
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children, this.margin});

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Divider(height: 1, thickness: 1, indent: 66, color: c.line));
      }
      items.add(children[i]);
    }
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: Space.gutter),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.l),
        border: Border.all(color: c.line.withValues(alpha: c.isDark ? 1 : 0.7)),
      ),
      child: Column(children: items),
    );
  }
}

/// Ligne de liste : pastille, titre, sous-titre, valeur et flèche.
class GroupedRow extends StatelessWidget {
  const GroupedRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.value,
    this.valueColor,
    this.onTap,
    this.chevron = false,
    this.minHeight = 60,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool chevron;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: Space.m)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: T.body(color: c.ink, weight: 600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: T.caption(color: c.ink2, weight: 500), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: Space.s),
                child: Text(value!, style: T.figure(color: valueColor ?? c.ink)),
              ),
            if (trailing != null) ...[const SizedBox(width: Space.s), trailing!],
            if (chevron) ...[
              const SizedBox(width: Space.xs),
              Icon(Icons.chevron_right_rounded, size: 22, color: c.ink2),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return PressScale(onTap: onTap, scale: 0.99, child: row);
  }
}
