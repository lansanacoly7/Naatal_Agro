import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../../features/auth/data/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/welcome_loading_screen.dart';

import '../../features/inventory/presentation/screens/inventory_management_screen.dart';
import '../../features/finances/presentation/screens/financial_performance_screen.dart';

import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/mon_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/price_analysis_screen.dart';
import '../../features/dashboard/presentation/screens/calendar_screen.dart';
import '../../features/agriculture/presentation/screens/crops_list_screen.dart';
import '../../features/agriculture/presentation/screens/add_crop_screen.dart';

import '../../features/agriculture/data/models/crop.dart';
import '../../features/agriculture/presentation/screens/crop_detail_screen.dart';
import '../../features/ai/presentation/screens/ai_chat_screen.dart';
import '../../features/markets/presentation/screens/markets_screen.dart';
import '../../features/markets/presentation/screens/b2b_marketplace_screen.dart';
import '../../features/markets/presentation/screens/product_detail_screen.dart';
import '../../features/markets/presentation/screens/market_comparison_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

/// Shell avec Bottom Navigation Bar premium — Navigation principale
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/agriculture')) return 1;
    if (location.startsWith('/markets')) return 2;
    if (location.startsWith('/ai')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0; // Dashboard
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/agriculture');
        break;
      case 2:
        context.go('/markets');
        break;
      case 3:
        context.go('/ai');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => _onItemTapped(index, context),
          backgroundColor: Colors.white,
          indicatorColor: AppColors.primary.withOpacity(0.12),
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.primary),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.eco_outlined),
              selectedIcon: Icon(Icons.eco_rounded, color: AppColors.primary),
              label: 'Mes Cultures',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront_rounded, color: AppColors.primary),
              label: 'Marchés',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
              label: 'Naatal IA',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

/// Shell pour le Profil Acheteur / B2B Trader
class BuyerShell extends StatelessWidget {
  final Widget child;

  const BuyerShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/buyer_profile')) return 1;
    return 0; // B2B Marketplace Home
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/buyer_home');
        break;
      case 1:
        context.go('/buyer_profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => _onItemTapped(index, context),
          backgroundColor: Colors.white,
          indicatorColor: AppColors.primary.withOpacity(0.12),
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront_rounded, color: AppColors.primary),
              label: 'Marketplace B2B',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
              label: 'Mon Profil',
            ),
          ],
        ),
      ),
    );
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'farmerShell');
final _buyerShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'buyerShell');

final hasSeenOnboardingProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('has_seen_onboarding') ?? false;
});

final welcomeStateProvider = StateProvider<bool>((ref) => false);
final roleStateProvider = StateProvider<String>((ref) => 'farmer');

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<bool>>(
      authStateProvider,
      (previous, next) async {
        if (previous?.value != next.value) {
          _ref.read(welcomeStateProvider.notifier).state = false;
          if (next.value == true) {
            final role = await _ref.read(apiClientProvider).getUserRole();
            _ref.read(roleStateProvider.notifier).state = role;
          }
        }
        notifyListeners();
      },
    );
    _ref.listen<bool>(hasSeenOnboardingProvider, (previous, next) => notifyListeners());
    _ref.listen<bool>(welcomeStateProvider, (previous, next) => notifyListeners());
    _ref.listen<String>(roleStateProvider, (previous, next) => notifyListeners());
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
      final role = ref.read(roleStateProvider);

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
          return role == 'buyer' ? '/buyer_home' : '/';
        }

        if (role == 'buyer' && (state.matchedLocation == '/' || state.matchedLocation.startsWith('/agriculture'))) {
          return '/buyer_home';
        }
        if (role == 'farmer' && state.matchedLocation.startsWith('/buyer_home')) {
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
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/agriculture',
            builder: (context, state) => const CropsListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const AddCropScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/markets',
            builder: (context, state) => const MarketsScreen(),
          ),
          GoRoute(
            path: '/ai',
            builder: (context, state) => const AiChatScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      ShellRoute(
        navigatorKey: _buyerShellNavigatorKey,
        builder: (context, state, child) => BuyerShell(child: child),
        routes: [
          GoRoute(
            path: '/buyer_home',
            builder: (context, state) => const B2BMarketplaceScreen(),
          ),
          GoRoute(
            path: '/buyer_profile',
            builder: (context, state) => const ProfileScreen(),
          ),
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
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/inventory',
        builder: (context, state) => const InventoryManagementScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/performances',
        builder: (context, state) => const FinancialPerformanceScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/product_detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ProductDetailScreen(
            productName: extra['productName'] as String? ?? 'Oignon Local',
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
            productName: extra['productName'] as String? ?? 'Oignon Local',
            imageAsset: extra['imageAsset'] as String? ?? '',
            price: extra['price'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/crop_detail',
        builder: (context, state) {
          final crop = state.extra as Crop;
          return CropDetailScreen(crop: crop);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/mon_dashboard',
        builder: (context, state) => const MonDashboardScreen(),
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
    ],
  );
});
