import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Séparation stricte des comptes : à chaque fermeture de session, tout ce que l'application garde en mémoire
/// (cultures, stock, ventes, discussion IA, profil…) est jeté et reconstruit à vide pour le compte suivant.
class SessionReset {
  SessionReset._();

  /// Numéro de la session courante : il change à chaque déconnexion.
  static final ValueNotifier<int> generation = ValueNotifier<int>(0);

  static void bump() => generation.value++;
}

/// Racine de l'application : un nouvel espace d'état (`ProviderScope`) pour chaque session.
class SessionRoot extends StatelessWidget {
  const SessionRoot({super.key, required this.overrides, required this.child});

  final List<Override> overrides;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SessionReset.generation,
      builder: (context, generation, _) => ProviderScope(
        key: ValueKey('session-$generation'),
        overrides: overrides,
        child: child,
      ),
    );
  }
}
