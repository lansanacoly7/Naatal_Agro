import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/markets_provider.dart';
import '../../data/models/price.dart';
import '../../../agriculture/data/guides_provider.dart';
import '../../../agriculture/data/models/agronomic_guide.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productName;
  final String imageAsset;
  final String price;

  const ProductDetailScreen({
    super.key,
    required this.productName,
    this.imageAsset = '',
    this.price = '',
  });

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  double _parsePrice(String priceStr) {
    final cleaned = priceStr.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  String _resolveImageAsset(String name, String providedAsset) {
    if (providedAsset.isNotEmpty && !providedAsset.contains('placeholder')) {
      return providedAsset;
    }
    final lower = name.toLowerCase();
    if (lower.contains('tomate')) return 'assets/images/products/tomate.png';
    if (lower.contains('oignon')) return 'assets/images/products/oignon_local.png';
    if (lower.contains('riz')) return 'assets/images/products/riz.jpg';
    if (lower.contains('mais') || lower.contains('maïs')) return 'assets/images/products/mais.jpg';
    if (lower.contains('arachide')) return 'assets/images/products/arachide.png';
    if (lower.contains('pomme de terre')) return 'assets/images/products/pomme_de_terre.png';
    if (lower.contains('chou')) return 'assets/images/products/chou.png';
    if (lower.contains('mil')) return 'assets/images/products/mil.jpg';
    if (lower.contains('mangue')) return 'assets/images/products/mangue.png';
    return 'assets/images/naatal_agro_logo-removebg-preview.png';
  }

  AgronomicGuide? _findMatchingGuide(List<AgronomicGuide> guides, String name) {
    final lower = name.toLowerCase().trim();
    for (final guide in guides) {
      final gName = guide.name.toLowerCase();
      final gSlug = guide.slug.toLowerCase();
      if (lower.contains(gName) || gName.contains(lower) || lower.contains(gSlug)) {
        return guide;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fallbackPrice = _parsePrice(widget.price);
    final imageAsset = _resolveImageAsset(widget.productName, widget.imageAsset);

    // Données réelles des prix et des fiches agronomiques
    final priceHistoryAsync = ref.watch(productPriceHistoryProvider(widget.productName));
    final guidesState = ref.watch(guidesNotifierProvider);
    final matchingGuide = _findMatchingGuide(guidesState.guides, widget.productName);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: priceHistoryAsync.when(
        data: (prices) {
          // Tri chronologique des relevés de prix
          final sortedPrices = List<Price>.from(prices)
            ..sort((a, b) => a.date.compareTo(b.date));

          final currentPrice = sortedPrices.isNotEmpty
              ? sortedPrices.last.priceValue
              : (fallbackPrice > 0 ? fallbackPrice : 450.0);

          double trendPercentage = 0.0;
          if (sortedPrices.length >= 2) {
            final first = sortedPrices.first.priceValue;
            final last = sortedPrices.last.priceValue;
            if (first > 0) {
              trendPercentage = ((last - first) / first) * 100;
            }
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(
                context,
                widget.productName,
                imageAsset,
                currentPrice,
                trendPercentage,
                matchingGuide?.category ?? 'Culture Vivrière',
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuickActions(currentPrice),
                      const SizedBox(height: 24),
                      _buildNaatalRecommendation(trendPercentage, matchingGuide),
                      const SizedBox(height: 24),
                      _buildDescriptionCard(matchingGuide),
                      const SizedBox(height: 24),
                      _buildPriceTrendChart(sortedPrices, currentPrice),
                      const SizedBox(height: 24),
                      _buildDetailedInfoCard(matchingGuide, sortedPrices),
                      const SizedBox(height: 24),
                      _buildMarketComparison(currentPrice, imageAsset),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                Text('Erreur de chargement : $error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(productPriceHistoryProvider(widget.productName)),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SliverAppBar ---
  Widget _buildSliverAppBar(
    BuildContext context,
    String name,
    String imageAsset,
    double currentPrice,
    double trendPercentage,
    String category,
  ) {
    final isPositive = trendPercentage >= 0;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/markets');
              }
            },
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              imageAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.primaryDark,
                child: const Center(
                  child: Icon(Icons.eco, color: Colors.white54, size: 64),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildGlassChip(
                        isPositive ? '+${trendPercentage.toStringAsFixed(1)} %' : '${trendPercentage.toStringAsFixed(1)} %',
                        isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        isPositive ? Colors.greenAccent : Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                      _buildGlassChip(category, null, Colors.white),
                      const SizedBox(width: 8),
                      _buildGlassChip('Marché certifié', Icons.verified, Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Cours actuel', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(
                            '${currentPrice.toInt()} FCFA/kg',
                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassChip(String label, IconData? icon, Color iconColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor, size: 14),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Quick Actions ---
  Widget _buildQuickActions(double currentPrice) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionButton(Icons.insights, 'Analyse', const Color(0xFF673AB7), () {
          context.push('/price-analysis', extra: {
            'product': widget.productName,
            'price': currentPrice,
          });
        }),
        _buildActionButton(Icons.notifications_active, 'Alerte', Colors.amber.shade700, () => context.push('/price-alerts')),
        _buildActionButton(Icons.inventory_2, 'Stock', Colors.brown.shade400, () => context.push('/inventory')),
        _buildActionButton(Icons.auto_awesome, 'Naatal IA', AppColors.primary, () => context.push('/ai')),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- Recommendation Naatal IA ---
  Widget _buildNaatalRecommendation(double trendPercentage, AgronomicGuide? guide) {
    final isFavorable = trendPercentage >= 0;
    final title = isFavorable ? 'Fenêtre favorable à la commercialisation' : 'Cours en baisse — Stockage recommandé';
    final String advice;

    if (guide != null && guide.harvest.isNotEmpty) {
      advice = 'Tendance du marché : ${trendPercentage.toStringAsFixed(1)}%. Recommandation technique officielle : ${guide.harvest}';
    } else if (isFavorable) {
      advice = 'Le cours de ${widget.productName} progresse (+${trendPercentage.toStringAsFixed(1)}%). Écoulez en priorité vos lots mûrs pour maximiser la marge.';
    } else {
      advice = 'Le cours actuel subit un repli (${trendPercentage.toStringAsFixed(1)}%). Si vous disposez d\'un stockage ventilé, conservez pour attendre la remontée.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF673AB7).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF673AB7).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF673AB7), size: 20),
              SizedBox(width: 8),
              Text('Recommandation Naatal IA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF673AB7))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(isFavorable ? Icons.check_circle : Icons.warning_amber_rounded, color: isFavorable ? Colors.green : Colors.orange, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isFavorable ? Colors.green : Colors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            advice,
            style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  // --- Description ---
  Widget _buildDescriptionCard(AgronomicGuide? guide) {
    final text = (guide != null && guide.summary.isNotEmpty)
        ? guide.summary
        : "Produit agricole suivi sur le réseau des marchés sénégalais. Les cours sont enregistrés en temps réel au kilogramme ou au sac sur les principaux foirails régionaux.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fiche Descriptive', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              if (guide != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Text('ISRA / ANCAR', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
          ),
          if (guide != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.push('/guides/detail', extra: guide.slug),
              child: const Text(
                'Consulter le guide agronomique complet >',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Price Trend Chart Réel ---
  Widget _buildPriceTrendChart(List<Price> prices, double currentPrice) {
    final List<FlSpot> spots = [];
    double minY = currentPrice * 0.9;
    double maxY = currentPrice * 1.1;

    if (prices.isNotEmpty) {
      final values = prices.map((p) => p.priceValue).toList();
      final minVal = values.reduce(math.min);
      final maxVal = values.reduce(math.max);
      minY = (minVal * 0.9).floorToDouble();
      maxY = (maxVal * 1.1).ceilToDouble();
      if (minY == maxY) {
        minY = currentPrice * 0.9;
        maxY = currentPrice * 1.1;
      }

      for (int i = 0; i < prices.length; i++) {
        spots.add(FlSpot(i.toDouble(), prices[i].priceValue));
      }
    } else {
      // Courbe de référence basée sur le cours actuel
      spots.addAll([
        FlSpot(0, currentPrice),
        FlSpot(1, currentPrice),
        FlSpot(2, currentPrice),
      ]);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Évolution des cours réels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                child: Text('${prices.length} relevés', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: (spots.length > 3 ? (spots.length / 3).floorToDouble() : 1),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < prices.length) {
                          final dateParts = prices[idx].date.split('-');
                          if (dateParts.length == 3) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text('${dateParts[2]}/${dateParts[1]}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: math.max(1, (spots.length - 1).toDouble()),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: spots.length <= 10,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(radius: 3, color: AppColors.primary, strokeWidth: 0);
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.25),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Detailed Info ---
  Widget _buildDetailedInfoCard(AgronomicGuide? guide, List<Price> prices) {
    final latestDate = prices.isNotEmpty ? prices.last.date : 'Aujourd\'hui';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Données du Marché', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.calendar_today, 'Dernier relevé', latestDate),
          const Divider(color: Color(0xFFF0F0F0), height: 24),
          _buildInfoRow(Icons.category, 'Catégorie', guide?.category ?? 'Agricole'),
          const Divider(color: Color(0xFFF0F0F0), height: 24),
          _buildInfoRow(Icons.scale, 'Unité de vente', 'Kilogramme (Kg)'),
          const Divider(color: Color(0xFFF0F0F0), height: 24),
          _buildInfoRow(Icons.verified_outlined, 'Source', 'SIM / CSA Sénégal'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildMarketComparison(double currentPrice, String imageAsset) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comparaison inter-marchés', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          const Text(
            'Comparez les cotations réelles relevées pour ce produit sur les différents marchés régionaux (Dakar, Thiès, Kaolack, etc.).',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.push('/market_comparison', extra: {
                  'productName': widget.productName,
                  'imageAsset': imageAsset,
                  'price': '${currentPrice.toInt()} FCFA/kg',
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Voir la comparaison par marché', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
