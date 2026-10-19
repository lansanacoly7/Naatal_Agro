import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../features/dashboard/data/dashboard_provider.dart';
import '../../features/markets/data/markets_provider.dart';
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

  void _fit(List<MarketQuote> quotes, LatLng? me) {
    final key = '$_product-${quotes.length}';
    if (_fittedFor == key) return;
    final points = [for (final q in quotes) if (q.position != null) q.position!, ?me];
    if (points.isEmpty) return;
    _fittedFor = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _map.fitCamera(CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(48, 130, 48, 360),
          maxZoom: 11,
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
    if (quotes.isNotEmpty) _fit(quotes, location.position);

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
            child: FlutterMap(
              mapController: _map,
              options: const MapOptions(
                initialCenter: LatLng(14.5, -14.5),
                initialZoom: 6.3,
                minZoom: 5,
                maxZoom: 17,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.nataalagro.nataal_agro',
                  tileBuilder: c.isDark ? darkModeTileBuilder : null,
                ),
                MarkerLayer(
                  markers: [
                    if (location.position != null)
                      Marker(
                        point: location.position!,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                          ),
                        ),
                      ),
                    for (final q in quotes)
                      if (q.position != null)
                        Marker(
                          point: q.position!,
                          width: 92,
                          height: 64,
                          alignment: Alignment.topCenter,
                          child: _Pin(
                            label: '${Fmt.grouped(q.price)} F',
                            color: levelColor(context, levelOf(q.price, average)),
                            onTap: () => showMarketSheet(context, quote: q, average: average, distanceKm: _km(location.position, q.position)),
                          ),
                        ),
                  ],
                ),
                const SimpleAttributionWidget(source: Text('© OpenStreetMap')),
              ],
            ),
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
                          if (location.position == null) {
                            ref.read(userLocationProvider.notifier).locate();
                          } else {
                            ref.read(userLocationProvider.notifier).clear();
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
                          : Icon(location.position == null ? Icons.near_me_outlined : Icons.near_me_rounded, color: location.position == null ? c.ink : c.accent),
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
                  ref.read(userLocationProvider.notifier).locate();
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

class _Pin extends StatelessWidget {
  const _Pin({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(0, 2))],
            ),
            child: const Icon(Icons.storefront_rounded, size: 12, color: Colors.white),
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
