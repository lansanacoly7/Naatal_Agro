import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/network/connectivity_provider.dart';
import 'ui/ui.dart';
import 'core/router/app_router.dart';
import 'core/network/api_client.dart';
import 'core/network/sync_service.dart';
import 'features/auth/data/auth_provider.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences non initialisé');
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const NataalAgroApp(),
    ),
  );
}

/// Application principale Nataal Agro
class NataalAgroApp extends ConsumerStatefulWidget {
  const NataalAgroApp({super.key});

  @override
  ConsumerState<NataalAgroApp> createState() => _NataalAgroAppState();
}

class _NataalAgroAppState extends ConsumerState<NataalAgroApp> {
  late final GoRouter _router;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _router = ref.read(routerProvider);
    _startOfflineSync();
  }

  /// Rejoue les actions faites hors ligne au démarrage, puis à chaque retour du réseau.
  void _startOfflineSync() {
    final apiClient = ref.read(apiClientProvider);
    _syncOfflineActions(apiClient);
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        if (!results.contains(ConnectivityResult.none)) {
          _syncOfflineActions(apiClient);
        }
      });
    } catch (e) {
      // Plugin indisponible (tests, certaines plateformes) : la synchro au démarrage suffit
      debugPrint('[Sync] Surveillance de la connectivité indisponible : $e');
    }
  }

  /// Lance la synchro sans bloquer l'UI ; toute erreur est journalisée, jamais ignorée.
  Future<void> _syncOfflineActions(ApiClient apiClient) async {
    try {
      await SyncService.syncOfflineData(apiClient);
    } catch (e, stack) {
      debugPrint('[Sync] Échec de la synchronisation hors ligne : $e\n$stack');
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceEffects = ref.watch(effectsReducedProvider);
    final offline = ref.watch(isOfflineProvider);
    return MaterialApp.router(
      title: 'Naatal Agro',
      debugShowCheckedModeBanner: false,
      theme: NaatalTheme.light,
      themeMode: ThemeMode.light, // mode sombre désactivé : thème clair uniquement
      routerConfig: _router,
      builder: (context, child) {
        // Texte global un peu plus petit (le réglage de taille du téléphone reste respecté).
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(0.9 * mq.textScaler.scale(1))),
          child: EffectsScope(
          reduced: reduceEffects,
          child: Stack(
            children: [
              Positioned.fill(child: child ?? const SizedBox.shrink()),
              if (offline)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: const Padding(
                      padding: EdgeInsets.only(top: Space.s),
                      child: StatusStrip(text: 'Hors ligne : vos actions seront envoyées au retour du réseau.'),
                    ),
                  ),
                ),
            ],
          ),
          ),
        );
      },
    );
  }
}
