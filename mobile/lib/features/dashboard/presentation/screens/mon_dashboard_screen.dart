import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../finances/data/finances_provider.dart';
import '../../../inventory/data/inventory_provider.dart';
import '../../../inventory/data/models/stock_item.dart';
import '../../data/dashboard_provider.dart';
import '../../data/models/dashboard_data.dart';
import '../widgets/my_dashboard_logic.dart';

/// Page détaillée « Mon Dashboard » (/mon_dashboard).
/// Affiche la vue complète en 4 sections :
/// 1. Finances (solde, recettes, dépenses, barre de proportion, lien vers /finances)
/// 2. Stock (valeur estimée, liste des produits valorisés, badge BAS, lien vers /stock)
/// 3. Opportunités (3 grandes cartes distinctes : Rentabilité, Investir, Prévision)
/// 4. Conseils (section plus discrète : vendre, mieux vendre, gérer, organiser)
class MonDashboardScreen extends ConsumerWidget {
  const MonDashboardScreen({
    super.key,
    this.stock,
    this.prices,
  });

  final List<StockItem>? stock;
  final List<MarketPrice>? prices;

  BoxDecoration get _card => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finances = ref.watch(financialSummaryProvider).valueOrNull;
    final effectiveStock = stock ??
        ref.watch(inventoryProvider).valueOrNull ??
        ref.watch(dashboardDataProvider).valueOrNull?.stockItems ??
        const <StockItem>[];
    final effectivePrices = prices ??
        ref.watch(dashboardDataProvider).valueOrNull?.markets ??
        const <MarketPrice>[];

    final revenue = (finances?.totalRevenue ?? 0).toDouble();
    final expenses = (finances?.totalExpenses ?? 0).toDouble();
    final balance = (finances?.balance ?? 0).toDouble();
    final hasFinances = finances != null && (revenue > 0 || expenses > 0);

    final lines = [
      for (final s in effectiveStock)
        DashboardStockLine(s, findPriceForStock(s.name, effectivePrices)),
    ];

    final eval = DashboardEvaluation(
      lines: lines,
      prices: effectivePrices,
      revenue: revenue,
      expenses: expenses,
      balance: balance,
      hasFinances: hasFinances,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Mon Dashboard',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(financialSummaryProvider);
          ref.invalidate(inventoryProvider);
          ref.invalidate(dashboardDataProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre d'accueil de la page
              const Text(
                'Vue d\'ensemble de votre exploitation',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),

              // ───────────── 1. Finances ─────────────
              _buildFinancesSection(context, revenue, expenses, balance, hasFinances),
              const SizedBox(height: 24),

              // ───────────── 2. Stock et valeur ─────────────
              _buildStockSection(context, lines, eval),
              const SizedBox(height: 28),

              // ───────────── 3. Opportunités ─────────────
              _buildSectionHeader('Opportunités stratégiques', Icons.auto_awesome_rounded, const Color(0xFF7C3AED)),
              const SizedBox(height: 14),
              _buildOpportunitiesSection(context, eval, effectivePrices),
              const SizedBox(height: 28),

              // ───────────── 4. Conseils pratiques ─────────────
              _buildSectionHeader('Conseils pratiques', Icons.lightbulb_outline_rounded, AppColors.textSecondary),
              const SizedBox(height: 12),
              _buildAdviceSection(context, eval),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 1. FINANCES
  // ─────────────────────────────────────────────
  Widget _buildFinancesSection(
    BuildContext context,
    double revenue,
    double expenses,
    double balance,
    bool hasFinances,
  ) {
    final total = revenue + expenses;
    final empty = !hasFinances;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Finances',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (empty)
            const Text(
              'Aucune transaction enregistrée. Notez vos ventes et vos dépenses pour suivre votre marge nette.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            )
          else ...[
            Text(
              '${balance >= 0 ? '+' : '−'}${formatFcfa(balance.abs())} F',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: balance >= 0 ? AppColors.primary : AppColors.error,
              ),
            ),
            const Text(
              'Solde net : recettes moins dépenses',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: total > 0 ? (revenue / total * 1000).round().clamp(1, 1000) : 500,
                      child: Container(color: AppColors.primary),
                    ),
                    Expanded(
                      flex: total > 0 ? (expenses / total * 1000).round().clamp(1, 1000) : 500,
                      child: Container(color: AppColors.error.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildFinanceLegend(AppColors.primary, 'Recettes', revenue),
                const SizedBox(width: 16),
                _buildFinanceLegend(AppColors.error.withValues(alpha: 0.8), 'Dépenses', expenses),
              ],
            ),
          ],
          const SizedBox(height: 18),
          _buildActionButton(
            label: 'Ouvrir les finances',
            icon: Icons.arrow_forward_rounded,
            onTap: () => context.push('/finances'),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceLegend(Color color, String label, double value) => Expanded(
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$label : ${formatFcfa(value)} F',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      );

  // ─────────────────────────────────────────────
  // 2. STOCK ET VALEUR
  // ─────────────────────────────────────────────
  Widget _buildStockSection(BuildContext context, List<DashboardStockLine> lines, DashboardEvaluation eval) {
    final empty = lines.isEmpty;
    final valued = eval.valuedLines;
    final total = eval.totalStockValue;
    final maxValue = eval.maxStockValue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Stock et valeur',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (empty)
            const Text(
              'Aucun produit en stock actuellement. Ajoutez vos récoltes pour en suivre la valeur.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            )
          else ...[
            if (valued.isNotEmpty) ...[
              Text(
                '≈ ${formatFcfa(total)} F',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              const Text(
                'Valeur estimée au prix moyen du marché',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
            ],
            for (final l in lines) ...[
              _buildStockRow(l, maxValue),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            Text(
              valued.length == lines.length
                  ? 'Estimation indicative : poids en stock × prix moyen du kg relevé sur les marchés.'
                  : 'Estimation indicative. Les produits en sacs ou sans prix relevé ne sont pas valorisés (poids ou prix inconnu).',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11, height: 1.3),
            ),
          ],
          const SizedBox(height: 18),
          _buildActionButton(
            label: 'Ouvrir le stock',
            icon: Icons.arrow_forward_rounded,
            onTap: () => context.push('/stock'),
          ),
        ],
      ),
    );
  }

  Widget _buildStockRow(DashboardStockLine l, double maxValue) {
    final value = l.value;
    final ratio = (value != null && maxValue > 0) ? (value / maxValue).clamp(0.04, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${l.item.name} · ${formatQty(l.item.quantity)} ${l.item.unit}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary),
              ),
            ),
            if (l.item.alertStatus)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'BAS',
                  style: TextStyle(color: AppColors.warning, fontSize: 9.5, fontWeight: FontWeight.w800),
                ),
              ),
            Text(
              value == null ? '—' : '≈ ${formatFcfa(value)} F',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: value == null ? AppColors.textSecondary : AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: Colors.grey.shade100,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 3. OPPORTUNITÉS (3 GRANDES CARTES DISTINCTES)
  // ─────────────────────────────────────────────
  Widget _buildOpportunitiesSection(
    BuildContext context,
    DashboardEvaluation eval,
    List<MarketPrice> prices,
  ) {
    return Column(
      children: [
        // Carte 1 : Rentabilité
        _buildOpportunityCard(
          context: context,
          tag: 'RENTABILITÉ',
          tagColor: AppColors.primary,
          icon: Icons.emoji_events_rounded,
          iconColor: AppColors.primary,
          title: eval.topValuedProduct != null
              ? '${eval.topValuedProduct!.item.name} : votre stock le plus précieux'
              : 'Rentabilité du stock',
          mainValue: eval.topValuedProduct?.value != null
              ? '≈ ${formatFcfa(eval.topValuedProduct!.value!)} F'
              : null,
          mainValueLabel: eval.topValuedProduct?.price != null
              ? 'au prix moyen de ${formatFcfa(eval.topValuedProduct!.price!.price)} F/kg'
              : null,
          description: eval.topValuedProduct != null
              ? 'C\'est ce produit qui pèse le plus dans votre stock. Veillez à le valoriser sur le meilleur marché disponible.'
              : 'Ajoutez des récoltes pesées avec leurs cours pour identifier votre produit le plus rentable.',
          indicativeNote: 'Calcul indicatif basé sur le cours moyen.',
          actionLabel: 'Gérer ce stock',
          onTap: () => context.push('/stock'),
        ),
        const SizedBox(height: 16),

        // Carte 2 : Investir
        _buildInvestCard(context, eval),
        const SizedBox(height: 16),

        // Carte 3 : Prévision
        _buildForecastCard(context, eval, prices),
      ],
    );
  }

  Widget _buildInvestCard(BuildContext context, DashboardEvaluation eval) {
    final bestP = eval.bestInvestCandidate;
    final hasCandidate = bestP != null;
    final isUp = (bestP?.changePercent ?? 0) > 0;

    return _buildOpportunityCard(
      context: context,
      tag: 'INVESTIR',
      tagColor: const Color(0xFF7C3AED),
      icon: Icons.savings_rounded,
      iconColor: const Color(0xFF7C3AED),
      title: hasCandidate
          ? '${bestP.productName} : le plus rémunérateur au kg'
          : 'Opportunités d\'investissement',
      mainValue: hasCandidate ? '${formatFcfa(bestP.price)} F/kg' : null,
      mainValueLabel: hasCandidate
          ? (isUp ? 'en moyenne (cours en hausse)' : 'en moyenne sur les marchés')
          : null,
      description: hasCandidate
          ? 'Envisagez d\'en cultiver davantage lors de la prochaine saison, en tenant compte du cycle végétatif et de vos coûts de production.'
          : 'Suivez les cotations des marchés régionaux pour identifier les cultures à forte valeur ajoutée.',
      indicativeNote: 'Mention indicative : rendements variables selon terroirs et intrants.',
      actionLabel: 'Analyser ce produit',
      onTap: hasCandidate
          ? () => context.push(
                '/price-analysis',
                extra: {
                  'product': bestP.productName,
                  'price': bestP.price,
                  'stock': 0.0,
                },
              )
          : () => context.go('/markets'),
    );
  }

  Widget _buildForecastCard(
    BuildContext context,
    DashboardEvaluation eval,
    List<MarketPrice> prices,
  ) {
    final target = eval.forecastTarget;
    final fallbackProduct = prices.isNotEmpty ? prices.first.productName : 'Oignon';
    final fallbackPrice = prices.isNotEmpty ? prices.first.price : 400.0;

    final String productName = target != null ? target.item.name : fallbackProduct;
    final double productPrice = target?.price?.price ?? fallbackPrice;
    final double productStock = target?.item.quantity ?? 0.0;

    return _buildOpportunityCard(
      context: context,
      tag: 'PRÉVISION',
      tagColor: const Color(0xFF0284C7),
      icon: Icons.auto_graph_rounded,
      iconColor: const Color(0xFF0284C7),
      title: 'Prévoir le prix de $productName',
      description:
          'Consultez les projections de prix à 7 et 30 jours calculées à partir des tendances régionales et simulez vos revenus.',
      indicativeNote: 'Estimation indicative, non garantie.',
      actionLabel: 'Lancer l\'analyse des prix',
      actionIsPrimary: true,
      onTap: () => context.push(
        '/price-analysis',
        extra: {
          'product': productName,
          'price': productPrice,
          'stock': productStock,
        },
      ),
    );
  }

  Widget _buildOpportunityCard({
    required BuildContext context,
    required String tag,
    required Color tagColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? mainValue,
    String? mainValueLabel,
    required String description,
    required String indicativeNote,
    required String actionLabel,
    bool actionIsPrimary = false,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tagColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: tagColor.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: tagColor),
                    const SizedBox(width: 5),
                    Text(
                      tag,
                      style: TextStyle(
                        color: tagColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'indicatif',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          if (mainValue != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  mainValue,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: tagColor,
                  ),
                ),
                if (mainValueLabel != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mainValueLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '* $indicativeNote',
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          if (actionIsPrimary)
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.auto_graph_rounded, size: 16),
              label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: tagColor,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            )
          else
            _buildActionButton(
              label: actionLabel,
              icon: Icons.chevron_right_rounded,
              color: tagColor,
              onTap: onTap,
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 4. CONSEILS (SECTION DISCRÈTE)
  // ─────────────────────────────────────────────
  Widget _buildAdviceSection(BuildContext context, DashboardEvaluation eval) {
    final advice = eval.practicalAdvice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (advice.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aucun conseil prioritaire pour le moment. Vos stocks et finances sont sous contrôle.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
            )
          else
            for (var i = 0; i < advice.length; i++) ...[
              if (i > 0) Divider(height: 22, color: Colors.grey.withValues(alpha: 0.12)),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => advice[i].onTap(context),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: advice[i].color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(advice[i].icon, color: advice[i].color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            advice[i].tag,
                            style: TextStyle(
                              color: advice[i].color,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            advice[i].title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            advice[i].text,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 18),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    Color? color,
    required VoidCallback onTap,
  }) {
    final effectiveColor = color ?? AppColors.primary;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: effectiveColor,
        side: BorderSide(color: effectiveColor.withValues(alpha: 0.3)),
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 6),
          Icon(icon, size: 16),
        ],
      ),
    );
  }
}
