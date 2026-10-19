import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../screens/markets/markets_data.dart';
import '../../../../ui/ui.dart';
import '../../../finances/data/finances_provider.dart';
import '../../../inventory/data/inventory_provider.dart';
import '../../../inventory/data/models/stock_item.dart';
import '../../data/dashboard_provider.dart';
import '../../data/models/dashboard_data.dart';
import '../widgets/my_dashboard_logic.dart';

/// Vue d'ensemble de l'exploitation agricole :
/// 1. Trésorerie & Solde (finances réelles)
/// 2. Stock valorisé (avec photos studio réelles)
/// 3. Opportunités du marché
class MonDashboardScreen extends ConsumerWidget {
  const MonDashboardScreen({
    super.key,
    this.stock,
    this.prices,
  });

  final List<StockItem>? stock;
  final List<MarketPrice>? prices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
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

    return LargeTitleScaffold(
      title: 'Mon exploitation',
      eyebrow: 'Vue de décision',
      reserveNav: false,
      onRefresh: () async {
        ref.invalidate(financialSummaryProvider);
        ref.invalidate(inventoryProvider);
        ref.invalidate(dashboardDataProvider);
      },
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ──────────────────── 1. Trésorerie ────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: AppCard(
                  color: c.surface,
                  padding: const EdgeInsets.all(Space.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: (balance >= 0 ? c.accent : c.clay).withValues(alpha: c.isDark ? 0.25 : 0.1),
                                  borderRadius: BorderRadius.circular(Radii.m),
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: balance >= 0 ? c.accent : c.clay,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: Space.s),
                              Text('Trésorerie nette', style: T.caption(color: c.ink2, weight: 700)),
                            ],
                          ),
                          InkWell(
                            onTap: () => context.push('/finances'),
                            child: Row(
                              children: [
                                Text('Détails', style: T.caption(color: c.accent, weight: 700)),
                                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: c.accent),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.m),
                      Text(
                        hasFinances ? '${balance >= 0 ? '+' : ''}${formatFcfa(balance)} F' : '0 F',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: balance >= 0 ? c.ink : c.clay,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: Space.m),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(Space.m),
                              decoration: BoxDecoration(
                                color: c.surfaceAlt,
                                borderRadius: BorderRadius.circular(Radii.m),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Recettes', style: T.caption(color: c.ink2, weight: 600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '+${formatFcfa(revenue)} F',
                                    style: T.body(color: c.accent, weight: 800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: Space.m),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(Space.m),
                              decoration: BoxDecoration(
                                color: c.surfaceAlt,
                                borderRadius: BorderRadius.circular(Radii.m),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Dépenses', style: T.caption(color: c.ink2, weight: 600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '−${formatFcfa(expenses)} F',
                                    style: T.body(color: c.clay, weight: 800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.l),
                      Row(
                        children: [
                          Expanded(
                            child: PillButton(
                              label: 'Vendre',
                              icon: Icons.sell_rounded,
                              compact: true,
                              expand: true,
                              onPressed: () => context.push('/sell'),
                            ),
                          ),
                          const SizedBox(width: Space.m),
                          Expanded(
                            child: PillButton(
                              label: 'Noter dépense',
                              icon: Icons.receipt_long_rounded,
                              variant: PillVariant.secondary,
                              compact: true,
                              expand: true,
                              onPressed: () => context.push('/finances', extra: {'add': 'expense'}),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ──────────────────── 2. Stock valorisé ────────────────────
              const SectionHeader('Stock valorisé'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: AppCard(
                  color: c.surface,
                  padding: const EdgeInsets.all(Space.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: c.accent.withValues(alpha: c.isDark ? 0.25 : 0.1),
                                  borderRadius: BorderRadius.circular(Radii.m),
                                ),
                                child: Icon(Icons.inventory_2_rounded, color: c.accent, size: 18),
                              ),
                              const SizedBox(width: Space.s),
                              Text('Valeur indicative', style: T.caption(color: c.ink2, weight: 700)),
                            ],
                          ),
                          InkWell(
                            onTap: () => context.push('/stock'),
                            child: Row(
                              children: [
                                Text('Tout voir', style: T.caption(color: c.accent, weight: 700)),
                                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: c.accent),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.m),
                      Text(
                        eval.totalStockValue > 0 ? '${formatFcfa(eval.totalStockValue)} F' : 'Stock non valorisé',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: c.ink,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: Space.m),
                      if (effectiveStock.isEmpty)
                        Text(
                          'Votre stock est vide. Enregistrez une pesée de récolte pour le valoriser.',
                          style: T.caption(color: c.ink2),
                        )
                      else ...[
                        Text(
                          '${effectiveStock.length} produit${effectiveStock.length > 1 ? 's' : ''} en réserve',
                          style: T.caption(color: c.ink2, weight: 600),
                        ),
                        const SizedBox(height: Space.m),
                        for (final line in lines.take(4)) ...[
                          _StockProductRow(line: line),
                          const SizedBox(height: Space.s),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              // ──────────────────── 3. Opportunités du marché ────────────────────
              const SectionHeader('Opportunités du marché'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: AppCard(
                  color: c.surface,
                  padding: const EdgeInsets.all(Space.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c.slate.withValues(alpha: c.isDark ? 0.25 : 0.1),
                              borderRadius: BorderRadius.circular(Radii.m),
                            ),
                            child: Icon(Icons.trending_up_rounded, color: c.slate, size: 18),
                          ),
                          const SizedBox(width: Space.s),
                          Text('Cours rémunérateurs', style: T.caption(color: c.ink2, weight: 700)),
                        ],
                      ),
                      const SizedBox(height: Space.m),
                      if (effectivePrices.isEmpty)
                        Text(
                          'Les cours de marché se chargent lors de la connexion réseau.',
                          style: T.caption(color: c.ink2),
                        )
                      else ...[
                        for (final p in effectivePrices.take(3)) ...[
                          _MarketOpportunityRow(price: p),
                          const SizedBox(height: Space.s),
                        ],
                      ],
                      const SizedBox(height: Space.m),
                      PillButton(
                        label: 'Consulter tous les marchés',
                        icon: Icons.storefront_rounded,
                        variant: PillVariant.secondary,
                        expand: true,
                        onPressed: () => context.go('/markets'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: Space.xxl),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockProductRow extends StatelessWidget {
  const _StockProductRow({required this.line});

  final DashboardStockLine line;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final item = line.item;
    final img = productImageForName(item.name);

    return Container(
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.m),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.s),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Image.asset(
                img,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.eco_rounded, size: 22, color: c.accent),
              ),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: T.caption(color: c.ink, weight: 800)),
                Text(
                  '${formatQty(item.quantity)} ${item.unit}',
                  style: T.caption(color: c.ink2, weight: 600),
                ),
              ],
            ),
          ),
          if (line.value != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${formatFcfa(line.value!)} F', style: T.caption(color: c.ink, weight: 800)),
                if (line.price != null)
                  Text('${line.price!.price.round()} F/kg', style: T.caption(color: c.ink2)),
              ],
            )
          else
            Text('Non coté', style: T.caption(color: c.ink2)),
        ],
      ),
    );
  }
}

class _MarketOpportunityRow extends StatelessWidget {
  const _MarketOpportunityRow({required this.price});

  final MarketPrice price;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final img = productImageForName(price.productName);

    return Container(
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.m),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.s),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Image.asset(
                img,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.store_rounded, size: 20, color: c.slate),
              ),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(price.productName, style: T.caption(color: c.ink, weight: 800)),
                Text(
                  price.marketName.isNotEmpty ? price.marketName : 'Marché de référence',
                  style: T.caption(color: c.ink2, weight: 500),
                ),
              ],
            ),
          ),
          Text(
            '${price.price.round()} F/kg',
            style: T.caption(color: c.accent, weight: 800),
          ),
        ],
      ),
    );
  }
}
