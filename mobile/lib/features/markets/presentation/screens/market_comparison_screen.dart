import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/mock_product_database.dart';
import '../../data/models/product_detail_model.dart';

class MarketComparisonScreen extends ConsumerStatefulWidget {
  final String productName;
  final String imageAsset;
  final String price;

  const MarketComparisonScreen({
    super.key,
    required this.productName,
    this.imageAsset = '',
    this.price = '',
  });

  @override
  ConsumerState<MarketComparisonScreen> createState() => _MarketComparisonScreenState();
}

class _MarketComparisonScreenState extends ConsumerState<MarketComparisonScreen> {
  late final ProductDetail product;
  
  // Available markets and their base prices (mocked logic)
  final Map<String, double> allMarkets = {
    'Sandaga': 450.0,
    'Tilène': 435.0,
    'Castors': 470.0,
    'Rufisque': 425.0,
    'Thiaroye': 440.0,
  };

  Set<String> selectedMarkets = {'Sandaga', 'Castors', 'Tilène'};

  @override
  void initState() {
    super.initState();
    final priceStr = widget.price.replaceAll(RegExp(r'[^0-9.]'), '');
    final fallbackPrice = double.tryParse(priceStr) ?? 0.0;
    
    product = MockProductDatabase.getProduct(
      widget.productName,
      fallbackImage: widget.imageAsset,
      fallbackPrice: fallbackPrice,
    );

    // Adjust prices based on product currentPrice to make it realistic
    final base = product.currentPrice > 0 ? product.currentPrice : 450.0;
    allMarkets['Sandaga'] = base;
    allMarkets['Tilène'] = base - 15;
    allMarkets['Castors'] = base + 20;
    allMarkets['Rufisque'] = base - 25;
    allMarkets['Thiaroye'] = base - 10;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Marchés à comparer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  _buildMarketChips(),
                  const SizedBox(height: 24),
                  if (selectedMarkets.isNotEmpty) ...[
                    _buildBestMarketAdvice(),
                    const SizedBox(height: 24),
                    const Text('Détails par marché', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    _buildMarketList(),
                  ] else ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text("Sélectionnez au moins un marché pour voir la comparaison.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250.0,
      pinned: true,
      backgroundColor: AppColors.primary,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              product.imageAsset,
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Comparaison des prix', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
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

  Widget _buildMarketChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allMarkets.keys.map((market) {
        final isSelected = selectedMarkets.contains(market);
        return FilterChip(
          label: Text(market, style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary)),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                selectedMarkets.add(market);
              } else {
                selectedMarkets.remove(market);
              }
            });
          },
          selectedColor: AppColors.primary,
          backgroundColor: Colors.grey.shade100,
          checkmarkColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
        );
      }).toList(),
    );
  }

  Widget _buildBestMarketAdvice() {
    String bestMarket = '';
    double maxPrice = 0.0;

    for (var m in selectedMarkets) {
      if (allMarkets[m]! > maxPrice) {
        maxPrice = allMarkets[m]!;
        bestMarket = m;
      }
    }

    final priceDiff = maxPrice - product.currentPrice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.insights, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Analyse Naatal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Meilleur choix actuel : $bestMarket',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            priceDiff > 0 
                ? "Il est conseillé de vendre à $bestMarket pour maximiser vos revenus. Vous pourriez réaliser un bénéfice supplémentaire de +${priceDiff.toInt()} FCFA/kg par rapport au prix moyen."
                : "Les prix sur les marchés sélectionnés sont inférieurs ou égaux au prix moyen. $bestMarket reste l'option la plus viable parmi votre sélection.",
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketList() {
    // Sort selected markets by price descending
    final sortedMarkets = selectedMarkets.toList()..sort((a, b) => allMarkets[b]!.compareTo(allMarkets[a]!));

    return Column(
      children: sortedMarkets.map((market) {
        final price = allMarkets[market]!;
        final diff = price - product.currentPrice;
        final isBest = sortedMarkets.first == market;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isBest ? AppColors.primary.withValues(alpha: 0.5) : Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.storefront, color: isBest ? AppColors.primary : AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(market, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isBest ? AppColors.primary : AppColors.textPrimary)),
                      if (diff != 0)
                        Text(
                          '${diff > 0 ? '+' : ''}${diff.toInt()} FCFA vs moyenne',
                          style: TextStyle(color: diff > 0 ? Colors.green : Colors.red, fontSize: 12),
                        ),
                    ],
                  ),
                ],
              ),
              Text('${price.toInt()} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
