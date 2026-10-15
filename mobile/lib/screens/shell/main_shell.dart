import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/ui.dart';

/// Coque des quatre onglets principaux : le contenu passe sous une barre
/// de navigation flottante en verre dépoli.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _items = [
    NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Accueil'),
    NavItem(icon: Icons.eco_outlined, activeIcon: Icons.eco_rounded, label: 'Cultures'),
    NavItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'Marchés'),
    NavItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome_rounded, label: 'Assistant'),
  ];

  static const _paths = ['/', '/agriculture', '/markets', '/ai'];

  int _indexFor(String location) {
    if (location.startsWith('/agriculture')) return 1;
    if (location.startsWith('/markets')) return 2;
    if (location.startsWith('/ai')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      backgroundColor: context.c.bg,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingNavBar(
              items: _items,
              currentIndex: _indexFor(location),
              onTap: (i) => context.go(_paths[i]),
            ),
          ),
        ],
      ),
    );
  }
}
