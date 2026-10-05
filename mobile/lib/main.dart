import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
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
    SyncService.syncOfflineData(apiClient).catchError((_) {});
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        if (!results.contains(ConnectivityResult.none)) {
          SyncService.syncOfflineData(apiClient).catchError((_) {});
        }
      });
    } catch (_) {
      // Plugin indisponible (tests, certaines plateformes) : la synchro au démarrage suffit
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Nataal Agro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}


