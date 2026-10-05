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

class MarketsScreen extends ConsumerStatefulWidget {
  const MarketsScreen({super.key});

  @override
  ConsumerState<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends ConsumerState<MarketsScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final LatLng _userLocation = const LatLng(14.6928, -17.4467); // Dakar centre (sur terre)
  
  String _selectedProduct = 'Oignon';
  String _activeFilter = 'Tous';
  final List<String> _availableProducts = ['Oignon', 'Tomate', 'Riz', 'Arachide'];
  bool _isMapView = true;

  // Filtre GPS "Autour de moi"
  bool _nearbyFilterActive = false;
  double _nearbyRadiusKm = 20.0; // rayon par défaut en km
  bool _showRadiusSlider = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: false);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    var p = 0.017453292519943295;
    var a = 0.5 - cos((p2.latitude - p1.latitude) * p)/2 + 
            cos(p1.latitude * p) * cos(p2.latitude * p) * 
            (1 - cos((p2.longitude - p1.longitude) * p))/2;
    return 12742 * asin(sqrt(a)); 
  }

  void _centerOnUser() {
    if (_isMapView) {
      _mapController.move(_userLocation, 14.0); // Zoom plus proche sur l'utilisateur
    }
  }
  
  void _zoomIn() {
    if (_isMapView) {
      _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
    }
  }

  void _zoomOut() {
    if (_isMapView) {
      _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketsAsync = ref.watch(marketsListProvider);
    final pricesAsync = ref.watch(pricesListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      body: marketsAsync.when(
        data: (markets) => pricesAsync.when(
          data: (prices) => _buildContent(markets, prices),
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, _) => Center(child: Text('Erreur Prix: $err')),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Erreur Marchés: $err')),
      ),
    );
  }

  Widget _buildContent(List<Market> markets, List<Price> prices) {
    final productPrices = prices.where((p) => p.productName.toLowerCase() == _selectedProduct.toLowerCase()).toList();
    double avgPrice = 0;
    if (productPrices.isNotEmpty) {
      avgPrice = productPrices.map((p) => p.priceValue).reduce((a, b) => a + b) / productPrices.length;
    }

    return Stack(
      children: [
        // CONTENU (Carte ou Liste)
        if (_isMapView)
          _buildMapView(markets, productPrices, avgPrice)
        else
          _buildListView(markets, productPrices, avgPrice),

        // HEADER COMPLETEMENT REFAIT (PROPRE, FOND BLANC)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 16, left: 16, right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5))],
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Ligne 1 : Recherche et toggle
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Rechercher un marché...",
                            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Toggle Carte/Liste
                    Container(
                      height: 48,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSwitchButton(true, Icons.map_rounded),
                          _buildSwitchButton(false, Icons.list_rounded),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Ligne 2 : Filtres
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Dropdown Produit
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3))],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedProduct,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                            dropdownColor: AppColors.primary,
                            isDense: true,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            onChanged: (String? newValue) {
                              if (newValue != null) setState(() => _selectedProduct = newValue);
                            },
                            items: _availableProducts.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.eco_rounded, size: 16, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(value),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildFilterChip('Tous'),
                      _buildFilterChip('Prix', icon: Icons.payments_outlined),
                      _buildFilterChip('Opportunités', icon: Icons.auto_awesome_rounded),
                      const SizedBox(width: 8),
                      // Filtre "Autour de moi"
                      GestureDetector(
                        onTap: () => setState(() {
                          _nearbyFilterActive = !_nearbyFilterActive;
                          _showRadiusSlider = _nearbyFilterActive;
                          if (!_nearbyFilterActive) _showRadiusSlider = false;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _nearbyFilterActive ? Colors.blue.shade700 : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _nearbyFilterActive ? Colors.blue.shade700 : Colors.grey.shade300,
                            ),
                            boxShadow: _nearbyFilterActive
                                ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3))]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.near_me_rounded,
                                size: 14,
                                color: _nearbyFilterActive ? Colors.white : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _nearbyFilterActive
                                    ? '≤ ${_nearbyRadiusKm.toInt()} km'
                                    : 'Autour de moi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _nearbyFilterActive ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Slider de rayon GPS (animé)
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: _showRadiusSlider
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Icon(Icons.radio_button_checked, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Rayon : ${_nearbyRadiusKm.toInt()} km',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              thumbColor: Colors.blue.shade700,
                              activeTrackColor: Colors.blue.shade700,
                              inactiveTrackColor: Colors.blue.shade100,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                            ),
                            child: Slider(
                              min: 5,
                              max: 100,
                              divisions: 19,
                              value: _nearbyRadiusKm,
                              onChanged: (val) => setState(() => _nearbyRadiusKm = val),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, {IconData? icon}) {
    final isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.black87 : Colors.grey.shade300),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.black87),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchButton(bool isMapBtn, IconData icon) {
    final isSelected = _isMapView == isMapBtn;
    return GestureDetector(
      onTap: () {
        if (_isMapView != isMapBtn) setState(() => _isMapView = isMapBtn);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : [],
        ),
        child: Icon(icon, size: 20, color: isSelected ? AppColors.primary : Colors.grey.shade500),
      ),
    );
  }

  Widget _buildMapView(List<Market> markets, List<Price> productPrices, double avgPrice) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation,
            initialZoom: 12.5,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'com.nataalagro.app',
            ),
            // Position utilisateur avec animation Pulse
            MarkerLayer(
              markers: [
                Marker(
                  point: _userLocation,
                  width: 60,
                  height: 60,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 20 + (_pulseAnimation.value * 40),
                            height: 20 + (_pulseAnimation.value * 40),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withValues(alpha: (1 - _pulseAnimation.value) * 0.5),
                            ),
                          ),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            // Marqueurs marchés
            MarkerLayer(
              markers: markets.where((m) => m.latLng != null).map((m) {
                final marketPriceObj = productPrices.where((p) => p.marketId == m.id).firstOrNull;
                final priceVal = marketPriceObj?.priceValue ?? 0;
                
                final isOpportunity = priceVal > avgPrice + 10;
                
                if (_activeFilter == 'Opportunités' && !isOpportunity) {
                  return Marker(point: m.latLng!, width: 0, height: 0, child: const SizedBox());
                }

                // Filtre "Autour de moi" sur la carte
                if (_nearbyFilterActive) {
                  final dist = _calculateDistance(_userLocation, m.latLng!);
                  if (dist > _nearbyRadiusKm) {
                    return Marker(point: m.latLng!, width: 0, height: 0, child: const SizedBox());
                  }
                }

                return Marker(
                  point: m.latLng!,
                  width: 160,
                  height: 80,
                  alignment: Alignment.topCenter,
                  child: AnimatedMarketPin(
                    market: m,
                    marketPriceObj: marketPriceObj,
                    avgPrice: avgPrice,
                    activeFilter: _activeFilter,
                    onTap: () => _showIntelligentBottomSheet(m, marketPriceObj, avgPrice),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Contrôles Google Maps flottants
        Positioned(
          right: 16,
          bottom: 120,
          child: Column(
            children: [
              FloatingActionButton(
                heroTag: 'myLoc',
                mini: true,
                backgroundColor: Colors.white,
                onPressed: _centerOnUser,
                child: const Icon(Icons.my_location_rounded, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                ),
                child: Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.black87),
                      onPressed: _zoomIn,
                    ),
                    Container(height: 1, width: 30, color: Colors.grey.shade200),
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.black87),
                      onPressed: _zoomOut,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Légende (déplacée en bas au centre)
        if (_activeFilter != 'Tous')
          Positioned(
            bottom: 110,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendItem(Colors.green, "Opportunité"),
                    const SizedBox(width: 12),
                    _buildLegendItem(Colors.orange, "Moyen"),
                    const SizedBox(width: 12),
                    _buildLegendItem(Colors.red, "Faible"),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildListView(List<Market> markets, List<Price> productPrices, double avgPrice) {
    // Calculer la distance et la renta pour trier la liste
    List<Market> sortedMarkets = List<Market>.from(markets);
    
    // Appliquer le filtre "Autour de moi" si actif
    if (_nearbyFilterActive) {
      sortedMarkets = sortedMarkets.where((m) {
        if (m.latLng == null) return false;
        return _calculateDistance(_userLocation, m.latLng!) <= _nearbyRadiusKm;
      }).toList();
    }

    sortedMarkets.sort((a, b) {
      if (a.latLng == null || b.latLng == null) return 0;
      final priceA = productPrices.where((p) => p.marketId == a.id).firstOrNull?.priceValue ?? 0;
      final priceB = productPrices.where((p) => p.marketId == b.id).firstOrNull?.priceValue ?? 0;
      // On trie par prix décroissant
      return priceB.compareTo(priceA);
    });

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 130), // Espace pour le header
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: sortedMarkets.length,
              itemBuilder: (context, index) {
                final m = sortedMarkets[index];
                if (m.latLng == null) return const SizedBox.shrink();

                final marketPriceObj = productPrices.where((p) => p.marketId == m.id).firstOrNull;
                final priceVal = marketPriceObj?.priceValue ?? 0;
                
                Color trendColor = Colors.orange;
                String trendText = "Stagnant";
                IconData trendIcon = Icons.trending_flat;

                if (priceVal > 0) {
                  if (priceVal > avgPrice + 10) {
                    trendColor = Colors.green;
                    trendText = "Favorable";
                    trendIcon = Icons.trending_up;
                  } else if (priceVal < avgPrice - 10) {
                    trendColor = Colors.red;
                    trendText = "Défavorable";
                    trendIcon = Icons.trending_down;
                  }
                }

                double distanceKm = _calculateDistance(_userLocation, m.latLng!);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.05),
                  child: InkWell(
                    onTap: () => _showIntelligentBottomSheet(m, marketPriceObj, avgPrice),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: trendColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.storefront, color: trendColor),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text('${distanceKm.toStringAsFixed(1)} km', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                priceVal > 0 ? '${priceVal.toInt()} F' : '-',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: trendColor),
                              ),
                              const SizedBox(height: 6),
                              // Barre dégradé visuel de tendance (vert/rouge)
                              if (priceVal > 0)
                                Container(
                                  width: 80,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    gradient: LinearGradient(
                                      colors: trendColor == Colors.green
                                          ? [Colors.green.shade200, Colors.green.shade600]
                                          : trendColor == Colors.red
                                              ? [Colors.red.shade600, Colors.red.shade200]
                                              : [Colors.orange.shade300, Colors.orange.shade500],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(trendText, style: TextStyle(color: trendColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 4),
                                  Icon(trendIcon, size: 14, color: trendColor),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showIntelligentBottomSheet(Market market, Price? currentPrice, double avgPrice) {
    if (_isMapView) {
      _mapController.move(market.latLng!, 13.0);
    }
    
    double distanceKm = _calculateDistance(_userLocation, market.latLng!);
    int timeMin = (distanceKm * 2.5).round();
    int transportCost = (distanceKm * 500).round();

    final bool isOpportunity = currentPrice != null && currentPrice.priceValue > avgPrice + 10;
    final int priceDiff = currentPrice != null ? (currentPrice.priceValue - avgPrice).toInt() : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  // Drag indicator
                  Center(
                    child: Container(
                      width: 40, height: 5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(market.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: AppColors.primary, size: 16),
                                const SizedBox(width: 4),
                                Text(market.region, style: TextStyle(color: Colors.grey.shade600)),
                                const SizedBox(width: 12),
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text('${market.rating ?? 4.5}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  
                  // Nouveaux indicateurs de fraîcheur et fiabilité
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Icon(Icons.update, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text("Mis à jour il y a 25 min", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          children: [
                            Icon(Icons.verified, size: 14, color: Colors.green),
                            SizedBox(width: 4),
                            Text("Fiabilité Élevée", style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Prix Actuel 
                  if (currentPrice != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedProduct, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            // Tendance textuelle pure
                            Row(
                              children: [
                                Icon(
                                  priceDiff > 0 ? Icons.arrow_upward : (priceDiff < 0 ? Icons.arrow_downward : Icons.arrow_forward), 
                                  size: 16, 
                                  color: priceDiff > 0 ? Colors.green : (priceDiff < 0 ? Colors.red : Colors.orange),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${priceDiff > 0 ? "+" : ""}${((priceDiff/avgPrice)*100).toStringAsFixed(1)} % cette semaine',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: priceDiff > 0 ? Colors.green : (priceDiff < 0 ? Colors.red : Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${currentPrice.priceValue.toInt()} FCFA/kg',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isOpportunity ? Colors.green : Colors.black87),
                            ),
                            Text(
                              'Moyenne régionale : ${avgPrice.toInt()} FCFA',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Opportunité détectée
                  if (isOpportunity)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.green.shade50, Colors.white]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: Colors.green),
                              const SizedBox(width: 8),
                              const Text('Opportunité détectée', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Ce marché affiche un prix supérieur de +$priceDiff FCFA/kg à la moyenne actuelle.',
                            style: const TextStyle(color: Colors.black87),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Pour 500 kg :', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text('≈ +${priceDiff * 500} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (currentPrice != null && priceDiff < 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Prix inférieur à la moyenne ($priceDiff FCFA). La vente n\'est pas recommandée ici.',
                              style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Logistique & Transport
                  const Text('Logistique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildLogisticsCard(Icons.route, 'Distance', '${distanceKm.toStringAsFixed(1)} km')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildLogisticsCard(Icons.timer, 'Temps', '≈ $timeMin min')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildLogisticsCard(Icons.local_shipping, 'Transport', '≈ $transportCost F')),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Boutons d'action
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_car, color: Colors.black87, size: 20),
                              SizedBox(width: 8),
                              Text('Itinéraire', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => MarketDetailScreen(market: market)));
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.read_more_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Voir le marché', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLogisticsCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    var path = Path();
    path.moveTo(0, 0); // Haut gauche
    path.lineTo(size.width, 0); // Haut droite
    path.lineTo(size.width / 2, size.height); // Bas centre
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AnimatedMarketPin extends StatefulWidget {
  final Market market;
  final Price? marketPriceObj;
  final double avgPrice;
  final String activeFilter;
  final VoidCallback onTap;

  const AnimatedMarketPin({
    super.key,
    required this.market,
    required this.marketPriceObj,
    required this.avgPrice,
    required this.activeFilter,
    required this.onTap,
  });

  @override
  State<AnimatedMarketPin> createState() => _AnimatedMarketPinState();
}

class _AnimatedMarketPinState extends State<AnimatedMarketPin> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.market;
    final priceVal = widget.marketPriceObj?.priceValue ?? 0;
    
    final isOpportunity = priceVal > widget.avgPrice + 10;
    final isBad = priceVal < widget.avgPrice - 10;
    
    bool showPrice = (widget.activeFilter == 'Prix' || widget.activeFilter == 'Opportunités') && priceVal > 0;
    
    Color markerBgColor = Colors.grey.shade900;
    Color textColor = Colors.white;
    
    if (showPrice) {
      if (isOpportunity) {
        markerBgColor = Colors.green.shade600;
      } else if (isBad) {
        markerBgColor = Colors.red.shade500;
      } else {
        markerBgColor = Colors.orange.shade500;
      }
    }

    String displayMarketName = m.name.replaceAll('Marché ', '').replaceAll('de ', '');
    if (displayMarketName.length > 8) {
      displayMarketName = '${displayMarketName.substring(0, 7)}.';
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isHovered ? 14 : 10, 
                  vertical: _isHovered ? 8 : 6
                ),
                decoration: BoxDecoration(
                  color: markerBgColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: markerBgColor.withValues(alpha: _isHovered ? 0.6 : 0.4), 
                      blurRadius: _isHovered ? 12 : 8, 
                      offset: Offset(0, _isHovered ? 6 : 4)
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showPrice ? (isOpportunity ? Icons.trending_up : (isBad ? Icons.trending_down : Icons.trending_flat)) : Icons.storefront,
                      color: textColor,
                      size: _isHovered ? 16 : 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      showPrice ? '${priceVal.toInt()} F' : displayMarketName,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: _isHovered ? 15 : 14,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (showPrice) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          displayMarketName,
                          style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.bold),
                        ),
                      )
                    ]
                  ],
                ),
              ),
              CustomPaint(
                size: const Size(12, 6),
                painter: TrianglePainter(color: markerBgColor),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
