import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../finances/data/finances_provider.dart';
import '../../../inventory/data/models/stock_item.dart';
import '../../data/models/dashboard_data.dart';
import 'my_dashboard_logic.dart';

/// « Mon Dashboard » (Accueil) : résumé synthétique sous forme d'une grande carte
/// blanche avec mini-cartes horizontales défilantes (Finances, Stock, Opportunités).
/// Un clic sur le titre ou les mini-cartes ouvre la page complète /mon_dashboard.
class MyDashboardSection extends ConsumerWidget {
  const MyDashboardSection({
    super.key,
    required this.stock,
    required this.prices,
  });

  final List<StockItem> stock;
  final List<MarketPrice> prices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finances = ref.watch(financialSummaryProvider).valueOrNull;
    final revenue = (finances?.totalRevenue ?? 0).toDouble();
    final expenses = (finances?.totalExpenses ?? 0).toDouble();
    final balance = (finances?.balance ?? 0).toDouble();
    final hasFinances = finances != null && (revenue > 0 || expenses > 0);

    final lines = [for (final s in stock) DashboardStockLine(s, findPriceForStock(s.name, prices))];
    final eval = DashboardEvaluation(
      lines: lines,
      prices: prices,
      revenue: revenue,
      expenses: expenses,
      balance: balance,
      hasFinances: hasFinances,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/mon_dashboard'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.dashboard_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Synthèse de l\'exploitation',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    'Détails',
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 114,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildFinancesMiniCard(context, balance, hasFinances),
                const SizedBox(width: 10),
                _buildStockMiniCard(context, eval),
                const SizedBox(width: 10),
                _buildOpportunitiesMiniCard(context, eval),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────── Mini-carte Finances ─────────────
  Widget _buildFinancesMiniCard(BuildContext context, double balance, bool hasFinances) {
    final Color valueColor = !hasFinances
        ? AppColors.textSecondary
        : (balance >= 0 ? AppColors.primary : AppColors.error);
    final String valueText = !hasFinances
        ? '0 F'
        : '${balance >= 0 ? '+' : '−'}${formatFcfa(balance.abs())} F';
    final String labelText = !hasFinances ? 'Aucune transaction' : 'recettes − dépenses';

    return _miniCardContainer(
      context: context,
      icon: Icons.account_balance_wallet_rounded,
      iconColor: balance >= 0 ? AppColors.primary : AppColors.error,
      tag: 'FINANCES',
      value: valueText,
      valueColor: valueColor,
      subtitle: labelText,
    );
  }

  // ───────────── Mini-carte Stock ─────────────
  Widget _buildStockMiniCard(BuildContext context, DashboardEvaluation eval) {
    final hasValued = eval.totalStockValue > 0;
    final hasItems = stock.isNotEmpty;
    final hasAlert = eval.lowStockCount > 0;

    final String valueText;
    if (hasValued) {
      valueText = '≈ ${formatFcfa(eval.totalStockValue)} F';
    } else if (hasItems) {
      valueText = '${stock.length} produit${stock.length > 1 ? 's' : ''}';
    } else {
      valueText = '0 produit';
    }

    final String subtitleText;
    final Color? subtitleColor;
    if (hasAlert) {
      subtitleText = '⚠️ ${eval.lowStockCount} stock bas';
      subtitleColor = AppColors.warning;
    } else if (hasItems) {
      subtitleText = '${stock.length} produit${stock.length > 1 ? 's' : ''} en stock';
      subtitleColor = null;
    } else {
      subtitleText = 'Aucun stock';
      subtitleColor = null;
    }

    return _miniCardContainer(
      context: context,
      icon: Icons.inventory_2_rounded,
      iconColor: hasAlert ? AppColors.warning : AppColors.primary,
      tag: 'STOCK',
      value: valueText,
      valueColor: AppColors.primary,
      subtitle: subtitleText,
      subtitleColor: subtitleColor,
    );
  }

  // ───────────── Mini-carte Opportunités ─────────────
  Widget _buildOpportunitiesMiniCard(BuildContext context, DashboardEvaluation eval) {
    final count = eval.allInsights.length;
    final String valueText = count > 0 ? '$count piste${count > 1 ? 's' : ''}' : 'Aucune piste';
    final String subtitleText = count > 0
        ? eval.allInsights.first.title
        : 'Complétez vos données';

    return _miniCardContainer(
      context: context,
      icon: Icons.lightbulb_rounded,
      iconColor: const Color(0xFFF59E0B),
      tag: 'OPPORTUNITÉS',
      value: valueText,
      valueColor: const Color(0xFF92400E),
      subtitle: subtitleText,
    );
  }

  Widget _miniCardContainer({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String tag,
    required String value,
    required Color valueColor,
    required String subtitle,
    Color? subtitleColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/mon_dashboard'),
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, color: iconColor, size: 14),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: subtitleColor ?? AppColors.textSecondary,
                fontWeight: subtitleColor != null ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
