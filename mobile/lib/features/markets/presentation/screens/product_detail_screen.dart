import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/product_detail_model.dart';
import '../../data/mock_product_database.dart';

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
  late final ProductDetail product;

  @override
  void initState() {
    super.initState();
    // Try to parse the price from string "450 FCFA/kg" -> 450.0
    final priceStr = widget.price.replaceAll(RegExp(r'[^0-9.]'), '');
    final fallbackPrice = double.tryParse(priceStr) ?? 0.0;
    
    product = MockProductDatabase.getProduct(
      widget.productName,
      fallbackImage: widget.imageAsset,
      fallbackPrice: fallbackPrice,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  _buildNaatalRecommendation(),
                  const SizedBox(height: 24),
                  _buildDescriptionCard(),
                  const SizedBox(height: 24),
                  _buildPriceTrendChart(),
                  const SizedBox(height: 24),
                  _buildDetailedInfoCard(),
                  const SizedBox(height: 24),
                  _buildMarketComparison(),
                  const SizedBox(height: 120), // Space for Bottom Nav
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SliverAppBar ---
  Widget _buildSliverAppBar(BuildContext context) {
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
              product.imageAsset,
              fit: BoxFit.cover,
            ),
            // Gradient Overlay
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
            // Content
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chips
                  Row(
                    children: [
                      _buildGlassChip(
                          product.trendPercentage >= 0 ? '↑ +${product.trendPercentage} %' : '↓ ${product.trendPercentage} %',
                          null,
                          product.trendPercentage >= 0 ? Colors.greenAccent : Colors.redAccent),
                      const SizedBox(width: 8),
                      _buildGlassChip(product.category, null, Colors.white),
                      const SizedBox(width: 8),
                      _buildGlassChip('${product.rating}/5', Icons.star, Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Title & Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Prix moyen', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(
                            '${product.currentPrice.toInt()} FCFA/kg',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Quick Actions ---
  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionButton(Icons.sensors, 'Prédire', const Color(0xFF673AB7)),
        _buildActionButton(Icons.notifications_active, 'Alerte', Colors.amber.shade700),
        _buildActionButton(Icons.inventory_2, 'Mon Stock', Colors.brown.shade400),
        _buildActionButton(Icons.chat_bubble, 'Chatbot', AppColors.primary),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
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
    );
  }

  Widget _buildNaatalRecommendation() {
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
              Text('Recommandation Naatal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF673AB7))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(product.recommendation.isPositive ? Icons.check_circle : Icons.warning, color: product.recommendation.isPositive ? Colors.green : Colors.orange, size: 16),
              const SizedBox(width: 6),
              Text(product.recommendation.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: product.recommendation.isPositive ? Colors.green : Colors.orange)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            product.recommendation.message,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          const Text('[Voir l\'analyse]', style: TextStyle(color: Color(0xFF673AB7), fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  // --- Description ---
  Widget _buildDescriptionCard() {
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
          const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Text(
            product.description,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text('[Lire plus]', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  // --- Price Trend Chart ---
  Widget _buildPriceTrendChart() {
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
                child: Text('Tendance des prix (30 jours)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
              Row(
                children: [
                  Text('Voir plus', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const Icon(Icons.chevron_right, color: AppColors.primary, size: 16),
                ],
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
                      reservedSize: 30,
                      interval: 50,
                      getTitlesWidget: (value, meta) {
                        if (value == 400 || value == 450 || value == 500) {
                          return Text(value.toInt().toString(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 10));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        String text = '';
                        if (value == 0) text = '1 Nov';
                        if (value == 4) text = '15 Nov';
                        if (value == 8) text = '30 Nov';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 8,
                minY: 380,
                maxY: 520,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 410),
                      FlSpot(2, 418),
                      FlSpot(3, 435),
                      FlSpot(5, 455),
                      FlSpot(6, 458),
                      FlSpot(7, 478),
                      FlSpot(8, 490),
                    ],
                    isCurved: true,
                    color: AppColors.primaryDark,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        if (index == barData.spots.length - 1) {
                          return FlDotCirclePainter(radius: 5, color: Colors.red, strokeWidth: 0);
                        }
                        if (index == 3 || index == 5) {
                          return FlDotCirclePainter(radius: 4, color: AppColors.primaryDark, strokeWidth: 0);
                        }
                        return FlDotCirclePainter(radius: 0, color: Colors.transparent, strokeWidth: 0);
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark.withValues(alpha: 0.2),
                          AppColors.primaryDark.withValues(alpha: 0.0),
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
  Widget _buildDetailedInfoCard() {
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
          const Text('Informations Détaillées', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.calendar_today, 'Mise à jour', 'Aujourd\'hui, 08:30'),
          const Divider(color: Color(0xFFF0F0F0), height: 24),
          _buildInfoRow(Icons.storefront, 'Marché principal', 'Marché Sandaga'),
          const Divider(color: Color(0xFFF0F0F0), height: 24),
          _buildInfoRow(Icons.category, 'Catégorie', 'Légumes frais'),
          const Divider(color: Color(0xFFF0F0F0), height: 24),
          _buildInfoRow(Icons.scale, 'Unité de vente', 'Kilogramme (Kg)'),
          const Divider(color: Color(0xFFF0F0F0), height: 24),
          _buildRatingRow(),
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

  Widget _buildRatingRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Icon(Icons.star_border, size: 16, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text('Qualité marchande', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 14),
            const Icon(Icons.star, color: Colors.amber, size: 14),
            const Icon(Icons.star, color: Colors.amber, size: 14),
            const Icon(Icons.star, color: Colors.amber, size: 14),
            const Icon(Icons.star_half, color: Colors.amber, size: 14),
            const SizedBox(width: 4),
            const Text(' 4.5', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textPrimary)),
          ],
        ),
      ],
    );
  }

  Widget _buildMarketComparison() {
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
          const Text('Comparaison des prix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          const Text(
            'Analysez et comparez les prix sur les différents marchés (Sandaga, Tilène, Castors, etc.) pour trouver la meilleure opportunité de vente ou d\'achat.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.push('/market_comparison', extra: {
                  'productName': product.name,
                  'imageAsset': product.imageAsset,
                  'price': '${product.currentPrice.toInt()} FCFA/kg',
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Voir la comparaison détaillée', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
