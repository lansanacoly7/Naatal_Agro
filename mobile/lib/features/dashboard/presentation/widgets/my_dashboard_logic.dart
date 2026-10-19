import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../inventory/data/models/stock_item.dart';
import '../../data/models/dashboard_data.dart';

String formatFcfa(double v) =>
    v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');

String formatQty(double q) =>
    q.truncateToDouble() == q ? q.toStringAsFixed(0) : q.toStringAsFixed(1);

/// Poids en kg d'une quantité en stock, ou null si l'unité n'a pas de poids connu (ex. « sacs »).
double? stockItemToKg(StockItem s) {
  final u = s.unit.toLowerCase().trim();
  if (u == 'kg' || u == 'kilo' || u == 'kilos' || u == 'kilogramme' || u == 'kilogrammes') {
    return s.quantity;
  }
  if (u == 't' || u.startsWith('tonne')) return s.quantity * 1000;
  if (u.startsWith('quintal')) return s.quantity * 100;
  return null;
}

MarketPrice? findPriceForStock(String stockName, List<MarketPrice> prices) {
  final n = stockName.toLowerCase();
  for (final p in prices) {
    final m = p.productName.toLowerCase();
    if (m.contains(n) || n.contains(m)) return p;
  }
  return null;
}

class DashboardStockLine {
  DashboardStockLine(this.item, this.price) : kg = stockItemToKg(item);

  final StockItem item;
  final MarketPrice? price;
  final double? kg;

  /// Valeur estimée : poids × prix moyen du kg. Absente si le poids ou le prix est inconnu.
  double? get value =>
      (kg != null && price != null && price!.price > 0) ? kg! * price!.price : null;
}

class DashboardInsight {
  const DashboardInsight(this.tag, this.color, this.icon, this.title, this.text, this.onTap);

  final String tag;
  final Color color;
  final IconData icon;
  final String title;
  final String text;
  final void Function(BuildContext) onTap;
}

/// Analyse les opportunités et conseils à partir du stock, des prix et des finances.
class DashboardEvaluation {
  DashboardEvaluation({
    required this.lines,
    required this.prices,
    required this.revenue,
    required this.expenses,
    required this.balance,
    required this.hasFinances,
  }) {
    _compute();
  }

  final List<DashboardStockLine> lines;
  final List<MarketPrice> prices;
  final double revenue;
  final double expenses;
  final double balance;
  final bool hasFinances;

  List<DashboardStockLine> get valuedLines =>
      lines.where((l) => l.value != null).toList()..sort((a, b) => b.value!.compareTo(a.value!));

  double get totalStockValue =>
      valuedLines.fold<double>(0, (a, l) => a + l.value!);

  double get maxStockValue =>
      valuedLines.isEmpty ? 0.0 : valuedLines.first.value!;

  int get lowStockCount =>
      lines.where((l) => l.item.alertStatus).length;

  DashboardStockLine? get topValuedProduct =>
      valuedLines.isNotEmpty ? valuedLines.first : null;

  MarketPrice? get bestInvestCandidate {
    final priced = prices.where((p) => p.price > 0).toList()
      ..sort((a, b) => b.price.compareTo(a.price));
    return priced.isNotEmpty ? priced.first : null;
  }

  DashboardStockLine? get forecastTarget =>
      valuedLines.isNotEmpty ? valuedLines.first : null;

  final List<DashboardInsight> practicalAdvice = [];
  final List<DashboardInsight> allInsights = [];

  void _compute() {
    // 1. Rentabilité
    if (topValuedProduct != null) {
      final top = topValuedProduct!;
      allInsights.add(
        DashboardInsight(
          'RENTABILITÉ',
          AppColors.primary,
          Icons.emoji_events_rounded,
          '${top.item.name} : votre stock le plus précieux',
          'Environ ${formatFcfa(top.value!)} F au prix moyen (${formatFcfa(top.price!.price)} F/kg). C\'est ce produit qui pèse le plus dans votre stock.',
          (c) => c.push('/stock'),
        ),
      );
    }

    // 2. Vendre : variation du prix sur un produit en stock
    for (final l in valuedLines) {
      final ch = l.price!.changePercent;
      if (ch != null && ch.abs() >= 3) {
        final insight = ch > 0
            ? DashboardInsight(
                'VENDRE',
                AppColors.primary,
                Icons.trending_up_rounded,
                '${l.item.name} : prix en hausse (+${ch.toStringAsFixed(1)} %)',
                'Le prix monte : regardez où vendre dès maintenant avant un éventuel retournement.',
                (c) => c.go('/markets'),
              )
            : DashboardInsight(
                'VENDRE',
                AppColors.error,
                Icons.trending_down_rounded,
                '${l.item.name} : prix en baisse (${ch.toStringAsFixed(1)} %)',
                'Le prix baisse : comparez les marchés avant de vendre, sans vous précipiter ni tout garder.',
                (c) => c.go('/markets'),
              );
        allInsights.add(insight);
        practicalAdvice.add(insight);
        break;
      }
    }

    // 3. Mieux vendre : écart entre marchés
    DashboardStockLine? best;
    double bestGain = 0;
    for (final l in valuedLines) {
      final max = l.price!.maxPrice;
      if (max == null) continue;
      final gain = l.kg! * (max - l.price!.price);
      if (gain > bestGain) {
        bestGain = gain;
        best = l;
      }
    }
    if (best != null && bestGain >= 1000) {
      final insight = DashboardInsight(
        'MIEUX VENDRE',
        AppColors.primary,
        Icons.storefront_rounded,
        'Choisissez le bon marché pour ${best.item.name}',
        'Au marché le mieux payé (${formatFcfa(best.price!.maxPrice!)} F/kg), vous gagneriez jusqu\'à ${formatFcfa(bestGain)} F de plus qu\'au prix moyen.',
        (c) => c.go('/markets'),
      );
      allInsights.add(insight);
      practicalAdvice.add(insight);
    }

    // 4. Investir
    final bestP = bestInvestCandidate;
    if (bestP != null) {
      final up = (bestP.changePercent ?? 0) > 0;
      allInsights.add(
        DashboardInsight(
          'INVESTIR',
          const Color(0xFF7C3AED),
          Icons.savings_rounded,
          '${bestP.productName} : le plus rémunérateur au kg',
          '${formatFcfa(bestP.price)} F/kg en moyenne${up ? ' et prix en hausse' : ''}. Envisagez d\'en cultiver davantage, en tenant compte de son cycle et de vos coûts.',
          (c) => c.push(
            '/price-analysis',
            extra: {'product': bestP.productName, 'price': bestP.price, 'stock': 0.0},
          ),
        ),
      );
    }

    // 5. Prévoir
    if (forecastTarget != null) {
      final p = forecastTarget!;
      allInsights.add(
        DashboardInsight(
          'PRÉVOIR',
          const Color(0xFF0284C7),
          Icons.auto_graph_rounded,
          'Prévoir le prix de ${p.item.name}',
          'Estimation indicative à 7 ou 30 jours à partir des derniers relevés, et revenu attendu pour votre stock.',
          (c) => c.push(
            '/price-analysis',
            extra: {'product': p.item.name, 'price': p.price!.price, 'stock': p.item.quantity},
          ),
        ),
      );
    }

    // 6. Gérer
    if (hasFinances && balance < 0) {
      final insight = DashboardInsight(
        'GÉRER',
        AppColors.error,
        Icons.account_balance_wallet_rounded,
        'Vos dépenses dépassent vos recettes',
        'Il manque ${formatFcfa(-balance)} F. Regardez vos postes de dépense avant la prochaine campagne.',
        (c) => c.push('/finances'),
      );
      allInsights.add(insight);
      practicalAdvice.add(insight);
    } else if (hasFinances && expenses > 0 && revenue == 0) {
      final insight = DashboardInsight(
        'GÉRER',
        AppColors.warning,
        Icons.account_balance_wallet_rounded,
        'Aucune vente enregistrée',
        '${formatFcfa(expenses)} F dépensés. Notez vos ventes pour connaître votre marge réelle.',
        (c) => c.push('/finances'),
      );
      allInsights.add(insight);
      practicalAdvice.add(insight);
    }

    // 7. Organiser
    final low = lines.where((l) => l.item.alertStatus).toList();
    if (low.isNotEmpty) {
      final insight = DashboardInsight(
        'ORGANISER',
        AppColors.warning,
        Icons.inventory_rounded,
        '${low.first.item.name} : stock bas',
        '${formatQty(low.first.item.quantity)} ${low.first.item.unit} restants. Planifiez le réapprovisionnement ou la prochaine récolte.',
        (c) => c.push('/stock'),
      );
      allInsights.add(insight);
      practicalAdvice.add(insight);
    }
  }
}
