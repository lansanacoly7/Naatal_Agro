import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/welcome_loading_screen.dart';

import '../../features/inventory/presentation/screens/inventory_management_screen.dart';
import '../../features/finances/presentation/screens/financial_performance_screen.dart';

import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/agriculture/presentation/screens/crops_list_screen.dart';
import '../../features/agriculture/presentation/screens/add_crop_screen.dart';

import '../../features/ai/presentation/screens/ai_chat_screen.dart';
import '../../features/markets/presentation/screens/markets_screen.dart';
import '../../features/markets/presentation/screens/b2b_marketplace_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

/// Shell avec Bottom Navigation Bar premium — Navigation principale
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/agriculture')) return 1;
    if (location.startsWith('/markets')) return 2;
    if (location.startsWith('/ai')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    return Scaffold(
      extendBody: true, // Le contenu défile sous la barre de navigation
      body: child,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Accueil', index: 0, currentIndex: currentIndex, onTap: () => context.go('/')),
              _NavItem(icon: Icons.grass_outlined, activeIcon: Icons.grass_rounded, label: 'Cultures', index: 1, currentIndex: currentIndex, onTap: () => context.go('/agriculture')),
              _NavItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'Marchés', index: 2, currentIndex: currentIndex, onTap: () => context.go('/markets')),
              _NavItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome, label: 'IA', index: 3, currentIndex: currentIndex, onTap: () => context.go('/ai')),
              _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profil', index: 4, currentIndex: currentIndex, onTap: () => context.go('/profile')),
            ],
          ),
        ),
      ),
    );
  }
}

class BuyerShell extends StatelessWidget {
  final Widget child;

  const BuyerShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/buyer_profile')) return 1;
    return 0; // Default to Bourse
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'Bourse B2B', index: 0, currentIndex: currentIndex, onTap: () => context.go('/buyer_home')),
              _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profil', index: 1, currentIndex: currentIndex, onTap: () => context.go('/buyer_profile')),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 26,
              color: isSelected ? AppColors.primary : const Color(0xFF8E8E93),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : const Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Provider pour savoir si l'utilisateur a vu l'écran de chargement de bienvenue
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
          // Load role when auth changes
          final role = await _ref.read(apiClientProvider).getUserRole();
          _ref.read(roleStateProvider.notifier).state = role;
        }
        notifyListeners();
      },
    );
    _ref.listen<bool>(welcomeStateProvider, (previous, next) => notifyListeners());
    _ref.listen<String>(roleStateProvider, (previous, next) => notifyListeners());
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);
  final role = ref.watch(roleStateProvider);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/',
    redirect: (context, state) async {
      final authState = ref.read(authStateProvider);
      final hasSeenWelcome = ref.read(welcomeStateProvider);
      
      if (authState.isLoading) return null;

      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

      final isGoingToOnboarding = state.uri.toString() == '/onboarding';
      final isGoingToLogin = state.uri.toString() == '/login';
      final isGoingToRegister = state.uri.toString() == '/register';
      final isGoingToWelcome = state.uri.toString() == '/welcome';

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

        // Prevent buyer from accessing farmer routes and vice versa
        if (role == 'buyer' && (state.uri.toString() == '/' || state.uri.toString().startsWith('/agriculture'))) {
          return '/buyer_home';
        }
        if (role == 'farmer' && state.uri.toString().startsWith('/buyer_home')) {
          return '/';
        }
      }

      return null;
    },
    routes: [
      ShellRoute(
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
      // Routes hors navigation (onboarding, login, register)
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeLoadingScreen(),
      ),
      GoRoute(
        path: '/inventory',
        builder: (context, state) => const InventoryManagementScreen(),
      ),
      GoRoute(
        path: '/performances',
        builder: (context, state) => const FinancialPerformanceScreen(),
      ),
    ],
  );
});
