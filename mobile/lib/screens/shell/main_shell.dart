import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/ui.dart';

/// Coque des onglets principaux : une barre de navigation fixe, qui ne recouvre jamais le contenu.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  /// Accueil, Cultures, Mon dashboard au centre, Marchés, puis Naatal IA tout au bout.
  static const _paths = ['/', '/agriculture', '/mon_dashboard', '/markets', '/ai'];

  int _indexFor(String location) {
    if (location.startsWith('/agriculture')) return 1;
    if (location.startsWith('/mon_dashboard') || location.startsWith('/finances')) return 2;
    if (location.startsWith('/markets')) return 3;
    if (location.startsWith('/ai')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final c = context.c;

    return Scaffold(
      backgroundColor: c.bg,
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
        child: NavigationBar(
          selectedIndex: _indexFor(location),
          onDestinationSelected: (i) => context.go(_paths[i]),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Accueil'),
            NavigationDestination(icon: Icon(Icons.eco_outlined), selectedIcon: Icon(Icons.eco_rounded), label: 'Cultures'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront_rounded), label: 'Marchés'),
            NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome_rounded), label: 'Naatal IA'),
          ],
        ),
      ),
    );
  }
}
