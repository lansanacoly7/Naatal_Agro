import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../../features/auth/data/auth_provider.dart';

import '../../features/agriculture/data/models/crop.dart';
import '../../features/markets/presentation/screens/product_detail_screen.dart';
import '../../features/markets/presentation/screens/market_comparison_screen.dart';
import '../../features/profile/presentation/screens/price_alerts_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/settings_notifications_screen.dart';
import '../../features/profile/presentation/screens/settings_language_screen.dart';
import '../../features/profile/presentation/screens/settings_security_screen.dart';
import '../../features/profile/presentation/screens/settings_support_screen.dart';

import '../../screens/crops/add_crop_screen.dart';
import '../../screens/crops/crop_detail_screen.dart';
import '../../screens/crops/crops_screen.dart';
import '../../screens/assistant/assistant_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/onboarding_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/welcome_screen.dart';
import '../../features/weather/presentation/screens/weather_screen.dart';
import '../../screens/finances/finances_screen.dart';
import '../../screens/guides/guides_screens.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/markets/markets_screen.dart';
import '../../screens/sell/sell_screen.dart';
import '../../screens/shell/main_shell.dart';
import '../../screens/stock/stock_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'farmerShell');

final hasSeenOnboardingProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('has_seen_onboarding') ?? false;
});

final welcomeStateProvider = StateProvider<bool>((ref) => false);

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
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/agriculture', builder: (context, state) => const CropsScreen()),
          GoRoute(path: '/markets', builder: (context, state) => const MarketsScreen()),
          GoRoute(path: '/ai', builder: (context, state) => const AssistantScreen()),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/welcome',
        builder: (context, state) => const WelcomeLoadingScreen(),
      ),
      // Cultures : les chemins fixes passent avant « :id ».
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/agriculture/add',
        builder: (context, state) => const AddCropScreen(),
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
        builder: (context, state) => CropDetailScreen(cropId: state.pathParameters['id'] ?? ''),
      ),
      // Ancien chemin encore utilisé par d'anciens écrans : renvoie vers la fiche.
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/crop_detail',
        redirect: (context, state) {
          final crop = state.extra;
          return crop is Crop ? '/agriculture/${crop.id}' : '/agriculture';
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
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: '/weather', builder: (context, state) => const WeatherScreen()),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: '/profile', builder: (context, state) => const ProfileScreen()),
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
