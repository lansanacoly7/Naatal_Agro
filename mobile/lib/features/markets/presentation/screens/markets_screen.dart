import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../../core/theme/app_theme.dart';
import '../../data/markets_provider.dart';
import '../../data/models/market.dart';
import '../../data/models/price.dart';
import 'market_detail_screen.dart';

/// Situation d'un marché par rapport à la moyenne du produit sélectionné.
enum _Level { high, mid, low, none }

/// Filtre de situation de prix.
enum _PriceFilter { all, high, low }

const _levelColors = {
  _Level.high: Color(0xFF2E7D32),
  _Level.mid: Color(0xFFEF8F00),
  _Level.low: Color(0xFFC62828),
  _Level.none: Color(0xFF546E7A),
};

class MarketsScreen extends ConsumerStatefulWidget {
  const MarketsScreen({super.key});

  @override
  ConsumerState<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends ConsumerState<MarketsScreen> {
  static const LatLng _userLocation = LatLng(14.6928, -17.4467); // Dakar

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedProduct; // null = aucun produit (marchés seuls)
  bool _productInitialised = false;
  _PriceFilter _priceFilter = _PriceFilter.all;
  bool _isMapView = true;
  String _query = '';

  bool _nearbyActive = false;
  double _radiusKm = 50;
  double _zoom = 7.5;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------- Données ----------

  double _distanceKm(LatLng a, LatLng b) {
    const p = 0.017453292519943295;
    final h = 0.5 -
        cos((b.latitude - a.latitude) * p) / 2 +
        cos(a.latitude * p) * cos(b.latitude * p) * (1 - cos((b.longitude - a.longitude) * p)) / 2;
    return 12742 * asin(sqrt(h));
  }

  /// Dernier prix connu de chaque marché pour le produit sélectionné.
  Map<String, Price> _latestPrices(List<Price> prices) {
    final product = _selectedProduct?.toLowerCase();
    if (product == null) return {};
    final result = <String, Price>{};
    for (final p in prices) {
      if (p.productName.toLowerCase() != product) continue;
      final current = result[p.marketId];
      if (current == null || p.date.compareTo(current.date) > 0) result[p.marketId] = p;
    }
    return result;
  }

  _Level _level(Price? price, double avg) {
    if (price == null || avg <= 0) return _Level.none;
    if (price.priceValue >= avg * 1.05) return _Level.high;
    if (price.priceValue <= avg * 0.95) return _Level.low;
    return _Level.mid;
  }

  /// Marchés filtrés (recherche, GPS, situation de prix).
  List<Market> _visibleMarkets(List<Market> all, Map<String, Price> prices, double avg) {
    final q = _query.trim().toLowerCase();
    return all.where((m) {
      if (m.latLng == null) return false;
      if (q.isNotEmpty && !('${m.name} ${m.region}'.toLowerCase().contains(q))) return false;
      if (_nearbyActive && _distanceKm(_userLocation, m.latLng!) > _radiusKm) return false;
      final level = _level(prices[m.id], avg);
      if (_priceFilter == _PriceFilter.high && level != _Level.high) return false;
      if (_priceFilter == _PriceFilter.low && level != _Level.low) return false;
      return true;
    }).toList();
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final marketsAsync = ref.watch(marketsListProvider);
    final pricesAsync = ref.watch(pricesListProvider);
    final productsAsync = ref.watch(allProductsProvider);

    if (marketsAsync.isLoading || pricesAsync.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    final error = marketsAsync.error ?? pricesAsync.error;
    if (error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                const Text('Impossible de charger les marchés', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text('$error', textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(marketsListProvider);
                    ref.invalidate(pricesListProvider);
                  },
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final markets = marketsAsync.value ?? [];
    final prices = pricesAsync.value ?? [];

    // Catalogue complet : produits de l'application + produits ayant des prix
    final names = <String>{
      ...?productsAsync.value?.map((p) => p.name.trim()),
      ...prices.map((p) => p.productName.trim()),
    }..removeWhere((n) => n.isEmpty);
    final products = names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (!_productInitialised && products.isNotEmpty) {
      _productInitialised = true;
      _selectedProduct = products.firstWhere((n) => n.toLowerCase() == 'oignon', orElse: () => products.first);
    }

    final latest = _latestPrices(prices);
    final avg = latest.isEmpty ? 0.0 : latest.values.map((p) => p.priceValue).reduce((a, b) => a + b) / latest.length;
    final visible = _visibleMarkets(markets, latest, avg);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(products, latest.length, avg),
            Expanded(
              child: _isMapView
                  ? _buildMap(visible, latest, avg)
                  : _buildList(visible, latest, avg),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Barre du haut ----------

  Widget _buildTopBar(List<String> products, int pricedCount, double avg) {
    return Material(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un marché ou une région',
                        hintStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(() {
                                  _searchController.clear();
                                  _query = '';
                                }),
                              ),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    selectedBackgroundColor: AppColors.primary,
                    selectedForegroundColor: Colors.white,
                  ),
                  segments: const [
                    ButtonSegment(value: true, icon: Icon(Icons.map_outlined, size: 18)),
                    ButtonSegment(value: false, icon: Icon(Icons.view_list_outlined, size: 18)),
                  ],
                  selected: {_isMapView},
                  onSelectionChanged: (s) => setState(() => _isMapView = s.first),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip(
                    icon: Icons.eco_outlined,
                    label: _selectedProduct ?? 'Produit',
                    selected: true,
                    trailing: Icons.expand_more,
                    onTap: () => _pickProduct(products),
                  ),
                  _chip(
                    label: 'Tous',
                    selected: _priceFilter == _PriceFilter.all,
                    onTap: () => setState(() => _priceFilter = _PriceFilter.all),
                  ),
                  _chip(
                    label: 'Prix élevés',
                    dot: _levelColors[_Level.high],
                    selected: _priceFilter == _PriceFilter.high,
                    onTap: () => setState(() => _priceFilter = _PriceFilter.high),
                  ),
                  _chip(
                    label: 'Prix bas',
                    dot: _levelColors[_Level.low],
                    selected: _priceFilter == _PriceFilter.low,
                    onTap: () => setState(() => _priceFilter = _PriceFilter.low),
                  ),
                  _chip(
                    icon: Icons.near_me_outlined,
                    label: _nearbyActive ? 'Rayon ${_radiusKm.round()} km' : 'Autour de moi',
                    selected: _nearbyActive,
                    onTap: _toggleNearby,
                  ),
                ],
              ),
            ),
            if (_selectedProduct != null && pricedCount > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$_selectedProduct · moyenne ${avg.round()} FCFA/kg sur $pricedCount marchés',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip({
    IconData? icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? dot,
    IconData? trailing,
  }) {
    final fg = selected ? Colors.white : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.primary : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : const Color(0xFFD0D5DA))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dot != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: selected ? Colors.white : dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
                if (trailing != null) ...[const SizedBox(width: 2), Icon(trailing, size: 18, color: fg)],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleNearby() {
    if (_nearbyActive) {
      setState(() => _nearbyActive = false);
      return;
    }
    setState(() => _nearbyActive = true);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rayon de recherche : ${_radiusKm.round()} km',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Slider(
                min: 5,
                max: 500,
                divisions: 99,
                value: _radiusKm,
                label: '${_radiusKm.round()} km',
                onChanged: (v) {
                  setSheet(() => _radiusKm = v);
                  setState(() => _radiusKm = v);
                },
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() => _nearbyActive = false);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Désactiver'),
                  ),
                  const Spacer(),
                  FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Appliquer')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sélecteur de produit : tous les produits de l'application, avec recherche.
  void _pickProduct(List<String> products) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        var filter = '';
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final shown = products.where((p) => p.toLowerCase().contains(filter.toLowerCase())).toList();
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.75,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Choisir un produit', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        ),
                        Text('${products.length} produits', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: false,
                      onChanged: (v) => setSheet(() => filter = v),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un produit',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: AppColors.background,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: shown.isEmpty
                          ? const Center(child: Text('Aucun produit trouvé', style: TextStyle(color: AppColors.textSecondary)))
                          : ListView.separated(
                              itemCount: shown.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final name = shown[i];
                                final selected = name == _selectedProduct;
                                return ListTile(
                                  dense: true,
                                  title: Text(name, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                                  trailing: selected ? const Icon(Icons.check, color: AppColors.primary) : null,
                                  onTap: () {
                                    setState(() => _selectedProduct = name);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
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

  // ---------- Carte ----------

  Widget _buildMap(List<Market> visible, Map<String, Price> latest, double avg) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation,
            initialZoom: 7.5,
            minZoom: 5,
            maxZoom: 18,
            onPositionChanged: (camera, _) {
              if ((camera.zoom - _zoom).abs() > 0.05) setState(() => _zoom = camera.zoom);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'com.nataalagro.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _userLocation,
                  width: 22,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                ),
              ],
            ),
            MarkerLayer(
              markers: _declutter(visible, latest, avg).map((g) {
                final m = g.market;
                final price = latest[m.id];
                final level = _level(price, avg);
                return Marker(
                  point: m.latLng!,
                  width: 96,
                  height: 58,
                  alignment: Alignment.topCenter,
                  child: _MarketPin(
                    color: _levelColors[level]!,
                    label: price != null ? '${price.priceValue.round()} F' : null,
                    extra: g.hidden,
                    onTap: () => g.hidden > 0
                        ? _mapController.move(m.latLng!, min(_zoom + 2, 18))
                        : _showMarketSheet(m, price, avg),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        Positioned(
          right: 12,
          bottom: 16,
          child: Column(
            children: [
              _mapButton(Icons.my_location, () => _mapController.move(_userLocation, 11)),
              const SizedBox(height: 8),
              _mapButton(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
              const SizedBox(height: 8),
              _mapButton(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
            ],
          ),
        ),
        Positioned(left: 12, bottom: 16, child: _buildLegend(visible.length)),
        if (visible.isEmpty)
          const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucun marché ne correspond à ces filtres'),
              ),
            ),
          ),
      ],
    );
  }

  /// Évite les superpositions : à un zoom donné, un marché trop proche d'un marché
  /// déjà affiché est regroupé avec lui (badge +N). Les marchés avec prix passent en premier.
  List<({Market market, int hidden})> _declutter(List<Market> markets, Map<String, Price> latest, double avg) {
    final pxPerDeg = 256 * pow(2, _zoom) / 360;
    final sorted = [...markets]..sort((a, b) => (latest[b.id]?.priceValue ?? 0).compareTo(latest[a.id]?.priceValue ?? 0));
    final kept = <({Market market, int hidden})>[];
    final hiddenCount = <String, int>{};
    for (final m in sorted) {
      final p = m.latLng!;
      Market? near;
      for (final k in kept) {
        final q = k.market.latLng!;
        final dx = (p.longitude - q.longitude) * pxPerDeg;
        final dy = (p.latitude - q.latitude) * pxPerDeg * 1.1;
        if (dx.abs() < 60 && dy.abs() < 50) {
          near = k.market;
          break;
        }
      }
      if (near != null) {
        hiddenCount[near.id] = (hiddenCount[near.id] ?? 0) + 1;
      } else {
        kept.add((market: m, hidden: 0));
      }
    }
    return kept.map((k) => (market: k.market, hidden: hiddenCount[k.market.id] ?? 0)).toList();
  }

  Widget _mapButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: AppColors.textPrimary)),
      ),
    );
  }

  Widget _buildLegend(int count) {
    Widget row(Color c, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(t, style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count marché${count > 1 ? 's' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            row(_levelColors[_Level.high]!, 'Au-dessus de la moyenne'),
            row(_levelColors[_Level.mid]!, 'Proche de la moyenne'),
            row(_levelColors[_Level.low]!, 'Sous la moyenne'),
            row(_levelColors[_Level.none]!, 'Pas de prix'),
          ],
        ),
      ),
    );
  }

  // ---------- Liste ----------

  Widget _buildList(List<Market> visible, Map<String, Price> latest, double avg) {
    final items = [...visible]..sort((a, b) {
        final pa = latest[a.id]?.priceValue ?? -1;
        final pb = latest[b.id]?.priceValue ?? -1;
        return pb.compareTo(pa);
      });

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(marketsListProvider);
        ref.invalidate(pricesListProvider);
        ref.invalidate(allProductsProvider);
      },
      child: items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Aucun marché ne correspond à ces filtres', style: TextStyle(color: AppColors.textSecondary))),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final m = items[i];
                final price = latest[m.id];
                final level = _level(price, avg);
                final color = _levelColors[level]!;
                final km = _distanceKm(_userLocation, m.latLng!);
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showMarketSheet(m, price, avg),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(width: 4, height: 40, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text('${m.region} · ${km.toStringAsFixed(0)} km',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                            price != null ? '${price.priceValue.round()} F/kg' : '—',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ---------- Détail ----------

  void _showMarketSheet(Market market, Price? price, double avg) {
    final km = _distanceKm(_userLocation, market.latLng!);
    final level = _level(price, avg);
    final color = _levelColors[level]!;
    final diff = price != null && avg > 0 ? (price.priceValue - avg) / avg * 100 : null;
    final verdict = switch (level) {
      _Level.high => 'Prix supérieur à la moyenne : bon marché pour vendre.',
      _Level.low => 'Prix inférieur à la moyenne : vente peu avantageuse.',
      _Level.mid => 'Prix proche de la moyenne du marché.',
      _Level.none => 'Aucun prix relevé pour ce produit sur ce marché.',
    };

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(market.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('${market.region} · ${km.toStringAsFixed(0)} km de vous',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedProduct ?? 'Produit', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(
                          price != null ? '${price.priceValue.round()} FCFA/kg' : 'Non disponible',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
                        ),
                      ],
                    ),
                  ),
                  if (diff != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)} %',
                            style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                        Text('moy. ${avg.round()} F', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(verdict, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MarketDetailScreen(market: market)));
                },
                child: const Text('Voir le marché'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Repère de marché : pastille colorée + étiquette de prix.
class _MarketPin extends StatelessWidget {
  final Color color;
  final String? label;
  final int extra;
  final VoidCallback onTap;

  const _MarketPin({required this.color, required this.label, required this.onTap, this.extra = 0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: extra > 0
                ? Center(child: Text('+$extra', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)))
                : const Icon(Icons.storefront, size: 14, color: Colors.white),
          ),
          if (label != null)
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
              ),
              child: Text(label!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
            ),
        ],
      ),
    );
  }
}
