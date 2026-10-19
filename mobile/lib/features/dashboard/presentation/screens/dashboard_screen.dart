import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
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
      backgroundColor: AppColors.background,
      body: dashboardAsync.when(
        data: (data) => FadeTransition(
          opacity: _fadeAnimation,
          child: _buildContent(context, data),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardDataProvider);
        await ref.read(profileNotifierProvider.notifier).loadProfile();
      },
      color: AppColors.primary,
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
                  _buildHeader(location, data.alerts.length),
                  const SizedBox(height: 24),
                  Text(
                    firstName.isEmpty ? 'Bonjour' : 'Bonjour, $firstName',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildWeatherCard(data.weather),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Actions Rapides', domainColor: AppColors.primary),
                  const SizedBox(height: 16),
                  _buildQuickActions(context),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Aujourd\'hui', domainColor: AppColors.domainCultures),
                  const SizedBox(height: 16),
                  _buildTodayTasks(data.calendarEvents),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Conseils Naatal IA', badgeText: 'POUR VOUS', domainColor: AppColors.domainIa),
                  const SizedBox(height: 16),
                  AdviceCarousel(
                    tips: buildAdvice(
                      crops: ref.watch(cropsProvider).valueOrNull ?? const [],
                      stock: data.stockItems,
                      finances: ref.watch(financialSummaryProvider).valueOrNull,
                      prices: data.markets,
                      weather: data.weather,
                      alerts: data.alerts,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                    'Prix du Marché',
                    actionLabel: 'Tous les prix >',
                    onActionTap: () => context.go('/markets'),
                    domainColor: AppColors.domainMarches,
                  ),
                  const SizedBox(height: 16),
                  MarketPricesSection(markets: data.markets, stocks: data.stockItems),
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                    'Produits en Vedette',
                    actionLabel: 'Voir >',
                    onActionTap: () => context.go('/agriculture'),
                    domainColor: AppColors.domainCultures,
                  ),
                  const SizedBox(height: 16),
                  _buildFeaturedProducts(data.featuredProducts),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Calendrier Agricole', badgeText: _currentMonthLabel(), domainColor: AppColors.domainCultures),
                  const SizedBox(height: 16),
                  _buildAgriculturalCalendar(data.calendarEvents),
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                    'Mon Dashboard',
                    domainColor: AppColors.domainFinances,
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
            const CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey,
              backgroundImage: AssetImage('assets/images/naatal_agro_logo-removebg-preview.png'), // Placeholder
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Naatal Agro',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recherche globale bientôt disponible')),
                );
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.search, color: AppColors.textPrimary, size: 20),
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
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 20),
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

  // ─────────────────────────────────────────────
  // WEATHER CARD
  // ─────────────────────────────────────────────
  String _weatherDateLabel(WeatherSummary w) {
    final d = w.date;
    if (d == null) return 'RELEVÉ';
    final days = DateTime.now().difference(d).inDays;
    final label = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return days >= 2 ? 'RELEVÉ ANCIEN · $label' : 'RELEVÉ DU $label';
  }

  Widget _buildWeatherCard(WeatherSummary weather) {
    if (!weather.isAvailable) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(gradient: AppColors.weatherGradient, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 28),
            const SizedBox(height: 12),
            const Text('Météo non disponible', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Aucun relevé météo pour votre région. Vérifiez la région de votre profil.', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, height: 1.4)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/profile'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary, minimumSize: const Size(150, 44)),
              child: const Text('Modifier ma région', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/ui/ui_meteo.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: const BoxDecoration(gradient: AppColors.weatherGradient),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0284C7).withValues(alpha: 0.88),
                      const Color(0xFF0369A1).withValues(alpha: 0.82),
                      const Color(0xFF0F1A14).withValues(alpha: 0.90),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            weather.location,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded, color: Colors.white, size: 11),
                            const SizedBox(width: 4),
                            Text(_weatherDateLabel(weather), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${weather.temp.toInt()}°C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Text(
                            weather.rainfall > 0
                                ? 'Pluie : ${weather.rainfall.toStringAsFixed(1)} mm'
                                : 'Aucune pluie relevée',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _showWeatherDetails(context, weather),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0284C7),
                      minimumSize: const Size(150, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Voir les détails', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeatherDetails(BuildContext context, WeatherSummary weather) {
    showNaatalSheet<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bulletin météo', style: T.title(color: ctx.c.ink)),
                    const SizedBox(height: 2),
                    Text(weather.location, style: T.caption(color: ctx.c.ink2, weight: 600)),
                  ],
                ),
                Text('${weather.temp.toInt()}°C', style: T.largeTitle(color: ctx.c.accent)),
              ],
            ),
            const SizedBox(height: Space.xl),
            Row(
              children: [
                _buildWeatherStat(Icons.water_drop_outlined, 'Humidité', '${weather.humidity.toInt()}%', const Color(0xFF0284C7)),
                const SizedBox(width: Space.m),
                _buildWeatherStat(Icons.cloud_outlined, 'Précipitations', '${weather.rainfall.toStringAsFixed(1)} mm', const Color(0xFF3A5670)),
              ],
            ),
            if (weather.rainfall > 5 || weather.temp >= 32) ...[
              const SizedBox(height: Space.l),
              Container(
                padding: const EdgeInsets.all(Space.m),
                decoration: BoxDecoration(
                  color: ctx.c.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Radii.m),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded, color: ctx.c.accent),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Text(
                        weather.rainfall > 5
                            ? 'Fortes pluies : reportez les pulvérisations pour éviter le lessivage des intrants.'
                            : 'Forte chaleur : irriguez de préférence tôt le matin ou après 17h.',
                        style: T.caption(color: ctx.c.ink, weight: 600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherStat(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.m, horizontal: Space.s),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(Radii.m),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
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
                domainColor: AppColors.domainMarches,
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
                domainColor: AppColors.domainCultures,
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
                domainColor: AppColors.domainStock,
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
                domainColor: AppColors.domainFinances,
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
                domainColor: AppColors.domainMarches,
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
                domainColor: AppColors.domainIa,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: const Text(
          'Aucune activité planifiée. Ajoutez une culture pour alimenter votre calendrier agricole.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
      );
    }
    final event = events.first;
    final eventMonth = event.date.contains('\n') ? event.date.split('\n').last : '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  color: Colors.white,
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
                      child: Text(event.date.split('\n').first, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
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
                          child: Text(event.phase, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                        ),
                        const Icon(Icons.more_horiz, color: Colors.grey, size: 20),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text(event.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
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
                  const Text('Progression', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('75%', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.75,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
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
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Voir calendrier', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
          color: Colors.white,
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
                color: Colors.white,
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
                              Text(product.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              Text(product.variety, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
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
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
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
                  color: domainColor ?? AppColors.primary,
                ),
              ),
            ),
          ),
        if (badgeText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
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
          color: Colors.white,
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
      color = AppColors.primary;
    } else if (lowerTitle.contains('récolte') || lowerTitle.contains('recolte')) {
      icon = Icons.agriculture;
      color = Colors.amber.shade800;
    } else if (lowerTitle.contains('trait') || lowerTitle.contains('fert') || lowerTitle.contains('engrais')) {
      icon = Icons.science;
      color = Colors.purple;
    } else {
      icon = Icons.eco;
      color = AppColors.primary;
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
        color: Colors.white,
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
                color: isCompleted ? Colors.grey.shade300 : color,
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
                              color: isCompleted ? Colors.grey : AppColors.textPrimary,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 12, color: isCompleted ? Colors.grey : AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                time,
                                style: TextStyle(
                                  color: isCompleted ? Colors.grey : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.location_on, size: 12, color: isCompleted ? Colors.grey : AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                location,
                                style: TextStyle(
                                  color: isCompleted ? Colors.grey : AppColors.textSecondary,
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
                      color: isCompleted ? AppColors.primary : Colors.grey.shade300,
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
