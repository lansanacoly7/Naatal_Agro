import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../screens/guides/guides_screens.dart' show GuideSections;
import '../../../markets/data/markets_provider.dart';
import '../../../markets/data/models/product.dart';
import '../../data/guides_provider.dart';
import 'cultures_screen.dart' show guideForProduct, productImagePath;

/// Fiche unique d'une culture du catalogue : prix, cycle, itinéraire technique et sources,
/// avec un bouton pour la cultiver.
class CultureFicheScreen extends ConsumerWidget {
  const CultureFicheScreen({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guides = ref.watch(guidesNotifierProvider).guides;
    final guide = guideForProduct(product.name, guides);
    final detail = guide == null ? null : ref.watch(guideDetailProvider(guide.slug));
    final full = detail?.guide;
    final trend = product.trendPercentage;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 230,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
              title: Text(product.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(productImagePath(product), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.primary, child: const Icon(Icons.eco_rounded, color: Colors.white24, size: 90))),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.25), Colors.black.withValues(alpha: 0.7)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 18, 0, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  Row(
                    children: [
                      Expanded(child: _info('Prix indicatif', '${product.currentPrice.round()} F/kg', trend == 0 ? 'tendance inconnue' : '${trend > 0 ? '+' : '−'}${trend.abs().toStringAsFixed(1)} %', onTap: () {
                        ref.invalidate(allProductsProvider);
                        context.go('/markets');
                      })),
                      const SizedBox(width: 12),
                      Expanded(child: _info('Cycle', guide?.cycleDisplay ?? 'Non documenté', guide == null ? 'pas de fiche' : 'semis à récolte')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Prix de référence du catalogue : consultez les marchés pour les relevés réels.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/agriculture/add', extra: guide?.slug),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Cultiver ceci'),
                  ),
                  const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  if (guide == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: const Text(
                        'Pas encore de fiche technique pour cette culture. Posez la question à Naatal IA ou consultez un conseiller agricole (ANCAR, SAED).',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                      ),
                      ),
                    )
                  else if (full == null)
                    detail!.error != null
                        ? Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(detail.error!, style: const TextStyle(color: AppColors.textSecondary)))
                        : const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary)))
                  else ...[
                    if (full.summary.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                        child: Text(full.summary.trim(), style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary)),
                      ),
                    GuideSections(guide: full),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value, String caption, {VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.primary)),
            const SizedBox(height: 2),
            Text(caption, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}
