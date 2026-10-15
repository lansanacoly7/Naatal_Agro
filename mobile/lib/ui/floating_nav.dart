import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass.dart';
import 'tokens.dart';
import 'typography.dart';

class NavItem {
  const NavItem({required this.icon, required this.activeIcon, required this.label});

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Barre de navigation flottante en verre dépoli.
///
/// La page active est une pastille qui glisse d'un onglet à l'autre.
/// Chaque onglet garde son libellé : on ne se fie pas aux icônes seules.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double height = 68;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(Space.l + 2, 0, Space.l + 2, bottom > 0 ? bottom : Space.m),
      child: Glass(
        strong: true,
        radius: Radii.pill,
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, box) {
              final slot = box.maxWidth / items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 380),
                    curve: Motion.out,
                    left: slot * currentIndex + 6,
                    top: 6,
                    width: slot - 12,
                    height: height - 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.isDark ? c.accent : c.ink,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavButton(
                            item: items[i],
                            selected: i == currentIndex,
                            onTap: () {
                              if (i != currentIndex) HapticFeedback.selectionClick();
                              onTap(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final Color on = c.isDark ? c.onAccent : c.bg;
    final color = selected ? on : c.ink2;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1 : 0.96,
          duration: Motion.base,
          curve: Motion.out,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: Motion.fast,
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  key: ValueKey(selected),
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: Motion.base,
                style: T.caption(color: color, weight: selected ? 700 : 600).copyWith(fontSize: 11),
                child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
