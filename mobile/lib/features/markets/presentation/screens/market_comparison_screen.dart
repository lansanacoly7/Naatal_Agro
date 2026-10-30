import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/markets_provider.dart';

import '../../../../ui/ui.dart';
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
  final Set<String> _selectedMarkets = {};
  bool _isInitialized = false;

  double _parsePrice(String priceStr) {
    final cleaned = priceStr.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Image fournie, sinon celle du produit (même règle partout) : jamais le logo de l'application à la place d'un produit.
  String _resolveImageAsset(String name, String providedAsset) {
    if (providedAsset.isNotEmpty && !providedAsset.contains('placeholder')) return providedAsset;
    return productImageForName(name);
  }

  @override
  Widget build(BuildContext context) {
    final fallbackPrice = _parsePrice(widget.price);
    final imageAsset = _resolveImageAsset(widget.productName, widget.imageAsset);

    final marketsAsync = ref.watch(marketsListProvider);
    final pricesAsync = ref.watch(productPriceHistoryProvider(widget.productName));

    return Scaffold(
      backgroundColor: context.c.bg,
      body: marketsAsync.when(
        data: (markets) {
          return pricesAsync.when(
            data: (prices) {
              // Construire la cartographie réelle : Nom du Marché -> Dernier prix réel
              final Map<String, double> realMarketPrices = {};

              // Associer les prix aux marchés réels
              for (final market in markets) {
                // Trouver les cotations de ce produit pour ce marché
                final marketPrices = prices.where((p) => p.marketId == market.id).toList();
                if (marketPrices.isNotEmpty) {
                  marketPrices.sort((a, b) => a.date.compareTo(b.date));
                  realMarketPrices[market.name] = marketPrices.last.priceValue;
                } else if (fallbackPrice > 0 && markets.length <= 5) {
                  // Si pas de relevé spécifique mais marché actif, utiliser le cours fourni
                  realMarketPrices[market.name] = fallbackPrice;
                }
              }

              // Initialisation de la sélection (par défaut tous sélectionnés)
              if (!_isInitialized && realMarketPrices.isNotEmpty) {
                _selectedMarkets.addAll(realMarketPrices.keys.take(4));
                _isInitialized = true;
              }

              // Calcul de la moyenne réelle
              final double avgPrice;
              if (realMarketPrices.isNotEmpty) {
                final values = realMarketPrices.values.toList();
                avgPrice = values.reduce((a, b) => a + b) / values.length;
              } else {
                avgPrice = fallbackPrice > 0 ? fallbackPrice : 0.0;
              }

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(widget.productName, imageAsset, avgPrice),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Marchés réels à comparer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.c.ink)),
                              Text('${realMarketPrices.length} marchés', style: TextStyle(fontSize: 12, color: context.c.ink2, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildMarketChips(realMarketPrices.keys.toList()),
                          const SizedBox(height: 24),
                          if (realMarketPrices.isEmpty) ...[
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text(
                                  "Aucun relevé disponible pour ce produit sur les marchés répertoriés.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: context.c.ink2),
                                ),
                              ),
                            ),
                          ] else if (_selectedMarkets.isNotEmpty) ...[
                            _buildBestMarketAdvice(realMarketPrices, avgPrice),
                            const SizedBox(height: 24),
                            Text('Détails des cotations par marché', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.c.ink)),
                            const SizedBox(height: 12),
                            _buildMarketList(realMarketPrices, avgPrice),
                          ] else ...[
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text("Sélectionnez au moins un marché pour voir la comparaison.", textAlign: TextAlign.center, style: TextStyle(color: context.c.ink2)),
                              ),
                            ),
                          ],
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: context.c.accent)),
            error: (err, _) => Center(child: Text('Erreur cotations : $err')),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: context.c.accent)),
        error: (err, _) => Center(child: Text('Erreur marchés : $err')),
      ),
    );
  }

  Widget _buildSliverAppBar(String productName, String imageAsset, double avgPrice) {
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
              imageAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.primaryDark,
                child: const Center(child: Icon(Icons.storefront, color: Colors.white54, size: 64)),
              ),
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
                    child: const Text('Relevés indicatifs de marché', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          productName,
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Prix moyen relevé', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(
                            avgPrice > 0 ? '${avgPrice.toInt()} FCFA/kg' : 'Prix non renseigné',
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

  /// Sélecteur compact : un résumé des marchés choisis et une liste avec recherche, au lieu d'un mur de pastilles.
  Widget _buildMarketChips(List<String> marketNames) {
    final selected = marketNames.where(_selectedMarkets.contains).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected.isNotEmpty)
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: selected.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(18)),
                child: Text(selected[i], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        if (selected.isNotEmpty) const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openMarketPicker(marketNames),
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: Text(selected.isEmpty ? 'Choisir les marchés' : 'Modifier les marchés (${selected.length} sur ${marketNames.length})'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.c.accent,
            side: BorderSide(color: context.c.accent),
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Future<void> _openMarketPicker(List<String> marketNames) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final q = query.trim().toLowerCase();
            final shown = marketNames.where((m) => q.isEmpty || m.toLowerCase().contains(q)).toList();
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.75,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: context.c.line, borderRadius: BorderRadius.circular(2))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                      child: Row(
                        children: [
                          Expanded(child: Text('Marchés à comparer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.c.ink))),
                          TextButton(
                            onPressed: () {
                              setState(() => _selectedMarkets
                                ..clear()
                                ..addAll(marketNames));
                              setSheet(() {});
                            },
                            child: const Text('Tous'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _selectedMarkets.clear());
                              setSheet(() {});
                            },
                            child: const Text('Aucun'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: TextField(
                        onChanged: (v) => setSheet(() => query = v),
                        decoration: const InputDecoration(hintText: 'Rechercher un marché', prefixIcon: Icon(Icons.search_rounded)),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final name = shown[i];
                          return CheckboxListTile(
                            value: _selectedMarkets.contains(name),
                            activeColor: AppColors.primary,
                            controlAffinity: ListTileControlAffinity.trailing,
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            onChanged: (v) {
                              setState(() => v == true ? _selectedMarkets.add(name) : _selectedMarkets.remove(name));
                              setSheet(() {});
                            },
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: ElevatedButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Valider (${_selectedMarkets.length})')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBestMarketAdvice(Map<String, double> realPrices, double avgPrice) {
    String bestMarket = '';
    double maxPrice = 0.0;

    for (final m in _selectedMarkets) {
      final p = realPrices[m] ?? 0.0;
      if (p > maxPrice) {
        maxPrice = p;
        bestMarket = m;
      }
    }

    final priceDiff = maxPrice - avgPrice;

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
                child: const Icon(Icons.insights, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Opportunité de Vente Naatal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Meilleur cours : $bestMarket (${maxPrice.toInt()} FCFA/kg)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: context.c.ink),
          ),
          const SizedBox(height: 6),
          Text(
            priceDiff > 0
                ? "Le marché de $bestMarket offre la meilleure valorisation actuelle avec +${priceDiff.toInt()} FCFA/kg au-dessus de la moyenne. Privilégiez ce débouché pour vos livraisons."
                : "Les cours sont homogènes sur les marchés sélectionnés. $bestMarket reste un choix solide pour votre écoulement.",
            style: TextStyle(color: context.c.ink2, height: 1.45, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketList(Map<String, double> realPrices, double avgPrice) {
    final sortedMarkets = _selectedMarkets.toList()
      ..sort((a, b) => (realPrices[b] ?? 0).compareTo(realPrices[a] ?? 0));

    return Column(
      children: sortedMarkets.map((market) {
        final price = realPrices[market] ?? 0.0;
        final diff = price - avgPrice;
        final isBest = sortedMarkets.first == market;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isBest ? context.c.accent : context.c.line, width: isBest ? 1.5 : 1.0),
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
                  Icon(Icons.storefront, color: isBest ? context.c.accent : context.c.ink2),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(market, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isBest ? context.c.accent : context.c.ink)),
                          if (isBest) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text('MAX', style: TextStyle(color: context.c.accent, fontSize: 9, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        diff == 0
                            ? 'Conforme à la moyenne'
                            : '${diff > 0 ? '+' : ''}${diff.toInt()} FCFA vs moyenne',
                        style: TextStyle(color: diff > 0 ? Colors.green : (diff < 0 ? Colors.red : Colors.grey), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              Text('${price.toInt()} FCFA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.c.ink)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
