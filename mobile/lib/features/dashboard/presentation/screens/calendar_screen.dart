import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../screens/markets/markets_data.dart';
import '../../../../ui/ui.dart';
import '../../../agriculture/data/agriculture_provider.dart';
import '../../../agriculture/data/models/crop.dart';

/// Calendrier cultural : suivi visuel clair des parcelles en cours et dates clés.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final cropsAsync = ref.watch(cropsProvider);

    return LargeTitleScaffold(
      title: 'Calendrier cultural',
      reserveNav: false,
      onRefresh: () async => ref.invalidate(cropsProvider),
      bottom: Container(
        padding: EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, MediaQuery.paddingOf(context).bottom + Space.m),
        decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
        child: PillButton(
          label: 'Ajouter une culture',
          icon: Icons.add_rounded,
          expand: true,
          onPressed: () => context.push('/agriculture/add'),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: cropsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(Space.gutter),
              child: Skeleton(height: 240, radius: 24),
            ),
            error: (err, _) => ErrorState(
              message: 'Impossible de charger le calendrier de vos cultures.',
              onRetry: () => ref.invalidate(cropsProvider),
            ),
            data: (crops) {
              if (crops.isEmpty) {
                return const EmptyState(
                  imageAsset: 'assets/images/ui/ui_premiere_culture.jpg',
                  icon: Icons.calendar_month_rounded,
                  title: 'Aucune culture en cours',
                  message: 'Ajoutez une parcelle pour générer automatiquement son calendrier de semis et de récolte.',
                );
              }

              // Trouver la prochaine récolte
              Crop? nextHarvest;
              int minDays = 99999;
              final now = DateTime.now();
              for (final crop in crops) {
                final harvest = crop.parsedHarvestDate;
                if (harvest != null && harvest.isAfter(now)) {
                  final days = harvest.difference(now).inDays;
                  if (days < minDays) {
                    minDays = days;
                    nextHarvest = crop;
                  }
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bannière résumé
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.xl),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/ui/ui_cultures.jpg'),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: c.isDark ? 0.3 : 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(Space.l),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Radii.xl),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
                          ),
                        ),
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${crops.length} parcelle${crops.length > 1 ? 's' : ''} en suivi',
                              style: T.caption(color: Colors.white.withValues(alpha: 0.85), weight: 700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextHarvest != null
                                  ? 'Prochaine récolte : ${nextHarvest.name} dans $minDays j'
                                  : 'Toutes vos parcelles sont à jour',
                              style: T.body(color: Colors.white, weight: 800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SectionHeader('Vos parcelles'),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    child: Column(
                      children: [
                        for (var i = 0; i < crops.length; i++) ...[
                          Reveal(
                            index: i,
                            child: _CropCalendarCard(crop: crops[i]),
                          ),
                          const SizedBox(height: Space.m),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xxl),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CropCalendarCard extends StatelessWidget {
  const _CropCalendarCard({required this.crop});

  final Crop crop;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final img = productImageForName(crop.name);
    final isHarvested = crop.status == 'harvested';
    final progress = crop.calculatedProgress.clamp(0.0, 1.0);
    final daysLeft = crop.daysToHarvest;

    return AppCard(
      onTap: () => context.push('/crop_detail', extra: crop),
      padding: const EdgeInsets.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.m),
                child: Container(
                  width: 52,
                  height: 52,
                  color: c.surfaceAlt,
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    img,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.eco_rounded, size: 28, color: c.accent),
                  ),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crop.name,
                      style: T.body(color: c.ink, weight: 800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${crop.areaSize.toStringAsFixed(crop.areaSize.truncateToDouble() == crop.areaSize ? 0 : 1)} ha · ${crop.location.isNotEmpty ? crop.location : "Parcelle"}',
                      style: T.caption(color: c.ink2, weight: 500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isHarvested
                      ? c.accent.withValues(alpha: c.isDark ? 0.25 : 0.12)
                      : (daysLeft != null && daysLeft <= 14
                          ? c.clay.withValues(alpha: c.isDark ? 0.25 : 0.12)
                          : c.slate.withValues(alpha: c.isDark ? 0.25 : 0.12)),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  isHarvested
                      ? 'Récoltée'
                      : (daysLeft != null
                          ? (daysLeft == 0 ? 'Récolte ajd' : 'J-$daysLeft')
                          : crop.calculatedPhase),
                  style: T.caption(
                    color: isHarvested
                        ? c.accent
                        : (daysLeft != null && daysLeft <= 14 ? c.clay : c.slate),
                    weight: 800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),

          // Barre de progression
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: isHarvested ? 1.0 : progress,
              minHeight: 8,
              backgroundColor: c.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(isHarvested ? c.accent : c.accent),
            ),
          ),
          const SizedBox(height: Space.m),

          // 3 Jalons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Milestone(
                icon: Icons.spa_rounded,
                label: 'Semis',
                date: _formatDate(crop.plantingDate),
                color: c.ink2,
              ),
              _Milestone(
                icon: Icons.grain_rounded,
                label: 'Phase',
                date: crop.calculatedPhase,
                color: c.accent,
                highlight: true,
              ),
              _Milestone(
                icon: Icons.agriculture_rounded,
                label: isHarvested ? 'Récoltée' : 'Récolte',
                date: _formatDate(crop.expectedHarvestDate),
                color: isHarvested ? c.accent : c.clay,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(String iso) {
    if (iso.isEmpty) return 'Non fixée';
    try {
      final parts = iso.split('-');
      if (parts.length >= 3) {
        final d = parts[2].substring(0, 2);
        final m = _monthShort(int.tryParse(parts[1]) ?? 0);
        return '$d $m';
      }
    } catch (_) {}
    return iso;
  }

  static String _monthShort(int m) {
    const months = ['janv', 'févr', 'mars', 'avr', 'mai', 'juin', 'juil', 'août', 'sept', 'oct', 'nov', 'déc'];
    return (m >= 1 && m <= 12) ? months[m - 1] : '';
  }
}

class _Milestone extends StatelessWidget {
  const _Milestone({
    required this.icon,
    required this.label,
    required this.date,
    required this.color,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String date;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: highlight ? color : c.ink2),
            const SizedBox(width: 4),
            Text(label, style: T.caption(color: c.ink2, weight: 600)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          date,
          style: T.caption(color: highlight ? color : c.ink, weight: highlight ? 800 : 700),
        ),
      ],
    );
  }
}
