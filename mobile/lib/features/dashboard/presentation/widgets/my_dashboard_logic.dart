import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../inventory/data/models/stock_item.dart';
import '../../../markets/data/models/product.dart';
import '../../data/models/dashboard_data.dart';

String formatFcfa(double v) =>
    v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');

String formatQty(double q) =>
    q.truncateToDouble() == q ? q.toStringAsFixed(0) : q.toStringAsFixed(1);

/// Normalise une chaîne (minuscules, sans accents, sans parenthèses) pour comparaison tolérante.
String _normalize(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Poids en kg d'une quantité en stock. Supporte toutes les unités de conditionnement usuelles.
/// Ne renvoie jamais null pour garantir la valorisation systématique du stock.
double stockItemToKg(StockItem s) {
  final u = s.unit.toLowerCase().trim();
  if (u == 'kg' || u == 'kilo' || u == 'kilos' || u == 'kilogramme' || u == 'kilogrammes') {
    return s.quantity;
  }
  if (u == 'g' || u == 'gramme' || u == 'grammes') {
    return s.quantity / 1000.0;
  }
  if (u == 't' || u.startsWith('tonne')) return s.quantity * 1000.0;
  if (u.startsWith('quintal') || u.startsWith('quintaux')) return s.quantity * 100.0;
  if (u.contains('100') && u.contains('sac')) return s.quantity * 100.0;
  if (u.contains('50') && u.contains('sac')) return s.quantity * 50.0;
  if (u.startsWith('sac')) return s.quantity * 50.0; // sac standard de 50 kg
  if (u.startsWith('filet')) return s.quantity * 25.0; // filet d'oignons/pommes de terre de 25 kg
  if (u.startsWith('caisse')) return s.quantity * 25.0; // caisse maraîchère de 25 kg
  if (u.startsWith('panier')) return s.quantity * 15.0;
  if (u.startsWith('botte')) return s.quantity * 1.0;
  return s.quantity;
}

/// Prix indicatifs de référence au Sénégal (FCFA/kg) issus des relevés SIM/CSA/WFP.
/// Garantit qu'aucun stock ne reste « non valorisé » même hors ligne ou avant le chargement des marchés.
const Map<String, double> senegalBenchmarkPrices = {
  'ail': 2500.0,
  'ananas': 800.0,
  'arachide': 635.0,
  'aubergine': 700.0,
  'banane': 635.0,
  'betterave': 500.0,
  'bissap': 800.0,
  'carotte': 550.0,
  'chou': 410.0,
  'citron': 900.0,
  'concombre': 450.0,
  'courge': 350.0,
  'citrouille': 350.0,
  'coton': 300.0,
  'feve': 800.0,
  'fonio': 845.0,
  'gombo': 900.0,
  'goyave': 700.0,
  'haricot': 1100.0,
  'igname': 500.0,
  'laitue': 600.0,
  'mangue': 320.0,
  'manioc': 265.0,
  'mais': 330.0,
  'melon': 500.0,
  'mil': 375.0,
  'navet': 450.0,
  'niebe': 960.0,
  'oignon': 422.0,
  'orange': 740.0,
  'papaye': 800.0,
  'pasteque': 1550.0,
  'patate': 435.0,
  'piment': 1500.0,
  'poivron': 1000.0,
  'pomme': 540.0,
  'riz': 462.0,
  'sesame': 900.0,
  'sorgho': 350.0,
  'tomate': 520.0,
};

const Set<String> _ignoredStopwords = {
  'parcelle', 'champ', 'culture', 'plantation', 'lot', 'stock', 'reserve',
  'de', 'du', 'des', 'le', 'la', 'les', 'un', 'une', 'en', 'au', 'aux',
  'sac', 'sacs', 'vrac', 'kg', 'kilo', 'kilos', 'bio', 'frais', 'primeur',
  'saison', 'recolte', 'produit', 'produits', 'agricole',
};

MarketPrice? findPriceForStock(
  String stockName,
  List<MarketPrice> prices, {
  List<Product>? allProducts,
}) {
  final cleanStock = _normalize(stockName);
  if (cleanStock.isEmpty) return null;

  // 1. Correspondance directe dans les cours du marché reçus
  for (final p in prices) {
    final cleanMarket = _normalize(p.productName);
    if (cleanMarket == cleanStock || cleanStock.contains(cleanMarket) || cleanMarket.contains(cleanStock)) {
      if (p.price > 0) return p;
    }
  }

  // 2. Correspondance par mots-clés pertinents (sans les mots vides type 'parcelle')
  final allWords = cleanStock.split(' ').where((w) => w.length >= 3).toList();
  final keywords = allWords.where((w) => !_ignoredStopwords.contains(w)).toList();
  final searchWords = keywords.isNotEmpty ? keywords : allWords;

  for (final w in searchWords) {
    for (final p in prices) {
      final cleanMarket = _normalize(p.productName);
      if (cleanMarket.split(' ').contains(w) || cleanMarket.contains(w) || w.contains(cleanMarket)) {
        if (p.price > 0) return p;
      }
    }
  }

  // 3. Fallback sur le catalogue complet des produits du marché
  if (allProducts != null && allProducts.isNotEmpty) {
    for (final prod in allProducts) {
      final cleanProd = _normalize(prod.name);
      if (cleanProd == cleanStock || cleanStock.contains(cleanProd) || cleanProd.contains(cleanStock)) {
        if (prod.currentPrice > 0) {
          return MarketPrice(
            productName: prod.name,
            price: prod.currentPrice,
            trend: prod.trendPercentage >= 0 ? 'up' : 'down',
            marketName: 'Marché de référence',
            date: DateTime.now(),
            changePercent: prod.trendPercentage,
          );
        }
      }
    }
    for (final w in searchWords) {
      for (final prod in allProducts) {
        final cleanProd = _normalize(prod.name);
        if (cleanProd.split(' ').contains(w) || cleanProd.contains(w) || w.contains(cleanProd)) {
          if (prod.currentPrice > 0) {
            return MarketPrice(
              productName: prod.name,
              price: prod.currentPrice,
              trend: prod.trendPercentage >= 0 ? 'up' : 'down',
              marketName: 'Marché de référence',
              date: DateTime.now(),
              changePercent: prod.trendPercentage,
            );
          }
        }
      }
    }
  }

  // 4. Filet de sécurité : barème indicatif national du Sénégal pour garantir 100% de valorisation
  for (final entry in senegalBenchmarkPrices.entries) {
    final key = entry.key;
    if (cleanStock.contains(key) || searchWords.any((w) => w.contains(key) || key.contains(w))) {
      return MarketPrice(
        productName: stockName,
        price: entry.value,
        trend: 'stable',
        marketName: 'Barème indicatif national',
        date: DateTime.now(),
        changePercent: 0.0,
      );
    }
  }

  // Si vraiment aucun nom connu (produit exotique non répertorié), moyenne maraîchère sahélienne (500 F/kg)
  return MarketPrice(
    productName: stockName,
    price: 500.0,
    trend: 'stable',
    marketName: 'Estimation indicative',
    date: DateTime.now(),
    changePercent: 0.0,
  );
}

class DashboardStockLine {
  DashboardStockLine(this.item, this.price) : kg = stockItemToKg(item);

  final StockItem item;
  final MarketPrice? price;
  final double kg;

  /// Valeur estimée : poids × prix moyen du kg. Absente si le prix est inconnu.
  double? get value =>
      (price != null && price!.price > 0) ? kg * price!.price : null;
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
      final gain = l.kg * (max - l.price!.price);
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
