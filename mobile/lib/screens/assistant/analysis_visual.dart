import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// Lecture visuelle d'une analyse chiffrée de l'assistant. Les chiffres viennent du serveur (calcul déterministe) ;
/// le texte de la réponse reste la version de référence, ce carton n'en est qu'un résumé graphique.
class AnalysisVisualCard extends StatelessWidget {
  const AnalysisVisualCard({super.key, required this.visual});

  /// Descripteur envoyé par le serveur (`bars`, `compare`, `months` ou `levels`).
  final Map<String, dynamic> visual;

  /// `true` si le descripteur est exploitable (type connu et au moins une donnée).
  static bool isDrawable(Map<String, dynamic>? visual) {
    if (visual == null) return false;
    final key = visual['type'] == 'compare' ? 'rows' : 'items';
    return const {'bars', 'compare', 'months', 'levels'}.contains(visual['type']) &&
        visual[key] is List &&
        (visual[key] as List).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!isDrawable(visual)) return const SizedBox.shrink();
    final title = (visual['title'] ?? '').toString();
    final unit = (visual['unit'] ?? '').toString();

    final Widget body;
    switch (visual['type']) {
      case 'bars':
        body = _Bars(items: _maps(visual['items']), unit: unit);
      case 'compare':
        body = _Compare(
          rows: _maps(visual['rows']),
          unit: unit,
          currentLabel: (visual['current_label'] ?? 'Période en cours').toString(),
          previousLabel: (visual['previous_label'] ?? 'Référence').toString(),
        );
      case 'months':
        body = _Months(items: _maps(visual['items']), unit: unit);
      default:
        body = _Levels(items: _maps(visual['items']));
    }

    return Semantics(
      container: true,
      label: 'Graphique : $title',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: Space.m),
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.m),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: T.caption(color: c.ink, weight: 800)),
            const SizedBox(height: Space.s),
            body,
          ],
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _maps(dynamic raw) =>
    (raw as List<dynamic>? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

/// « 1 234 567 » : séparateur de milliers français, sans décimales.
String formatAmount(num value) {
  final negative = value < 0;
  final digits = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '${negative ? '−' : ''}$buffer';
}

Color _tone(NaatalColors c, String? tone) => switch (tone) {
      'positive' => c.accent,
      'negative' => c.clay,
      _ => c.slate,
    };

/// Barres horizontales ; les valeurs négatives partent vers la gauche de l'axe.
class _Bars extends StatelessWidget {
  const _Bars({required this.items, required this.unit});

  final List<Map<String, dynamic>> items;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final maxAbs = items.map((i) => _num(i['value']).abs()).fold<double>(0, math.max);
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _BarRow(
              label: (item['label'] ?? '').toString(),
              value: _num(item['value']),
              maxAbs: maxAbs,
              color: _tone(c, item['tone']?.toString()),
              unit: unit,
            ),
          ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.label, required this.value, required this.maxAbs, required this.color, required this.unit});

  final String label;
  final double value;
  final double maxAbs;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ratio = maxAbs == 0 ? 0.0 : (value.abs() / maxAbs).clamp(0.0, 1.0);
    return Semantics(
      label: '$label : ${formatAmount(value)} $unit',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: T.caption(color: c.ink2), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: Space.s),
              Text('${formatAmount(value)} $unit', style: T.caption(color: c.ink, weight: 700)),
            ],
          ),
          const SizedBox(height: 3),
          LayoutBuilder(
            builder: (context, box) => Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: math.max(4, box.maxWidth * ratio),
                height: 8,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Période en cours contre période de référence, ligne par ligne.
class _Compare extends StatelessWidget {
  const _Compare({required this.rows, required this.unit, required this.currentLabel, required this.previousLabel});

  final List<Map<String, dynamic>> rows;
  final String unit;
  final String currentLabel;
  final String previousLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final maxAbs = rows
        .expand((r) => [_num(r['current']).abs(), _num(r['previous']).abs()])
        .fold<double>(0, math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: Space.m, children: [
          _Legend(color: c.accent, label: currentLabel),
          _Legend(color: c.slate.withValues(alpha: 0.55), label: previousLabel),
        ]),
        const SizedBox(height: Space.s),
        for (final row in rows) ...[
          Text((row['label'] ?? '').toString(), style: T.caption(color: c.ink2)),
          const SizedBox(height: 2),
          _BarRow(label: 'En cours', value: _num(row['current']), maxAbs: maxAbs, color: c.accent, unit: unit),
          _BarRow(
              label: 'Référence',
              value: _num(row['previous']),
              maxAbs: maxAbs,
              color: c.slate.withValues(alpha: 0.55),
              unit: unit),
          const SizedBox(height: Space.s),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: T.caption(color: context.c.ink2)),
      ]);
}

/// Recettes et dépenses mois par mois (barres groupées).
class _Months extends StatelessWidget {
  const _Months({required this.items, required this.unit});

  final List<Map<String, dynamic>> items;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final maxY = items.expand((m) => [_num(m['revenue']), _num(m['expenses'])]).fold<double>(0, math.max);
    final top = maxY == 0 ? 1.0 : maxY * 1.15;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: Space.m, children: [
          _Legend(color: c.accent, label: 'Recettes'),
          _Legend(color: c.clay, label: 'Dépenses'),
        ]),
        const SizedBox(height: Space.m),
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: top,
              minY: 0,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= items.length) return const SizedBox.shrink();
                      final label = (items[i]['label'] ?? '').toString();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(label.split(' ').first, style: T.caption(color: c.ink2), overflow: TextOverflow.clip),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                    '${rodIndex == 0 ? 'Recettes' : 'Dépenses'}\n${formatAmount(rod.toY)} $unit',
                    TextStyle(color: c.onAccent, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < items.length; i++)
                  BarChartGroupData(x: i, barsSpace: 3, barRods: [
                    BarChartRodData(toY: _num(items[i]['revenue']), color: c.accent, width: 9, borderRadius: BorderRadius.circular(3)),
                    BarChartRodData(toY: _num(items[i]['expenses']), color: c.clay, width: 9, borderRadius: BorderRadius.circular(3)),
                  ]),
              ],
            ),
          ),
        ),
        if (items.any((m) => m['partial'] == true))
          Padding(
            padding: const EdgeInsets.only(top: Space.s),
            child: Text('Le dernier mois est en cours (incomplet).', style: T.caption(color: c.ink2)),
          ),
      ],
    );
  }
}

/// Niveaux de stock : une pastille de couleur et un libellé en toutes lettres (jamais la couleur seule).
class _Levels extends StatelessWidget {
  const _Levels({required this.items});

  final List<Map<String, dynamic>> items;

  static const _labels = {
    'rupture': 'En rupture',
    'critique': 'Rupture imminente',
    'attention': 'À surveiller',
    'bas': 'Stock bas',
    'inconnu': 'Couverture non calculable',
    'ok': 'Suffisant',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Color colorOf(String level) => switch (level) {
          'rupture' || 'critique' => c.clay,
          'attention' || 'bas' => c.gold,
          'ok' => c.accent,
          _ => c.slate,
        };
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: colorOf('${item['level']}'), shape: BoxShape.circle),
                ),
                const SizedBox(width: Space.s),
                Expanded(child: Text('${item['label']}', style: T.caption(color: c.ink, weight: 700), overflow: TextOverflow.ellipsis)),
                Text(
                  '${formatAmount(_num(item['quantity']))} ${item['unit'] ?? ''} · ${_labels['${item['level']}'] ?? ''}',
                  style: T.caption(color: c.ink2),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
