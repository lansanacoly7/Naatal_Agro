import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../ui/ui.dart';
import '../../../markets/data/models/market.dart';
import '../../data/map_provider.dart';
import '../../data/models/map_marker_item.dart';

/// Écran Cartographique Interactif Naatal Agro
/// Visualisation géolocalisée des marchés agricoles et des parcelles de l'exploitant au Sénégal.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.initialMarket});

  final Market? initialMarket;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  static const LatLng _senegalCenter = LatLng(14.4974, -14.4524);
  static const double _defaultZoom = 7.2;

  MapMarkerItem? _selectedItem;
  String _searchQuery = '';
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMarket != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pos = widget.initialMarket!.latLng;
        if (pos != null) {
          _mapController.move(pos, 13.0);
          setState(() {
            _selectedItem = MapMarkerItem(
              id: 'market_${widget.initialMarket!.id}',
              title: widget.initialMarket!.name,
              subtitle: 'Marché · ${widget.initialMarket!.region}',
              position: pos,
              type: MapMarkerType.market,
              market: widget.initialMarket,
              detailText: 'Horaires : ${widget.initialMarket!.openingTime?.substring(0, 5) ?? "08:00"} - ${widget.initialMarket!.closingTime?.substring(0, 5) ?? "18:00"}',
            );
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Autorisation de géolocalisation refusée.')),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez activer la localisation dans les paramètres.')),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final userLatLng = LatLng(pos.latitude, pos.longitude);
      _mapController.move(userLatLng, 13.5);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Position actuelle localisée avec succès.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'obtenir la position : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _resetToSenegal() {
    _mapController.move(_senegalCenter, _defaultZoom);
    setState(() => _selectedItem = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final markersAsync = ref.watch(mapMarkersProvider);
    final activeFilter = ref.watch(mapFilterProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Carte interactive', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: c.surface,
        foregroundColor: c.ink,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Vue globale Sénégal',
            icon: const Icon(Icons.public_rounded),
            onPressed: _resetToSenegal,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Fond de Carte OpenStreetMap
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _senegalCenter,
                initialZoom: _defaultZoom,
                minZoom: 6.0,
                maxZoom: 18.0,
                onTap: (_, __) {
                  if (_selectedItem != null) {
                    setState(() => _selectedItem = null);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'sn.isep.naatal_agro',
                  maxZoom: 19,
                ),
                // Layer des Marqueurs
                markersAsync.when(
                  data: (markers) {
                    final filtered = markers.where((m) {
                      if (_searchQuery.trim().isEmpty) return true;
                      final q = _searchQuery.toLowerCase();
                      return m.title.toLowerCase().contains(q) || m.subtitle.toLowerCase().contains(q);
                    }).toList();

                    return MarkerLayer(
                      markers: filtered.map((item) {
                        final isSelected = _selectedItem?.id == item.id;
                        final isMarket = item.isMarket;
                        final color = isMarket ? const Color(0xFF1B5E20) : const Color(0xFFE65100);

                        return Marker(
                          point: item.position,
                          width: isSelected ? 56 : 44,
                          height: isSelected ? 56 : 44,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedItem = item);
                              _mapController.move(item.position, 12.0);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.45),
                                    blurRadius: isSelected ? 12 : 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  isMarket ? Icons.storefront_rounded : Icons.grass_rounded,
                                  color: Colors.white,
                                  size: isSelected ? 28 : 20,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // 2. Barre de Recherche et Filtres Flottants
          Positioned(
            top: Space.m,
            left: Space.m,
            right: Space.m,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Champ de recherche
                Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(Radii.l),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: T.body(color: c.ink),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un marché ou une parcelle…',
                      hintStyle: T.body(color: c.ink2),
                      prefixIcon: Icon(Icons.search_rounded, color: c.ink2),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: Space.s),

                // Filtres Catégories
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tous', MapFilter.all, activeFilter),
                      const SizedBox(width: Space.s),
                      _buildFilterChip('Marchés du Sénégal', MapFilter.markets, activeFilter, icon: Icons.storefront_rounded),
                      const SizedBox(width: Space.s),
                      _buildFilterChip('Mes Parcelles', MapFilter.crops, activeFilter, icon: Icons.grass_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Bouton Flottant de Géolocalisation
          Positioned(
            right: Space.m,
            bottom: _selectedItem != null ? 220 : Space.l,
            child: FloatingActionButton(
              heroTag: 'map_gps_btn',
              backgroundColor: c.surface,
              foregroundColor: c.accent,
              elevation: 4,
              onPressed: _isLocating ? null : _locateUser,
              child: _isLocating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),

          // 4. Carte d'Information Modale lors de la Sélection d'un Marqueur
          if (_selectedItem != null)
            Positioned(
              left: Space.m,
              right: Space.m,
              bottom: Space.l,
              child: _buildItemCard(context, _selectedItem!),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, MapFilter filter, MapFilter activeFilter, {IconData? icon}) {
    final c = context.c;
    final isSelected = filter == activeFilter;
    return GestureDetector(
      onTap: () => ref.read(mapFilterProvider.notifier).state = filter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isSelected ? c.onAccent : c.ink),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: T.caption(
                color: isSelected ? c.onAccent : c.ink,
                weight: 700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, MapMarkerItem item) {
    final c = context.c;
    final isMarket = item.isMarket;
    final themeColor = isMarket ? const Color(0xFF1B5E20) : const Color(0xFFE65100);

    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isMarket ? Icons.storefront_rounded : Icons.grass_rounded,
                    color: themeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: T.title(color: c.ink)),
                      Text(item.subtitle, style: T.caption(color: c.ink2, weight: 600)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _selectedItem = null),
                ),
              ],
            ),
            if (item.detailText != null) ...[
              const SizedBox(height: Space.m),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.m),
                ),
                child: Text(item.detailText!, style: T.body(color: c.ink)),
              ),
            ],
            const SizedBox(height: Space.l),
            ElevatedButton.icon(
              onPressed: () {
                if (item.isMarket && item.market != null) {
                  context.push('/market-detail', extra: item.market);
                } else if (item.isCrop && item.crop != null) {
                  context.push('/crop_detail', extra: item.crop);
                }
              },
              icon: Icon(isMarket ? Icons.shopping_basket_outlined : Icons.visibility_outlined),
              label: Text(
                isMarket ? 'Consulter les cotations du marché' : 'Accéder à la parcelle',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.m)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
