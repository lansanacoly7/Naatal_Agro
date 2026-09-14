import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../../../core/theme/app_theme.dart';
import '../../data/models/dashboard_data.dart';
import '../../../inventory/data/models/stock_item.dart';

class MarketPricesSection extends StatefulWidget {
  final List<MarketPrice> markets;
  final List<StockItem> stocks;

  const MarketPricesSection({
    super.key, 
    required this.markets,
    required this.stocks,
  });

  @override
  State<MarketPricesSection> createState() => _MarketPricesSectionState();
}

class _MarketPricesSectionState extends State<MarketPricesSection> {
  String _selectedProduct = 'Oignon';

  // Données générées dynamiquement pour un look boursier réaliste (30 jours)
  final Map<String, List<double>> _historicalData = {};
  final List<String> _days = [];

  final List<String> _availableProducts = [
    'Oignon', 'Tomate', 'Mil', 'Arachide', 'Maïs', 'Riz', 'Pomme de terre',
    'Pastèque', 'Papaye', 'Mangue', 'Fraise', 'Pomme'
  ];

  @override
  void initState() {
    super.initState();
    _generateRealisticData();
  }

  void _generateRealisticData() {
    final random = math.Random(42); // Seed fixe pour avoir toujours le même graphe
    final basePrices = {
      'Oignon': 350.0, 'Tomate': 900.0, 'Mil': 330.0, 'Arachide': 580.0,
      'Maïs': 240.0, 'Riz': 420.0, 'Pomme de terre': 400.0, 'Pastèque': 180.0,
      'Papaye': 550.0, 'Mangue': 450.0, 'Fraise': 1800.0, 'Pomme': 1100.0,
    };

    final now = DateTime.now();
    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      _days.add('${date.day}/${date.month}');
    }

    for (final product in _availableProducts) {
      double currentPrice = basePrices[product]!;
      List<double> prices = [];
      for (int i = 0; i < 30; i++) {
        // Variation aléatoire type bourse entre -2% et +2.5% par jour
        double changePercent = (random.nextDouble() * 0.045) - 0.02;
        currentPrice = currentPrice * (1 + changePercent);
        prices.add(currentPrice);
      }
      _historicalData[product] = prices;
    }
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
          _buildCurrentPriceHeader(),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCards() {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _availableProducts.length,
        itemBuilder: (context, index) {
          final product = _availableProducts[index];
          final isSelected = _selectedProduct == product;
          
          final prices = _historicalData[product]!;
          final currentPrice = prices.last;
          final previousPrice = prices[prices.length - 2];
          final diff = currentPrice - previousPrice;
          final percent = (diff / previousPrice) * 100;
          final isUp = diff >= 0;
          final trendColor = isUp ? Colors.green : Colors.red;
          final trendIcon = isUp ? Icons.trending_up : Icons.trending_down;

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
                              '${isUp ? '+' : ''}${percent.toStringAsFixed(0)}%',
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

  Widget _buildCurrentPriceHeader() {
    final prices = _historicalData[_selectedProduct]!;
    final currentPrice = prices.last;
    final previousPrice = prices[prices.length - 2];
    final diff = currentPrice - previousPrice;
    final percent = (diff / previousPrice) * 100;
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
            // Trouver si l'utilisateur a ce produit en stock
            double stockQuantity = 0.0;
            try {
              final stock = widget.stocks.firstWhere(
                (s) => s.name.toLowerCase() == _selectedProduct.toLowerCase()
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

  Widget _buildChart() {
    final dataPoints = _historicalData[_selectedProduct]!;
    final spots = dataPoints.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    double minY = dataPoints.reduce((a, b) => a < b ? a : b);
    double maxY = dataPoints.reduce((a, b) => a > b ? a : b);
    
    // Calculate a nice interval and bounds for the Y axis
    final range = maxY - minY;
    // Add 20% padding top and bottom for better readability
    minY = (minY - (range * 0.2)).floorToDouble();
    if (minY < 0) minY = 0; // Prevent negative prices
    maxY = (maxY + (range * 0.2)).ceilToDouble();
    
    // Ensure we have a minimum range so flat lines don't look weird
    if (maxY == minY) {
      minY -= 100;
      maxY += 100;
      if (minY < 0) minY = 0;
    }

    final yInterval = ((maxY - minY) / 4).ceilToDouble();

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
              dashArray: [8, 4], // Tirets plus longs et espacés
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
              interval: 6, // Un label tous les 6 jours
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < _days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      _days[index],
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
              reservedSize: 55, // Plus d'espace pour les grands nombres
              getTitlesWidget: (value, meta) {
                // Ne pas afficher la valeur min absolue ni la max absolue si elles collent aux bords
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
        maxX: (_days.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false, // Ligne droite boursière
            color: AppColors.primary,
            barWidth: 2.5, // Plus fine
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
                return LineTooltipItem(
                  '${touchedSpot.y.toInt()} FCFA\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: _days[touchedSpot.x.toInt()],
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.normal),
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
}
