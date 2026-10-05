import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/connectivity_provider.dart';

/// Bandeau indicateur affiché en haut de l'écran lorsque l'application est hors ligne
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      crossFadeState: isOffline ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: Material(
        color: const Color(0xFFD97706), // Ambre vif
        child: SafeArea(
          bottom: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Mode hors ligne — Synchronisation automatique dès retour du réseau',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }
}
