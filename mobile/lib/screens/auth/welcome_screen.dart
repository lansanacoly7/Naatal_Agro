import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../ui/ui.dart';

/// Courte transition après la connexion, avant l'accueil.
class WelcomeLoadingScreen extends ConsumerStatefulWidget {
  const WelcomeLoadingScreen({super.key});

  @override
  ConsumerState<WelcomeLoadingScreen> createState() => _WelcomeLoadingScreenState();
}

class _WelcomeLoadingScreenState extends ConsumerState<WelcomeLoadingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) ref.read(welcomeStateProvider.notifier).state = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: Reveal(
            index: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Glass(
                  style: GlassStyle.onHero,
                  radius: 36,
                  padding: const EdgeInsets.all(Space.xl),
                  child: const Icon(Icons.eco_rounded, size: 64, color: Colors.white),
                ),
                const SizedBox(height: Space.xl),
                Text('Naatal Agro', style: T.largeTitle(color: Colors.white)),
                const SizedBox(height: Space.xs),
                Text('Préparation de votre espace…', style: T.body(color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
