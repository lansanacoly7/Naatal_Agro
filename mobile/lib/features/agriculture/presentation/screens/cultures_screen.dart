import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../ui/ui.dart';
import '../../../markets/data/markets_provider.dart';
import '../../../markets/data/models/product.dart';
import '../../data/agriculture_provider.dart';
import '../../data/guides_provider.dart';
import '../../data/models/agronomic_guide.dart';
import '../../data/models/crop.dart';

String _plain(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c');

/// Fiche technique correspondant à un produit du catalogue (null si aucune n'est documentée).
AgronomicGuide? guideForProduct(String productName, List<AgronomicGuide> guides) {
  final p = _plain(productName).trim();
  if (p.length < 3) return null;
  final first = p.split(RegExp(r'\s+')).first;
  for (final g in guides) {
    final n = _plain(g.name);
    if (n == p || n.startsWith(p) || p.startsWith(n.split(RegExp(r'[\s(]+')).first) && n.split(RegExp(r'[\s(]+')).first.length >= 3) return g;
  }
  for (final g in guides) {
    if (first.length >= 4 && _plain(g.name).contains(first)) return g;
  }
  return null;
}

/// Chemin de l'image d'un produit : celui du catalogue, sinon `assets/images/products/<nom>.png`
/// (nom en minuscules, sans accent, espaces remplacés par « _ »). Un fichier absent affiche l'icône feuille.
String productImagePath(Product p) {
  if (p.imageAsset.isNotEmpty) return p.imageAsset;
  final slug = _plain(p.name).trim().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.isEmpty ? '' : 'assets/images/products/$slug.png';
}

/// Page Cultures : « Mon exploitation » (mes cultures) et « Découvrir » (catalogue).
class CulturesScreen extends ConsumerStatefulWidget {
  const CulturesScreen({super.key});

  @override
  ConsumerState<CulturesScreen> createState() => _CulturesScreenState();
}

class _CulturesScreenState extends ConsumerState<CulturesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Cultures', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ),
                  IconButton(
                    tooltip: 'Fiches techniques',
                    icon: const Icon(Icons.menu_book_rounded, color: AppColors.primary),
                    onPressed: () => context.push('/agriculture/guides'),
                  ),
                  IconButton(
                    tooltip: 'Ajouter une culture',
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    onPressed: () => context.push('/agriculture/add'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.surfaceVariant.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    _segment('Mon exploitation', 0),
                    _segment('Découvrir', 1),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _tab == 0
                    ? _MyFarm(key: const ValueKey('farm'), onDiscover: () => setState(() => _tab = 1))
                    : const _Discover(key: ValueKey('discover')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, int index) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: selected ? AppColors.primary : AppColors.textSecondary)),
        ),
      ),
    );
  }
}

// ───────────────────────── Mon exploitation ─────────────────────────

class _MyFarm extends ConsumerStatefulWidget {
  const _MyFarm({super.key, required this.onDiscover});

  final VoidCallback onDiscover;

  @override
  ConsumerState<_MyFarm> createState() => _MyFarmState();
}

class _MyFarmState extends ConsumerState<_MyFarm> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(cropsProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(cropsProvider),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator(color: AppColors.primary))]),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 60),
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text('Vos cultures n\'ont pas pu être chargées.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Center(child: ElevatedButton(onPressed: () => ref.invalidate(cropsProvider), style: ElevatedButton.styleFrom(minimumSize: const Size(160, 48)), child: const Text('Réessayer'))),
          ],
        ),
        data: (crops) => crops.isEmpty ? _empty(context) : _list(context, crops),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: EmptyState(
            imageAsset: 'assets/images/ui/ui_premiere_culture.jpg',
            title: 'Votre exploitation est vide',
            message: 'Ajoutez ce que vous cultivez pour suivre vos travaux, vos dates de récolte et les cours des marchés.',
            actionLabel: 'Ajouter ma première culture',
            onAction: () => context.push('/agriculture/add'),
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, List<Crop> crops) {
    final active = crops.where((c) => c.status.toLowerCase() != 'harvested').toList();
    final area = active.fold<double>(0, (a, c) => a + c.areaSize);
    final soon = active.map((c) => c.daysToHarvest).whereType<int>().where((d) => d >= 0).toList()..sort();
    final shown = switch (_filter) {
      'active' => active,
      'done' => crops.where((c) => c.status.toLowerCase() == 'harvested').toList(),
      _ => crops,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // Synthèse
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(22)),
          child: Row(
            children: [
              _stat('${active.length}', active.length > 1 ? 'cultures en cours' : 'culture en cours'),
              _divider(),
              _stat(area == 0 ? '—' : '${area.toStringAsFixed(area.truncateToDouble() == area ? 0 : 1)} ha', 'surface'),
              _divider(),
              _stat(soon.isEmpty ? '—' : (soon.first == 0 ? 'Aujourd\'hui' : 'J-${soon.first}'), 'prochaine récolte'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterButton('Toutes', '${crops.length}', 'all', Icons.grid_view_rounded),
              _filterButton('En cours', '${active.length}', 'active', Icons.grass_rounded),
              _filterButton('Récoltées', '${crops.length - active.length}', 'done', Icons.check_circle_rounded),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (shown.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Text('Aucune culture dans cette catégorie.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)))
        else
          for (final c in shown) ...[
            _CropCard(crop: c),
            const SizedBox(height: 14),
          ],
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => context.push('/agriculture/add'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter une culture'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22))),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5)),
          ],
        ),
      );

  Widget _divider() => Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.25));

  Widget _filterButton(String label, String count, String value, IconData icon) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? AppColors.primary : Colors.grey.withValues(alpha: 0.2)),
            boxShadow: selected
                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textPrimary),
              const SizedBox(width: 6),
              Text(
                '$label ($count)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropCard extends StatelessWidget {
  const _CropCard({required this.crop});

  final Crop crop;

  @override
  Widget build(BuildContext context) {
    final harvested = crop.status.toLowerCase() == 'harvested';
    final days = crop.daysToHarvest;
    final progress = harvested ? 1.0 : (crop.progressOrNull ?? 0.0);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/crop_detail', extra: crop),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo plein cadre (hauteur 145) avec dégradé et badges lisibles
              SizedBox(
                height: 145,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      crop.imageAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        child: const Center(
                          child: Icon(Icons.eco_rounded, color: AppColors.primary, size: 48),
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.20),
                            Colors.black.withValues(alpha: 0.78),
                          ],
                          stops: const [0.2, 0.5, 1.0],
                        ),
                      ),
                    ),
                    // Badge Surface & Emplacement en haut à gauche
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.landscape_rounded, color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              '${crop.areaSize.toStringAsFixed(crop.areaSize.truncateToDouble() == crop.areaSize ? 0 : 1)} ha${crop.location.isNotEmpty ? " · ${crop.location}" : ""}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Grand Décompte ou Grande Coche Récoltée en bas
                    Positioned(
                      bottom: 12,
                      left: 14,
                      right: 14,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              crop.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 19,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (harvested)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B5E20),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 5),
                                  Text(
                                    'Récoltée',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer_outlined, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  Text(
                                    days == null
                                        ? 'À prévoir'
                                        : days < 0
                                            ? 'J+${-days}'
                                            : days == 0
                                                ? 'Aujourd\'hui'
                                                : '$days j',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Progression & Dates
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          harvested
                              ? 'Cycle terminé'
                              : days == null
                                  ? 'Dates à renseigner'
                                  : days < 0
                                      ? 'Récolte attendue il y a ${-days} j'
                                      : days == 0
                                          ? 'Récolte aujourd\'hui !'
                                          : 'Récolte dans $days jours',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: harvested ? AppColors.textSecondary : AppColors.primary,
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()} %',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          harvested ? const Color(0xFF6FD3A0) : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Découvrir ─────────────────────────

class _Discover extends ConsumerStatefulWidget {
  const _Discover({super.key});

  @override
  ConsumerState<_Discover> createState() => _DiscoverState();
}

class _DiscoverState extends ConsumerState<_Discover> {
  static const _categories = ['Tout', 'Céréales', 'Fruits', 'Légumes', 'Tubercules'];
  String _category = 'Tout';
  String _query = '';

  bool _matchesCategory(Product p) {
    final c = _plain(p.category);
    return switch (_category) {
      'Céréales' => c.contains('cereale'),
      'Fruits' => c.contains('fruit'),
      'Légumes' => c.contains('legume'),
      'Tubercules' => c.contains('tubercule'),
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allProductsProvider);
    final guides = ref.watch(guidesNotifierProvider).guides;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(hintText: 'Rechercher une culture', prefixIcon: Icon(Icons.search_rounded)),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final selected = _category == _categories[i];
              return GestureDetector(
                onTap: () => setState(() => _category = _categories[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? AppColors.primary : Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Text(_categories[i], style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? Colors.white : AppColors.textPrimary)),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Le catalogue n\'a pas pu être chargé.', style: TextStyle(color: AppColors.textSecondary)),
                  TextButton(onPressed: () => ref.invalidate(allProductsProvider), child: const Text('Réessayer')),
                ],
              ),
            ),
            data: (products) {
              final q = _plain(_query.trim());
              final shown = products.where((p) => _matchesCategory(p) && (q.isEmpty || _plain(p.name).contains(q))).toList();
              // Les cultures illustrées ou avec fiche technique d'abord, puis l'ordre alphabétique.
              shown.sort((a, b) {
                int score(Product p) => (p.imageAsset.isNotEmpty ? 2 : 0) + (guideForProduct(p.name, guides) != null ? 1 : 0);
                final byScore = score(b).compareTo(score(a));
                return byScore != 0 ? byScore : a.name.compareTo(b.name);
              });
              if (shown.isEmpty) {
                return const Center(child: Text('Aucune culture ne correspond.', style: TextStyle(color: AppColors.textSecondary)));
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.74),
                itemCount: shown.length,
                itemBuilder: (context, i) => _ProductCard(product: shown[i], guide: guideForProduct(shown[i].name, guides)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.guide});

  final Product product;
  final AgronomicGuide? guide;

  @override
  Widget build(BuildContext context) {
    final trend = product.trendPercentage;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/agriculture/culture', extra: product),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: productImagePath(product).isEmpty
                          ? _placeholder()
                          : Image.asset(productImagePath(product), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder()),
                    ),
                    if (trend != 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(10)),
                          child: Text('${trend > 0 ? '+' : '−'}${trend.abs().toStringAsFixed(1)} %', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: trend > 0 ? AppColors.primary : AppColors.error)),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.name.split(RegExp(r'\s+')).first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${product.currentPrice.round()} F/kg', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary)),
                          const Text('prix indicatif', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                        ],
                      ),
                      Text(
                        guide?.cycleDisplay != null ? 'Cycle ${guide!.cycleDisplay}' : 'Cycle non documenté',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.primary.withValues(alpha: 0.08),
        child: const Center(child: Icon(Icons.eco_rounded, color: AppColors.primary, size: 36)),
      );
}
