import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/market.dart';
import '../../data/models/price.dart';
import '../../data/markets_provider.dart';

class MarketDetailScreen extends ConsumerStatefulWidget {
  final Market market;

  const MarketDetailScreen({super.key, required this.market});

  @override
  ConsumerState<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends ConsumerState<MarketDetailScreen> {
  bool _showAllPrices = false;
  Market get market => widget.market;

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(pricesListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(market.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Lien du marché ${market.name} copié.'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pricesListProvider),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header (Nom, Lieu, Note, Statut)
              _buildHeader(),
              const SizedBox(height: 24),

              // 2. Prix actuels & 3. Évolution du marché
              pricesAsync.when(
                data: (prices) {
                  final marketPrices = prices.where((p) => p.marketId == market.id).toList();
                  return Column(
                    children: [
                      _buildCurrentPrices(marketPrices),
                      const SizedBox(height: 24),
                      _buildMarketEvolution(marketPrices),
                      const SizedBox(height: 24),
                      _buildMarketInfo(marketPrices),
                    ],
                  );
                },
                loading: () => Column(
                  children: [
                    const Center(child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )),
                    const SizedBox(height: 24),
                    _buildMarketInfo([]),
                  ],
                ),
                error: (err, _) => Column(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 36),
                            const SizedBox(height: 8),
                            Text("Erreur: $err", textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => ref.invalidate(pricesListProvider),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildMarketInfo([]),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // 5. Actions (Itinéraire, Alerte)
            _buildActions(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(market.region, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text('${market.rating ?? 4.5}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.access_time_rounded, size: 16, color: Colors.green),
              ),
              const SizedBox(width: 8),
              Text(
                'Ouvert aujourd\'hui (${market.openingTime?.substring(0, 5) ?? "06:00"} - ${market.closingTime?.substring(0, 5) ?? "20:00"})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPrices(List<Price> marketPrices) {
    if (marketPrices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text("Aucun prix disponible pour le moment."),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('Prix actuels', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: _showAllPrices
              ? marketPrices.length
              : (marketPrices.length > 4 ? 4 : marketPrices.length),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final price = marketPrices[index];
            return _buildPriceRow(price);
          },
        ),
        if (marketPrices.length > 4)
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 24, right: 24),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _showAllPrices = !_showAllPrices;
                });
              },
              child: Text(
                _showAllPrices ? 'Réduire' : 'Voir tous les prix (${marketPrices.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPriceRow(Price price) {
    IconData productIcon = Icons.eco_rounded;
    Color productIconColor = AppColors.primary;
    final nameLower = price.productName.toLowerCase();
    if (nameLower.contains("oignon")) {
      productIcon = Icons.circle_outlined;
      productIconColor = Colors.purple.shade400;
    } else if (nameLower.contains("arachide")) {
      productIcon = Icons.grain_rounded;
      productIconColor = Colors.amber.shade700;
    } else if (nameLower.contains("mil")) {
      productIcon = Icons.grass_rounded;
      productIconColor = Colors.orange.shade600;
    } else if (nameLower.contains("tomate")) {
      productIcon = Icons.lens;
      productIconColor = Colors.redAccent;
    } else if (nameLower.contains("riz")) {
      productIcon = Icons.rice_bowl_outlined;
      productIconColor = Colors.teal.shade600;
    }

    IconData trendIcon;
    Color trendColor;
    if (price.trend == 'up') {
      trendIcon = Icons.arrow_upward; trendColor = Colors.green;
    } else if (price.trend == 'down') {
      trendIcon = Icons.arrow_downward; trendColor = Colors.red;
    } else {
      trendIcon = Icons.arrow_forward; trendColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: productIconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(productIcon, size: 18, color: productIconColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(price.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          Text('${price.priceValue.toInt()} FCFA/kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 8),
          Icon(trendIcon, size: 16, color: trendColor),
        ],
      ),
    );
  }

  Widget _buildMarketEvolution(List<Price> marketPrices) {
    if (marketPrices.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Évolution du marché', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text(
              'Aucune cotation enregistrée pour ce marché.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final featuredPrice = marketPrices.first;
    final isUp = featuredPrice.trend == 'up';
    final isDown = featuredPrice.trend == 'down';
    final trendLabel = isUp ? 'Haussière' : (isDown ? 'Baissière' : 'Stable');
    final trendColor = isUp ? Colors.green : (isDown ? Colors.red : Colors.orange);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Évolution du marché', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      featuredPrice.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${featuredPrice.priceValue.toInt()} FCFA/kg',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Relevé indicatif du ${featuredPrice.date}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: trendColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isUp ? Icons.trending_up : (isDown ? Icons.trending_down : Icons.trending_flat), color: trendColor, size: 18),
                    const SizedBox(width: 6),
                    Text(trendLabel, style: TextStyle(color: trendColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tendance observée sur ${market.name} selon les derniers relevés.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketInfo(List<Price> marketPrices) {
    final productsStr = marketPrices.isNotEmpty
        ? marketPrices.map((p) => p.productName).toSet().take(4).join(', ')
        : 'Céréales, légumes et vivriers';
    final latestUpdate = marketPrices.isNotEmpty
        ? marketPrices.first.date
        : 'Relevé indicatif périodique';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fiche marché', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildInfoRow('Produits répertoriés', productsStr),
          _buildInfoRow('Dernier relevé', latestUpdate),
          _buildInfoRow('Localisation', market.region),
          _buildInfoRow(
            'Horaires',
            '${market.openingTime?.substring(0, 5) ?? "08:00"} - ${market.closingTime?.substring(0, 5) ?? "18:00"}',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.directions_car_rounded, color: Colors.black87),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Itinéraire vers ${market.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text(market.region, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_off_outlined, color: Colors.grey.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      "Calcul d'itinéraire non disponible (nécessite la géolocalisation active)",
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              if (market.locationGps != null && market.locationGps!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Coordonnées GPS', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text(market.locationGps!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Position de ${market.name} : ${market.locationGps ?? market.region}'),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Localisation du marché'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.directions_car, color: Colors.white),
              label: const Text('Voir l\'itinéraire', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final targetController = TextEditingController(text: '500');
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  builder: (ctx) => Padding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 24,
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Créer une alerte de prix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text(market.name, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Soyez alerté dès que le cours moyen sur ${market.name} évolue selon votre seuil fixé.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.3),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: targetController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Seuil de prix souhaité (FCFA/kg)',
                            suffixText: 'FCFA/kg',
                            prefixIcon: const Icon(Icons.price_change_outlined, color: AppColors.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            final threshold = targetController.text.trim();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Alerte enregistrée pour ${market.name} au seuil de $threshold FCFA/kg.'),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Enregistrer l\'alerte'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
              label: const Text('Créer une alerte de prix', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  final bool isUp;
  SparklinePainter({this.isUp = true});

  @override
  void paint(Canvas canvas, Size size) {
    final color = isUp ? Colors.green : Colors.red;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (isUp) {
      path.moveTo(0, size.height * 0.8);
      path.lineTo(size.width * 0.2, size.height * 0.6);
      path.lineTo(size.width * 0.4, size.height * 0.7);
      path.lineTo(size.width * 0.6, size.height * 0.3);
      path.lineTo(size.width * 0.8, size.height * 0.4);
      path.lineTo(size.width, 0);
    } else {
      path.moveTo(0, size.height * 0.1);
      path.lineTo(size.width * 0.2, size.height * 0.3);
      path.lineTo(size.width * 0.4, size.height * 0.2);
      path.lineTo(size.width * 0.6, size.height * 0.7);
      path.lineTo(size.width * 0.8, size.height * 0.6);
      path.lineTo(size.width, size.height * 0.9);
    }

    canvas.drawPath(path, paint);

    // Gradient sous la ligne
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
