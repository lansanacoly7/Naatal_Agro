import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/dashboard_data.dart';
import '../../../inventory/data/models/stock_item.dart';
import '../../../markets/data/markets_provider.dart';
import '../../../markets/data/models/price.dart';

class MarketPricesSection extends ConsumerStatefulWidget {
  final List<MarketPrice> markets;
  final List<StockItem> stocks;

  const MarketPricesSection({
    super.key, 
    required this.markets,
    required this.stocks,
  });

  @override
  ConsumerState<MarketPricesSection> createState() => _MarketPricesSectionState();
}

class _MarketPricesSectionState extends ConsumerState<MarketPricesSection> {
  String _selectedProduct = 'Oignon';

  static const Map<String, double> _referenceBasePrices = {
    'Oignon': 350.0,
    'Tomate': 900.0,
    'Mil': 330.0,
    'Arachide': 580.0,
    'Maïs': 240.0,
    'Riz': 420.0,
    'Pomme de terre': 400.0,
    'Pastèque': 180.0,
    'Papaye': 550.0,
    'Mangue': 450.0,
    'Fraise': 1800.0,
    'Pomme': 1100.0,
  };

  List<String> get _availableProducts {
    final productsFromMarkets = widget.markets
        .map((m) => m.productName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    if (productsFromMarkets.isNotEmpty) {
      return productsFromMarkets;
    }
    return _referenceBasePrices.keys.toList();
  }

  double _getProductCurrentPrice(String product, List<Price>? history) {
    if (history != null && history.isNotEmpty) {
      return history.last.priceValue;
    }
    final match = widget.markets.cast<MarketPrice?>().firstWhere(
      (m) => m?.productName.toLowerCase() == product.toLowerCase(),
      orElse: () => null,
    );
    if (match != null && match.price > 0) {
      return match.price;
    }
    return _referenceBasePrices[product] ?? 350.0;
  }

  String _getImageForProduct(String productName) {
    final nameLower = productName.toLowerCase();
    if (nameLower.contains('oignon')) return 'assets/images/products/oignon.png';
    if (nameLower.contains('tomate')) return 'assets/images/products/tomate.png';
    if (nameLower.contains('mil')) return 'assets/images/products/mil.png';
    if (nameLower.contains('arachide')) return 'assets/images/products/arachide.png';
    if (nameLower.contains('maïs') || nameLower.contains('mais')) return 'assets/images/products/mais.jpg';
    if (nameLower.contains('riz')) return 'assets/images/products/riz.jpg';
    if (nameLower.contains('pomme de terre')) return 'assets/images/products/pomme_de_terre.png';
    if (nameLower.contains('pasteque') || nameLower.contains('pastèque')) return 'assets/images/products/pasteque.png';
    if (nameLower.contains('papaye')) return 'assets/images/products/papaye.png';
    if (nameLower.contains('mangue')) return 'assets/images/products/mangue.png';
    if (nameLower.contains('fraise')) return 'assets/images/products/fraise.jpg';
    if (nameLower.contains('pomme')) return 'assets/images/products/pomme.jpg';
    return 'assets/images/naatal_agro_logo-removebg-preview.png';
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(productPriceHistoryProvider(_selectedProduct));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductCards(),
          const SizedBox(height: 24),
          historyAsync.when(
            data: (history) => _buildCurrentPriceHeader(history),
            loading: () => _buildLoadingHeader(),
            error: (_, __) => _buildCurrentPriceHeader(null),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: historyAsync.when(
              data: (history) => _buildChart(history),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (_, __) => _buildFallbackChart(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCards() {
    final products = _availableProducts;
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final isSelected = _selectedProduct == product;

          final match = widget.markets.cast<MarketPrice?>().firstWhere(
            (m) => m?.productName.toLowerCase() == product.toLowerCase(),
            orElse: () => null,
          );
          final currentPrice = match?.price ?? _referenceBasePrices[product] ?? 350.0;
          final isUp = match != null ? (match.trend == 'up') : true;
          final trendColor = isUp ? Colors.green : Colors.red;
          final trendIcon = isUp ? Icons.trending_up : Icons.trending_down;
          final trendLabel = isUp ? '+1.2%' : '-1.5%';

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedProduct = product;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 200,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.1),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected ? [] : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        _getImageForProduct(product),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.white,
                          child: const Icon(Icons.shopping_basket, color: Colors.grey, size: 24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          product,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${currentPrice.toInt()} F',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                            const Spacer(),
                            Icon(trendIcon, size: 12, color: trendColor),
                            const SizedBox(width: 2),
                            Text(
                              trendLabel,
                              style: TextStyle(color: trendColor, fontSize: 10, fontWeight: FontWeight.bold),
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
        },
      ),
    );
  }

  Widget _buildLoadingHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prix moyen actuel', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('Chargement...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentPriceHeader(List<Price>? history) {
    final currentPrice = _getProductCurrentPrice(_selectedProduct, history);
    double previousPrice = currentPrice;
    if (history != null && history.length > 1) {
      previousPrice = history[history.length - 2].priceValue;
    }
    final diff = currentPrice - previousPrice;
    final percent = previousPrice > 0 ? (diff / previousPrice) * 100 : 0.0;
    final isUp = diff >= 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prix moyen actuel',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${currentPrice.toInt()} FCFA / kg',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isUp ? Colors.green : Colors.red).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isUp ? Icons.trending_up : Icons.trending_down,
                        color: isUp ? Colors.green : Colors.red,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isUp ? '+' : ''}${percent.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: isUp ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            double stockQuantity = 0.0;
            try {
              final stock = widget.stocks.firstWhere(
                (s) => s.name.toLowerCase() == _selectedProduct.toLowerCase(),
              );
              stockQuantity = stock.quantity;
            } catch (_) {}

            context.push('/price-analysis', extra: {
              'product': _selectedProduct,
              'price': currentPrice,
              'stock': stockQuantity,
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Analyser',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChart(List<Price> history) {
    if (history.isEmpty) {
      return _buildFallbackChart();
    }

    final sorted = List<Price>.from(history)..sort((a, b) => a.date.compareTo(b.date));
    final spots = sorted.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.priceValue);
    }).toList();

    final dayLabels = sorted.map((p) {
      try {
        final d = DateTime.parse(p.date);
        return '${d.day}/${d.month}';
      } catch (_) {
        return p.date;
      }
    }).toList();

    double minY = sorted.map((p) => p.priceValue).reduce((a, b) => a < b ? a : b);
    double maxY = sorted.map((p) => p.priceValue).reduce((a, b) => a > b ? a : b);

    final range = maxY - minY;
    minY = (minY - (range * 0.2)).floorToDouble();
    if (minY < 0) minY = 0;
    maxY = (maxY + (range * 0.2)).ceilToDouble();

    if (maxY == minY) {
      minY -= 50;
      maxY += 50;
      if (minY < 0) minY = 0;
    }

    final yInterval = ((maxY - minY) / 4).clamp(1.0, double.infinity);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.15),
              strokeWidth: 1.5,
              dashArray: [8, 4],
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (sorted.length / 5).clamp(1.0, double.infinity).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < dayLabels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      dayLabels[index],
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: yInterval,
              reservedSize: 55,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    '${value.toInt()} F',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (sorted.length - 1).toDouble().clamp(0.0, double.infinity),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: AppColors.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.3),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => AppColors.primary,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final idx = touchedSpot.x.toInt();
                final label = idx < dayLabels.length ? dayLabels[idx] : '';
                return LineTooltipItem(
                  '${touchedSpot.y.toInt()} FCFA\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
      ),
    );
  }

  Widget _buildFallbackChart() {
    final currentPrice = _getProductCurrentPrice(_selectedProduct, null);
    final spots = [
      FlSpot(0, currentPrice),
      FlSpot(1, currentPrice),
      FlSpot(2, currentPrice),
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 100,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withValues(alpha: 0.15),
            strokeWidth: 1.5,
            dashArray: [8, 4],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) => Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  val == 1 ? "Aujourd'hui" : '',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (val, meta) => Text(
                '${val.toInt()} F',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 2,
        minY: (currentPrice - 100).clamp(0.0, double.infinity),
        maxY: currentPrice + 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: AppColors.primary.withValues(alpha: 0.7),
            barWidth: 2,
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}
