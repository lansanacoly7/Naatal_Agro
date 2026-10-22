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
import 'features/reminders/data/reminder_alarms.dart';
import 'features/reminders/data/reminder_sync.dart';

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

class _NataalAgroAppState extends ConsumerState<NataalAgroApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<InAppAlert>? _alertSub;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _router = ref.read(routerProvider);
    _startOfflineSync();
    _startReminderSync();
  }

  /// Alarmes de rappel : synchronisées à la connexion, à la reprise de l'application et au retour du réseau ;
  /// retirées à la déconnexion pour qu'elles ne sonnent jamais pour un autre compte.
  void _startReminderSync() {
    WidgetsBinding.instance.addObserver(this);
    final platform = ref.read(alarmPlatformProvider);
    if (platform is InAppAlarmPlatform) {
      // Pas de notifications système (navigateur, ordinateur) : le rappel s'affiche tant que l'application est ouverte
      _alertSub = platform.alerts.listen(_showReminderAlert);
    }
    ref.listenManual<AsyncValue<bool>>(authStateProvider, (previous, next) {
      final reminders = ref.read(reminderSyncProvider);
      if (next.valueOrNull == true) {
        reminders.syncQuietly();
      } else if (next.valueOrNull == false && previous?.valueOrNull == true) {
        reminders.clear().catchError((Object e) => debugPrint('[Rappels] Nettoyage des alarmes impossible : $e'));
      }
    }, fireImmediately: true);
  }

  void _showReminderAlert(InAppAlert alert) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('⏰ ${alert.body}'),
        duration: const Duration(seconds: 20),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ref.read(authStateProvider).valueOrNull == true) {
      ref.read(reminderSyncProvider).syncQuietly();
    }
  }

  /// Rejoue les actions faites hors ligne au démarrage, puis à chaque retour du réseau.
  void _startOfflineSync() {
    final apiClient = ref.read(apiClientProvider);
    _syncOfflineActions(apiClient);
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        if (!results.contains(ConnectivityResult.none)) {
          _syncOfflineActions(apiClient);
          if (ref.read(authStateProvider).valueOrNull == true) ref.read(reminderSyncProvider).syncQuietly();
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
    WidgetsBinding.instance.removeObserver(this);
    _alertSub?.cancel();
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
      scaffoldMessengerKey: _messengerKey,
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
