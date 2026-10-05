import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier qui surveille en temps réel la connectivité réseau
class ConnectivityNotifier extends StateNotifier<bool> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityNotifier() : super(false) {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      state = _isEffectivelyOffline(results);
      _subscription = Connectivity().onConnectivityChanged.listen((results) {
        state = _isEffectivelyOffline(results);
      });
    } catch (e) {
      debugPrint('[Connectivity] Plugin non disponible: $e');
    }
  }

  bool _isEffectivelyOffline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.contains(ConnectivityResult.none) && results.length == 1;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Fournit `true` lorsque l'appareil est détecté hors ligne
final isOfflineProvider = StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});
