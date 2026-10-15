import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agriculture/data/agriculture_provider.dart';
import '../../features/agriculture/data/models/crop.dart';
import '../../features/dashboard/data/dashboard_provider.dart';
import '../../features/dashboard/data/models/dashboard_data.dart';
import '../../features/finances/data/finances_provider.dart';
import '../../features/inventory/data/inventory_provider.dart';
import '../../features/inventory/data/models/stock_item.dart';
import '../../features/profile/data/profile_provider.dart';
import '../../ui/ui.dart';
import '../crops/harvest_flow.dart';
import 'activity_feed.dart';

/// Accueil : « Aujourd'hui ». Tout ce qui s'affiche vient de l'exploitation de
/// l'utilisateur ou d'un relevé daté. Sans donnée, un état vide explique quoi faire.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dashboardDataProvider);
    ref.invalidate(cropsProvider);
    ref.invalidate(financialSummaryProvider);
    ref.invalidate(inventoryProvider);
    await ref.read(transactionsNotifierProvider.notifier).fetchTransactions();
    await ref.read(profileNotifierProvider.notifier).loadProfile();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardDataProvider);
    final profile = ref.watch(profileNotifierProvider).valueOrNull;
    final firstName = (profile?.fullName.trim().split(RegExp(r'\s+')).first) ?? '';

    return LargeTitleScaffold(
      title: "Aujourd'hui",
      eyebrow: Fmt.dayMonth(DateTime.now()),
      onRefresh: () => _refresh(ref),
      actions: [
        _AvatarButton(
          initials: profile?.initials ?? '·',
          onTap: () => context.push('/profile'),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (firstName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.m),
                  child: Text('Bonjour, $firstName', style: T.body(color: context.c.ink2, weight: 600)),
                ),
              Reveal(
                index: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: dash.when(
                    data: (d) => _WeatherHero(weather: d.weather),
                    loading: () => const Skeleton(height: 210, radius: 28),
                    error: (e, _) => ErrorState(
                      compact: true,
                      message: 'La météo n\'a pas pu être chargée.',
                      onRetry: () => ref.invalidate(dashboardDataProvider),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.l),
              Reveal(index: 1, child: const _QuickActions()),
              if (dash.valueOrNull?.alerts.isNotEmpty ?? false)
                Reveal(index: 2, child: _AlertBanner(message: dash.value!.alerts.first)),
              const Reveal(index: 3, child: _CropsSection()),
              const Reveal(index: 4, child: _BalanceSection()),
              const Reveal(index: 5, child: _StockSection()),
              Reveal(index: 6, child: _PricesSection(prices: dash.valueOrNull?.markets ?? const [], loading: dash.isLoading)),
              const Reveal(index: 7, child: _ActivitySection()),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.initials, required this.onTap});

  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      semanticLabel: 'Mon profil',
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [c.gold, const Color(0xFFF08A6A)]),
        ),
        child: Text(initials, style: T.body(color: const Color(0xFF2B1700), weight: 800)),
      ),
    );
  }
}

// ───────────────────────── Météo ─────────────────────────

class _WeatherHero extends StatelessWidget {
  const _WeatherHero({required this.weather});

  final WeatherSummary weather;

  String _place(String raw) {
    final first = raw.split(',').first.trim();
    if (first.isEmpty) return 'Votre région';
    return first[0].toUpperCase() + first.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const radius = BorderRadius.all(Radius.circular(28));

    if (!weather.isAvailable) {
      return AuroraBackground(
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 32),
              const SizedBox(height: Space.m),
              Text('Météo non disponible', style: T.title(color: Colors.white)),
              const SizedBox(height: Space.xs + 2),
              Text(
                'Aucun relevé météo pour votre région. Vérifiez que votre région est bien renseignée.',
                style: T.body(color: Colors.white.withValues(alpha: 0.86)),
              ),
              const SizedBox(height: Space.l),
              PillButton(
                label: 'Modifier ma région',
                variant: PillVariant.glass,
                compact: true,
                onPressed: () => context.push('/edit-profile'),
              ),
            ],
          ),
        ),
      );
    }

    final date = weather.date;
    final stale = date != null && DateTime.now().difference(date).inDays >= 2;
    final rain = weather.rainfall > 0
        ? 'Pluie relevée : ${Fmt.decimal(weather.rainfall)} mm'
        : 'Pas de pluie relevée';

    return AuroraBackground(
      borderRadius: radius,
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Glass(
                  style: GlassStyle.onHero,
                  radius: Radii.pill,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place_rounded, size: 15, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(_place(weather.location), style: T.caption(color: Colors.white, weight: 700)),
                    ],
                  ),
                ),
                const Spacer(),
                Glass(
                  style: GlassStyle.onHero,
                  radius: Radii.pill,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.water_drop_outlined, size: 15, color: Colors.white),
                      const SizedBox(width: 5),
                      Text('${weather.humidity.round()} %', style: T.caption(color: Colors.white, weight: 700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.l),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedNumber(
                  value: weather.temp,
                  style: T.number(76, color: Colors.white),
                  formatter: (v) => v.round().toString(),
                  suffix: '°',
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(rain, style: T.body(color: Colors.white, weight: 600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(
              date == null
                  ? 'Date du relevé inconnue'
                  : stale
                      ? 'Relevé ancien : ${Fmt.shortDate(date)}'
                      : 'Relevé du ${Fmt.shortDate(date)}',
              style: T.caption(color: stale ? c.gold : Colors.white.withValues(alpha: 0.82), weight: 700),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Actions rapides ─────────────────────────

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.sell_rounded,
              label: 'Vendre',
              primary: true,
              onTap: () => context.push('/sell'),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: _QuickAction(
              icon: Icons.agriculture_rounded,
              label: 'Récolter',
              onTap: () => startHarvestFlow(context, ref),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: _QuickAction(
              icon: Icons.receipt_long_rounded,
              label: 'Dépense',
              onTap: () => context.push('/finances', extra: const {'add': 'expense'}),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.primary = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bg = primary ? c.accent : c.surface;
    final fg = primary ? c.onAccent : c.ink;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 84,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.l),
          border: primary ? null : Border.all(color: c.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primary ? c.onAccent : c.accent, size: 26),
            const SizedBox(height: 6),
            Text(label, style: T.caption(color: fg, weight: 700)),
          ],
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, 0),
      child: PressScale(
        onTap: () => context.push('/notifications'),
        child: Container(
          padding: const EdgeInsets.all(Space.l),
          decoration: BoxDecoration(
            color: c.clay.withValues(alpha: c.isDark ? 0.2 : 0.11),
            borderRadius: BorderRadius.circular(Radii.l),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: c.clay),
              const SizedBox(width: Space.m),
              Expanded(
                child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: T.caption(color: c.ink, weight: 600)),
              ),
              Icon(Icons.chevron_right_rounded, color: c.clay),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Cultures ─────────────────────────

class _CropsSection extends ConsumerWidget {
  const _CropsSection();

  static const _tints = [Color(0xFFF2C14E), Color(0xFF6FD3A0), Color(0xFFF4A38A), Color(0xFF9CC7E8)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crops = ref.watch(cropsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Vos cultures', action: 'Tout voir', onAction: () => context.go('/agriculture')),
        crops.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Skeleton(height: 150, radius: 24),
          ),
          error: (e, _) => ErrorState(
            compact: true,
            message: 'Vos cultures n\'ont pas pu être chargées.',
            onRetry: () => ref.invalidate(cropsProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: AppCard(
                  child: EmptyState(
                    compact: true,
                    icon: Icons.eco_rounded,
                    title: 'Aucune culture',
                    message: 'Ajoutez votre première culture pour suivre son avancement, ses prix et sa récolte.',
                    actionLabel: 'Ajouter une culture',
                    onAction: () => context.push('/agriculture/add'),
                  ),
                ),
              );
            }
            return SizedBox(
              height: 156,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                physics: const BouncingScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: Space.m),
                itemBuilder: (context, i) => _CropTile(crop: list[i], tint: _tints[i % _tints.length]),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CropTile extends StatelessWidget {
  const _CropTile({required this.crop, required this.tint});

  final Crop crop;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17210F);
    final progress = crop.progressOrNull;
    final days = crop.daysToHarvest;
    final harvested = crop.status == 'harvested';
    final caption = harvested
        ? 'Récoltée'
        : days == null
            ? 'Dates à renseigner'
            : days > 0
                ? 'Récolte dans $days j'
                : days == 0
                    ? 'Récolte aujourd\'hui'
                    : 'Récolte dépassée de ${-days} j';
    return PressScale(
      onTap: () => context.push('/agriculture/${crop.id}'),
      child: Container(
        width: 156,
        padding: const EdgeInsets.all(Space.l),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: tint.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressRing(
              value: harvested ? 1 : (progress ?? 0),
              size: 52,
              stroke: 6,
              color: ink,
              track: ink.withValues(alpha: 0.16),
              child: Text(
                harvested ? '✓' : (progress == null ? '–' : '${(progress * 100).round()}'),
                style: T.number(14, color: ink, weight: 800),
              ),
            ),
            const Spacer(),
            Text(crop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(color: ink, weight: 800)),
            const SizedBox(height: 2),
            Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption(color: ink.withValues(alpha: 0.78), weight: 600)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Bilan ─────────────────────────

class _BalanceSection extends ConsumerWidget {
  const _BalanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(financialSummaryProvider);
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Bilan', action: 'Détails', onAction: () => context.push('/finances')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: summary.when(
            loading: () => const Skeleton(height: 118, radius: 20),
            error: (e, _) => ErrorState(
              compact: true,
              message: 'Le bilan n\'a pas pu être chargé.',
              onRetry: () => ref.invalidate(financialSummaryProvider),
            ),
            data: (s) => AppCard(
              onTap: () => context.push('/finances'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Solde depuis le début', style: T.caption(color: c.ink2)),
                  const SizedBox(height: Space.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedNumber(value: s.balance, style: T.number(34, color: s.balance < 0 ? c.clay : c.ink)),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text('FCFA', style: T.caption(color: c.ink2, weight: 700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.m),
                  Row(
                    children: [
                      _Flow(label: 'Revenus', value: s.totalRevenue, color: c.accent, icon: Icons.south_west_rounded),
                      const SizedBox(width: Space.xl),
                      _Flow(label: 'Dépenses', value: s.totalExpenses, color: c.clay, icon: Icons.north_east_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Flow extends StatelessWidget {
  const _Flow({required this.label, required this.value, required this.color, required this.icon});

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: T.caption(color: c.ink2, weight: 500)),
                Text(Fmt.grouped(value), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.figure(color: c.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Stock ─────────────────────────

class _StockSection extends ConsumerWidget {
  const _StockSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stock = ref.watch(inventoryProvider);
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Stock', action: 'Gérer', onAction: () => context.push('/stock')),
        stock.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Skeleton(height: 120, radius: 20),
          ),
          error: (e, _) => ErrorState(
            compact: true,
            message: 'Le stock n\'a pas pu être chargé.',
            onRetry: () => ref.invalidate(inventoryProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: AppCard(
                  child: EmptyState(
                    compact: true,
                    icon: Icons.inventory_2_rounded,
                    title: 'Stock vide',
                    message: 'Une récolte enregistrée ajoute automatiquement votre stock ici.',
                    actionLabel: 'Ajouter un stock',
                    onAction: () => context.push('/stock'),
                  ),
                ),
              );
            }
            return GroupedList(
              children: [
                for (final StockItem item in items.take(3))
                  GroupedRow(
                    leading: IconTile(icon: Icons.inventory_2_rounded, color: item.alertStatus ? c.clay : c.accent),
                    title: item.name,
                    subtitle: item.alertStatus ? 'Stock bas' : null,
                    value: '${Fmt.decimal(item.quantity)} ${item.unit}',
                    onTap: () => context.push('/stock'),
                    chevron: true,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ───────────────────────── Prix ─────────────────────────

class _PricesSection extends StatelessWidget {
  const _PricesSection({required this.prices, required this.loading});

  final List<MarketPrice> prices;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Prix de vos cultures', action: 'Marchés', onAction: () => context.go('/markets')),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Skeleton(height: 120, radius: 20),
          )
        else if (prices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: AppCard(
              child: EmptyState(
                compact: true,
                icon: Icons.storefront_rounded,
                title: 'Aucun prix pour vos cultures',
                message: 'Ajoutez une culture pour suivre son prix sur les marchés.',
                actionLabel: 'Voir les marchés',
                onAction: () => context.go('/markets'),
              ),
            ),
          )
        else ...[
          GroupedList(
            children: [
              for (final p in prices)
                GroupedRow(
                  leading: const IconTile(icon: Icons.sell_rounded, color: Color(0xFF3A5670)),
                  title: p.productName,
                  subtitle: [
                    if (p.marketsCount > 0) p.marketName,
                    if (p.date != null) Fmt.shortDay(p.date!),
                  ].join(' · '),
                  value: '${Fmt.grouped(p.price)} F/kg',
                  trailing: p.changePercent == null
                      ? null
                      : _Change(percent: p.changePercent!),
                  onTap: () => context.go('/markets'),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter + 4, Space.s, Space.gutter, 0),
            child: Text('Relevés indicatifs, non officiels.', style: T.caption(color: c.ink2, weight: 500)),
          ),
        ],
      ],
    );
  }
}

class _Change extends StatelessWidget {
  const _Change({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final up = percent >= 0;
    final color = up ? c.accent : c.clay;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: color),
          const SizedBox(width: 2),
          Text('${Fmt.decimal(percent.abs())} %', style: T.caption(color: color, weight: 700)),
        ],
      ),
    );
  }
}

// ───────────────────────── Activité ─────────────────────────

class _ActivitySection extends ConsumerWidget {
  const _ActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(activityFeedProvider);
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Activité récente'),
        feed.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Skeleton(height: 140, radius: 20),
          ),
          error: (e, _) => ErrorState(
            compact: true,
            message: 'L\'activité n\'a pas pu être chargée.',
            onRetry: () => ref.invalidate(cropsProvider),
          ),
          data: (events) {
            if (events.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: AppCard(
                  child: EmptyState(
                    compact: true,
                    icon: Icons.history_rounded,
                    title: 'Rien pour l\'instant',
                    message: 'Vos récoltes, ventes et dépenses apparaîtront ici.',
                  ),
                ),
              );
            }
            return GroupedList(
              children: [
                for (final e in events.take(5))
                  GroupedRow(
                    leading: IconTile(
                      icon: switch (e.kind) {
                        ActivityKind.harvest => Icons.agriculture_rounded,
                        ActivityKind.income => Icons.south_west_rounded,
                        ActivityKind.expense => Icons.north_east_rounded,
                      },
                      color: switch (e.kind) {
                        ActivityKind.harvest => c.accent,
                        ActivityKind.income => c.accent,
                        ActivityKind.expense => c.clay,
                      },
                    ),
                    title: e.title,
                    subtitle: Fmt.relativeDays(e.date),
                    value: switch (e.kind) {
                      ActivityKind.harvest => '+${Fmt.decimal(e.quantity ?? 0)} ${e.unit ?? ''}',
                      ActivityKind.income => '+${Fmt.grouped(e.amount ?? 0)} F',
                      ActivityKind.expense => '−${Fmt.grouped(e.amount ?? 0)} F',
                    },
                    valueColor: e.kind == ActivityKind.expense ? c.clay : c.accent,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
