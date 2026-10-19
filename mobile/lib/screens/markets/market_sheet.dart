import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/ui.dart';
import 'markets_data.dart';
import 'markets_screen.dart' show levelColor, levelOf, PriceLevel;

/// Fiche d'un marché pour un produit : prix du dernier relevé, écart à la moyenne
/// et courbe des 30 derniers jours (relevés enregistrés uniquement).
Future<void> showMarketSheet(
  BuildContext context, {
  required MarketQuote quote,
  required double average,
  double? distanceKm,
}) {
  return showNaatalSheet<void>(
    context,
    builder: (ctx) => _MarketSheet(quote: quote, average: average, distanceKm: distanceKm),
  );
}

class _MarketSheet extends ConsumerWidget {
  const _MarketSheet({required this.quote, required this.average, this.distanceKm});

  final MarketQuote quote;
  final double average;
  final double? distanceKm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final level = levelOf(quote.price, average);
    final color = levelColor(context, level);
    final diff = average > 0 ? (quote.price - average) / average * 100 : null;
    final history = ref.watch(priceHistoryProvider(HistoryKey(quote.productName, quote.marketId)));
    final verdict = switch (level) {
      PriceLevel.high => 'Au-dessus de la moyenne des marchés : bon endroit pour vendre.',
      PriceLevel.low => 'En dessous de la moyenne des marchés : vente peu avantageuse.',
      PriceLevel.mid => 'Proche de la moyenne des marchés.',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(quote.marketName, style: T.title(color: c.ink)),
          const SizedBox(height: 2),
          Text(
            [
              if (quote.region.isNotEmpty) quote.region,
              if (distanceKm != null) '${distanceKm!.round()} km de vous',
            ].join(' · '),
            style: T.body(color: c.ink2),
          ),
          const SizedBox(height: Space.l),
          Builder(
            builder: (context) {
              final productImg = productImageForName(quote.productName);
              return Container(
                padding: const EdgeInsets.all(Space.l),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: c.isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(Radii.l),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (productImg.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.m),
                        child: Container(
                          width: 52,
                          height: 52,
                          color: c.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Image.asset(
                              productImg,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(Icons.eco_rounded, size: 28, color: c.accent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.m),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(quote.productName, style: T.caption(color: c.ink2)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AnimatedNumber(value: quote.price, style: T.number(36, color: color)),
                              const SizedBox(width: 6),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text('FCFA/kg', style: T.caption(color: c.ink2, weight: 700)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (diff != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${diff >= 0 ? '+' : '−'}${Fmt.decimal(diff.abs())} %', style: T.figure(color: color, weight: 800)),
                          Text('moy. ${Fmt.grouped(average)} F', style: T.caption(color: c.ink2, weight: 500)),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: Space.m),
          Text(verdict, style: T.body(color: c.ink)),
          if (quote.date != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Relevé du ${Fmt.shortDate(quote.date!)}', style: T.caption(color: c.ink2, weight: 500)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Prix de référence (valeur catalogue)', style: T.caption(color: c.ink2, weight: 500)),
            ),
          const SizedBox(height: Space.xl),
          Text('30 derniers jours', style: T.body(color: c.ink, weight: 700)),
          const SizedBox(height: Space.m),
          history.when(
            loading: () => const Skeleton(height: 150, radius: 16),
            error: (e, _) => ErrorState(
              compact: true,
              message: 'L\'historique n\'a pas pu être chargé.',
              onRetry: () => ref.invalidate(priceHistoryProvider(HistoryKey(quote.productName, quote.marketId))),
            ),
            data: (points) {
              if (points.length < 2) {
                return Container(
                  padding: const EdgeInsets.all(Space.l),
                  decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m)),
                  child: Text(
                    points.isEmpty ? 'Aucun historique pour ce marché.' : 'Un seul relevé enregistré : pas encore de courbe.',
                    style: T.body(color: c.ink2),
                  ),
                );
              }
              return PriceChart(points: points, color: color);
            },
          ),
          if (quote.position != null) ...[
            const SizedBox(height: Space.xl),
            PillButton(
              label: 'Copier les coordonnées GPS',
              icon: Icons.copy_rounded,
              variant: PillVariant.secondary,
              expand: true,
              onPressed: () async {
                final text = '${quote.position!.latitude.toStringAsFixed(5)}, ${quote.position!.longitude.toStringAsFixed(5)}';
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Coordonnées copiées : $text')));
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Courbe de prix sur la période (axe des dates et des prix tirés des relevés).
class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.points, required this.color});

  final List<PricePoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final values = points.map((p) => p.price).toList();
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final pad = math.max(1.0, (maxV - minV) * 0.2);
    final spots = [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].price)];

    return SizedBox(
      height: 170,
      child: LineChart(
        LineChartData(
          minY: minV - pad,
          maxY: maxV + pad,
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: math.max(1, (maxV - minV + 2 * pad) / 3),
            getDrawingHorizontalLine: (_) => FlLine(color: c.line, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: math.max(1, (maxV - minV + 2 * pad) / 3),
                getTitlesWidget: (v, meta) => v == meta.min || v == meta.max
                    ? const SizedBox.shrink()
                    : Text(Fmt.grouped(v), style: T.caption(color: c.ink2, weight: 500).copyWith(fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: math.max(1, ((points.length - 1) / 3).floorToDouble()),
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  final step = math.max(1, ((points.length - 1) / 3).floor());
                  final last = points.length - 1;
                  final onStep = i % step == 0 && (last - i) >= step * 0.6;
                  if (i != last && !onStep) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(Fmt.shortDay(points[i].date), style: T.caption(color: c.ink2, weight: 500).copyWith(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.ink,
              getTooltipItems: (items) => [
                for (final s in items)
                  LineTooltipItem(
                    '${Fmt.grouped(s.y)} F\n${Fmt.shortDay(points[s.x.round()].date)}',
                    T.caption(color: c.bg, weight: 700),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: color,
              barWidth: 3.2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, _) => spot.x == spots.last.x,
                getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 5, color: color, strokeWidth: 2.5, strokeColor: c.surface),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
        duration: Motion.slow,
        curve: Motion.out,
      ),
    );
  }
}
