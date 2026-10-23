import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../../features/auth/data/auth_provider.dart';

import '../../features/agriculture/data/models/crop.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/markets/data/models/market.dart';
import '../../features/markets/presentation/screens/market_detail_screen.dart';
import '../../features/markets/presentation/screens/product_detail_screen.dart';
import '../../features/markets/presentation/screens/market_comparison_screen.dart';
import '../../features/profile/presentation/screens/price_alerts_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/settings_notifications_screen.dart';
import '../../features/profile/presentation/screens/settings_language_screen.dart';
import '../../features/profile/presentation/screens/settings_security_screen.dart';
import '../../features/profile/presentation/screens/settings_support_screen.dart';

import '../../screens/assistant/assistant_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../screens/onboarding/crop_setup_screen.dart';
import '../../features/auth/presentation/screens/welcome_loading_screen.dart';
import '../../features/weather/presentation/screens/weather_screen.dart';
import '../../features/agriculture/data/agriculture_provider.dart';
import '../../features/agriculture/presentation/screens/add_crop_screen.dart';
import '../../features/agriculture/presentation/screens/crop_detail_screen.dart';
import '../../features/agriculture/presentation/screens/culture_fiche_screen.dart';
import '../../features/agriculture/presentation/screens/cultures_screen.dart';
import '../../features/markets/data/models/product.dart';
import '../../screens/finances/finances_screen.dart';
import '../../screens/guides/guides_screens.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../features/dashboard/presentation/screens/calendar_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/mon_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/price_analysis_screen.dart';
import '../../screens/markets/markets_screen.dart';
import '../../screens/sell/sell_screen.dart';
import '../../screens/shell/main_shell.dart';
import '../../screens/stock/stock_screen.dart';
import '../../ui/ui.dart' show AuthStyle;

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'farmerShell');

final hasSeenOnboardingProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('has_seen_onboarding') ?? false;
});

final welcomeStateProvider = StateProvider<bool>((ref) => false);

/// Vrai juste après une inscription : la première chose demandée est la suggestion de culture.
/// Mémorisé sur le téléphone pour survivre à une fermeture de l'application avant la fin de cette étape.
final pendingCropSetupProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('pending_crop_setup') ?? false;
});

Future<void> setCropSetupPending(WidgetRef ref, bool pending) async {
  ref.read(pendingCropSetupProvider.notifier).state = pending;
  try {
    await ref.read(sharedPreferencesProvider).setBool('pending_crop_setup', pending);
  } catch (_) {
    // Sans stockage local, le drapeau reste valable jusqu'à la fermeture de l'application
  }
}

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<bool>>(
      authStateProvider,
      (previous, next) async {
        if (previous?.value != next.value) {
          _ref.read(welcomeStateProvider.notifier).state = false;
        }
        notifyListeners();
      },
    );
    _ref.listen<bool>(hasSeenOnboardingProvider, (previous, next) => notifyListeners());
    _ref.listen<bool>(welcomeStateProvider, (previous, next) => notifyListeners());
    _ref.listen<bool>(pendingCropSetupProvider, (previous, next) => notifyListeners());
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(routerNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: notifier,
    initialLocation: '/',
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final hasSeenWelcome = ref.read(welcomeStateProvider);
      final hasSeenOnboarding = ref.read(hasSeenOnboardingProvider);

      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register' || loc == '/onboarding';

      if (authState.isLoading) {
        // Pendant le chargement, ne pas rester sur une page protégée
        if (!isAuthRoute) return hasSeenOnboarding ? '/login' : '/onboarding';
        return null;
      }

      final isGoingToOnboarding = state.matchedLocation == '/onboarding';
      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToRegister = state.matchedLocation == '/register';
      final isGoingToWelcome = state.matchedLocation == '/welcome';

      if (!hasSeenOnboarding) {
        if (!isGoingToOnboarding && !isGoingToLogin && !isGoingToRegister) return '/onboarding';
        return null;
      }

      final isAuthenticated = authState.valueOrNull ?? false;

      if (!isAuthenticated) {
        if (!isGoingToLogin && !isGoingToRegister && !isGoingToOnboarding) {
          return '/login';
        }
      } else {
        if (!hasSeenWelcome) {
          if (!isGoingToWelcome) {
            return '/welcome';
          }
          return null;
        }

        // Nouveau compte : la suggestion de culture passe avant tout le reste
        final pendingCropSetup = ref.read(pendingCropSetupProvider);
        if (pendingCropSetup) return loc == '/crop-setup' ? null : '/crop-setup';
        if (loc == '/crop-setup') return '/';

        if (isGoingToLogin || isGoingToRegister || isGoingToOnboarding || isGoingToWelcome) {
          return '/';
        }
      }

      return null;
    },
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          GoRoute(path: '/agriculture', builder: (context, state) => const CulturesScreen()),
          GoRoute(path: '/markets', builder: (context, state) => const MarketsScreen()),
          GoRoute(path: '/ai', builder: (context, state) => const AssistantScreen()),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/onboarding',
        builder: (context, state) => const AuthStyle(child: OnboardingScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/login',
        builder: (context, state) => const AuthStyle(child: LoginScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/register',
        builder: (context, state) => const AuthStyle(child: RegisterScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/welcome',
        builder: (context, state) => const AuthStyle(child: WelcomeLoadingScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/crop-setup',
        builder: (context, state) => const CropSetupScreen(),
      ),
      // Cultures : les chemins fixes passent avant « :id ».
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/agriculture/add',
        builder: (context, state) => AddCropScreen(initialGuideSlug: state.extra is String ? state.extra as String : null),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/agriculture/culture',
        builder: (context, state) {
          final product = state.extra;
          return product is Product ? CultureFicheScreen(product: product) : const CulturesScreen();
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/agriculture/guides',
        builder: (context, state) => const GuidesListScreen(),
        routes: [
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: ':slug',
            builder: (context, state) => GuideDetailScreen(slug: state.pathParameters['slug'] ?? ''),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/agriculture/:id',
        builder: (context, state) => _CropById(cropId: state.pathParameters['id'] ?? ''),
      ),
      // Ouverture directe avec l'objet culture (depuis la liste).
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/crop_detail',
        builder: (context, state) {
          final crop = state.extra;
          return crop is Crop ? CropDetailScreen(crop: crop) : const CulturesScreen();
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/sell',
        builder: (context, state) {
          final extra = state.extra;
          return SellScreen(stockId: extra is Map ? extra['stockId'] as String? : null);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/stock',
        builder: (context, state) => const StockScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/inventory',
        builder: (context, state) => const StockScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/finances',
        builder: (context, state) {
          final extra = state.extra;
          return FinancesScreen(openAdd: extra is Map ? extra['add'] as String? : null);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/performances',
        builder: (context, state) => const FinancesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/product_detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ProductDetailScreen(
            productName: extra['productName'] as String? ?? '',
            imageAsset: extra['imageAsset'] as String? ?? '',
            price: extra['price'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/market_comparison',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return MarketComparisonScreen(
            productName: extra['productName'] as String? ?? '',
            imageAsset: extra['imageAsset'] as String? ?? '',
            price: extra['price'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/price-analysis',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return PriceAnalysisScreen(
            productName: extra['product'] as String? ?? 'Inconnu',
            currentPrice: (extra['price'] as num?)?.toDouble() ?? 0.0,
            initialStock: (extra['stock'] as num?)?.toDouble() ?? 0.0,
          );
        },
      ),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: '/calendar', builder: (context, state) => const CalendarScreen()),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: '/mon_dashboard', builder: (context, state) => const MonDashboardScreen()),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: '/weather', builder: (context, state) => const WeatherScreen()),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/map',
        builder: (context, state) {
          final extra = state.extra;
          return MapScreen(initialMarket: extra is Market ? extra : null);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/market-detail',
        builder: (context, state) {
          final extra = state.extra;
          return extra is Market
              ? MarketDetailScreen(market: extra)
              : const Scaffold(body: Center(child: Text('Marché introuvable.')));
        },
      ),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: '/price-alerts', builder: (context, state) => const PriceAlertsScreen()),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: '/edit-profile', builder: (context, state) => const EditProfileScreen()),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: '/settings-notifications', builder: (context, state) => const SettingsNotificationsScreen()),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: '/settings-language', builder: (context, state) => const SettingsLanguageScreen()),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: '/settings-security', builder: (context, state) => const SettingsSecurityScreen()),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: '/settings-support', builder: (context, state) => const SettingsSupportScreen()),
    ],
  );
});


/// Fiche d'une culture ouverte par son identifiant (liens venant d'autres écrans).
class _CropById extends ConsumerWidget {
  const _CropById({required this.cropId});

  final String cropId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crops = ref.watch(cropsProvider);
    return crops.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: const Center(child: Text('Impossible de charger cette culture.'))),
      data: (list) {
        final matches = list.where((c) => c.id == cropId);
        if (matches.isEmpty) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Culture introuvable.')));
        }
        return CropDetailScreen(crop: matches.first);
      },
    );
  }
}
