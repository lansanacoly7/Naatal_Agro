import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/dashboard_data.dart';
import '../../../inventory/data/models/stock_item.dart';
import '../../../markets/data/markets_provider.dart';
import '../../../markets/data/models/price.dart';
import '../../../../screens/markets/market_sheet.dart' show PriceChart;
import '../../../../screens/markets/markets_data.dart' show PricePoint;

import '../../../../ui/ui.dart';
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
  String? _picked;

  String get _selectedProduct {
    final products = _availableProducts;
    if (_picked != null && products.contains(_picked)) return _picked!;
    return products.isEmpty ? '' : products.first;
  }


  /// Prix moyen par jour : plusieurs marchés le même jour ne font plus osciller la courbe.
  List<PricePoint> _daily(List<Price>? history) {
    if (history == null) return const [];
    final byDay = <String, List<double>>{};
    for (final p in history) {
      final day = p.date.length >= 10 ? p.date.substring(0, 10) : p.date;
      byDay.putIfAbsent(day, () => []).add(p.priceValue);
    }
    final points = <PricePoint>[];
    byDay.forEach((day, values) {
      final d = DateTime.tryParse(day);
      if (d != null) points.add(PricePoint(date: d, price: values.reduce((a, b) => a + b) / values.length));
    });
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  List<String> get _availableProducts {
    final productsFromMarkets = widget.markets
        .map((m) => m.productName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    if (productsFromMarkets.isNotEmpty) {
      return productsFromMarkets;
    }
    return const <String>[];
  }

  double? _getProductCurrentPrice(String product, List<Price>? history) {
    final daily = _daily(history);
    if (daily.isNotEmpty) {
      return daily.last.price;
    }
    final match = widget.markets.cast<MarketPrice?>().firstWhere(
      (m) => m?.productName.toLowerCase() == product.toLowerCase(),
      orElse: () => null,
    );
    if (match != null && match.price > 0) {
      return match.price;
    }
    return null;
  }

  /// Image du produit (même règle partout) : jamais le logo de l'application à la place d'un produit.
  String _getImageForProduct(String productName) => productImageForName(productName);

  @override
  Widget build(BuildContext context) {
    if (_availableProducts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
        child: Text(
          'Aucun prix pour vos cultures. Ajoutez une culture : ses prix relevés sur les marchés apparaîtront ici.',
          style: TextStyle(color: context.c.ink2, fontSize: 13, height: 1.4),
        ),
      );
    }
    final historyAsync = ref.watch(productPriceHistoryProvider(_selectedProduct));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.c.surface,
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
          if (_availableProducts.isEmpty)
            Text(
              'Aucun prix pour vos cultures. Ajoutez une culture : ses prix relevés sur les marchés apparaîtront ici.',
              style: TextStyle(color: context.c.ink2, fontSize: 13, height: 1.4),
            )
          else
            _buildProductCards(),
          const SizedBox(height: 24),
          historyAsync.when(
            data: (history) => _buildCurrentPriceHeader(history),
            loading: () => _buildLoadingHeader(),
            error: (_, __) => _buildCurrentPriceHeader(null),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 190,
            child: historyAsync.when(
              data: (history) => _buildChart(history),
              loading: () => Center(
                child: CircularProgressIndicator(color: context.c.accent),
              ),
              error: (_, __) => _buildFallbackChart(),
            ),
          ),
          const SizedBox(height: 8),
          Text('Relevés indicatifs, non officiels.', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          const SizedBox(height: 16),
          historyAsync.maybeWhen(data: (history) => _buildAnalyzeButton(history), orElse: () => const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildProductCards() {
    final products = _availableProducts;
    return SizedBox(
      height: 66,
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
          final double? currentPrice = (match != null && match.price > 0) ? match.price : null;
          final change = match?.changePercent;
          final isUp = (change ?? 0) >= 0;
          final trendColor = isUp ? Colors.green : Colors.red;
          final trendIcon = isUp ? Icons.trending_up : Icons.trending_down;
          final trendLabel = change == null ? '' : '${isUp ? '+' : '−'}${change.abs().toStringAsFixed(1)}%';

          return GestureDetector(
            onTap: () {
              setState(() {
                _picked = product;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 168,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : context.c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? context.c.accent : Colors.grey.withValues(alpha: 0.1),
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
                    width: 36,
                    height: 36,
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
                          color: context.c.surface,
                          child: const Icon(Icons.shopping_basket, color: Colors.grey, size: 24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                            color: isSelected ? context.c.accent : context.c.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              currentPrice != null ? '${currentPrice.toInt()} F' : 'Non renseigné',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: currentPrice != null ? 13 : 11,
                                color: currentPrice != null ? context.c.ink : context.c.ink2,
                              ),
                            ),
                            const Spacer(),
                            if (currentPrice != null && change != null) ...[
                              Icon(trendIcon, size: 12, color: trendColor),
                              const SizedBox(width: 2),
                              Text(
                                trendLabel,
                                style: TextStyle(color: trendColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
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
    if (currentPrice == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prix moyen actuel',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Prix non renseigné',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.c.ink2,
                ),
              ),
            ],
          ),
        ],
      );
    }
    double previousPrice = currentPrice;
    final daily = _daily(history);
    if (daily.length > 1) {
      previousPrice = daily[daily.length - 2].price;
    }
    final diff = currentPrice - previousPrice;
    final percent = previousPrice > 0 ? (diff / previousPrice) * 100 : 0.0;
    final isUp = diff >= 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
         child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prix moyen actuel',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                 child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                  '${currentPrice.toInt()} FCFA / kg',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.c.ink,
                  ),
                ),
                 ),
                ),
                const SizedBox(width: 12),
                if (_daily(history).length > 1)
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
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton(List<Price>? history) {
    final currentPrice = _getProductCurrentPrice(_selectedProduct, history);
    if (currentPrice == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          double stockQuantity = 0.0;
          try {
            final stock = widget.stocks.firstWhere((s) => s.name.toLowerCase() == _selectedProduct.toLowerCase());
            stockQuantity = stock.quantity;
          } catch (_) {}
          context.push('/price-analysis', extra: {
            'product': _selectedProduct,
            'price': currentPrice,
            'stock': stockQuantity,
          });
        },
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: Text('Analyser $_selectedProduct'),
      ),
    );
  }

  Widget _buildChart(List<Price> history) {
    final daily = _daily(history);
    if (daily.length >= 2) {
      return Align(alignment: Alignment.bottomCenter, child: PriceChart(points: daily, color: context.c.accent));
    }
    return Center(
      child: Text(
        'Pas encore assez de relevés pour tracer une courbe.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.c.ink2, fontSize: 13),
      ),
    );
  }

  // Ancienne courbe en zig-zag (conservée pour référence, non utilisée)
  // ignore: unused_element
  Widget _buildChartLegacy(List<Price> history) {
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
                      style: TextStyle(
                        color: context.c.ink2,
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
                      color: context.c.ink2,
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
            color: context.c.accent,
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
            getTooltipColor: (touchedSpot) => context.c.accent,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart_rounded, size: 40, color: Colors.grey),
          SizedBox(height: 8),
          Text('Historique des prix indisponible', style: TextStyle(color: context.c.ink2, fontSize: 13)),
        ],
      ),
    );
  }
}
