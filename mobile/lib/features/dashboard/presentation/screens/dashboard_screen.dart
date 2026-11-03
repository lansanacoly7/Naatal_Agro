import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../calendar/presentation/season_banner.dart';
import '../../../weather/presentation/widgets/weather_widgets.dart';
import '../../../../ui/ui.dart';
import '../../data/dashboard_provider.dart';
import '../widgets/advice_carousel.dart';
import '../widgets/my_dashboard_section.dart';
import '../widgets/market_prices_section.dart';
import '../../../agriculture/data/agriculture_provider.dart';
import '../../../agriculture/data/guides_provider.dart';
import '../../../agriculture/presentation/screens/cultures_screen.dart' show guideForProduct;
import '../../../finances/data/finances_provider.dart';
import '../../../markets/data/markets_provider.dart';
import '../../../markets/data/models/product.dart';
import '../../data/models/dashboard_data.dart';
import 'package:go_router/go_router.dart';
import '../../../profile/data/profile_provider.dart';
import '../../../profile/data/notifications_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return Scaffold(
      backgroundColor: context.c.bg,
      body: dashboardAsync.when(
        data: (data) => FadeTransition(
          opacity: _fadeAnimation,
          child: _buildContent(context, data),
        ),
        loading: () => Center(
          child: CircularProgressIndicator(color: context.c.accent),
        ),
        error: (error, stack) => _buildErrorState(error),
      ),
    );
  }

  Widget _buildContent(BuildContext context, DashboardData data) {
    // Identité de l'utilisateur connecté : la même source que l'écran Profil
    final profile = ref.watch(profileNotifierProvider).valueOrNull;
    final firstName = (profile?.fullName.trim().split(RegExp(r'\s+')).first) ?? '';
    final location = (profile?.location.trim().isNotEmpty ?? false) ? profile!.location.trim() : 'Sénégal';

    final unreadAlerts = ref.watch(unreadNotificationsCountProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardDataProvider);
        ref.read(notificationsProvider.notifier).fetchNotifications();
        await ref.read(profileNotifierProvider.notifier).loadProfile();
      },
      color: context.c.accent,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(location, unreadAlerts),
                  const SizedBox(height: 24),
                  Text(
                    firstName.isEmpty ? 'Bonjour' : 'Bonjour, $firstName',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: context.c.ink,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const LiveWeatherCard(),
                  const SeasonBanner(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Actions Rapides', domainColor: context.c.accent),
                  const SizedBox(height: 16),
                  _buildQuickActions(context),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Aujourd\'hui', domainColor: context.c.domainCultures),
                  const SizedBox(height: 16),
                  _buildTodayTasks(data.calendarEvents),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Conseils Naatal IA', badgeText: 'POUR VOUS', domainColor: context.c.domainIa),
                  const SizedBox(height: 16),
                  AdviceCarousel(
                    tips: buildAdvice(
                      crops: ref.watch(cropsProvider).valueOrNull ?? const [],
                      stock: data.stockItems,
                      finances: ref.watch(financialSummaryProvider).valueOrNull,
                      prices: data.markets,
                      weather: ref.watch(liveWeatherSummaryProvider),
                      alerts: data.alerts,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                    'Prix du Marché',
                    actionLabel: 'Tous les prix >',
                    onActionTap: () => context.go('/markets'),
                    domainColor: context.c.domainMarches,
                  ),
                  const SizedBox(height: 16),
                  MarketPricesSection(markets: data.markets, stocks: data.stockItems),
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                    'Produits en Vedette',
                    actionLabel: 'Voir >',
                    onActionTap: () => context.go('/agriculture'),
                    domainColor: context.c.domainCultures,
                  ),
                  const SizedBox(height: 16),
                  _buildFeaturedProducts(data.featuredProducts),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Calendrier Agricole', badgeText: _currentMonthLabel(), domainColor: context.c.domainCultures),
                  const SizedBox(height: 16),
                  _buildAgriculturalCalendar(data.calendarEvents),
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                    'Mon Dashboard',
                    domainColor: context.c.domainFinances,
                  ),
                  const SizedBox(height: 16),
                  MyDashboardSection(stock: data.stockItems, prices: data.markets),
                  const SizedBox(height: 120), // Bottom navigation padding
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  // ─────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────
  Widget _buildHeader(String location, int unreadAlertsCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _buildProfileButton(),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Naatal Agro',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: context.c.ink,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: context.c.accent),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: TextStyle(
                        color: context.c.ink2,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                context.push('/map');
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.c.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(Icons.map_outlined, color: context.c.accent, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                context.push('/notifications');
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.c.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Icon(Icons.notifications_outlined, color: context.c.ink, size: 20),
                  ),
                  if (unreadAlertsCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          unreadAlertsCount > 9 ? '9+' : '$unreadAlertsCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Le profil s'ouvre depuis ce bouton, en haut à gauche de l'accueil, à la place du logo (il n'est plus dans la barre du bas).
  Widget _buildProfileButton() {
    final initials = ref.watch(profileNotifierProvider).valueOrNull?.initials;
    return Semantics(
      button: true,
      label: 'Mon profil',
      child: GestureDetector(
        onTap: () => context.push('/profile'),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Color(0xFFE9B949), Color(0xFFF08A6A)]),
          ),
          child: initials == null || initials.isEmpty
              ? const Icon(Icons.person_rounded, color: Color(0xFF2B1700), size: 22)
              : Text(initials, style: const TextStyle(color: Color(0xFF2B1700), fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // QUICK ACTIONS (Refonte Images d'Abord : 6 tuiles photo)
  // ─────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: PhotoTile(
                imageAsset: 'assets/images/ui/ui_vendre.jpg',
                label: 'Vendre',
                icon: Icons.point_of_sale_rounded,
                domainColor: context.c.domainMarches,
                height: 125,
                onTap: () => context.push('/sell'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PhotoTile(
                imageAsset: 'assets/images/ui/ui_recolter.jpg',
                label: 'Récolter',
                icon: Icons.agriculture_rounded,
                domainColor: context.c.domainCultures,
                height: 125,
                onTap: () => context.go('/agriculture'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PhotoTile(
                imageAsset: 'assets/images/ui/ui_stock.jpg',
                label: 'Stock',
                icon: Icons.inventory_2_rounded,
                domainColor: context.c.domainStock,
                height: 125,
                onTap: () => context.push('/stock'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PhotoTile(
                imageAsset: 'assets/images/ui/ui_depenses.jpg',
                label: 'Dépenses',
                icon: Icons.account_balance_wallet_rounded,
                domainColor: context.c.domainFinances,
                height: 125,
                onTap: () => context.push('/finances'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PhotoTile(
                imageAsset: 'assets/images/ui/ui_marches.jpg',
                label: 'Marchés',
                icon: Icons.storefront_rounded,
                domainColor: context.c.domainMarches,
                height: 125,
                onTap: () => context.go('/markets'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PhotoTile(
                imageAsset: 'assets/images/ui/ui_ia.jpg',
                label: 'Aide IA',
                icon: Icons.auto_awesome_rounded,
                domainColor: context.c.domainIa,
                height: 125,
                onTap: () => context.go('/ai'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // L'ancienne méthode _buildMarketPrices a été remplacée par le widget MarketPricesSection


  // ─────────────────────────────────────────────
  // AGRICULTURAL CALENDAR
  // ─────────────────────────────────────────────
  /// Mois courant en français, ex. « OCTOBRE 2026 » (évite d'initialiser les locales intl).
  String _currentMonthLabel() {
    const months = [
      'JANVIER', 'FÉVRIER', 'MARS', 'AVRIL', 'MAI', 'JUIN',
      'JUILLET', 'AOÛT', 'SEPTEMBRE', 'OCTOBRE', 'NOVEMBRE', 'DÉCEMBRE',
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }

  Widget _buildAgriculturalCalendar(List<CalendarEvent> events) {
    if (events.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Text(
          'Aucune activité planifiée. Ajoutez une culture pour alimenter votre calendrier agricole.',
          style: TextStyle(color: context.c.ink2, fontSize: 13, height: 1.4),
        ),
      );
    }
    final event = events.first;
    final eventMonth = event.date.contains('\n') ? event.date.split('\n').last : '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Box (Calendar style)
              Container(
                width: 70,
                decoration: BoxDecoration(
                  color: context.c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Text(eventMonth, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(event.date.split('\n').first, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: context.c.ink)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Event Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(event.phase, style: TextStyle(color: context.c.accent, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                        ),
                        const Icon(Icons.more_horiz, color: Colors.grey, size: 20),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(event.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.c.ink)),
                    const SizedBox(height: 6),
                    Text(event.description, style: TextStyle(color: context.c.ink2, fontSize: 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progression', style: TextStyle(color: context.c.ink2, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('75%', style: TextStyle(color: context.c.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.75,
                  backgroundColor: context.c.line,
                  valueColor: AlwaysStoppedAnimation<Color>(context.c.accent),
                  minHeight: 6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: context.c.line),
          const SizedBox(height: 16),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/calendar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(0, 48),
                    side: BorderSide(color: context.c.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Voir calendrier', style: TextStyle(color: context.c.ink, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Activité "${event.title}" marquée comme terminée.'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(0, 48),
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Terminer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FEATURED PRODUCTS
  // ─────────────────────────────────────────────
  Widget _buildFeaturedProducts(List<FeaturedProduct> products) {
    if (products.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: context.c.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: EmptyState(
          imageAsset: 'assets/images/ui/ui_marches.jpg',
          title: 'Produits agricoles',
          message: 'Consultez les fiches techniques des cultures du Sénégal.',
          actionLabel: 'Explorer les cultures',
          onAction: () => context.go('/agriculture'),
          compact: true,
        ),
      );
    }
    final guides = ref.watch(guidesNotifierProvider).guides;
    final allProducts = ref.watch(allProductsProvider).valueOrNull ?? const <Product>[];

    return SizedBox(
      height: 285,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final guide = guideForProduct(product.name, guides);
          final effectiveCycle = guide?.cycleDisplay ?? (product.cycle.isNotEmpty ? product.cycle : '');

          // Retrouve le produit du catalogue officiel pour ouvrir sa fiche technique complète
          final matchedProduct = allProducts.firstWhere(
            (p) => p.name.trim().toLowerCase() == product.name.trim().toLowerCase(),
            orElse: () => Product(
              id: product.name,
              name: product.name,
              category: product.variety,
              currentPrice: double.tryParse(product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0,
              trendPercentage: 0.0,
              imageAsset: product.imageAsset,
              isTrending: true,
            ),
          );

          // Génération d'une couleur pastel douce basée sur l'index
          final bgColors = [const Color(0xFFFDECEA), const Color(0xFFE8F5E9), const Color(0xFFFFF3E0)];
          final bgColor = bgColors[index % bgColors.length];

          return GestureDetector(
            onTap: () => context.push('/agriculture/culture', extra: matchedProduct),
            child: Container(
              width: 215,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: context.c.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Stack(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            child: Image.asset(
                              product.imageAsset,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: bgColor,
                                child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: context.c.ink)),
                              const SizedBox(height: 4),
                              Text(product.variety, style: TextStyle(color: context.c.ink2, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Divider(height: 1, color: context.c.line),
                          if (product.price.isNotEmpty || effectiveCycle.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (product.price.isNotEmpty)
                                  _buildProductInfoItem(Icons.payments_outlined, product.price)
                                else
                                  const SizedBox.shrink(),
                                if (effectiveCycle.isNotEmpty)
                                  _buildProductInfoItem(Icons.timer_outlined, effectiveCycle)
                                else
                                  const SizedBox.shrink(),
                              ],
                            ),
                          if (product.profitability.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.trending_up, size: 14, color: AppColors.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  'Rentabilité : ${product.profitability}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: context.c.accent),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: context.c.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    String title, {
    String? actionLabel,
    String? badgeText,
    VoidCallback? onActionTap,
    Color? domainColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (domainColor != null) ...[
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: domainColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.c.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onActionTap,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                actionLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: domainColor ?? context.c.accent,
                ),
              ),
            ),
          ),
        if (badgeText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.c.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.c.ink2,
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // AUJOURD'HUI (Tâches du jour)
  // ─────────────────────────────────────────────
  Widget _buildTodayTasks(List<CalendarEvent> events) {
    if (events.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: context.c.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: EmptyState(
          imageAsset: 'assets/images/ui/ui_cultures.jpg',
          title: 'Aucune tâche urgente',
          message: 'Vos parcelles sont à jour.',
          actionLabel: 'Calendrier agricole',
          onAction: () => context.push('/calendar'),
          compact: true,
        ),
      );
    }

    final displayEvents = events.take(3).toList();
    return Column(
      children: [
        for (int i = 0; i < displayEvents.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildTaskItemFromEvent(displayEvents[i]),
        ],
      ],
    );
  }

  Widget _buildTaskItemFromEvent(CalendarEvent event) {
    final lowerTitle = event.title.toLowerCase();
    final IconData icon;
    final Color color;

    if (lowerTitle.contains('irrig') || lowerTitle.contains('arros')) {
      icon = Icons.water_drop;
      color = Colors.blueAccent;
    } else if (lowerTitle.contains('semis') || lowerTitle.contains('plant')) {
      icon = Icons.grass;
      color = context.c.accent;
    } else if (lowerTitle.contains('récolte') || lowerTitle.contains('recolte')) {
      icon = Icons.agriculture;
      color = Colors.amber.shade800;
    } else if (lowerTitle.contains('trait') || lowerTitle.contains('fert') || lowerTitle.contains('engrais')) {
      icon = Icons.science;
      color = Colors.purple;
    } else {
      icon = Icons.eco;
      color = context.c.accent;
    }

    final dateDisplay = event.date.replaceAll('\n', ' ').trim();
    final timeOrDate = dateDisplay.isNotEmpty ? dateDisplay : 'Planifiée';
    final location = event.phase.isNotEmpty ? event.phase : 'Parcelle';

    return _buildPremiumTaskItem(
      title: event.title,
      time: timeOrDate,
      location: location,
      icon: icon,
      color: color,
      isCompleted: event.isCompleted,
    );
  }

  Widget _buildPremiumTaskItem({
    required String title,
    required String time,
    required String location,
    required IconData icon,
    required Color color,
    required bool isCompleted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre de couleur latérale
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: isCompleted ? context.c.line : color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.grey.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        color: isCompleted ? Colors.grey : color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isCompleted ? Colors.grey : context.c.ink,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 12, color: isCompleted ? Colors.grey : context.c.ink2),
                              const SizedBox(width: 4),
                              Text(
                                time,
                                style: TextStyle(
                                  color: isCompleted ? Colors.grey : context.c.ink2,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.location_on, size: 12, color: isCompleted ? Colors.grey : context.c.ink2),
                              const SizedBox(width: 4),
                              Text(
                                location,
                                style: TextStyle(
                                  color: isCompleted ? Colors.grey : context.c.ink2,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isCompleted ? context.c.accent : context.c.line,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ERROR STATE
  // ─────────────────────────────────────────────
  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(error.toString()),
          ElevatedButton(
            onPressed: () => ref.invalidate(dashboardDataProvider),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
