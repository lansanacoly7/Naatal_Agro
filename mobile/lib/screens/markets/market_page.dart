import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/location_access.dart' show locationFixLabel;
import '../../ui/ui.dart';
import 'market_page_data.dart';
import 'market_route_page.dart';
import 'market_sheet.dart' show PriceChart;
import 'markets_data.dart';

/// Page d'un marché : ouvert ou non, mise à jour des prix, trajet pour s'y rendre, produits phares, et pour chaque produit
/// son évolution et une prévision. Tout vient des relevés enregistrés ; ce qui manque est dit, jamais inventé.
class MarketPage extends ConsumerWidget {
  const MarketPage({super.key, required this.marketId, this.now});

  final String marketId;

  /// Heure de référence (tests) ; l'heure du téléphone par défaut.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(marketOverviewProvider(marketId));
    final data = overview.valueOrNull;

    return LargeTitleScaffold(
      title: data?.name ?? 'Marché',
      eyebrow: data?.region,
      reserveNav: false,
      onRefresh: () async => ref.invalidate(marketOverviewProvider(marketId)),
      slivers: [
        SliverToBoxAdapter(
          child: overview.when(
            loading: () => const Padding(padding: EdgeInsets.all(Space.gutter), child: Skeleton(height: 320, radius: 24)),
            error: (e, _) => ErrorState(
              message: 'Ce marché n\'a pas pu être chargé. Vérifiez votre réseau.',
              onRetry: () => ref.invalidate(marketOverviewProvider(marketId)),
            ),
            data: (market) => _Content(market: market, now: now ?? DateTime.now()),
          ),
        ),
      ],
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.market, required this.now});

  final MarketOverview market;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final location = ref.watch(userLocationProvider);
    final route = location.position != null && market.position != null
        ? ref.watch(marketRouteProvider(RouteKey(market.id, location.position!.latitude, location.position!.longitude)))
        : null;
    final featured = market.featuredProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: _StatusCard(market: market, now: now, spoken: _spoken(market, now, route?.valueOrNull)),
        ),

        const SectionHeader('Pour y aller'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: _TripCard(market: market, location: location, route: route),
        ),

        if (featured.isNotEmpty) ...[
          const SectionHeader('Produits phares'),
          SizedBox(
            height: 196,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              scrollDirection: Axis.horizontal,
              itemCount: featured.length,
              separatorBuilder: (_, __) => const SizedBox(width: Space.m),
              itemBuilder: (context, i) => _FeaturedCard(product: featured[i], onTap: () => _openProduct(context, featured[i])),
            ),
          ),
        ],

        if (market.products.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: AppCard(
              color: c.surface,
              padding: const EdgeInsets.all(Space.l),
              child: Text('Aucun prix n\'a encore été relevé sur ce marché.', style: T.body(color: c.ink)),
            ),
          )
        else ...[
          SectionHeader('Tous les produits (${market.products.length})'),
          GroupedList(
            children: [
              for (final p in market.products)
                _ProductRow(product: p, onTap: () => _openProduct(context, p)),
            ],
          ),
        ],

        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.xxl),
          child: Text(
            'Les prix viennent des relevés faits sur ce marché. Une prévision est une tendance des dernières semaines : '
            'elle peut se tromper.',
            style: T.caption(color: c.ink2, weight: 500),
          ),
        ),
      ],
    );
  }

  void _openProduct(BuildContext context, MarketProduct product) {
    showNaatalSheet<void>(context, builder: (ctx) => _ProductSheet(product: product, marketName: market.name));
  }
}


String _hour(String? hhmm) {
  final parts = (hhmm ?? '').split(':');
  if (parts.length < 2) return '';
  final h = int.tryParse(parts[0]) ?? 0, m = int.tryParse(parts[1]) ?? 0;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

String _updatedWords(DateTime? last, DateTime now) {
  if (last == null) return 'Aucun prix relevé';
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(last.year, last.month, last.day)).inDays;
  final when = days <= 0 ? 'aujourd\'hui' : days == 1 ? 'hier' : 'il y a $days jours';
  return 'Prix mis à jour $when (${Fmt.shortDate(last)})';
}

String _spoken(MarketOverview m, DateTime now, MarketRoute? route) {
  final parts = <String>['${m.name}${m.region.isEmpty ? '' : ', à ${m.region}'}.'];
  final open = m.isOpenAt(now);
  if (open != null) parts.add('${open ? 'Il est ouvert' : 'Il est fermé'} en ce moment. Il ouvre à ${_hour(m.openingTime)} et ferme à ${_hour(m.closingTime)}.');
  if (m.featuredProducts.isNotEmpty) parts.add('Produits phares : ${m.featuredProducts.map((p) => p.name).join(', ')}.');
  if (route?.car != null) parts.add('En voiture, ${durationWords(route!.car!.minutes)}.');
  if (route?.foot != null) parts.add('À pied, ${durationWords(route!.foot!.minutes)}.');
  parts.add('${_updatedWords(m.lastUpdate, now)}.');
  return parts.join(' ');
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.market, required this.now, required this.spoken});

  final MarketOverview market;
  final DateTime now;
  final String spoken;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final open = market.isOpenAt(now);
    final color = open == null ? c.ink2 : (open ? c.accent : c.clay);
    return AppCard(
      color: c.surface,
      padding: const EdgeInsets.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(
                  open == null ? 'Horaires inconnus' : (open ? 'Ouvert maintenant' : 'Fermé maintenant'),
                  style: T.title(color: c.ink),
                ),
              ),
              ReadAloudButton(key: ValueKey('listen-market-${market.id}'), text: spoken),
            ],
          ),
          if (open != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              'De ${_hour(market.openingTime)} à ${_hour(market.closingTime)}${market.hoursVerified ? '' : ' (horaires indicatifs)'}',
              style: T.body(color: c.ink2, weight: 600),
            ),
          ],
          const SizedBox(height: Space.m),
          Row(
            children: [
              Icon(Icons.update_rounded, size: 20, color: c.ink2),
              const SizedBox(width: Space.s),
              Expanded(child: Text(_updatedWords(market.lastUpdate, now), style: T.body(color: c.ink, weight: 600))),
            ],
          ),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              Icon(Icons.local_offer_outlined, size: 20, color: c.ink2),
              const SizedBox(width: Space.s),
              Expanded(child: Text('${market.products.length} produits suivis', style: T.body(color: c.ink, weight: 600))),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripCard extends ConsumerWidget {
  const _TripCard({required this.market, required this.location, required this.route});

  final MarketOverview market;
  final UserLocation location;
  final AsyncValue<MarketRoute>? route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;

    Widget message(String text, {Widget? action}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: T.body(color: c.ink)),
            if (action != null) ...[const SizedBox(height: Space.m), action],
          ],
        );

    Widget body;
    if (market.position == null) {
      body = message('Ce marché n\'a pas de position enregistrée : le trajet ne peut pas être calculé.');
    } else if (location.position == null) {
      body = message(
        location.error ?? 'Touchez le bouton pour voir le temps de trajet depuis où vous êtes.',
        action: PillButton(
          label: location.needsFix ? locationFixLabel(location.access!) : 'Voir le trajet',
          icon: location.needsFix ? Icons.location_on_rounded : Icons.my_location_rounded,
          expand: true,
          loading: location.loading,
          onPressed: () {
            final notifier = ref.read(userLocationProvider.notifier);
            location.needsFix ? notifier.enable() : notifier.locate();
          },
        ),
      );
    } else {
      body = route!.when(
        loading: () => const Skeleton(height: 96, radius: 16),
        error: (e, _) => message('Le trajet n\'a pas pu être calculé. Vérifiez votre réseau.',
            action: PillButton(
              label: 'Réessayer',
              icon: Icons.refresh_rounded,
              variant: PillVariant.secondary,
              expand: true,
              onPressed: () => ref.invalidate(marketRouteProvider),
            )),
        data: (r) {
          if (r.car == null && r.foot == null) {
            return message('Les trajets ne sont pas disponibles pour le moment. À vol d\'oiseau, le marché est à ${Fmt.decimal(r.straightKm)} km.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _ModeTile(icon: Icons.directions_car_rounded, label: 'En voiture', mode: r.car)),
                  const SizedBox(width: Space.m),
                  Expanded(child: _ModeTile(icon: Icons.directions_walk_rounded, label: 'À pied', mode: r.foot)),
                ],
              ),
              const SizedBox(height: Space.m),
              PillButton(
                label: 'Voir le trajet sur la carte',
                icon: Icons.map_rounded,
                expand: true,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => MarketRoutePage(market: market, route: r, origin: location.position!)),
                ),
              ),
            ],
          );
        },
      );
    }

    return AppCard(color: c.surface, padding: const EdgeInsets.all(Space.l), child: body);
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.icon, required this.label, required this.mode});

  final IconData icon;
  final String label;
  final RouteMode? mode;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: c.accent),
          const SizedBox(height: Space.s),
          Text(label, style: T.caption(color: c.ink2, weight: 700)),
          Text(mode == null ? 'Indisponible' : durationWords(mode!.minutes), style: T.title(color: c.ink)),
          if (mode != null) Text('${Fmt.decimal(mode!.distanceKm)} km', style: T.caption(color: c.ink2, weight: 600)),
        ],
      ),
    );
  }
}

Color _trendColor(BuildContext context, String trend) {
  final c = context.c;
  return trend == 'up' ? c.accent : (trend == 'down' ? c.clay : c.ink2);
}

IconData _trendIcon(String trend) => trend == 'up' ? Icons.trending_up_rounded : (trend == 'down' ? Icons.trending_down_rounded : Icons.trending_flat_rounded);

String _trendWords(String trend) => trend == 'up' ? 'Le prix monte' : (trend == 'down' ? 'Le prix baisse' : 'Le prix ne bouge pas');

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.product, required this.onTap});

  final MarketProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      semanticLabel: '${product.name}, ${Fmt.grouped(product.price)} francs. ${_trendWords(product.trend)}',
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 96,
              width: double.infinity,
              child: Image.asset(
                productImageForName(product.name),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(color: c.surfaceAlt, child: Icon(Icons.eco_rounded, color: c.accent, size: 36)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(color: c.ink, weight: 800)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(child: Text('${Fmt.grouped(product.price)} F', style: T.title(color: c.ink))),
                      Icon(_trendIcon(product.trend), color: _trendColor(context, product.trend), size: 24),
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
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onTap});

  final MarketProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GroupedRow(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.m),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Image.asset(
            productImageForName(product.name),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => ColoredBox(color: c.surfaceAlt, child: Icon(Icons.eco_rounded, color: c.accent, size: 24)),
          ),
        ),
      ),
      title: product.name,
      subtitle: product.source == null
          ? _trendWords(product.trend)
          : '${_trendWords(product.trend)} · ${product.source}${product.date == null ? '' : ', ${Fmt.shortDate(product.date!)}'}',
      value: '${Fmt.grouped(product.price)} F',
      chevron: true,
      onTap: onTap,
    );
  }
}

class _ProductSheet extends StatelessWidget {
  const _ProductSheet({required this.product, required this.marketName});

  final MarketProduct product;
  final String marketName;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = _trendColor(context, product.trend);
    final forecast = product.forecast;
    final points = [for (final h in product.history) PricePoint(date: h.date, price: h.price)];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.m),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Image.asset(
                    productImageForName(product.name),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(color: c.surfaceAlt, child: Icon(Icons.eco_rounded, color: c.accent, size: 30)),
                  ),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: T.title(color: c.ink)),
                    Text(marketName, style: T.caption(color: c.ink2, weight: 600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          Container(
            padding: const EdgeInsets.all(Space.l),
            decoration: BoxDecoration(
              color: color.withValues(alpha: c.isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(Radii.l),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(_trendIcon(product.trend), color: color, size: 44),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${Fmt.grouped(product.price)} F', style: T.number(36, color: c.ink)),
                      Text(_trendWords(product.trend), style: T.body(color: color, weight: 800)),
                      if (product.date != null) Text('Prix du ${Fmt.shortDate(product.date!)}', style: T.caption(color: c.ink2, weight: 600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (product.changeWeekPercent != null) ...[
            const SizedBox(height: Space.m),
            Text(
              product.changeWeekPercent!.abs() < 0.5
                  ? 'Depuis une semaine : le prix n\'a presque pas changé.'
                  : 'Depuis une semaine : ${product.changeWeekPercent! > 0 ? 'en hausse' : 'en baisse'} de ${Fmt.decimal(product.changeWeekPercent!.abs())} %.',
              style: T.body(color: c.ink),
            ),
          ],
          if (product.cheaperMarkets != null && product.marketsCompared > 1) ...[
            const SizedBox(height: Space.xs),
            Text(
              product.cheaperMarkets == 0
                  ? 'Ici, c\'est le moins cher des ${product.marketsCompared} marchés comparés.'
                  : 'Moins cher dans ${product.cheaperMarkets} marché${product.cheaperMarkets == 1 ? '' : 's'} sur ${product.marketsCompared}.',
              style: T.body(color: c.ink),
            ),
          ],
          const SizedBox(height: Space.xl),
          Text(product.windowDays >= 300 ? 'Cette dernière année' : 'Ces ${product.windowDays} derniers jours', style: T.body(color: c.ink, weight: 700)),
          const SizedBox(height: Space.m),
          if (points.length < 2)
            Container(
              padding: const EdgeInsets.all(Space.l),
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m)),
              child: Text('Un seul relevé : pas encore de courbe.', style: T.body(color: c.ink2)),
            )
          else
            PriceChart(points: points, color: color),
          if (product.min30 != null && product.max30 != null && product.avg30 != null) ...[
            const SizedBox(height: Space.m),
            Row(
              children: [
                Expanded(child: _Figure(label: 'Le plus bas', value: '${Fmt.grouped(product.min30!)} F')),
                Expanded(child: _Figure(label: 'En moyenne', value: '${Fmt.grouped(product.avg30!)} F')),
                Expanded(child: _Figure(label: 'Le plus haut', value: '${Fmt.grouped(product.max30!)} F')),
              ],
            ),
          ],
          const SizedBox(height: Space.xl),
          Text('Et la semaine prochaine ?', style: T.body(color: c.ink, weight: 700)),
          const SizedBox(height: Space.m),
          if (forecast == null)
            Container(
              padding: const EdgeInsets.all(Space.l),
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m)),
              child: Text('Pas assez de relevés pour prévoir le prix.', style: T.body(color: c.ink2)),
            )
          else
            _ForecastCard(forecast: forecast),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      children: [
        Text(value, style: T.figure(color: c.ink)),
        Text(label, style: T.caption(color: c.ink2, weight: 600)),
      ],
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast});

  final MarketForecast forecast;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = _trendColor(context, forecast.direction);
    final sentence = switch (forecast.direction) {
      'up' => 'Le prix devrait monter.',
      'down' => 'Le prix devrait baisser.',
      _ => 'Le prix devrait rester pareil.',
    };
    final sure = switch (forecast.confidence) {
      'good' => 'Assez sûr',
      'medium' => 'Moyennement sûr',
      _ => 'Peu sûr',
    };
    return Container(
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.l),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_trendIcon(forecast.direction), color: color, size: 36),
              const SizedBox(width: Space.m),
              Expanded(child: Text(sentence, style: T.title(color: c.ink))),
            ],
          ),
          const SizedBox(height: Space.m),
          Text('Dans ${forecast.horizonDays} jours : environ ${Fmt.grouped(forecast.expectedPrice)} F', style: T.body(color: c.ink, weight: 700)),
          Text('Entre ${Fmt.grouped(forecast.low)} et ${Fmt.grouped(forecast.high)} F', style: T.body(color: c.ink2, weight: 600)),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: c.ink2),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  '$sure · calculé sur les ${forecast.basisDays} derniers jours. Ce n\'est pas une promesse.',
                  style: T.caption(color: c.ink2, weight: 600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
