import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui/appearance.dart';
import '../../ui/map_tiles.dart';
import 'package:latlong2/latlong.dart';

import '../../core/location/location_access.dart' show locationFixLabel;
import '../../core/location/senegal_regions.dart';
import '../../features/dashboard/data/dashboard_provider.dart';
import '../../features/markets/data/markets_provider.dart';
import '../../features/profile/data/profile_provider.dart';
import '../../ui/map_cluster.dart';
import '../../ui/senegal_map.dart';
import '../../ui/ui.dart';
import 'market_sheet.dart';
import 'markets_data.dart';

/// Situation d'un marché par rapport à la moyenne du produit.
enum PriceLevel { high, mid, low }

PriceLevel levelOf(double price, double average) {
  if (price >= average * 1.05) return PriceLevel.high;
  if (price <= average * 0.95) return PriceLevel.low;
  return PriceLevel.mid;
}

Color levelColor(BuildContext context, PriceLevel level) {
  final c = context.c;
  return switch (level) {
    PriceLevel.high => c.accent,
    PriceLevel.mid => const Color(0xFFC98A1E),
    PriceLevel.low => c.clay,
  };
}

/// Carte et classement des marchés pour un produit. Les prix viennent des relevés
/// enregistrés (dernier relevé par marché) : aucun prix n'est inventé.
class MarketsScreen extends ConsumerStatefulWidget {
  const MarketsScreen({super.key});

  @override
  ConsumerState<MarketsScreen> createState() => _MarketsScreenState();
}

enum _Sort { priceDesc, priceAsc, distance }

class _MarketsScreenState extends ConsumerState<MarketsScreen> {
  final MapController _map = MapController();
  String? _product;
  _Sort _sort = _Sort.priceDesc;
  String? _fittedFor;
  bool _locateStarted = false;
  double _zoom = 7.2;

  /// Marchés montrés autour de la personne : ceux à moins de 50 km, les 6 plus proches au plus.
  static const _nearbyKm = 50.0;
  static const _nearbyMax = 6;

  @override
  void initState() {
    super.initState();
    // Dès l'ouverture, on cherche où se trouve la personne pour zoomer sur sa localité
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final location = ref.read(userLocationProvider);
      if (location.position == null && !location.loading) ref.read(userLocationProvider.notifier).locate();
      setState(() => _locateStarted = true);
    });
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  /// Région du profil (repli quand la position n'est pas connue), si elle est reconnue.
  SenegalRegion? _profileRegion() {
    final text = ref.read(profileNotifierProvider).valueOrNull?.location;
    return text == null || text.trim().isEmpty ? null : SenegalRegions.fromName(text);
  }

  String? _defaultProduct(List<String> catalog) {
    if (catalog.isEmpty) return null;
    final mine = ref.read(dashboardDataProvider).valueOrNull?.markets.map((m) => m.productName.toLowerCase()).toList() ?? const [];
    for (final name in catalog) {
      if (mine.contains(name.toLowerCase())) return name;
    }
    return catalog.first;
  }

  Future<void> _pickProduct(List<String> catalog) async {
    final chosen = await showNaatalSheet<String>(
      context,
      builder: (ctx) => _ProductPicker(names: catalog, selected: _product),
    );
    if (chosen != null) setState(() => _product = chosen);
  }

  /// Cadre la carte sur la personne et les marchés autour d'elle. Sans position : sur sa région si on la connaît,
  /// sinon sur l'ensemble des marchés.
  void _fit(List<MarketQuote> quotes, UserLocation location) {
    final me = location.position != null && isInSenegal(location.position!) ? location.position : null;
    if (me == null && (!_locateStarted || location.loading)) return; // on attend la position
    final key = '$_product-${quotes.length}-${me != null}';
    if (_fittedFor == key) return;

    final List<LatLng> points;
    if (me != null) {
      final near = [
        for (final q in quotes)
          if (q.position != null && _km(me, q.position)! <= _nearbyKm) q,
      ]..sort((a, b) => _km(me, a.position)!.compareTo(_km(me, b.position)!));
      points = [me, for (final q in near.take(_nearbyMax)) q.position!];
    } else if (_profileRegion() != null) {
      return; // la carte est déjà ouverte sur la région du profil
    } else {
      points = [for (final q in quotes) if (q.position != null) q.position!];
    }
    if (points.isEmpty) return;
    _fittedFor = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _map.fitCamera(CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(48, 130, 48, 360),
          maxZoom: points.length == 1 ? 12 : 13,
        ));
      } catch (_) {
        // La carte n'est pas encore prête : le cadrage se refera au prochain affichage.
        _fittedFor = null;
      }
    });
  }

  double? _km(LatLng? me, LatLng? to) {
    if (me == null || to == null) return null;
    return const Distance().as(LengthUnit.Kilometer, me, to).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final catalogAsync = ref.watch(allProductsProvider);
    final catalog = catalogAsync.valueOrNull?.map((p) => p.name.trim()).where((n) => n.isNotEmpty).toSet().toList() ?? <String>[];
    catalog.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _product ??= _defaultProduct(catalog);
    final product = _product;
    final location = ref.watch(userLocationProvider);

    final quotesAsync = product == null ? const AsyncValue<List<MarketQuote>>.data([]) : ref.watch(marketQuotesProvider(product));
    final quotes = quotesAsync.valueOrNull ?? const <MarketQuote>[];
    final average = quotes.isEmpty ? 0.0 : quotes.map((q) => q.price).reduce((a, b) => a + b) / quotes.length;
    if (quotes.isNotEmpty) _fit(quotes, location);
    final me = location.position != null && isInSenegal(location.position!) ? location.position : null;
    final region = _profileRegion();
    final initials = ref.watch(profileNotifierProvider).valueOrNull?.initials;

    final sorted = [...quotes]..sort((a, b) {
        switch (_sort) {
          case _Sort.priceDesc:
            return b.price.compareTo(a.price);
          case _Sort.priceAsc:
            return a.price.compareTo(b.price);
          case _Sort.distance:
            final da = _km(location.position, a.position) ?? double.infinity;
            final db = _km(location.position, b.position) ?? double.infinity;
            return da.compareTo(db);
        }
      });

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(builder: (context, box) {
              // Dézoom limité : l'écran ne peut jamais montrer autre chose que le Sénégal
              final minZoom = senegalFitZoom(box.biggest);
              return LightOnly(child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                // Ouverte sur la région de la personne si on la connaît, puis recadrée sur sa position
                initialCenter: region != null ? LatLng(region.lat, region.lon) : const LatLng(14.5, -14.5),
                initialZoom: math.max(region != null ? 10 : 7.2, minZoom),
                minZoom: minZoom,
                // La carte ne tourne jamais : on zoome et on se déplace, c'est tout
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                maxZoom: 17,
                cameraConstraint: senegalCameraConstraint,
                onPositionChanged: (camera, _) {
                  if ((camera.zoom - _zoom).abs() >= 0.1) setState(() => _zoom = camera.zoom);
                },
              ),
              children: [
                const NaatalTileLayer(),
                // Voile : rien n'est visible hors du Sénégal
                const SenegalMask(),
                MarkerLayer(
                  markers: [
                    // Les marchés qui se chevaucheraient sont comptés dans une bulle ; en zoomant, ils se séparent
                    for (final cluster in clusterByGrid(
                      [for (final q in quotes) if (q.position != null) q],
                      (q) => q.position!,
                      _zoom,
                    ))
                      if (cluster.isSingle)
                        Marker(
                          point: cluster.center, // position exacte du marché
                          width: 92,
                          height: _Pin.height,
                          alignment: Alignment.topCenter, // la pointe de la balise est sur le marché
                          child: _Pin(
                            label: '${Fmt.grouped(cluster.items.first.price)} F',
                            color: levelColor(context, levelOf(cluster.items.first.price, average)),
                            onTap: () => showMarketSheet(context,
                                quote: cluster.items.first, average: average, distanceKm: _km(location.position, cluster.items.first.position)),
                          ),
                        )
                      else
                        Marker(
                          point: cluster.center,
                          width: 60,
                          height: 60,
                          child: _ClusterBubble(
                            count: cluster.items.length,
                            onTap: () => _map.fitCamera(CameraFit.coordinates(
                              coordinates: [for (final q in cluster.items) q.position!],
                              padding: const EdgeInsets.all(80),
                              maxZoom: 15,
                            )),
                          ),
                        ),
                    // Avatar de la personne, au-dessus des marchés
                    if (me != null)
                      Marker(
                        point: me,
                        width: UserAvatarPin.markerWidth,
                        height: UserAvatarPin.markerHeight,
                        alignment: Alignment.topCenter,
                        child: UserAvatarPin(initials: initials),
                      ),
                  ],
                ),
                SimpleAttributionWidget(source: Text(NaatalTileLayer.attribution)),
              ],
              ));
            }),
          ),
          // En-tête en verre : produit, localisation
          Positioned(
            left: Space.l,
            right: Space.l,
            top: MediaQuery.paddingOf(context).top + Space.s,
            child: Row(
              children: [
                Expanded(
                  child: PressScale(
                    onTap: catalog.isEmpty ? null : () => _pickProduct(catalog),
                    semanticLabel: 'Choisir un produit',
                    child: Glass(
                      strong: true,
                      radius: Radii.pill,
                      padding: const EdgeInsets.symmetric(horizontal: Space.l),
                      child: SizedBox(
                        height: 56,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 34,
                                height: 34,
                                color: c.accent.withValues(alpha: 0.12),
                                child: Image.asset(
                                  productImageForName(product ?? ''),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(Icons.eco_rounded, size: 20, color: c.accent),
                                ),
                              ),
                            ),
                            const SizedBox(width: Space.s + 2),
                            Expanded(
                              child: Text(product ?? 'Choisir un produit', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(color: c.ink, weight: 700)),
                            ),
                            Icon(Icons.expand_more_rounded, color: c.ink2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Space.s),
                PressScale(
                  onTap: location.loading
                      ? null
                      : () {
                          if (me == null) {
                            final notifier = ref.read(userLocationProvider.notifier);
                            location.needsFix ? notifier.enable() : notifier.locate();
                          } else {
                            _map.move(me, 13); // revient sur la personne
                          }
                        },
                  semanticLabel: 'Autour de moi',
                  child: Glass(
                    strong: true,
                    radius: Radii.pill,
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: location.loading
                          ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2.5))
                          : Icon(me == null ? Icons.my_location_outlined : Icons.my_location_rounded, color: me == null ? c.ink : c.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (location.error != null)
            Positioned(
              left: Space.l,
              right: Space.l,
              top: MediaQuery.paddingOf(context).top + 52 + Space.m + Space.s,
              child: Glass(
                strong: true,
                radius: Radii.m,
                padding: const EdgeInsets.all(Space.m),
                child: Row(
                  children: [
                    Icon(Icons.location_off_rounded, size: 18, color: c.clay),
                    const SizedBox(width: Space.s),
                    Expanded(child: Text(location.error!, style: T.caption(color: c.ink, weight: 600))),
                    if (location.needsFix) ...[
                      const SizedBox(width: Space.s),
                      PillButton(
                        label: locationFixLabel(location.access!),
                        onPressed: () => ref.read(userLocationProvider.notifier).enable(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          // Classement : feuille déplaçable
          DraggableScrollableSheet(
            initialChildSize: 0.34,
            minChildSize: 0.16,
            maxChildSize: 0.86,
            snap: true,
            snapSizes: const [0.16, 0.34, 0.86],
            builder: (context, controller) => _RankingSheet(
              controller: controller,
              product: product,
              loading: quotesAsync.isLoading || catalogAsync.isLoading,
              error: quotesAsync.hasError || catalogAsync.hasError,
              onRetry: () {
                ref.invalidate(allProductsProvider);
                if (product != null) ref.invalidate(marketQuotesProvider(product));
              },
              quotes: sorted,
              average: average,
              sort: _sort,
              onSort: (s) {
                if (s == _Sort.distance && location.position == null) {
                  final notifier = ref.read(userLocationProvider.notifier);
                  location.needsFix ? notifier.enable() : notifier.locate();
                }
                setState(() => _sort = s);
              },
              distanceOf: (q) => _km(location.position, q.position),
              onOpen: (q) {
                if (q.position != null) _map.move(q.position!, math.max(_map.camera.zoom, 10));
                showMarketSheet(context, quote: q, average: average, distanceKm: _km(location.position, q.position));
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bulle qui compte les marchés regroupés au zoom courant ; toucher la bulle zoome pour les séparer.
class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.accent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Text('$count', style: T.number(20, color: c.onAccent)),
        ),
      ),
    );
  }
}

/// Balise d'un marché : le prix dans une étiquette, au-dessus d'une punaise dont la pointe est sur le marché.
class _Pin extends StatelessWidget {
  const _Pin({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  static const double _pinSize = 36;

  /// Hauteur du `Marker` : étiquette, espace et punaise.
  static final double height = 26 + 3 + MapPin.heightFor(_pinSize);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Text(label, style: T.caption(color: c.ink, weight: 800).copyWith(fontSize: 12)),
          ),
          const SizedBox(height: 3),
          MapPin(
            color: color,
            size: _pinSize,
            child: const Icon(Icons.storefront_rounded, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _RankingSheet extends StatelessWidget {
  const _RankingSheet({
    required this.controller,
    required this.product,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.quotes,
    required this.average,
    required this.sort,
    required this.onSort,
    required this.distanceOf,
    required this.onOpen,
  });

  final ScrollController controller;
  final String? product;
  final bool loading;
  final bool error;
  final VoidCallback onRetry;
  final List<MarketQuote> quotes;
  final double average;
  final _Sort sort;
  final ValueChanged<_Sort> onSort;
  final double? Function(MarketQuote) distanceOf;
  final ValueChanged<MarketQuote> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final newest = quotes.map((q) => q.date).whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, -6))],
      ),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.only(bottom: Space.navClearance),
        physics: const ClampingScrollPhysics(),
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: Space.s + 2, bottom: Space.m),
              width: 42,
              height: 5,
              decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(9)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (product != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: c.accent.withValues(alpha: 0.12),
                      child: Image.asset(
                        productImageForName(product!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.eco_rounded, size: 24, color: c.accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.m),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product == null ? 'Marchés' : '$product', style: T.title(color: c.ink)),
                      Text(
                        quotes.isEmpty
                            ? 'Aucun relevé'
                            : '${quotes.length} marché${quotes.length > 1 ? 's' : ''}${newest == null ? '' : ' · relevé du ${Fmt.shortDay(newest)}'}',
                        style: T.caption(color: c.ink2, weight: 500),
                      ),
                    ],
                  ),
                ),
                if (quotes.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Moyenne', style: T.caption(color: c.ink2, weight: 500)),
                      Text('${Fmt.grouped(average)} F/kg', style: T.figure(color: c.ink, weight: 800)),
                    ],
                  ),
              ],
            ),
          ),
          if (quotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, Space.s),
              child: Row(
                children: [
                  _Chip(label: 'Prix haut', selected: sort == _Sort.priceDesc, onTap: () => onSort(_Sort.priceDesc)),
                  const SizedBox(width: Space.s),
                  _Chip(label: 'Prix bas', selected: sort == _Sort.priceAsc, onTap: () => onSort(_Sort.priceAsc)),
                  const SizedBox(width: Space.s),
                  _Chip(label: 'Plus proches', selected: sort == _Sort.distance, onTap: () => onSort(_Sort.distance)),
                ],
              ),
            ),
          if (loading && quotes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.m),
              child: Column(children: [Skeleton(height: 60, radius: 16), SizedBox(height: Space.s), Skeleton(height: 60, radius: 16)]),
            )
          else if (error && quotes.isEmpty)
            ErrorState(compact: true, message: 'Les prix n\'ont pas pu être chargés.', onRetry: onRetry)
          else if (quotes.isEmpty)
            EmptyState(
              compact: true,
              icon: Icons.storefront_rounded,
              title: 'Aucun relevé de prix',
              message: product == null
                  ? 'Aucun produit n\'est disponible pour le moment.'
                  : 'Aucun marché n\'a de prix enregistré pour $product.',
            )
          else ...[
            GroupedList(
              children: [
                for (final q in quotes)
                  GroupedRow(
                    minHeight: 56,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: levelColor(context, levelOf(q.price, average)), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.storefront_rounded, size: 20, color: Colors.white),
                    ),
                    title: q.marketName,
                    subtitle: [
                      if (q.region.isNotEmpty) q.region,
                      if (distanceOf(q) != null) '${distanceOf(q)!.round()} km',
                    ].join(' · '),
                    value: '${Fmt.grouped(q.price)} F',
                    valueColor: levelColor(context, levelOf(q.price, average)),
                    chevron: true,
                    onTap: () => onOpen(q),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter + 4, Space.s, Space.gutter, 0),
              child: Text('Relevés indicatifs, non officiels. Vert : au-dessus de la moyenne. Rouge : en dessous.', style: T.caption(color: c.ink2, weight: 500)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.out,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? c.accent : c.line),
        ),
        child: Text(label, style: T.caption(color: selected ? c.onAccent : c.ink, weight: 700)),
      ),
    );
  }
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.names, required this.selected});

  final List<String> names;
  final String? selected;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final shown = widget.names.where((n) => n.toLowerCase().contains(_query.toLowerCase())).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choisir un produit', style: T.title(color: c.ink)),
                const SizedBox(height: Space.m),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(hintText: 'Rechercher : oignon, piment, arachide...', prefixIcon: Icon(Icons.search_rounded)),
                ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? const EmptyState(compact: true, icon: Icons.search_off_rounded, title: 'Aucun produit', message: 'Essayez un autre nom.')
                : ListView(
                    padding: const EdgeInsets.only(bottom: Space.xl),
                    children: [
                      GroupedList(
                        children: [
                          for (final n in shown)
                            GroupedRow(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  color: c.accent.withValues(alpha: 0.08),
                                  child: Image.asset(
                                    productImageForName(n),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(Icons.eco_rounded, size: 22, color: c.accent),
                                  ),
                                ),
                              ),
                              title: n,
                              minHeight: 56,
                              trailing: n == widget.selected ? Icon(Icons.check_circle_rounded, color: c.accent, size: 22) : null,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.pop(context, n);
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
